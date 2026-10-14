import 'package:flutter_test/flutter_test.dart';
import 'package:ipad_boss_app/services/douyin_share_resolver.dart';

/// 抖音分享链接解析（纯逻辑部分）。
///
/// 样本里的 URL 都是实测抓到的真实形态。
void main() {
  test('从短链跳转后的落地页取 aweme_id', () {
    // v.douyin.com/xxx 会 302 到这里
    const landed =
        'https://www.iesdouyin.com/share/video/7696144406725922057/'
        '?region=CN&mid=7696144417946045235&u_code=131mfab3h';
    expect(DouyinShareResolver.awemeIdFromUrl(landed), '7696144406725922057');
  });

  test('各种链接形态都能认出 aweme_id', () {
    const cases = <String, String>{
      'https://www.douyin.com/video/7696144406725922057': '7696144406725922057',
      'https://www.douyin.com/note/7696144406725922057': '7696144406725922057',
      'https://www.iesdouyin.com/share/video/1234567890123456789/':
          '1234567890123456789',
      'https://www.douyin.com/share/note/7555123456789012345':
          '7555123456789012345',
      'https://www.douyin.com/slides/7696144406725922057': '7696144406725922057',
    };
    cases.forEach((url, expected) {
      expect(
        DouyinShareResolver.awemeIdFromUrl(url),
        expected,
        reason: url,
      );
    });
  });

  test('认出抖音域名', () {
    expect(
      DouyinShareResolver.canHandle(Uri.parse('https://v.douyin.com/coXigiRF7IE/')),
      isTrue,
    );
    expect(
      DouyinShareResolver.canHandle(
        Uri.parse('https://www.iesdouyin.com/share/video/123/'),
      ),
      isTrue,
    );
    expect(
      DouyinShareResolver.canHandle(Uri.parse('https://example.com/video/1')),
      isFalse,
    );
  });

  test('从页面 video 元素的 src 里读 video_id', () {
    // 浏览器渲染 www.douyin.com/video/{id} 后实测拿到的 src
    const src =
        'https://m.douyin.com/aweme/v1/playwm/?video_id=v0200fg10000db7351fog65jhblln3e0'
        '&ratio=720p&line=0';
    expect(
      DouyinShareResolver.videoIdFromSrc(src),
      'v0200fg10000db7351fog65jhblln3e0',
    );
  });

  test('src 为空或没有 video_id 时返回 null', () {
    expect(DouyinShareResolver.videoIdFromSrc(null), isNull);
    expect(DouyinShareResolver.videoIdFromSrc(''), isNull);
    expect(
      DouyinShareResolver.videoIdFromSrc('https://example.com/a.mp4'),
      isNull,
    );
  });

  test('拼出的地址走 play 而不是 playwm —— 这是无水印的关键', () {
    final uri = DouyinShareResolver.noWatermarkUrl('v0200fg10000db7351fog65jhblln3e0');
    expect(uri.path, '/aweme/v1/play/');
    expect(uri.toString(), isNot(contains('playwm')));
    expect(uri.queryParameters['video_id'], 'v0200fg10000db7351fog65jhblln3e0');
    expect(uri.queryParameters['ratio'], '1080p');
  });

  test('备用主机覆盖全部三个可用端点', () {
    final urls = DouyinShareResolver.fallbackUrls('v0200fg00');
    expect(urls, hasLength(3));
    expect(urls.map((u) => u.host).toSet(), {
      'aweme.snssdk.com',
      'www.iesdouyin.com',
      'api-hl.amemv.com',
    });
    for (final u in urls) {
      expect(u.path, '/aweme/v1/play/');
    }
  });

  test('渲染地址指向桌面站（移动版分享页没有 video 元素）', () {
    final uri = DouyinShareResolver.videoPageUrl('7696144406725922057');
    expect(uri.host, 'www.douyin.com');
    expect(uri.path, '/video/7696144406725922057');
  });
}
