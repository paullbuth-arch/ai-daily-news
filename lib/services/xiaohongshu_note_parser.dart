import 'dart:convert';

/// 小红书笔记解析 —— 走分享页里的 SSR 数据（`__INITIAL_STATE__`）。
///
/// 为什么不用正则捞 CDN 链接：那样会把评论区的头像一并捞进来
/// （`commentData.comments[].user.image`），也会捞到主题图标之类的杂图。
/// 只读 `noteData.data.noteData.imageList` 才拿得准。
///
/// 原图走 `https://sns-img-qc.xhscdn.com/{fileId}`：实测比 SSR 里给的
/// `!h5_1080jpg` 变体更大更清晰（1200×1600 vs 1080×1440），而且**不带
/// 小红书水印、不需要签名、不会过期**。SSR 里那个带签名的 URL 有短 TTL，
/// 复用旧页面的链接会 403。
class XiaohongshuNote {
  final String noteId;
  final String title;
  final String description;
  final String author;

  /// 笔记正文里带的图片（原图，按笔记顺序）。
  final List<Uri> images;

  /// 视频笔记的视频源（按画质从高到低）。
  final List<Uri> videos;

  /// 解析过程中的提示，比如"只拿到预览图"。
  final List<String> warnings;

  const XiaohongshuNote({
    required this.noteId,
    required this.title,
    required this.description,
    required this.author,
    required this.images,
    required this.videos,
    this.warnings = const <String>[],
  });

  bool get hasMedia => images.isNotEmpty || videos.isNotEmpty;

  bool get isVideo => videos.isNotEmpty;
}

class XiaohongshuNoteParser {
  /// 原图 CDN。三个域名互为备份，实测内容一致。
  static const List<String> originalImageHosts = <String>[
    'https://sns-img-qc.xhscdn.com',
    'https://sns-img-bd.xhscdn.com',
    'https://ci.xiaohongshu.com',
  ];

  static bool canHandle(Uri uri) {
    final host = uri.host.toLowerCase();
    return host.contains('xhslink') ||
        host.contains('xiaohongshu') ||
        host == 'xhslink.cn';
  }

  /// 从分享页 HTML 里解析笔记。纯函数，便于用真实样本做单测。
  static XiaohongshuNote? parseHtml(String html, {Uri? base}) {
    final raw = _extractInitialState(html);
    if (raw == null || raw.isEmpty) return null;

    final dynamic decoded;
    try {
      decoded = json.decode(_stripJsUndefined(raw));
    } catch (_) {
      return null;
    }
    if (decoded is! Map) return null;

    // 只认 noteData.data.noteData —— 笔记本体。
    // 绝不能碰 commentData：那里全是评论头像。
    final noteData = _asMap(decoded['noteData']);
    final data = _asMap(noteData?['data']);
    final note = _asMap(data?['noteData']);
    if (note == null) return null;

    final warnings = <String>[];
    final images = _collectImages(note, warnings);
    final videos = _collectVideos(note);

    final title = _clean(note['title']);
    final desc = _clean(note['desc']);
    final user = _asMap(note['user']);

    return XiaohongshuNote(
      noteId: _clean(note['noteId']),
      title: title,
      description: desc,
      author: _clean(user?['nickname'] ?? user?['nickName']),
      images: images,
      videos: videos,
      warnings: warnings,
    );
  }

  /// 取 `__INITIAL_STATE__=` 后面那个完整的大括号块。
  ///
  /// 不能简单正则配到尾 —— 值里含花括号和转义引号，必须按字符扫描、
  /// 跳过字符串内部。
  static String? _extractInitialState(String html) {
    final marker = html.indexOf('__INITIAL_STATE__');
    if (marker < 0) return null;
    final start = html.indexOf('{', marker);
    if (start < 0) return null;

    var depth = 0;
    var inString = false;
    var escaped = false;
    for (var i = start; i < html.length; i++) {
      final c = html[i];
      if (escaped) {
        escaped = false;
        continue;
      }
      if (c == r'\') {
        escaped = true;
        continue;
      }
      if (c == '"') {
        inString = !inString;
        continue;
      }
      if (inString) continue;
      if (c == '{') {
        depth++;
      } else if (c == '}') {
        depth--;
        if (depth == 0) return html.substring(start, i + 1);
      }
    }
    return null;
  }

  /// SSR 里混了裸的 JS `undefined`，JSON 解不了。只替换字符串外的。
  static String _stripJsUndefined(String text) {
    final out = StringBuffer();
    var inString = false;
    var escaped = false;
    var i = 0;
    while (i < text.length) {
      final c = text[i];
      if (escaped) {
        out.write(c);
        escaped = false;
        i++;
        continue;
      }
      if (c == r'\') {
        out.write(c);
        escaped = true;
        i++;
        continue;
      }
      if (c == '"') {
        inString = !inString;
        out.write(c);
        i++;
        continue;
      }
      if (!inString && text.startsWith('undefined', i)) {
        out.write('null');
        i += 'undefined'.length;
        continue;
      }
      out.write(c);
      i++;
    }
    return out.toString();
  }

  static List<Uri> _collectImages(Map<String, dynamic> note, List<String> w) {
    final list = note['imageList'];
    if (list is! List || list.isEmpty) return const <Uri>[];

    final out = <Uri>[];
    final seen = <String>{};
    var fellBackToSigned = false;

    for (final entry in list) {
      final img = _asMap(entry);
      if (img == null) continue;

      // 首选：用 fileId 拼原图，高清、无水印、不过期。
      final fileId = _clean(img['fileId']);
      var added = false;
      if (fileId.isNotEmpty) {
        final uri = Uri.tryParse('${originalImageHosts.first}/$fileId');
        if (uri != null && seen.add(uri.toString())) {
          out.add(uri);
          added = true;
        }
      }
      if (added) continue;

      // 兜底：SSR 里带签名的 URL（1080 宽、带水印、会过期，但总比没有强）。
      final fallback = _firstNonEmpty(<String>[
        _clean(img['url']),
        ..._infoListUrls(img),
      ]);
      final uri = Uri.tryParse(fallback);
      if (uri != null && uri.hasScheme && seen.add(uri.toString())) {
        out.add(uri);
        fellBackToSigned = true;
      }
    }

    if (fellBackToSigned) {
      w.add('部分图片只能用平台签名地址（清晰度略低且带水印），建议稍后重试');
    }
    return out;
  }

  static List<String> _infoListUrls(Map<String, dynamic> img) {
    final info = img['infoList'];
    if (info is! List) return const <String>[];
    final out = <String>[];
    // H5_DTL 是详情图，优先于 H5_PRV 预览图
    for (final want in const <String>['H5_DTL', 'H5_PRV']) {
      for (final entry in info) {
        final m = _asMap(entry);
        if (m == null) continue;
        if (_clean(m['imageScene']) != want) continue;
        final u = _clean(m['url']);
        if (u.isNotEmpty) out.add(u);
      }
    }
    return out;
  }

  static List<Uri> _collectVideos(Map<String, dynamic> note) {
    final video = _asMap(note['video']);
    if (video == null) return const <Uri>[];

    final media = _asMap(video['media']);
    final stream = _asMap(media?['stream']);
    if (stream == null) return const <Uri>[];

    final scored = <_ScoredUrl>[];
    for (final entry in stream.entries) {
      final arr = entry.value;
      if (arr is! List) continue;
      for (final item in arr) {
        final m = _asMap(item);
        if (m == null) continue;
        final url = _clean(m['masterUrl']);
        if (url.isEmpty) continue;
        // 码率越高画质越好；没给码率就按声明顺序
        final rate = m['videoBitrate'] is num
            ? (m['videoBitrate'] as num).toInt()
            : (m['avgBitrate'] is num ? (m['avgBitrate'] as num).toInt() : 0);
        scored.add(_ScoredUrl(Uri.parse(url), rate));
      }
    }
    scored.sort((a, b) => b.score.compareTo(a.score));

    final out = <Uri>[];
    final seen = <String>{};
    for (final s in scored) {
      if (seen.add(s.uri.toString())) out.add(s.uri);
    }
    return out;
  }

  static Map<String, dynamic>? _asMap(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : null;

  static String _clean(dynamic value) =>
      value is String ? value.trim() : (value?.toString().trim() ?? '');

  static String _firstNonEmpty(List<String> values) {
    for (final v in values) {
      if (v.isNotEmpty) return v;
    }
    return '';
  }
}

class _ScoredUrl {
  final Uri uri;
  final int score;
  const _ScoredUrl(this.uri, this.score);
}
