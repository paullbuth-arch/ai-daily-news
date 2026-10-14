/// 抖音分享链接解析（纯逻辑部分）。
///
/// 为什么这里只有纯函数：抖音的 web 接口被 `ArgusSecurityPlugin` 拦着
/// （实测直连返回 `403 Blocked by ArgusSecurityPlugin Uifid Not Found`），
/// 分享页的 SSR 数据里也**没有**任何媒体地址（`_ROUTER_DATA` 只有页面配置，
/// `_SSR_DATA` 是空壳，经典公开接口 `v2/iteminfo` 现在返回 200 但 0 字节）。
///
/// 唯一稳的路子是让**页面自己的 JS** 去算签名：渲染
/// `https://www.douyin.com/video/{aweme_id}`，等它把 `<video>` 挂上来，
/// 从 `src` 里读出 `video_id`。这样抖音换签名算法时页面自己会跟上，
/// 我们不需要去移植那份随 SDK 版本变化的混淆代码。
///
/// 本文件负责的就是"渲染前"和"拿到 src 之后"的所有逻辑，不依赖 WebView，
/// 因此可以单测。WebView 只负责供应 `videoSrc` 这一个字符串。
class DouyinShareResolver {
  /// 无水印播放端点的主机，按可用性排序，互为备份。
  /// 实测三者都能用，`aweme-eagle.snssdk.com` 已失效（404）。
  static const List<String> playHosts = <String>[
    'https://aweme.snssdk.com',
    'https://www.iesdouyin.com',
    'https://api-hl.amemv.com',
  ];

  /// 抖音分享链接的形态很多，短链、长链、图集、视频都有。
  static bool canHandle(Uri uri) {
    final host = uri.host.toLowerCase();
    return host.contains('douyin.com') ||
        host.contains('iesdouyin.com') ||
        host.contains('amemv.com');
  }

  /// 从任意抖音链接里抠出 aweme_id。
  ///
  /// 覆盖：`/video/{id}`、`/note/{id}`（图集）、`/share/video/{id}`、
  /// `/share/note/{id}`、以及短链跳转后的落地页。
  static String? awemeIdFromUrl(String url) {
    final match = RegExp(
      r'(?:share/)?(?:video|note|slides)/(\d{6,})',
    ).firstMatch(url);
    if (match != null) return match.group(1);

    // 兜底：路径里最后一段是长数字（如 /7696144406725922057）
    final tail = RegExp(r'/(\d{15,})(?:[/?#]|$)').firstMatch(url);
    return tail?.group(1);
  }

  /// 拿去给 WebView 渲染的页面。桌面站才会把 `<video>` 挂出来，
  /// 移动版分享页（`m.douyin.com/share/video/…`）实测是一片空白。
  static Uri videoPageUrl(String awemeId) =>
      Uri.parse('https://www.douyin.com/video/$awemeId');

  /// 从页面 `<video>` 的 `src` 里读 `video_id`。
  ///
  /// 页面给的是 `…/aweme/v1/playwm/?video_id=v0200fg…&ratio=720p&line=0`。
  static String? videoIdFromSrc(String? src) {
    if (src == null || src.isEmpty) return null;
    final match = RegExp(r'video_id=([A-Za-z0-9]+)').firstMatch(src);
    return match?.group(1);
  }

  /// 拼无水印播放地址。
  ///
  /// 关键在 `play` 这个路径段：抖音在 CDN 上**同时存了带水印和无水印两份**
  /// 文件，`playwm` 指向带水印的、`play` 指向干净的。实测两者 302 到的
  /// CDN 路径完全不同：
  ///   playwm → tos-cn-ve-15/oguMsQEc1PADJjtOBziiglBCAZAeEp8EIifbCx
  ///   play   → tos-cn-ve-15/oUXtVxviBEjtcOzlAbiQCbeCjBfz1DAIiTguAZ
  /// 所以这不是"抹掉水印"，是取平台自己提供的干净副本。
  static Uri noWatermarkUrl(String videoId, {String ratio = '1080p'}) {
    final host = playHosts.first;
    return Uri.parse(
      '$host/aweme/v1/play/?video_id=$videoId&ratio=$ratio&line=0',
    );
  }

  /// 备用主机，下载失败时逐个重试。
  static List<Uri> fallbackUrls(String videoId, {String ratio = '1080p'}) =>
      playHosts
          .map(
            (h) => Uri.parse(
              '$h/aweme/v1/play/?video_id=$videoId&ratio=$ratio&line=0',
            ),
          )
          .toList();
}
