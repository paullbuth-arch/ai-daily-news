import 'package:flutter_test/flutter_test.dart';
import 'package:ipad_boss_app/services/douyin_share_resolver.dart';
import 'package:ipad_boss_app/services/douyin_web_extractor.dart';

void main() {
  group('unwrapJsString', () {
    test('剥掉 Android 额外包的 JSON 引号', () {
      expect(DouyinWebExtractor.unwrapJsString('"hello"'), 'hello');
    });

    test('未加引号的直接返回', () {
      expect(DouyinWebExtractor.unwrapJsString('hello'), 'hello');
    });

    test('空 / null / undefined 都归为空串', () {
      expect(DouyinWebExtractor.unwrapJsString(''), '');
      expect(DouyinWebExtractor.unwrapJsString('null'), '');
      expect(DouyinWebExtractor.unwrapJsString('undefined'), '');
    });

    test('带转义引号的 URL 能正确还原', () {
      const src =
          'https://m.douyin.com/aweme/v1/playwm/?video_id=v0300fg&ratio=720p';
      final encoded = '"$src"';
      expect(DouyinWebExtractor.unwrapJsString(encoded), src);
    });
  });

  group('parseMeta', () {
    test('解析常规 JSON（Android 会再包一层引号）', () {
      const inner =
          '{"title":"标题 - 抖音","description":"正文内容 - 作者于20261015发布在抖音"}';
      final raw = '"${inner.replaceAll('"', r'\"')}"';
      final meta = DouyinWebExtractor.parseMeta(raw);
      expect(meta, isNotNull);
      expect(meta!.title, '标题');
      expect(meta.description, '正文内容');
    });

    test('解析裸 JSON（未额外编码）', () {
      final meta = DouyinWebExtractor.parseMeta(
        '{"title":"标题","description":"正文"}',
      );
      expect(meta!.title, '标题');
      expect(meta.description, '正文');
    });

    test('垃圾输入返回 null 而不是抛异常', () {
      expect(DouyinWebExtractor.parseMeta(''), isNull);
      expect(DouyinWebExtractor.parseMeta('not json'), isNull);
      expect(DouyinWebExtractor.parseMeta('null'), isNull);
    });

    test('两个字段都空视作没解析到', () {
      expect(
        DouyinWebExtractor.parseMeta('{"title":"","description":""}'),
        isNull,
      );
    });
  });

  group('cleanTitle', () {
    test('去掉抖音拼的 " - 抖音" 尾巴', () {
      expect(DouyinWebExtractor.cleanTitle('某条视频 - 抖音'), '某条视频');
    });

    test('没有尾巴时原样返回', () {
      expect(DouyinWebExtractor.cleanTitle('某条视频'), '某条视频');
    });
  });

  group('cleanDescription', () {
    test('去掉带作者名的平台尾巴', () {
      const raw =
          'AI编程门槛又低了。#人工智能 #开源项目 - 老胡玩Ai于20261015发布在抖音，已经收获了0个喜欢，来抖音，记录美好生活！';
      final cleaned = DouyinWebExtractor.cleanDescription(raw);
      expect(cleaned, 'AI编程门槛又低了。#人工智能 #开源项目');
    });

    test('去掉没有作者名的裸尾巴', () {
      const raw = '一段正文于20261015发布在抖音，已经收获了0个喜欢';
      expect(DouyinWebExtractor.cleanDescription(raw), '一段正文');
    });

    test('正常内容不受影响', () {
      const raw = '这是一段正常的文案，没有任何平台尾巴。';
      expect(DouyinWebExtractor.cleanDescription(raw), raw);
    });
  });

  group('copyText 合并', () {
    test('描述以标题开头时不重复标题', () {
      const meta = DouyinWebMeta(title: '标题', description: '标题加上更多正文');
      expect(meta.copyText, '标题加上更多正文');
    });

    test('标题和描述不同时换行拼接', () {
      const meta = DouyinWebMeta(title: '标题', description: '正文');
      expect(meta.copyText, '标题\n正文');
    });

    test('只有一边有内容时不产生空行', () {
      expect(const DouyinWebMeta(title: '标题', description: '').copyText, '标题');
      expect(const DouyinWebMeta(title: '', description: '正文').copyText, '正文');
    });
  });

  group('与 DouyinShareResolver 串起来', () {
    test('从真实形态的 video src 取出 video_id 并拼出无水印地址', () {
      const src =
          'https://m.douyin.com/aweme/v1/playwm/?video_id=v0300fg10000db71kvvog65jl8njjst0&ratio=720p&line=0';
      final id = DouyinShareResolver.videoIdFromSrc(src);
      expect(id, 'v0300fg10000db71kvvog65jl8njjst0');

      final url = DouyinShareResolver.noWatermarkUrl(id!);
      expect(url.path, '/aweme/v1/play/');
      expect(url.queryParameters['video_id'], id);
    });
  });
}
