import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ipad_boss_app/services/ecommerce_material_import_service.dart';

void main() {
  late Directory tmp;
  late HttpServer server;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('boss_import_');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final path = request.uri.path;
      if (path == '/item') {
        request.response.headers.contentType = ContentType.html;
        request.response.write('''
<!doctype html>
<html>
<head>
  <title>备用标题</title>
  <meta property="og:title" content="iPad Air 5 256G">
  <meta name="description" content="成色干净，屏幕显示细腻，适合学习和办公。">
  <meta property="og:image" content="/img/main.jpg?x-oss-process=image/resize,w_800/watermark,text_platform">
  <script type="application/ld+json">
    {
      "@context": "https://schema.org",
      "@type": "Product",
      "name": "JSON-LD 标题",
      "description": "JSON-LD 商品描述",
      "image": ["/img/side.png?wm=platform"]
    }
  </script>
</head>
<body>
  <img data-src="/img/detail.jpg_800x800q90.jpg_.webp">
</body>
</html>
''');
      } else if (path == '/xhs') {
        request.response.headers.contentType = ContentType.html;
        request.response.write('''
<!doctype html>
<html>
<head><title>小红书</title></head>
<body>
  <div class="content-container">
    <div class="reds-text fs18 fw500 title title-no-padding-top">XHS Note Title</div>
    <div class="author-desc">
      <div class="author-desc-content">
        <span class="note-desc-text-opt">XHS note body line one<br>XHS note body line two</span>
      </div>
    </div>
  </div>
  <div class="image-gallery-container">
    <img data-xhs-img src="/xhs-img/first!h5_1080jpg">
    <img data-xhs-img src="/xhs-img/second!h5_1080jpg">
  </div>
</body>
</html>
''');
      } else if (path == '/xhs-state') {
        final host = InternetAddress.loopbackIPv4.host;
        final port = server.port;
        final imageOne =
            'http:\\u002F\\u002F$host:$port\\u002Fxhs-img\\u002Fstate-one!h5_1080jpg';
        final imageTwo =
            'http:\\u002F\\u002F$host:$port\\u002Fxhs-img\\u002Fstate-two!h5_1080jpg';
        final video =
            'http:\\u002F\\u002F$host:$port\\u002Fvideo\\u002Fmain.mp4?sign=abc\\u0026t=1';
        final backup =
            'http:\\u002F\\u002F$host:$port\\u002Fvideo\\u002Fmain.mp4?sign=backup\\u0026t=1';
        request.response.headers.contentType = ContentType.html;
        request.response.write('''
<!doctype html>
<html>
<head><title>小红书</title></head>
<body>
  <div class="content-container">
    <div class="reds-text fs18 fw500 title title-no-padding-top">XHS State Note</div>
    <div class="author-desc-content">State body from public note</div>
  </div>
  <script>
    window.__INITIAL_STATE__={
      "note":{
        "firstNote":{
          "imageList":[
            {"url":"$imageOne"},
            {"infoList":[{"url":"$imageTwo"},{"url":"$imageTwo!style_webp"}]}
          ],
          "video":{"media":{"stream":{"h264":[{"masterUrl":"$video","backupUrls":["$backup"]}]}}}
        }
      }
    }
  </script>
</body>
</html>
''');
      } else if (path.startsWith('/img/') || path.startsWith('/xhs-img/')) {
        request.response.headers.contentType =
            path.endsWith('.png')
                ? ContentType('image', 'png')
                : ContentType('image', 'jpeg');
        request.response.add([1, 2, 3, 4, 5]);
      } else if (path.startsWith('/video/')) {
        request.response.headers.contentType = ContentType('video', 'mp4');
        request.response.add(List<int>.filled(16, 7));
      } else {
        request.response.statusCode = HttpStatus.notFound;
      }
      await request.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('extracts copy and downloads cleaned product images', () async {
    final url = Uri(
      scheme: 'http',
      host: InternetAddress.loopbackIPv4.host,
      port: server.port,
      path: '/item',
      queryParameters: {'share': '1'},
    );

    final result = await EcommerceMaterialImportService.importFromText(
      '复制商品链接：$url，',
      docDir: tmp.path,
    );

    expect(result.title, 'iPad Air 5 256G');
    expect(result.description, contains('成色干净'));
    expect(result.copyText, contains('iPad Air 5'));
    expect(result.images, hasLength(3));
    expect(result.cleanedUrlCount, 3);
    expect(
      result.images.every((image) => File(image.savedPath).existsSync()),
      true,
    );
    expect(
      result.images.map((image) => image.downloadedUrl.toString()),
      contains(contains('/img/detail.jpg')),
    );
  });

  test(
    'extracts xiaohongshu note text and images from rendered html',
    () async {
      final url = Uri(
        scheme: 'http',
        host: InternetAddress.loopbackIPv4.host,
        port: server.port,
        path: '/xhs',
      );

      final result = await EcommerceMaterialImportService.importFromText(
        'xhs note $url',
        docDir: tmp.path,
      );

      expect(result.platform, '小红书');
      expect(result.title, 'XHS Note Title');
      expect(result.description, contains('XHS note body line one'));
      expect(result.images, hasLength(2));
      expect(
        result.images.every((image) => File(image.savedPath).existsSync()),
        true,
      );
    },
  );

  test('extracts xiaohongshu images and video from embedded state', () async {
    final url = Uri(
      scheme: 'http',
      host: InternetAddress.loopbackIPv4.host,
      port: server.port,
      path: '/xhs-state',
      queryParameters: {'type': 'video'},
    );

    final result = await EcommerceMaterialImportService.importFromText(
      'xhs note $url',
      docDir: tmp.path,
    );

    expect(result.platform, '小红书');
    expect(result.title, 'XHS State Note');
    expect(result.images, hasLength(2));
    expect(result.videos, hasLength(1));
    expect(result.candidateVideoCount, 1);
    expect(
      result.images.every((image) => File(image.savedPath).existsSync()),
      true,
    );
    expect(
      result.videos.every((video) => File(video.savedPath).existsSync()),
      true,
    );
  });

  test('cleans platform image processing params without pixel editing', () {
    final cleaned = EcommerceMaterialImportService.cleanPlatformImageUrl(
      Uri.parse(
        'https://img.alicdn.com/item.jpg_800x800q90.jpg_.webp?x-oss-process=image/watermark,text_abc&keep=1',
      ),
    );

    expect(cleaned.cleanedPlatformWatermark, true);
    expect(cleaned.uri.toString(), 'https://img.alicdn.com/item.jpg?keep=1');
  });

  test('upgrades known image cdn urls to https', () {
    final cleaned = EcommerceMaterialImportService.cleanPlatformImageUrl(
      Uri.parse(
        'http://img.alicdn.com/bao/uploaded/i3/abc-0-xy_item.jpg_640x640q90.jpg',
      ),
    );

    expect(
      cleaned.uri.toString(),
      'https://img.alicdn.com/bao/uploaded/i3/abc-0-xy_item.jpg',
    );
    expect(cleaned.cleanedPlatformWatermark, true);
  });

  test('extracts goofish item id from m.tb.cn redirect shell', () {
    final itemId = EcommerceMaterialImportService.extractGoofishItemId(
      Uri.parse('https://m.tb.cn/h.RDa7yl1?tk=abc'),
      html:
          "var url = 'https://h5.m.goofish.com/item?forceFlush=1&itemId=1050975779389&id=1050975779389';",
    );

    expect(itemId, '1050975779389');
  });

  test('does not treat ordinary taobao short links as goofish', () {
    final itemId = EcommerceMaterialImportService.extractGoofishItemId(
      Uri.parse('https://m.tb.cn/h.demo?tk=abc'),
      html: "var url = 'https://detail.tmall.com/item.htm?id=1050975779389';",
    );

    expect(itemId, isNull);
  });

  test('extracts first url from share text', () {
    final url = EcommerceMaterialImportService.extractFirstUrl(
      '打开看看 https://example.com/item?id=1&sku=2，复制到浏览器',
    );

    expect(url.toString(), 'https://example.com/item?id=1&sku=2');
  });
}
