import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../components/index.dart';
import '../main.dart';
import '../theme/colors.dart';
import '../services/douyin_share_resolver.dart';
import '../services/douyin_web_extractor.dart';
import '../services/ecommerce_material_import_service.dart';
import '../services/webview_js.dart';
import '../utils/utils.dart';

/// 浏览器页的工作模式。
enum BrowserMode {
  /// 纯浏览器，不自动提取任何东西。
  plain,

  /// 抖音视频页：轮询读出 `<video>` 的 src 并抓取页面文案。
  douyinVideo,

  /// 微购相册：用户在页面里登录（手机号+密码）后进入商品列表。
  /// 商品字段的提取规则需要真实页面结构，所以这里先提供"转存页面结构"。
  szwego,
}

/// 浏览器页返回给调用方的结果。
class BrowserResult {
  /// 停在哪个地址（短链会跳转，这里记的是最终地址）。
  final String finalUrl;

  /// 页面 `<video>` 的 src，抖音模式拿到才有值。
  final String? videoSrc;

  /// 渲染后页面里的文案，抖音模式拿到才有值。
  final DouyinWebMeta? meta;

  const BrowserResult({required this.finalUrl, this.videoSrc, this.meta});

  bool get hasVideo => videoSrc != null && videoSrc!.trim().isNotEmpty;

  /// 从 [videoSrc] 里抠出的 video_id，拿去拼无水印地址。
  String? get videoId => DouyinShareResolver.videoIdFromSrc(videoSrc);
}

/// 微购相册网页版的地址。PC 端登录入口，支持手机号+密码。
const String kSzwegoUrl = 'https://www.szwego.com/';

/// 打开微购相册网页版，用于登录并读取自己 ID 下的商品列表。
Future<void> openSzwegoBrowser(BuildContext context) => Navigator.push(
  context,
  MaterialPageRoute(
    builder:
        (_) => const BrowserPage(
          initialUrl: kSzwegoUrl,
          title: '微购相册',
          mode: BrowserMode.szwego,
        ),
  ),
);

/// 抖音素材导入的完整流程：展开短链 → 内嵌浏览器取 video_id → 下载无水印视频。
///
/// 返回 null 表示**没走通浏览器这条路**（用户取消 / 短链展不开 / 页面上没出现
/// 视频）。调用方应当回落到原来的 HTTP 路径，而不是直接判定失败——那样
/// 至少还能拿到文案，也便于给出更准确的原因。
Future<EcommerceMaterialImportResult?> importDouyinViaBrowser({
  required BuildContext context,
  required Uri sourceUrl,
  required String docDir,
  int maxImages = EcommerceMaterialImportService.defaultMaxImages,
}) async {
  var awemeId = DouyinShareResolver.awemeIdFromUrl(sourceUrl.toString());
  if (awemeId == null) {
    final expanded = await EcommerceMaterialImportService.expandDouyinShortLink(
      sourceUrl,
    );
    if (expanded != null) {
      awemeId = DouyinShareResolver.awemeIdFromUrl(expanded.toString());
    }
  }
  if (awemeId == null) return null;
  final id = awemeId;

  final browserResult = await Navigator.push<BrowserResult>(
    context,
    MaterialPageRoute(
      builder:
          (_) => BrowserPage(
            initialUrl: DouyinShareResolver.videoPageUrl(id).toString(),
            title: '解析抖音视频',
            mode: BrowserMode.douyinVideo,
          ),
    ),
  );

  final videoId = browserResult?.videoId;
  if (videoId == null) return null;

  return EcommerceMaterialImportService.importFromDouyinWeb(
    sourceUrl: sourceUrl,
    awemeId: id,
    videoId: videoId,
    title: browserResult?.meta?.title ?? '',
    description: browserResult?.meta?.description ?? '',
    docDir: docDir,
  );
}

/// 通用内嵌浏览器。
///
/// 为什么需要它：抖音分享页的 HTML 里已无任何媒体地址，微购相册
/// (szwego.com) 是纯 React SPA——两者都必须在真实浏览器里渲染出内容
/// 才能读到数据。把浏览器留在界面上（而不是藏在后台）还有一个额外好处：
/// 平台要登录或验证码时，用户可以直接在页面上操作。
///
/// **不要等 onPageFinished**：实测抖音视频页会持续流式加载，加载完成事件
/// 要么迟迟不来、要么来得太早（`<video>` 还没挂上）。这里一律用轮询。
class BrowserPage extends StatefulWidget {
  final String initialUrl;
  final String title;
  final BrowserMode mode;

  const BrowserPage({
    Key? key,
    required this.initialUrl,
    required this.title,
    this.mode = BrowserMode.plain,
  }) : super(key: key);

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  late final WebViewController _controller;

  double _progress = 0;
  String _currentUrl = '';
  String _status = '';
  bool _extractFailed = false;
  bool _finishing = false;

  Timer? _poll;
  DateTime? _startedAt;

  bool get _isDouyin => widget.mode == BrowserMode.douyinVideo;
  bool get _isSzwego => widget.mode == BrowserMode.szwego;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.initialUrl;

    if (_isSzwego) {
      _status = '请在页面里用「手机号 + 密码」登录。登录状态会保存在本机，下次不用重登。';
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(C.bgCard)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (!mounted) return;
            setState(() => _progress = p / 100);
          },
          onPageStarted: (url) {
            if (!mounted) return;
            setState(() {
              _currentUrl = url;
              _progress = 0;
            });
          },
          onPageFinished: (url) {
            if (!mounted) return;
            setState(() => _currentUrl = url);
          },
          onWebResourceError: (error) {
            // 只在确定是主文档加载失败时提示；子资源失败（图片/埋点）不影响使用。
            // isForMainFrame 是可空的，用 != true 而不是 !，避免 null 时抛异常。
            if (!mounted || error.isForMainFrame != true) return;
            setState(() => _status = '页面加载失败：${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));

    if (_isDouyin) _startPolling();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _poll?.cancel();
    _startedAt = DateTime.now();
    if (!mounted) return;
    setState(() {
      _extractFailed = false;
      _status = '正在解析视频…';
    });

    _poll = Timer.periodic(DouyinWebExtractor.pollInterval, (_) async {
      if (!mounted || _finishing) return;

      final elapsed = DateTime.now().difference(_startedAt!);
      if (elapsed > DouyinWebExtractor.timeout) {
        _poll?.cancel();
        if (!mounted) return;
        setState(() {
          _extractFailed = true;
          _status = '没能自动解析出视频。可以在这个页面上手动操作，然后点「重新解析」。';
        });
        return;
      }

      String src = '';
      try {
        final raw = await _controller.runJavaScriptReturningResult(
          DouyinWebExtractor.videoSrcJs,
        );
        src = DouyinWebExtractor.unwrapJsString('$raw');
      } catch (_) {
        // 页面还在导航中时注入会失败，下一轮再试
        return;
      }

      if (src.isEmpty || !src.contains('video_id=')) return;
      await _finishWith(videoSrc: src);
    });
  }

  Future<void> _finishWith({String? videoSrc}) async {
    if (_finishing) return;
    _finishing = true;
    _poll?.cancel();

    DouyinWebMeta? meta;
    try {
      final raw = await _controller.runJavaScriptReturningResult(
        DouyinWebExtractor.metaJs,
      );
      meta = DouyinWebExtractor.parseMeta('$raw');
    } catch (_) {
      // 文案拿不到不算失败，视频才是主要目标
    }

    if (!mounted) return;
    Navigator.pop(
      context,
      BrowserResult(
        finalUrl: _currentUrl,
        videoSrc: videoSrc,
        meta: meta,
      ),
    );
  }

  /// 用户手动触发：拿当前页面再试一次。
  Future<void> _extractNow() async {
    String src = '';
    try {
      final raw = await _controller.runJavaScriptReturningResult(
        DouyinWebExtractor.videoSrcJs,
      );
      src = DouyinWebExtractor.unwrapJsString('$raw');
    } catch (e) {
      if (mounted) toast(context, '读取页面失败：$e');
      return;
    }
    if (src.isEmpty || !src.contains('video_id=')) {
      _startPolling();
      if (mounted) toast(context, '页面上还没出现视频，已重新开始解析');
      return;
    }
    await _finishWith(videoSrc: src);
  }

  /// 微购相册：把当前页面的完整 DOM 导出成 html 文件并分享出去。
  ///
  /// 商品字段的提取规则必须照着真实结构写，而登录后才能看到商品列表——
  /// 所以先把结构转存出来，再据此编写解析。
  Future<void> _dumpStructure() async {
    setState(() => _status = '正在导出页面结构…');
    String html = '';
    try {
      final raw = await _controller.runJavaScriptReturningResult(
        'document.documentElement.outerHTML',
      );
      html = unwrapWebViewString('$raw');
    } catch (e) {
      if (mounted) setState(() => _status = '导出失败：$e');
      return;
    }

    if (html.isEmpty) {
      if (mounted) setState(() => _status = '页面还是空的，等加载完再试一次。');
      return;
    }

    try {
      final now = DateTime.now();
      final name =
          'szwego_页面结构_${now.year}${_two(now.month)}${_two(now.day)}_'
          '${_two(now.hour)}${_two(now.minute)}${_two(now.second)}.html';
      final file = File('$gDocDir/$name');
      await file.writeAsString(html);
      if (!mounted) return;

      final box = context.findRenderObject() as RenderBox?;
      final origin =
          box == null
              ? const Rect.fromLTWH(0, 0, 1, 1)
              : box.localToGlobal(Offset.zero) & box.size;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: '微购相册页面结构（用于编写商品解析规则）',
          sharePositionOrigin: origin,
        ),
      );
      if (mounted) {
        setState(
          () => _status = '已导出 ${(html.length / 1024).toStringAsFixed(0)}KB。'
              '把文件发给我就能写商品解析规则了。',
        );
      }
    } catch (e) {
      if (mounted) setState(() => _status = '保存/分享失败：$e');
    }
  }

  static String _two(int v) => v.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) => appScaffold(
    context,
    widget.title,
    Column(
      children: [
        if (_progress > 0 && _progress < 1)
          LinearProgressIndicator(
            value: _progress,
            backgroundColor: C.border,
            valueColor: AlwaysStoppedAnimation<Color>(C.purple),
            minHeight: 2,
          ),
        if ((_isDouyin || _isSzwego) && _status.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
            color:
                _extractFailed
                    ? C.orange.withValues(alpha: 0.12)
                    : C.hudDark2,
            child: Row(
              children: [
                if (_isDouyin && !_extractFailed)
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.6,
                      color: C.purple,
                    ),
                  )
                else
                  Icon(
                    _extractFailed
                        ? Icons.info_outline_rounded
                        : Icons.lock_outline_rounded,
                    size: 14,
                    color: _extractFailed ? C.orange : C.t3,
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _status,
                    style: TextStyle(fontSize: 11, color: C.t2, height: 1.4),
                  ),
                ),
                if (_isDouyin && _extractFailed)
                  TextButton(
                    onPressed: _extractNow,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                    ),
                    child: Text(
                      '重新解析',
                      style: TextStyle(fontSize: 12, color: C.purple),
                    ),
                  ),
                if (_isSzwego)
                  TextButton(
                    onPressed: _dumpStructure,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                    ),
                    child: Text(
                      '转存页面结构',
                      style: TextStyle(fontSize: 12, color: C.purple),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: WebViewWidget(controller: _controller),
        ),
      ],
    ),
    trailing: RoundIconButton(
      icon: Icons.refresh_rounded,
      onTap: () {
        _controller.reload();
        if (_isDouyin) _startPolling();
      },
    ),
  );
}
