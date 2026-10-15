import 'dart:convert';

import 'webview_js.dart';

/// 从渲染后的抖音页面里提取信息（纯逻辑，不依赖 WebView）。
///
/// 为什么要靠 WebView：抖音分享页的 HTML 里已经**没有任何媒体地址**
/// （`play_addr`/`url_list`/`video_id`/`og:video` 全为 0，`_ROUTER_DATA`
/// 和 `_SSR_DATA` 都是空壳）。唯一的出路是让页面自己的 JS 去算签名，
/// 我们从渲染结果里把 `video_id` 读出来。
///
/// 附带好处：渲染后的页面能拿到**真实文案**，而 HTTP 抓取只能拿到
/// "于xxxxxxxx发布在抖音，已经收获了N个喜欢" 这种模板句。
///
/// 这个文件只负责「注入什么 JS」和「怎么解析返回值」，WebView 由
/// `pages/browser_page.dart` 提供。纯逻辑部分可以单测。
class DouyinWebExtractor {
  /// 读 `<video>` 的 src。页面没挂上视频时返回空串。
  ///
  /// 实测桌面站会给出 `…/aweme/v1/playwm/?video_id=v0200fg…&ratio=720p&line=0`，
  /// 交给 [DouyinShareResolver.videoIdFromSrc] 就能取出 video_id。
  static const String videoSrcJs = '''
(function () {
  try {
    var v = document.querySelector('video');
    if (!v) return '';
    return v.getAttribute('src') || v.src || '';
  } catch (e) { return ''; }
})()
''';

  /// 读标题与描述，返回一个 JSON 字符串。
  ///
  /// 用 `JSON.stringify` 包一层是为了让返回值的结构明确——WebView 对字符串
  /// 结果的封装方式在各平台不一致，明确的 JSON 更好解析。
  static const String metaJs = '''
(function () {
  try {
    function meta(sel) {
      var el = document.querySelector(sel);
      return el && el.content ? el.content : '';
    }
    return JSON.stringify({
      title: meta('meta[property="og:title"]') || document.title || '',
      description: meta('meta[name="description"]') ||
                   meta('meta[property="og:description"]') || ''
    });
  } catch (e) { return ''; }
})()
''';

  /// 轮询间隔与总超时。
  ///
  /// 不能用「页面加载完成」作为信号：实测抖音视频页会持续流式加载，
  /// `onPageFinished` 要么迟迟不来要么来得太早（此时 `<video>` 还没挂上）。
  static const Duration pollInterval = Duration(milliseconds: 700);
  static const Duration timeout = Duration(seconds: 25);

  /// 剥掉 WebView 返回值外面可能包着的一层 JSON 编码。
  /// 具体行为见 [unwrapWebViewString]。
  static String unwrapJsString(String raw) => unwrapWebViewString(raw);

  /// 解析 [metaJs] 的返回值。解不出来返回 null。
  static DouyinWebMeta? parseMeta(String raw) {
    final outer = unwrapJsString(raw);
    if (outer.isEmpty) return null;

    final parsed = _decodeMap(outer);
    if (parsed != null) return _fromMap(parsed);

    // 有些平台会把 JSON 字符串再包一层，再试一次
    final nested = _decodeMap(outer.trim());
    if (nested != null) return _fromMap(nested);
    return null;
  }

  /// 清理标题：抖音会在 `<title>` 尾巴上拼 " - 抖音"，去掉。
  static String cleanTitle(String raw) {
    var t = raw.trim();
    for (final suffix in const [' - 抖音', '-抖音', '_抖音']) {
      if (t.endsWith(suffix)) {
        t = t.substring(0, t.length - suffix.length).trim();
        break;
      }
    }
    return t;
  }

  /// 清理描述：去掉尾部平台拼接的 " - 作者名于20261015发布在抖音，已经收获了…"。
  ///
  /// 实测原始形态是：
  /// `…正文…#标签 - 老胡玩Ai于20261015发布在抖音，已经收获了0个喜欢，来抖音，记录美好生活！`
  static String cleanDescription(String raw) {
    var d = raw.trim();
    // 带作者名的完整尾巴
    d = d.replaceFirst(RegExp(r'\s*-\s*[^\s-]{1,30}于\d{6,8}[\s\S]*$'), '');
    // 没有作者段、只剩"于…发布在抖音…"的裸尾巴
    d = d.replaceFirst(RegExp(r'[，,、\s]*于\d{6,8}发布在抖音[\s\S]*$'), '');
    return d.trim();
  }

  static Map<String, dynamic>? _decodeMap(String text) {
    if (text.isEmpty) return null;
    try {
      final decoded = json.decode(text);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      if (decoded is String) {
        final inner = json.decode(decoded);
        if (inner is Map) return Map<String, dynamic>.from(inner);
      }
    } catch (_) {}
    return null;
  }

  static DouyinWebMeta? _fromMap(Map<String, dynamic> map) {
    final title = cleanTitle('${map['title'] ?? ''}');
    final description = cleanDescription('${map['description'] ?? ''}');
    if (title.isEmpty && description.isEmpty) return null;
    return DouyinWebMeta(title: title, description: description);
  }
}

/// 渲染后页面里能拿到的文案信息。
class DouyinWebMeta {
  final String title;
  final String description;

  const DouyinWebMeta({required this.title, required this.description});

  /// 合并成一段可用的文案。标题是主句，描述是正文。
  String get copyText {
    if (title.isEmpty) return description;
    if (description.isEmpty) return title;
    if (description.startsWith(title)) return description;
    return '$title\n$description';
  }

  bool get isEmpty => title.isEmpty && description.isEmpty;
}
