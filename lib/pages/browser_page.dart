import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// 桌面 Chrome 的 UA，只给微购相册用。
///
/// 该站按 UA 判设备：认出手机就只渲染一页「请在电脑上打开，或使用App」。
/// 实测同一个 URL，桌面 UA 出 1.44MB 正常页面（含手机号/密码表单），
/// WebView 的默认 UA（带 `; wv)` 标记）被拦。
///
/// 这不是绕过什么权限，就是浏览器里的「请求桌面版网站」。
const String _kDesktopUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

/// 把 `navigator.userAgentData` 覆盖成桌面。
///
/// 挂在 `Navigator.prototype` 和实例上都试一遍：不同 Chromium 版本放的位置不一样。
/// `configurable: true` 是为了可重复注入。整段包在 try 里，任何一步失败都不该
/// 影响页面本身。
const String _kDesktopIdentityJs = r'''
(function () {
  var def = function (o, k, v) {
    try { Object.defineProperty(o, k, { get: function () { return v; }, configurable: true }); } catch (e) {}
  };

  // 1) Client Hints。改 UA 字符串改不动这个，手机上照样报 mobile/Android。
  var fake = {
    mobile: false,
    platform: 'Windows',
    brands: [
      { brand: 'Chromium', version: '120' },
      { brand: 'Not_A Brand', version: '8' }
    ],
    getHighEntropyValues: function () { return Promise.resolve(fake); }
  };
  def(navigator, 'userAgentData', fake);
  try { def(Navigator.prototype, 'userAgentData', fake); } catch (e) {}
  def(navigator, 'platform', 'Win32');

  // 2) 触摸能力。**这条才是关键**：实测拦截页出现时 maxTouchPoints 是 5
  //    （手机），桌面是 0。前两条伪装成功后仍然被拦，就卡在这里。
  def(navigator, 'maxTouchPoints', 0);
  def(navigator, 'msMaxTouchPoints', 0);
  try { delete window.ontouchstart; } catch (e) { window.ontouchstart = undefined; }
  try { delete window.ontouchforcechange; } catch (e) {}

  // 3) matchMedia。CSS 的 pointer/hover 媒体特性也是按触摸判的，
  //    只改 maxTouchPoints 骗不过它。把返回的 MediaQueryList 换成一个
  //    哑对象——页面只用它读 matches，不会真的去监听变化。
  var dummy = function (q, m) {
    return {
      matches: m, media: q, onchange: null,
      addListener: function () {}, removeListener: function () {},
      addEventListener: function () {}, removeEventListener: function () {},
      dispatchEvent: function () { return false; }
    };
  };
  var mm = window.matchMedia ? window.matchMedia.bind(window) : null;
  if (mm) {
    window.matchMedia = function (q) {
      var s = String(q).toLowerCase();
      if (s.indexOf('coarse') >= 0) return dummy(q, false);
      if (s.indexOf('pointer: fine') >= 0 || s.indexOf('hover: hover') >= 0) return dummy(q, true);
      if (s.indexOf('pointer: none') >= 0) return dummy(q, false);
      return mm(q);
    };
  }
})();
''';

/// 打开微购相册网页版，用于登录并读取自己 ID 下的商品列表。
///
/// 走**原生 WebView**（`SzwegoActivity`），不用 Flutter 的 webview_flutter。
/// 原因见那个类的注释：该站按运行环境判设备，只有在原生
/// `shouldInterceptRequest` 里"只改主文档内容、其余保持原生"，URL 和 origin
/// 才是真的——而保住 origin 是登录态能持久化的前提。
Future<void> openSzwegoBrowser(BuildContext context) async {
  try {
    await const MethodChannel(
      'ipad_boss_app/gallery',
    ).invokeMethod<bool>('openSzwego');
  } on MissingPluginException {
    if (context.mounted) toast(context, '打不开微购相册：当前版本不支持');
  } on PlatformException catch (e) {
    if (context.mounted) toast(context, '打不开微购相册：${e.message}');
  }
}

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
            // 越早越好：拦截逻辑在页面自己的 bundle 里，要赶在它执行之前。
            if (_isSzwego) _spoofDesktopIdentity();
          },
          onPageFinished: (url) {
            if (!mounted) return;
            setState(() => _currentUrl = url);
            if (_isSzwego) _reportIdentity();
          },
          onWebResourceError: (error) {
            // 只在确定是主文档加载失败时提示；子资源失败（图片/埋点）不影响使用。
            // isForMainFrame 是可空的，用 != true 而不是 !，避免 null 时抛异常。
            if (!mounted || error.isForMainFrame != true) return;
            setState(() => _status = '页面加载失败：${error.description}');
          },
        ),
      );

    // UA 必须在第一次请求之前设好，否则首个请求已经带着默认 UA 出去了。
    _bootstrap();
    if (_isDouyin) _startPolling();
  }

  /// 设好 UA 再加载。为什么要单独一步见 [_kDesktopUserAgent] 的说明。
  Future<void> _bootstrap() async {
    if (_isSzwego) {
      await _controller.setUserAgent(_kDesktopUserAgent);
      // PC 版按桌面宽度排版，在手机屏上必须能缩放才看得清。
      await _controller.enableZoom(true);
      // 先试"脚本内联进 head"这条路，它保证伪装在页面任何脚本之前执行。
      final html = await _fetchWithInlineSpoof(widget.initialUrl);
      if (html != null) {
        if (!mounted) return;
        await _controller.loadHtmlString(html, baseUrl: kSzwegoUrl);
        return;
      }
    }
    if (!mounted) return;
    await _controller.loadRequest(Uri.parse(widget.initialUrl));
  }

  /// 取回 HTML，把伪装脚本插到 `<head>` 开头，再交给 WebView 渲染。
  ///
  /// 为什么不走 `onPageStarted` + `runJavaScript`：那条路要走两个平台通道来回，
  /// 实测注入虽然生效（诊断能读到改后的值），但拦截页已经渲染完了——**跑晚了**。
  /// 内联进 HTML 就没有时序问题：它在文档解析到 head 时就执行，必然早于任何页面脚本。
  ///
  /// baseUrl 传站点根地址，`loadHtmlString` 底层走 `loadDataWithBaseURL`，
  /// 文档的 origin 因此是 szwego.com，页面自己的 XHR 和 Cookie 才能正常工作。
  ///
  /// 拿不到 HTML 就返回 null，调用方退回普通的 `loadRequest`——注入只是加分项，
  /// 不该让页面打不开。
  Future<String?> _fetchWithInlineSpoof(String url) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(Uri.parse(url));
      request.followRedirects = true;
      request.maxRedirects = 5;
      request.headers.set(HttpHeaders.userAgentHeader, _kDesktopUserAgent);
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 20));

      final head = body.indexOf('<head>');
      if (head < 0) return null;
      final at = head + '<head>'.length;
      return body.replaceRange(at, at, '<script>$_kDesktopIdentityJs</script>');
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// 把 Client Hints 也伪装成桌面。
  ///
  /// `setUserAgent` 只改 UA 字符串，`navigator.userAgentData` 是另一套，
  /// 手机上照样报 `mobile: true / platform: Android`。实测三者对照：
  ///
  /// | UA 字符串 | Client Hints | 结果 |
  /// |---|---|---|
  /// | 桌面 | 桌面 | 放行 |
  /// | 桌面 | 手机 | 拦截 |
  /// | 手机 | 手机 | 拦截 |
  ///
  /// 所以要两边都像电脑。在 `onPageStarted` 注入，抢在对方的 bundle 之前执行。
  Future<void> _spoofDesktopIdentity() async {
    try {
      await _controller.runJavaScript(_kDesktopIdentityJs);
    } catch (_) {
      // 注入失败就让它按原样加载，不阻断流程——reportIdentity 会把结果读出来。
    }
  }

  /// 临时诊断：把 WebView 实际的身份读出来。
  ///
  /// 微购相册的拦截判据看的是 `navigator.userAgent` 字符串，所以只要 UA 真的
  /// 换成了桌面版就不该被拦。读出来是为了区分「UA 没设上」和「设上了但另有判据」
  /// ——这两种情况的修法完全不同。定位完就删。
  Future<void> _reportIdentity() async {
    try {
      final raw = await _controller.runJavaScriptReturningResult(
        'JSON.stringify({'
        'mobile:(navigator.userAgentData&&navigator.userAgentData.mobile),'
        'href:location.href,'
        'title:document.title,'
        'htmlLen:document.documentElement.outerHTML.length,'
        'frames:window.frames.length,'
        'touch:navigator.maxTouchPoints,'
        'inHtml:document.documentElement.outerHTML.indexOf("请在电脑上打开")>=0,'
        'inText:document.body.innerText.indexOf("请在电脑上打开")>=0,'
        'txt:document.body.innerText.slice(0,60)'
        '})',
      );
      if (!mounted) return;
      setState(() => _status = '诊断 ${unwrapWebViewString("$raw")}');
    } catch (e) {
      if (mounted) setState(() => _status = '诊断失败：$e');
    }
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
