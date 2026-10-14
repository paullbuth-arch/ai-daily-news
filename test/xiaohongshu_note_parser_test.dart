import 'package:flutter_test/flutter_test.dart';
import 'package:ipad_boss_app/services/xiaohongshu_note_parser.dart';

/// 小红书笔记解析的口径。
///
/// 样本刻意埋了几个坑，都是真实页面上遇到过的：
///  - 评论区的头像（`commentData.comments[].user.image`）绝不能被当成笔记图
///  - SSR 里混着裸的 JS `undefined`
///  - 正文含花括号和转义引号，用来验证大括号配平没写错
const String _fixture = r'''
<!DOCTYPE html><html><head><title>小红书</title></head><body>
<script>window.__INITIAL_STATE__={"noteData":{"data":{"noteData":{"noteId":"6aa7cf5d0000000012037f03","title":"深圳59元1000M宽带","desc":"宽带求业绩！！\n坐标{深圳}\n有个 \"引号\" 和 undefined 字样","type":"normal","user":{"nickname":"深速宽带小椰酱"},"imageList":[{"fileId":"spectrum/1040g0k03253i9d332u005p8o16lp5mvt0m3p7c8","url":"https://sns-webpic-qc.xhscdn.com/202610141828/6244/spectrum/1040g0k!h5_1080jpg","infoList":[{"imageScene":"H5_DTL","url":"https://sns-webpic-qc.xhscdn.com/202610141828/6244/spectrum/1040g0k!h5_1080jpg"},{"imageScene":"H5_PRV","url":"https://sns-webpic-qc.xhscdn.com/202610141828/870a/spectrum/1040g0k!style_d4c8"}]},{"fileId":"spectrum/1040g2jo31thcunr15a005p8o16lp5mvtsv340oo"}],"video":undefined},"commentData":{"comments":[{"content":"顶","user":{"image":"https://sns-avatar-qc.xhscdn.com/avatar/6400a273851484a2fac30a5b.jpg?imageView2/2/w/120"}},{"content":"同求","user":{"image":"https://sns-avatar-qc.xhscdn.com/avatar/7121a416be8e543266fd62c1cc9d575e.jpg"}}]},"otherImage":"https://sns-avatar-qc.xhscdn.com/avatar/should_not_appear.jpg"}},"global":{"a":undefined,"b":null}};</script>
</body></html>
''';

/// 视频笔记样本。
const String _videoFixture = r'''
<script>window.__INITIAL_STATE__ = {"noteData":{"data":{"noteData":{"noteId":"vid001","title":"视频笔记","desc":"","type":"video","user":{"nickname":"作者"},"imageList":[],"video":{"media":{"stream":{"h264":[{"masterUrl":"https://sns-video-qc.xhscdn.com/low.mp4","videoBitrate":800000},{"masterUrl":"https://sns-video-qc.xhscdn.com/high.mp4","videoBitrate":2400000}],"h265":[{"masterUrl":"https://sns-video-qc.xhscdn.com/h265.mp4","videoBitrate":1600000}]}}}}}}};
''';

void main() {
  test('解析出笔记基本信息', () {
    final note = XiaohongshuNoteParser.parseHtml(_fixture);
    expect(note, isNotNull);
    expect(note!.noteId, '6aa7cf5d0000000012037f03');
    expect(note.title, '深圳59元1000M宽带');
    expect(note.author, '深速宽带小椰酱');
  });

  test('正文里的花括号和转义引号不会破坏大括号配平', () {
    final note = XiaohongshuNoteParser.parseHtml(_fixture);
    expect(note, isNotNull, reason: '配平写错的话这里会解析失败');
    expect(note!.description, contains('{深圳}'));
    expect(note.description, contains('"引号"'));
  });

  test('SSR 里裸的 JS undefined 不会导致解析失败', () {
    expect(XiaohongshuNoteParser.parseHtml(_fixture), isNotNull);
  });

  test('图片走 fileId 拼的原图地址，不是带签名的降采样地址', () {
    final note = XiaohongshuNoteParser.parseHtml(_fixture)!;
    expect(note.images, hasLength(2));
    expect(
      note.images.first.toString(),
      'https://sns-img-qc.xhscdn.com/spectrum/1040g0k03253i9d332u005p8o16lp5mvt0m3p7c8',
    );
    for (final u in note.images) {
      expect(u.host, 'sns-img-qc.xhscdn.com');
      expect(u.toString(), isNot(contains('!h5')));
      expect(u.toString(), isNot(contains('sns-webpic')));
    }
  });

  test('评论头像和头像域名绝不出现在结果里', () {
    final note = XiaohongshuNoteParser.parseHtml(_fixture)!;
    final all = note.images.map((u) => u.toString()).join(' ');
    expect(all, isNot(contains('avatar')));
    expect(all, isNot(contains('sns-avatar')));
    expect(all, isNot(contains('should_not_appear')));
    // 只认笔记本体的 imageList，别处的图片字段一概不算
    expect(note.images, hasLength(2));
  });

  test('视频笔记按码率从高到低取源', () {
    final note = XiaohongshuNoteParser.parseHtml(_videoFixture)!;
    expect(note.isVideo, isTrue);
    expect(note.videos.first.toString(), 'https://sns-video-qc.xhscdn.com/high.mp4');
    expect(note.videos, hasLength(3));
  });

  test('没有 __INITIAL_STATE__ 时返回 null 而不是抛错', () {
    expect(XiaohongshuNoteParser.parseHtml('<html><body>普通页面</body></html>'), isNull);
  });

  test('结构对不上时返回 null', () {
    expect(
      XiaohongshuNoteParser.parseHtml(
        '<script>window.__INITIAL_STATE__={"noteData":{"data":{}}};</script>',
      ),
      isNull,
    );
  });

  test('只认小红书域名', () {
    expect(
      XiaohongshuNoteParser.canHandle(Uri.parse('https://xhslink.cn/o/9DL17277TIW')),
      isTrue,
    );
    expect(
      XiaohongshuNoteParser.canHandle(
        Uri.parse('https://www.xiaohongshu.com/explore/abc'),
      ),
      isTrue,
    );
    expect(
      XiaohongshuNoteParser.canHandle(Uri.parse('https://example.com/a')),
      isFalse,
    );
  });
}
