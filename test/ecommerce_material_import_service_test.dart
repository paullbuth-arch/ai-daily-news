import 'dart:convert';
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
      } else if (path == '/xhs-noisy-state') {
        final host = InternetAddress.loopbackIPv4.host;
        final port = server.port;
        String mainImage(int index) =>
            'http:\\u002F\\u002F$host:$port\\u002Fxhs-img\\u002Fmain-$index!nd_dft_wlteh_jpg_3';
        String previewImage(int index) =>
            'http:\\u002F\\u002F$host:$port\\u002Fxhs-img\\u002Fmain-$index!nd_prv_wlteh_jpg_3';
        String recommendImage(int index) =>
            'http:\\u002F\\u002F$host:$port\\u002Frec-img\\u002Frec-$index.jpg';
        request.response.headers.contentType = ContentType.html;
        request.response.write('''
<!doctype html>
<html>
<head><title>XHS Noisy State</title></head>
<body>
  <div class="content-container">
    <div class="reds-text fs18 fw500 title title-no-padding-top">Durian Guide</div>
    <div class="author-desc-content">Five image note</div>
  </div>
  <script>
    window.__INITIAL_STATE__={
      "global":{"jsAssetsList":undefined},
      "note":{
        "firstNote":{
          "noteData":{
            "title":"Durian Guide",
            "type":"normal",
            "imageList":[
              {"fileId":"main-1","width":1260,"height":1680,"url":"","urlDefault":"${mainImage(1)}","urlPre":"${previewImage(1)}","infoList":[{"imageScene":"WB_DFT","url":"${mainImage(1)}"},{"imageScene":"WB_PRV","url":"${previewImage(1)}"}]},
              {"fileId":"main-2","width":1260,"height":1680,"url":"","urlDefault":"${mainImage(2)}","urlPre":"${previewImage(2)}","infoList":[{"imageScene":"WB_DFT","url":"${mainImage(2)}"},{"imageScene":"WB_PRV","url":"${previewImage(2)}"}]},
              {"fileId":"main-3","width":1260,"height":1680,"url":"","urlDefault":"${mainImage(3)}","urlPre":"${previewImage(3)}","infoList":[{"imageScene":"WB_DFT","url":"${mainImage(3)}"},{"imageScene":"WB_PRV","url":"${previewImage(3)}"}]},
              {"fileId":"main-4","width":1260,"height":1680,"url":"","urlDefault":"${mainImage(4)}","urlPre":"${previewImage(4)}","infoList":[{"imageScene":"WB_DFT","url":"${mainImage(4)}"},{"imageScene":"WB_PRV","url":"${previewImage(4)}"}]},
              {"fileId":"main-5","width":1260,"height":1680,"url":"","urlDefault":"${mainImage(5)}","urlPre":"${previewImage(5)}","infoList":[{"imageScene":"WB_DFT","url":"${mainImage(5)}"},{"imageScene":"WB_PRV","url":"${previewImage(5)}"}]}
            ]
          }
        }
      },
      "recommendFeed":{
        "imageList":[
          {"url":"${recommendImage(1)}"},
          {"url":"${recommendImage(2)}"},
          {"url":"${recommendImage(3)}"},
          {"url":"${recommendImage(4)}"},
          {"url":"${recommendImage(5)}"},
          {"url":"${recommendImage(6)}"},
          {"url":"${recommendImage(7)}"},
          {"url":"${recommendImage(8)}"}
        ]
      }
    }
  </script>
</body>
</html>
''');
      } else if (path == '/generic-video') {
        request.response.headers.contentType = ContentType.html;
        request.response.write('''
<!doctype html>
<html>
<head>
  <title>Generic Video Product</title>
  <meta property="og:title" content="Generic Video Product">
  <meta property="og:description" content="Page with a downloadable video">
  <meta property="og:image" content="/img/main.jpg">
  <meta property="og:video" content="/media/item.mp4">
</head>
<body>
  <video src="/media/item.mp4"></video>
</body>
</html>
''');
      } else if (path == '/quality-video') {
        request.response.headers.contentType = ContentType.html;
        request.response.write('''
<!doctype html>
<html>
<head>
  <title>Quality Video Product</title>
  <meta property="og:title" content="Quality Video Product">
  <meta property="og:video" content="/stream/demo_360.mp4?ratio=360p">
</head>
<body>
  <video src="/stream/demo_360.mp4?ratio=360p"></video>
  <source src="/stream/demo_1080.mp4?ratio=1080p">
</body>
</html>
''');
      } else if (path == '/douyin') {
        final host = InternetAddress.loopbackIPv4.host;
        final port = server.port;
        final cover = 'http://$host:$port/douyin-img/cover.jpeg?sign=cover';
        final video =
            'http://$host:$port/aweme/v1/play/?video_id=douyin_test&ratio=720p';
        final renderData = Uri.encodeComponent(
          json.encode({
            'aweme': {
              'detail': {
                'desc': 'Douyin iPad demo body',
                'images': [
                  {
                    'url_list': [cover],
                  },
                ],
                'video': {
                  'play_addr': {
                    'url_list': [video],
                  },
                },
              },
            },
          }),
        );
        request.response.headers.contentType = ContentType.html;
        request.response.write('''
<!doctype html>
<html>
<head>
  <title>Douyin Share</title>
  <meta property="og:title" content="Douyin iPad demo">
  <meta property="og:description" content="Douyin iPad demo body">
  <meta property="og:image" content="$cover">
</head>
<body>
  <script id="RENDER_DATA" type="application/json">$renderData</script>
</body>
</html>
''');
      } else if (path == '/douyin-images') {
        final host = InternetAddress.loopbackIPv4.host;
        final port = server.port;
        final first = 'http://$host:$port/douyin-img/first.jpeg?sign=first';
        final second = 'http://$host:$port/douyin-img/second.jpeg?sign=second';
        final renderData = Uri.encodeComponent(
          json.encode({
            'aweme': {
              'detail': {
                'desc': 'Douyin image post body',
                'images': [
                  {
                    'url_list': [first],
                  },
                  {
                    'url_list': [second],
                  },
                ],
              },
            },
          }),
        );
        request.response.headers.contentType = ContentType.html;
        request.response.write('''
<!doctype html>
<html>
<head>
  <title>Douyin Images</title>
  <meta property="og:title" content="Douyin image post">
</head>
<body>
  <script id="RENDER_DATA" type="application/json">$renderData</script>
</body>
</html>
''');
      } else if (path == '/douyin-watermark-choice') {
        final host = InternetAddress.loopbackIPv4.host;
        final port = server.port;
        final watermarked =
            'http://$host:$port/aweme/v1/playwm/?video_id=douyin_choice&ratio=720p&watermark=1';
        final clean =
            'http://$host:$port/aweme/v1/play/?video_id=douyin_choice&ratio=720p';
        final renderData = Uri.encodeComponent(
          json.encode({
            'aweme': {
              'detail': {
                'desc': 'Douyin clean choice body',
                'video': {
                  'download_addr': {
                    'url_list': [watermarked],
                  },
                  'play_addr': {
                    'url_list': [clean],
                  },
                  'bit_rate': [
                    {
                      'play_addr': {
                        'url_list': [clean],
                      },
                    },
                  ],
                },
              },
            },
          }),
        );
        request.response.headers.contentType = ContentType.html;
        request.response.write('''
<!doctype html>
<html>
<head>
  <title>Douyin clean choice</title>
  <meta property="og:video" content="$watermarked">
</head>
<body>
  <script id="RENDER_DATA" type="application/json">$renderData</script>
</body>
</html>
''');
      } else if (path == '/douyin-playwm-only') {
        final host = InternetAddress.loopbackIPv4.host;
        final port = server.port;
        final watermarked =
            'http://$host:$port/aweme/v1/playwm/?video_id=douyin_wm_only&ratio=720p&watermark=1';
        final renderData = Uri.encodeComponent(
          json.encode({
            'aweme': {
              'detail': {
                'desc': 'Douyin playwm only body',
                'video': {
                  'download_addr': {
                    'url_list': [watermarked],
                  },
                },
              },
            },
          }),
        );
        request.response.headers.contentType = ContentType.html;
        request.response.write('''
<!doctype html>
<html>
<head>
  <title>Douyin playwm only</title>
  <meta property="og:video" content="$watermarked">
</head>
<body>
  <script id="RENDER_DATA" type="application/json">$renderData</script>
</body>
</html>
''');
      } else if (path == '/video/7651960984093110778') {
        request.response.headers.contentType = ContentType.html;
        request.response.write('''
<!doctype html>
<html>
<head><title>Douyin shell</title></head>
<body>douyin page without media</body>
</html>
''');
      } else if (path == '/share/video/7651960984093110778/') {
        final host = InternetAddress.loopbackIPv4.host;
        final port = server.port;
        final video =
            'http://$host:$port/aweme/v1/play/?video_id=douyin_fallback&ratio=720p';
        final routerData = json.encode({
          'loaderData': {
            'video_(id)/page': {
              'videoInfoRes': {
                'item_list': [
                  {
                    'desc': 'Douyin fallback body',
                    'video': {
                      'play_addr': {
                        'url_list': [video],
                      },
                    },
                  },
                ],
              },
            },
          },
        });
        request.response.headers.contentType = ContentType.html;
        request.response.write('''
<!doctype html>
<html>
<head>
  <title>Douyin fallback share</title>
  <meta property="og:description" content="Douyin fallback body">
</head>
<body>
  <script>window._ROUTER_DATA = $routerData</script>
</body>
</html>
''');
      } else if (path.startsWith('/img/') || path.startsWith('/xhs-img/')) {
        request.response.headers.contentType =
            path.endsWith('.png')
                ? ContentType('image', 'png')
                : ContentType('image', 'jpeg');
        request.response.add([1, 2, 3, 4, 5]);
      } else if (path.startsWith('/douyin-img/')) {
        request.response.headers.contentType = ContentType('image', 'jpeg');
        request.response.add([9, 8, 7, 6, 5]);
      } else if (path.startsWith('/rec-img/')) {
        request.response.headers.contentType = ContentType('image', 'jpeg');
        request.response.add([6, 7, 8]);
      } else if (path.startsWith('/media/')) {
        request.response.headers.contentType = ContentType('video', 'mp4');
        request.response.add(List<int>.filled(18, 8));
      } else if (path.startsWith('/stream/')) {
        request.response.headers.contentType = ContentType('video', 'mp4');
        final isHigh = path.contains('1080');
        request.response.add(
          List<int>.filled(isHigh ? 32 : 12, isHigh ? 10 : 3),
        );
      } else if (path.startsWith('/aweme/v1/playwm')) {
        request.response.headers.contentType = ContentType.binary;
        request.response.add(List<int>.filled(9, 1));
      } else if (path.startsWith('/aweme/v1/play')) {
        request.response.headers.contentType = ContentType.binary;
        request.response.add(List<int>.filled(20, 9));
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

  test(
    'xiaohongshu state parser keeps note images and ignores noisy feed',
    () async {
      final url = Uri(
        scheme: 'http',
        host: InternetAddress.loopbackIPv4.host,
        port: server.port,
        path: '/xhs-noisy-state',
      );

      final result = await EcommerceMaterialImportService.importFromText(
        'xhs note $url',
        docDir: tmp.path,
        maxImages: 20,
      );

      expect(
        result.images,
        hasLength(5),
        reason:
            'candidate=${result.candidateImageCount}, title=${result.title}, warnings=${result.warnings.join('|')}',
      );
      expect(result.candidateImageCount, 5);
      expect(
        result.images.map((image) => image.originalUrl.toString()),
        everyElement(contains('/xhs-img/main-')),
      );
      expect(
        result.images.map((image) => image.originalUrl.toString()),
        isNot(contains(contains('/rec-img/'))),
      );
      expect(
        result.images.map((image) => image.originalUrl.toString()),
        isNot(contains(contains('nd_prv'))),
      );
    },
  );

  test('downloads generic page videos as link material', () async {
    final url = Uri(
      scheme: 'http',
      host: InternetAddress.loopbackIPv4.host,
      port: server.port,
      path: '/generic-video',
    );

    final result = await EcommerceMaterialImportService.importFromText(
      'generic product $url',
      docDir: tmp.path,
    );

    expect(result.title, 'Generic Video Product');
    expect(result.images, hasLength(1));
    expect(result.videos, hasLength(1));
    expect(result.candidateVideoCount, 1);
    expect(File(result.videos.single.savedPath).existsSync(), true);
  });

  test('saves image and video link manifest for imported media', () async {
    final url = Uri(
      scheme: 'http',
      host: InternetAddress.loopbackIPv4.host,
      port: server.port,
      path: '/generic-video',
    );

    final result = await EcommerceMaterialImportService.importFromText(
      'generic product $url',
      docDir: tmp.path,
    );

    expect(result.linkManifestPath, isNotNull);
    final manifest =
        json.decode(await File(result.linkManifestPath!).readAsString())
            as Map<String, dynamic>;

    expect(manifest['sourceUrl'], url.toString());
    expect(manifest['downloadedImageCount'], 1);
    expect(manifest['downloadedVideoCount'], 1);
    expect(manifest['images'], hasLength(1));
    expect(manifest['videos'], hasLength(1));
    expect(
      (manifest['images'] as List).single['downloadedUrl'],
      contains('/img/main.jpg'),
    );
    expect(
      (manifest['videos'] as List).single['downloadedUrl'],
      contains('/media/item.mp4'),
    );
    expect(manifest['watermarkHandling']['pixelEditing'], false);
  });

  test(
    'downloads highest quality variant when video alternatives exist',
    () async {
      final url = Uri(
        scheme: 'http',
        host: InternetAddress.loopbackIPv4.host,
        port: server.port,
        path: '/quality-video',
      );

      final result = await EcommerceMaterialImportService.importFromText(
        'quality product $url',
        docDir: tmp.path,
        maxVideos: 1,
      );

      expect(result.videos, hasLength(1));
      expect(result.videos.single.downloadedUrl.toString(), contains('1080'));
      expect(await File(result.videos.single.savedPath).length(), 32);
    },
  );

  test('downloads only video from douyin video posts', () async {
    final url = Uri(
      scheme: 'http',
      host: InternetAddress.loopbackIPv4.host,
      port: server.port,
      path: '/douyin',
    );

    final result = await EcommerceMaterialImportService.importFromText(
      'douyin share $url',
      docDir: tmp.path,
    );

    expect(result.platform, '抖音');
    expect(result.title, 'Douyin iPad demo');
    expect(result.description, 'Douyin iPad demo body');
    expect(result.images, isEmpty);
    expect(result.candidateImageCount, 0);
    expect(result.videos, hasLength(1));
    expect(result.candidateVideoCount, 1);
    expect(File(result.videos.single.savedPath).existsSync(), true);
  });

  test('downloads only images from douyin image posts', () async {
    final url = Uri(
      scheme: 'http',
      host: InternetAddress.loopbackIPv4.host,
      port: server.port,
      path: '/douyin-images',
    );

    final result = await EcommerceMaterialImportService.importFromText(
      'douyin image share $url',
      docDir: tmp.path,
    );

    expect(result.platform, '抖音');
    expect(result.title, 'Douyin image post');
    expect(result.description, 'Douyin image post body');
    expect(result.images, hasLength(2));
    expect(result.videos, isEmpty);
    expect(result.candidateVideoCount, 0);
    expect(
      result.images.every((image) => File(image.savedPath).existsSync()),
      true,
    );
  });

  test(
    'prefers douyin play_addr over playwm or watermark candidates',
    () async {
      final url = Uri(
        scheme: 'http',
        host: InternetAddress.loopbackIPv4.host,
        port: server.port,
        path: '/douyin-watermark-choice',
      );

      final result = await EcommerceMaterialImportService.importFromText(
        'douyin share $url',
        docDir: tmp.path,
        maxVideos: 1,
      );

      expect(result.videos, hasLength(1));
      expect(result.videos.single.downloadedUrl.path, '/aweme/v1/play/');
      expect(
        result.videos.single.downloadedUrl.toString(),
        isNot(contains('playwm')),
      );
      expect(
        result.videos.single.downloadedUrl.toString(),
        isNot(contains('watermark')),
      );
      expect(await File(result.videos.single.savedPath).length(), 20);
    },
  );

  test('rewrites douyin playwm endpoint before downloading', () async {
    final url = Uri(
      scheme: 'http',
      host: InternetAddress.loopbackIPv4.host,
      port: server.port,
      path: '/douyin-playwm-only',
    );

    final result = await EcommerceMaterialImportService.importFromText(
      'douyin share $url',
      docDir: tmp.path,
      maxVideos: 1,
    );

    expect(result.videos, hasLength(1));
    expect(result.videos.single.downloadedUrl.path, '/aweme/v1/play/');
    expect(
      result.videos.single.downloadedUrl.toString(),
      isNot(contains('playwm')),
    );
    expect(
      result.videos.single.downloadedUrl.toString(),
      isNot(contains('watermark')),
    );
    expect(await File(result.videos.single.savedPath).length(), 20);
  });

  test(
    'falls back to douyin share page when video page has no media',
    () async {
      final url = Uri(
        scheme: 'http',
        host: InternetAddress.loopbackIPv4.host,
        port: server.port,
        path: '/video/7651960984093110778',
      );

      final result = await EcommerceMaterialImportService.importFromText(
        'douyin shell $url',
        docDir: tmp.path,
      );

      expect(result.platform, '抖音');
      expect(result.finalUrl.path, '/share/video/7651960984093110778/');
      expect(result.description, 'Douyin fallback body');
      expect(result.videos, hasLength(1));
      expect(result.candidateVideoCount, 1);
      expect(File(result.videos.single.savedPath).existsSync(), true);
    },
  );

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

  test('extracts goofish videos from detail videoPlayInfo', () {
    final urls = EcommerceMaterialImportService.extractGoofishVideoUrls({
      'flowData': {
        'body': {
          'sections': [
            {
              'components': [
                {
                  'data': {
                    'videoPlayInfo': {
                      'ld320pUrl':
                          'https://cloud.video.taobao.com/play/u/1/p/1/e/6/t/1/d/ld/572665021724.mp4',
                      'sd480pUrl':
                          'https://cloud.video.taobao.com/play/u/1/p/1/e/6/t/1/d/sd/572665021724.mp4',
                      'playUrl':
                          'http://xianyu-video.alicdn.com/aus/xianyu_item/438225802/E730F4621E9F47D8A6CDC41F8F6B84DC',
                      'url': 'http://img.alicdn.com/bao/uploaded/cover.jpg',
                    },
                  },
                },
              ],
            },
          ],
        },
      },
    });

    expect(urls, hasLength(2));
    expect(
      urls.first.toString(),
      'https://cloud.video.taobao.com/play/u/1/p/1/e/6/t/1/d/sd/572665021724.mp4',
    );
    expect(urls.last.host, 'xianyu-video.alicdn.com');
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
