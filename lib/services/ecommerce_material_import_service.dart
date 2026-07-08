import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

class ImportedMaterialImage {
  final Uri originalUrl;
  final Uri downloadedUrl;
  final String savedPath;
  final bool cleanedPlatformWatermark;

  const ImportedMaterialImage({
    required this.originalUrl,
    required this.downloadedUrl,
    required this.savedPath,
    required this.cleanedPlatformWatermark,
  });
}

class ImportedMaterialVideo {
  final Uri originalUrl;
  final Uri downloadedUrl;
  final String savedPath;

  const ImportedMaterialVideo({
    required this.originalUrl,
    required this.downloadedUrl,
    required this.savedPath,
  });
}

class PlatformImageUrl {
  final Uri uri;
  final bool cleanedPlatformWatermark;

  const PlatformImageUrl({
    required this.uri,
    required this.cleanedPlatformWatermark,
  });
}

class EcommerceMaterialImportResult {
  final Uri sourceUrl;
  final Uri finalUrl;
  final String platform;
  final String title;
  final String description;
  final String copyText;
  final List<ImportedMaterialImage> images;
  final List<ImportedMaterialVideo> videos;
  final int candidateImageCount;
  final int candidateVideoCount;
  final int cleanedUrlCount;
  final List<String> warnings;
  final String? linkManifestPath;

  const EcommerceMaterialImportResult({
    required this.sourceUrl,
    required this.finalUrl,
    required this.platform,
    required this.title,
    required this.description,
    required this.copyText,
    required this.images,
    this.videos = const <ImportedMaterialVideo>[],
    required this.candidateImageCount,
    this.candidateVideoCount = 0,
    required this.cleanedUrlCount,
    required this.warnings,
    this.linkManifestPath,
  });

  bool get hasCopyText => copyText.trim().isNotEmpty;
  bool get hasMedia => images.isNotEmpty || videos.isNotEmpty;

  EcommerceMaterialImportResult copyWith({
    List<String>? warnings,
    String? linkManifestPath,
  }) => EcommerceMaterialImportResult(
    sourceUrl: sourceUrl,
    finalUrl: finalUrl,
    platform: platform,
    title: title,
    description: description,
    copyText: copyText,
    images: images,
    videos: videos,
    candidateImageCount: candidateImageCount,
    candidateVideoCount: candidateVideoCount,
    cleanedUrlCount: cleanedUrlCount,
    warnings: warnings ?? this.warnings,
    linkManifestPath: linkManifestPath ?? this.linkManifestPath,
  );
}

class EcommerceMaterialImportService {
  static const int defaultMaxImages = 12;
  static const int defaultMaxVideos = 3;
  static const int _maxHtmlBytes = 4 * 1024 * 1024;
  static const int _maxImageBytes = 18 * 1024 * 1024;
  static const int _maxVideoBytes = 160 * 1024 * 1024;
  static const String _userAgent =
      'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36';

  static Future<EcommerceMaterialImportResult> importFromText(
    String input, {
    required String docDir,
    int maxImages = defaultMaxImages,
    int maxVideos = defaultMaxVideos,
  }) async {
    final sourceUrl = extractFirstUrl(input);
    if (sourceUrl == null) {
      throw const FormatException('没有识别到可访问的商品链接');
    }

    final client =
        HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final directMediaResult = await _tryImportDirectMedia(
        client,
        sourceUrl: sourceUrl,
        docDir: docDir,
        maxImages: maxImages,
        maxVideos: maxVideos,
      );
      if (directMediaResult != null) return directMediaResult;

      final fetched = await _fetchHtml(client, sourceUrl);
      final goofishResult = await _tryImportGoofish(
        client,
        sourceUrl: sourceUrl,
        fetched: fetched,
        docDir: docDir,
        maxImages: maxImages,
        maxVideos: maxVideos,
      );
      if (goofishResult != null) return goofishResult;

      final document = html_parser.parse(fetched.body);
      final douyinResult = await _tryImportDouyin(
        client,
        sourceUrl: sourceUrl,
        fetched: fetched,
        document: document,
        docDir: docDir,
        maxImages: maxImages,
        maxVideos: maxVideos,
      );
      if (douyinResult != null) return douyinResult;

      final xiaohongshuResult = await _tryImportXiaohongshu(
        client,
        sourceUrl: sourceUrl,
        fetched: fetched,
        document: document,
        docDir: docDir,
        maxImages: maxImages,
        maxVideos: maxVideos,
      );
      if (xiaohongshuResult != null) return xiaohongshuResult;

      final jsonLd = _extractJsonLd(document);

      final title = _firstNonEmpty([
        _metaContent(document, 'og:title'),
        _metaContent(document, 'twitter:title'),
        ...jsonLd.textsForKeys({'name', 'headline'}),
        document.querySelector('title')?.text,
      ]);
      final description = _firstNonEmpty([
        _metaContent(document, 'og:description'),
        _metaContent(document, 'description'),
        _metaContent(document, 'twitter:description'),
        ...jsonLd.textsForKeys({'description'}),
      ]);
      final copyText = _copyText(title, description, document);

      final candidates = _collectImageUrls(document, jsonLd, fetched.finalUrl);
      final videoCandidates = _collectVideoUrls(
        document,
        jsonLd,
        fetched.finalUrl,
        html: fetched.body,
      );
      final downloaded = await _downloadImages(
        client,
        candidates,
        docDir: docDir,
        maxImages: maxImages,
        referer: fetched.finalUrl,
      );
      final downloadedVideos = await _downloadVideos(
        client,
        videoCandidates,
        docDir: docDir,
        maxVideos: maxVideos,
        referer: fetched.finalUrl,
      );

      final warnings = <String>['仅清理平台图片处理参数，不抹除版权、作者或商家水印；请确认你有权使用导入素材。'];
      if (copyText.isEmpty) {
        warnings.add('没有提取到稳定文案，可能需要登录或页面使用了动态渲染。');
      }
      if (candidates.isEmpty && videoCandidates.isEmpty) {
        warnings.add('没有识别到可下载图片或视频。');
      } else if (candidates.isNotEmpty && downloaded.images.isEmpty) {
        warnings.add('识别到图片地址，但下载失败；平台可能限制了外部访问。');
      }
      if (videoCandidates.isNotEmpty && downloadedVideos.videos.isEmpty) {
        warnings.add('识别到视频地址，但下载失败；视频可能过大或平台限制了外部访问。');
      }

      return await _saveLinkManifest(
        EcommerceMaterialImportResult(
          sourceUrl: sourceUrl,
          finalUrl: fetched.finalUrl,
          platform: platformName(fetched.finalUrl),
          title: title,
          description: description,
          copyText: copyText,
          images: downloaded.images,
          videos: downloadedVideos.videos,
          candidateImageCount: candidates.length,
          candidateVideoCount: videoCandidates.length,
          cleanedUrlCount: downloaded.cleanedUrlCount,
          warnings: warnings,
        ),
        docDir: docDir,
      );
    } finally {
      client.close(force: true);
    }
  }

  static Uri? extractFirstUrl(String input) {
    final match = RegExp(
      "https?://[^\\s<>\"'\\]\\)）】,，。；;！!？]+",
    ).firstMatch(input);
    if (match == null) return null;
    var raw = match.group(0)!.trim();
    raw = raw.replaceAll(RegExp(r'[\])）】>,，。；;.!！?？]+$'), '');
    return Uri.tryParse(raw);
  }

  static Future<EcommerceMaterialImportResult?> _tryImportDirectMedia(
    HttpClient client, {
    required Uri sourceUrl,
    required String docDir,
    required int maxImages,
    required int maxVideos,
  }) async {
    final imageCandidates =
        _looksLikeUsefulImage(sourceUrl) ? <Uri>[sourceUrl] : <Uri>[];
    final videoCandidates =
        _looksLikeUsefulVideo(sourceUrl) ? <Uri>[sourceUrl] : <Uri>[];
    if (imageCandidates.isEmpty && videoCandidates.isEmpty) return null;

    final downloaded = await _downloadImages(
      client,
      imageCandidates,
      docDir: docDir,
      maxImages: maxImages,
      referer: sourceUrl,
    );
    final downloadedVideos = await _downloadVideos(
      client,
      videoCandidates,
      docDir: docDir,
      maxVideos: maxVideos,
      referer: sourceUrl,
    );

    final warnings = <String>['已按直接媒体链接处理；请确认你有权使用导入素材。'];
    if (imageCandidates.isNotEmpty && downloaded.images.isEmpty) {
      warnings.add('图片链接访问失败，可能已过期或平台限制外部访问。');
    }
    if (videoCandidates.isNotEmpty && downloadedVideos.videos.isEmpty) {
      warnings.add('视频链接访问失败，可能已过期、过大或平台限制外部访问。');
    }

    return await _saveLinkManifest(
      EcommerceMaterialImportResult(
        sourceUrl: sourceUrl,
        finalUrl: sourceUrl,
        platform: platformName(sourceUrl),
        title: '',
        description: '',
        copyText: '',
        images: downloaded.images,
        videos: downloadedVideos.videos,
        candidateImageCount: imageCandidates.length,
        candidateVideoCount: videoCandidates.length,
        cleanedUrlCount: downloaded.cleanedUrlCount,
        warnings: warnings,
      ),
      docDir: docDir,
    );
  }

  static Future<EcommerceMaterialImportResult> _saveLinkManifest(
    EcommerceMaterialImportResult result, {
    required String docDir,
  }) async {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final payload = <String, dynamic>{
      'sourceUrl': result.sourceUrl.toString(),
      'finalUrl': result.finalUrl.toString(),
      'platform': result.platform,
      'title': result.title,
      'description': result.description,
      'copyText': result.copyText,
      'candidateImageCount': result.candidateImageCount,
      'candidateVideoCount': result.candidateVideoCount,
      'downloadedImageCount': result.images.length,
      'downloadedVideoCount': result.videos.length,
      'cleanedUrlCount': result.cleanedUrlCount,
      'watermarkHandling': {
        'mode': 'link-parameter-cleaning-and-original-resource-preference',
        'pixelEditing': false,
        'note':
            'Only reversible URL processing parameters are cleaned; embedded author, seller, copyright, or platform marks are not erased.',
      },
      'qualityPreference': {
        'mode': 'highest-public-source-first',
        'note':
            'Media candidates are sorted to prefer original, raw, HD, higher resolution, and higher bitrate public URLs before download.',
      },
      'images': [
        for (final image in result.images)
          {
            'type': 'image',
            'originalUrl': image.originalUrl.toString(),
            'downloadedUrl': image.downloadedUrl.toString(),
            'savedPath': image.savedPath,
            'cleanedPlatformWatermark': image.cleanedPlatformWatermark,
          },
      ],
      'videos': [
        for (final video in result.videos)
          {
            'type': 'video',
            'originalUrl': video.originalUrl.toString(),
            'downloadedUrl': video.downloadedUrl.toString(),
            'savedPath': video.savedPath,
          },
      ],
      'warnings': result.warnings,
    };

    try {
      final dir = Directory(docDir);
      if (!await dir.exists()) await dir.create(recursive: true);
      final file = File('$docDir/import_${stamp}_links.json');
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(payload),
        flush: true,
      );
      return result.copyWith(linkManifestPath: file.path);
    } catch (error) {
      return result.copyWith(
        warnings: [...result.warnings, '素材链接清单保存失败：$error'],
      );
    }
  }

  static String platformName(Uri uri) {
    final host = uri.host.toLowerCase();
    if (host.contains('taobao')) return '淘宝';
    if (host.contains('tmall')) return '天猫';
    if (host.contains('jd.')) return '京东';
    if (host.contains('jingdong')) return '京东';
    if (host.contains('pinduoduo') || host.contains('yangkeduo')) return '拼多多';
    if (host.contains('1688')) return '1688';
    if (host.contains('douyin')) return '抖音商城';
    if (host.contains('kuaishou')) return '快手小店';
    if (host.contains('xiaohongshu')) return '小红书';
    if (host.contains('aliexpress')) return '速卖通';
    return host.replaceFirst(RegExp(r'^m\.|^www\.'), '');
  }

  static String? extractGoofishItemId(Uri uri, {String? html}) {
    final host = uri.host.toLowerCase();
    final text = html ?? uri.toString();
    final looksGoofish =
        host.contains('goofish.com') ||
        host.contains('2.taobao.com') ||
        text.contains('goofish.com') ||
        text.contains('fleamarket://');
    if (!looksGoofish) return null;

    final direct = uri.queryParameters['itemId'] ?? uri.queryParameters['id'];
    if (_isItemId(direct)) return direct;

    for (final pattern in [
      RegExp(r'(?:itemId|item_id|id)=([0-9]{8,})'),
      RegExp(r'"(?:itemId|item_id|id)"\s*:\s*"?([0-9]{8,})"?'),
      RegExp(r'fleamarket://item\?id=([0-9]{8,})'),
    ]) {
      final match = pattern.firstMatch(text);
      if (match != null) return match.group(1);
    }
    return null;
  }

  static Future<EcommerceMaterialImportResult?> _tryImportGoofish(
    HttpClient client, {
    required Uri sourceUrl,
    required _FetchedHtml fetched,
    required String docDir,
    required int maxImages,
    required int maxVideos,
  }) async {
    final targetUrl = _extractJsRedirectUrl(fetched.body, fetched.finalUrl);
    final itemId =
        extractGoofishItemId(sourceUrl, html: fetched.body) ??
        (targetUrl == null ? null : extractGoofishItemId(targetUrl));
    if (itemId == null) return null;

    final detail = await _fetchGoofishDetail(client, itemId);
    if (detail == null ||
        detail.imageUrls.isEmpty &&
            detail.videoUrls.isEmpty &&
            detail.copyText.isEmpty) {
      return null;
    }

    final referer = targetUrl ?? fetched.finalUrl;
    final downloaded = await _downloadImages(
      client,
      detail.imageUrls,
      docDir: docDir,
      maxImages: maxImages,
      referer: referer,
    );
    final downloadedVideos = await _downloadVideos(
      client,
      detail.videoUrls,
      docDir: docDir,
      maxVideos: maxVideos,
      referer: referer,
    );
    final warnings = <String>[
      '已优先从闲鱼公开详情接口下载商品原图，避免使用带右下角水印的分享海报。',
      '不会抹除图片里原本就存在的作者、商家或版权水印；请确认你有权使用导入素材。',
    ];
    if (detail.imageUrls.isNotEmpty && downloaded.images.isEmpty) {
      warnings.add('识别到闲鱼原图地址，但下载失败；平台可能临时限制了外部访问。');
    }

    if (detail.videoUrls.isNotEmpty && downloadedVideos.videos.isEmpty) {
      warnings.add('识别到闲鱼视频地址，但下载失败；视频可能过大、已过期或平台限制了外部访问。');
    }

    return await _saveLinkManifest(
      EcommerceMaterialImportResult(
        sourceUrl: sourceUrl,
        finalUrl: referer,
        platform: '闲鱼',
        title: detail.title,
        description: detail.description,
        copyText: detail.copyText,
        images: downloaded.images,
        videos: downloadedVideos.videos,
        candidateImageCount: detail.imageUrls.length,
        candidateVideoCount: detail.videoUrls.length,
        cleanedUrlCount: downloaded.cleanedUrlCount,
        warnings: warnings,
      ),
      docDir: docDir,
    );
  }

  static Future<EcommerceMaterialImportResult?> _tryImportDouyin(
    HttpClient client, {
    required Uri sourceUrl,
    required _FetchedHtml fetched,
    required dom.Document document,
    required String docDir,
    required int maxImages,
    required int maxVideos,
  }) async {
    final isDouyinPage =
        _isDouyinUrl(sourceUrl) ||
        _isDouyinUrl(fetched.finalUrl) ||
        _hasDouyinSignals(fetched.body);
    if (!isDouyinPage) return null;

    var resultFinalUrl = fetched.finalUrl;
    var title = _firstNonEmpty([
      _metaContent(document, 'og:title'),
      _metaContent(document, 'twitter:title'),
      _firstEmbeddedString(fetched.body, const ['title', 'aweme_title']),
      document.querySelector('title')?.text,
    ]);
    var description = _firstNonEmpty([
      _metaContent(document, 'og:description'),
      _metaContent(document, 'description'),
      _metaContent(document, 'twitter:description'),
      _firstEmbeddedString(fetched.body, const ['desc', 'description']),
    ]);
    var images = _collectDouyinImageUrls(
      document,
      fetched.finalUrl,
      html: fetched.body,
    );
    var videos = _collectDouyinVideoUrls(
      document,
      fetched.finalUrl,
      html: fetched.body,
    );

    if (images.isEmpty && videos.isEmpty) {
      for (final fallbackUrl in _douyinFallbackUrls(
        sourceUrl,
        fetched.finalUrl,
      )) {
        if (_dedupeKey(fallbackUrl) == _dedupeKey(fetched.finalUrl)) continue;
        try {
          final fallback = await _fetchHtml(client, fallbackUrl);
          final fallbackDocument = html_parser.parse(fallback.body);
          final fallbackTitle = _firstNonEmpty([
            _metaContent(fallbackDocument, 'og:title'),
            _metaContent(fallbackDocument, 'twitter:title'),
            _firstEmbeddedString(fallback.body, const ['title', 'aweme_title']),
            fallbackDocument.querySelector('title')?.text,
          ]);
          final fallbackDescription = _firstNonEmpty([
            _metaContent(fallbackDocument, 'og:description'),
            _metaContent(fallbackDocument, 'description'),
            _metaContent(fallbackDocument, 'twitter:description'),
            _firstEmbeddedString(fallback.body, const ['desc', 'description']),
          ]);
          final fallbackImages = _collectDouyinImageUrls(
            fallbackDocument,
            fallback.finalUrl,
            html: fallback.body,
          );
          final fallbackVideos = _collectDouyinVideoUrls(
            fallbackDocument,
            fallback.finalUrl,
            html: fallback.body,
          );
          if (fallbackTitle.isEmpty &&
              fallbackDescription.isEmpty &&
              fallbackImages.isEmpty &&
              fallbackVideos.isEmpty) {
            continue;
          }
          resultFinalUrl = fallback.finalUrl;
          title = _firstNonEmpty([title, fallbackTitle]);
          description = _firstNonEmpty([description, fallbackDescription]);
          if (fallbackImages.isNotEmpty) images = fallbackImages;
          if (fallbackVideos.isNotEmpty) videos = fallbackVideos;
          if (images.isNotEmpty || videos.isNotEmpty) break;
        } catch (_) {
          continue;
        }
      }
    }

    if (title.isEmpty &&
        description.isEmpty &&
        images.isEmpty &&
        videos.isEmpty &&
        !_isDouyinUrl(sourceUrl) &&
        !_isDouyinUrl(fetched.finalUrl)) {
      return null;
    }

    final downloaded = await _downloadImages(
      client,
      images,
      docDir: docDir,
      maxImages: maxImages,
      referer: resultFinalUrl,
    );
    final downloadedVideos = await _downloadVideos(
      client,
      videos,
      docDir: docDir,
      maxVideos: maxVideos,
      referer: resultFinalUrl,
    );

    final warnings = <String>[
      '已尝试从抖音公开分享页提取视频、图集和封面；如果页面需要登录或签名已过期，可能只能拿到部分素材。',
      '不会抹除视频或图片里原本就存在的作者、商家或版权水印；请确认你有权使用导入素材。',
    ];
    if (images.isEmpty && videos.isEmpty) {
      warnings.add('没有识别到可下载的抖音图片或视频；可以尝试复制浏览器打开后的最终链接再导入。');
    }
    if (images.isNotEmpty && downloaded.images.isEmpty) {
      warnings.add('识别到抖音图片地址，但下载失败；平台可能临时限制外部访问。');
    }
    if (videos.isNotEmpty && downloadedVideos.videos.isEmpty) {
      warnings.add('识别到抖音视频地址，但下载失败；视频可能过大、签名过期或平台限制外部访问。');
    }

    return await _saveLinkManifest(
      EcommerceMaterialImportResult(
        sourceUrl: sourceUrl,
        finalUrl: resultFinalUrl,
        platform: '抖音',
        title: title,
        description: description,
        copyText: _copyTextFromParts(title, description),
        images: downloaded.images,
        videos: downloadedVideos.videos,
        candidateImageCount: images.length,
        candidateVideoCount: videos.length,
        cleanedUrlCount: downloaded.cleanedUrlCount,
        warnings: warnings,
      ),
      docDir: docDir,
    );
  }

  static Uri? _extractJsRedirectUrl(String html, Uri base) {
    for (final pattern in [
      RegExp(r"""var\s+url\s*=\s*'([^']+)'"""),
      RegExp(r'''var\s+url\s*=\s*"([^"]+)"'''),
    ]) {
      final match = pattern.firstMatch(html);
      final raw = match?.group(1);
      if (raw == null || raw.isEmpty) continue;
      final parsed = Uri.tryParse(raw);
      if (parsed == null) continue;
      return base.resolveUri(parsed);
    }
    return null;
  }

  static bool _isItemId(String? value) =>
      value != null && RegExp(r'^[0-9]{8,}$').hasMatch(value);

  static Future<EcommerceMaterialImportResult?> _tryImportXiaohongshu(
    HttpClient client, {
    required Uri sourceUrl,
    required _FetchedHtml fetched,
    required dom.Document document,
    required String docDir,
    required int maxImages,
    required int maxVideos,
  }) async {
    final hasXhsMarkup =
        document.querySelector('img[data-xhs-img], .author-desc-content') !=
        null;
    if (!_isXiaohongshuUrl(sourceUrl) &&
        !_isXiaohongshuUrl(fetched.finalUrl) &&
        !hasXhsMarkup) {
      return null;
    }

    final title = _firstNonEmpty([
      document.querySelector('.title-no-padding-top')?.text,
      document.querySelector('.note-content .title')?.text,
      document.querySelector('.content-container .title')?.text,
      _metaContent(document, 'og:title'),
      document.querySelector('title')?.text,
    ]);
    final description = _firstNonEmpty([
      document.querySelector('.author-desc .note-desc-text-opt')?.text,
      document.querySelector('.author-desc-content')?.text,
      document.querySelector('.author-desc')?.text,
      _metaContent(document, 'description'),
      _metaContent(document, 'og:description'),
    ]);
    final images = _collectXiaohongshuImageUrls(
      document,
      fetched.finalUrl,
      html: fetched.body,
    );
    final videos =
        _isXiaohongshuVideoNote(fetched.finalUrl, fetched.body, document)
            ? _collectXiaohongshuVideoUrls(
              document,
              fetched.finalUrl,
              html: fetched.body,
            )
            : <Uri>[];
    if (title.isEmpty &&
        description.isEmpty &&
        images.isEmpty &&
        videos.isEmpty) {
      return null;
    }

    final downloaded = await _downloadImages(
      client,
      images,
      docDir: docDir,
      maxImages: maxImages,
      referer: fetched.finalUrl,
    );
    final downloadedVideos = await _downloadVideos(
      client,
      videos,
      docDir: docDir,
      maxVideos: maxVideos,
      referer: fetched.finalUrl,
    );
    final warnings = <String>[
      '已从小红书公开笔记页提取正文、图片和视频；如果页面要求登录，可能只能拿到部分内容。',
      '不会抹除图片里原本就存在的作者、商家或版权水印；请确认你有权使用导入素材。',
    ];
    if (images.isNotEmpty && downloaded.images.isEmpty) {
      warnings.add('识别到小红书图片地址，但下载失败；平台可能临时限制了外部访问。');
    }
    if (videos.isNotEmpty && downloadedVideos.videos.isEmpty) {
      warnings.add('识别到小红书视频地址，但下载失败；视频可能过大或平台临时限制外部访问。');
    }

    return await _saveLinkManifest(
      EcommerceMaterialImportResult(
        sourceUrl: sourceUrl,
        finalUrl: fetched.finalUrl,
        platform: '小红书',
        title: title,
        description: description,
        copyText: _copyTextFromParts(title, description),
        images: downloaded.images,
        videos: downloadedVideos.videos,
        candidateImageCount: images.length,
        candidateVideoCount:
            downloadedVideos.videos.isNotEmpty
                ? downloadedVideos.videos.length
                : videos.length,
        cleanedUrlCount: downloaded.cleanedUrlCount,
        warnings: warnings,
      ),
      docDir: docDir,
    );
  }

  static bool _isXiaohongshuUrl(Uri uri) {
    final host = uri.host.toLowerCase();
    return host.contains('xiaohongshu.com') || host.contains('xhslink.com');
  }

  static bool _isXiaohongshuVideoNote(
    Uri finalUrl,
    String html,
    dom.Document document,
  ) {
    final shareType = finalUrl.queryParameters['type']?.toLowerCase();
    if (shareType == 'video') return true;
    if (shareType == 'normal') return false;
    if (document.querySelector('.video-container, video') != null) {
      return true;
    }
    return RegExp(r'"type"\s*:\s*"video"').hasMatch(_decodeEscapedText(html));
  }

  static List<Uri> _collectXiaohongshuImageUrls(
    dom.Document document,
    Uri base, {
    String? html,
  }) {
    final urls = <Uri>[];
    final seen = <String>{};

    final structured = _collectXiaohongshuStructuredImageUrls(html, base);
    if (structured.isNotEmpty) return structured;

    void add(String? raw, {bool embedded = false}) {
      if (raw == null || raw.trim().isEmpty) return;
      for (final part in _srcsetParts(raw)) {
        final uri = _resolveImageUri(part, base);
        if (uri == null || !_looksLikeUsefulImage(uri)) continue;
        if (embedded && !_looksLikeXiaohongshuImage(uri, base)) continue;
        if (seen.add(_xiaohongshuImageDedupeKey(uri))) urls.add(uri);
      }
    }

    for (final image in document.querySelectorAll(
      'img[data-xhs-img], img.long-size-image, .image-gallery-container img',
    )) {
      add(image.attributes['src']);
      add(image.attributes['data-src']);
      add(image.attributes['srcset']);
    }
    if (urls.isEmpty) {
      for (final key in ['og:image', 'twitter:image', 'image']) {
        add(_metaContent(document, key));
      }
    }
    return _sortVideoUrlsForQuality(urls);
  }

  static List<Uri> _collectXiaohongshuStructuredImageUrls(
    String? html,
    Uri base,
  ) {
    if (html == null || html.isEmpty) return const <Uri>[];
    final imageLists = _extractJsonLikeArrays(html, '"imageList"');
    if (imageLists.isEmpty) return const <Uri>[];

    List<dynamic> best = const <dynamic>[];
    var bestScore = 0;
    for (final imageList in imageLists) {
      final score = _xiaohongshuImageListScore(imageList, base);
      if (score > bestScore) {
        best = imageList;
        bestScore = score;
      }
    }
    if (bestScore <= 0) return const <Uri>[];

    final urls = <Uri>[];
    final seen = <String>{};
    for (final item in best) {
      final raw = _preferredXiaohongshuImageUrl(item);
      if (raw == null || raw.isEmpty) continue;
      final uri = _resolveImageUri(raw, base);
      if (uri == null || !_looksLikeUsefulImage(uri)) continue;
      if (!_looksLikeXiaohongshuImage(uri, base)) continue;
      if (seen.add(_xiaohongshuImageDedupeKey(uri))) urls.add(uri);
    }
    return _sortVideoUrlsForQuality(urls);
  }

  static int _xiaohongshuImageListScore(List<dynamic> imageList, Uri base) {
    var score = 0;
    for (final item in imageList) {
      if (item is! Map) continue;
      final url = _preferredXiaohongshuImageUrl(item);
      if (url == null || url.isEmpty) continue;
      final uri = _resolveImageUri(url, base);
      if (uri == null || !_looksLikeUsefulImage(uri)) continue;
      if (!_looksLikeXiaohongshuImage(uri, base)) continue;
      score += 2;
      if (_stringValue(item['fileId']).isNotEmpty) score += 2;
      if (item['width'] is num && item['height'] is num) score += 1;
      final infoList = item['infoList'];
      if (infoList is List &&
          infoList.any(
            (entry) =>
                entry is Map &&
                _isXiaohongshuDetailImageScene(
                  _stringValue(entry['imageScene']),
                ),
          )) {
        score += 3;
      }
    }
    return score;
  }

  static String? _preferredXiaohongshuImageUrl(dynamic item) {
    if (item is! Map) return null;
    final infoList = item['infoList'];
    if (infoList is List) {
      for (final entry in infoList) {
        if (entry is! Map) continue;
        final scene = _stringValue(entry['imageScene']).toUpperCase();
        final url = _stringValue(entry['url']);
        if (url.isNotEmpty && _isXiaohongshuDetailImageScene(scene)) {
          return url;
        }
      }
      for (final entry in infoList) {
        if (entry is! Map) continue;
        final url = _stringValue(entry['url']);
        if (url.isNotEmpty &&
            (url.contains('!h5_') || url.contains('!nd_dft'))) {
          return url;
        }
      }
    }

    final urlDefault = _stringValue(item['urlDefault']);
    if (urlDefault.isNotEmpty) return urlDefault;

    final direct = _stringValue(item['url']);
    if (direct.isNotEmpty) return direct;

    final urlPre = _stringValue(item['urlPre']);
    if (urlPre.isNotEmpty) return urlPre;
    return null;
  }

  static bool _isXiaohongshuDetailImageScene(String scene) {
    final upper = scene.toUpperCase();
    return upper == 'H5_DTL' ||
        upper == 'WB_DFT' ||
        upper.endsWith('_DFT') ||
        upper.endsWith('_DTL');
  }

  static List<List<dynamic>> _extractJsonLikeArrays(String text, String key) {
    final arrays = <List<dynamic>>[];
    var cursor = 0;
    while (cursor < text.length) {
      final keyIndex = text.indexOf(key, cursor);
      if (keyIndex < 0) break;
      final bracketIndex = text.indexOf('[', keyIndex + key.length);
      if (bracketIndex < 0) break;
      final end = _matchingJsonLikeEnd(text, bracketIndex, '[', ']');
      if (end < 0) {
        cursor = bracketIndex + 1;
        continue;
      }
      final raw = text.substring(bracketIndex, end + 1);
      try {
        final decoded = json.decode(_sanitizeJsonLike(raw));
        if (decoded is List) arrays.add(decoded);
      } catch (_) {}
      cursor = end + 1;
    }
    return arrays;
  }

  static int _matchingJsonLikeEnd(
    String text,
    int start,
    String open,
    String close,
  ) {
    var depth = 0;
    var inString = false;
    var escaped = false;
    for (var i = start; i < text.length; i++) {
      final char = text[i];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (char == r'\') {
          escaped = true;
        } else if (char == '"') {
          inString = false;
        }
        continue;
      }
      if (char == '"') {
        inString = true;
      } else if (char == open) {
        depth++;
      } else if (char == close) {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1;
  }

  static String _sanitizeJsonLike(String value) {
    return value
        .replaceAllMapped(
          RegExp(r'(:|\[|,)\s*undefined\s*(?=,|\]|\})'),
          (match) => '${match.group(1)}null',
        )
        .replaceAll(RegExp(r',\s*(?=[\]}])'), '');
  }

  static List<Uri> _collectXiaohongshuVideoUrls(
    dom.Document document,
    Uri base, {
    String? html,
  }) {
    final structured = _collectXiaohongshuStructuredVideoUrls(html, base);
    if (structured.isNotEmpty) return structured;

    final urls = <Uri>[];
    final seen = <String>{};
    for (final text in _xiaohongshuEmbeddedTexts(document, html)) {
      for (final uri in _extractUrlsFromText(text, base)) {
        if (!_looksLikeUsefulVideo(uri)) continue;
        if (seen.add(_dedupeKey(uri))) urls.add(uri);
      }
    }
    return _sortVideoUrlsForQuality(urls);
  }

  static List<Uri> _collectXiaohongshuStructuredVideoUrls(
    String? html,
    Uri base,
  ) {
    if (html == null || html.isEmpty) return const <Uri>[];

    final scored = <_ScoredUri>[];
    var index = 0;

    void add(dynamic raw, int score) {
      final value = _stringValue(raw);
      if (value.isEmpty) return;
      final uri = _resolveImageUri(value, base);
      if (uri == null || !_looksLikeUsefulVideo(uri)) return;
      scored.add(_ScoredUri(uri, score + _videoQualityScore(uri), index++));
    }

    for (final key in ['"h264"', '"h265"', '"video"']) {
      for (final streamList in _extractJsonLikeArrays(html, key)) {
        for (final entry in streamList) {
          if (entry is! Map) continue;
          final streamScore = _xiaohongshuStreamScore(entry);
          add(entry['masterUrl'], streamScore + 30);
          final backupUrls = entry['backupUrls'];
          if (backupUrls is List) {
            for (final backupUrl in backupUrls) {
              add(backupUrl, streamScore - 20);
            }
          }
        }
      }
    }

    if (scored.isEmpty) return const <Uri>[];
    scored.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;
      return a.index.compareTo(b.index);
    });

    final urls = <Uri>[];
    final seen = <String>{};
    for (final candidate in scored) {
      if (seen.add(_videoDedupeKey(candidate.uri))) {
        urls.add(candidate.uri);
      }
    }
    return urls;
  }

  static int _xiaohongshuStreamScore(Map<dynamic, dynamic> stream) {
    var score = 0;
    final width = _numValue(stream['width']);
    final height = _numValue(stream['height']);
    if (width > 0 && height > 0) {
      score += (width * height / 1000).round();
    }
    final size = _numValue(stream['size']);
    if (size > 0) score += (size / (1024 * 1024) * 8).round();
    for (final key in ['avgBitrate', 'videoBitrate', 'bitrate']) {
      final bitrate = _numValue(stream[key]);
      if (bitrate > 0) score += (bitrate / 1000).round();
    }

    final quality = _stringValue(stream['qualityType']).toUpperCase();
    if (quality.contains('ORIGIN') || quality.contains('SOURCE')) score += 900;
    if (quality.contains('UHD') || quality.contains('4K')) score += 800;
    if (quality.contains('FHD') || quality.contains('1080')) score += 650;
    if (quality == 'HD' || quality.contains('720')) score += 450;
    if (quality.contains('SD') || quality.contains('480')) score += 250;

    final codec = _stringValue(stream['videoCodec']).toLowerCase();
    if (codec.contains('h264') || codec.contains('avc')) score += 20;
    if (stream['defaultStream'] == 1) score += 10;
    return score;
  }

  static bool _isDouyinUrl(Uri uri) {
    final host = uri.host.toLowerCase();
    return host.contains('douyin.com') ||
        host.contains('iesdouyin.com') ||
        host.contains('douyinvod.com') ||
        host.contains('douyinpic.com') ||
        host.contains('douyincdn.com');
  }

  static bool _hasDouyinSignals(String html) {
    final lower = html.toLowerCase();
    return lower.contains('douyin') || lower.contains('aweme');
  }

  static List<Uri> _douyinFallbackUrls(Uri sourceUrl, Uri finalUrl) {
    final urls = <Uri>[];
    final seen = <String>{};

    void add(Uri uri) {
      if (seen.add(_dedupeKey(uri))) urls.add(uri);
    }

    for (final id in _douyinVideoIds(sourceUrl, finalUrl)) {
      if (_isLocalHost(finalUrl.host)) {
        add(
          finalUrl.replace(
            path: '/share/video/$id/',
            query: null,
            fragment: null,
          ),
        );
      } else {
        add(Uri.https('www.iesdouyin.com', '/share/video/$id/'));
        add(Uri.https('m.douyin.com', '/share/video/$id'));
      }
    }
    return _sortVideoUrlsForQuality(urls);
  }

  static List<String> _douyinVideoIds(Uri sourceUrl, Uri finalUrl) {
    final ids = <String>[];
    final seen = <String>{};

    void add(String? value) {
      if (value == null || value.isEmpty) return;
      if (!RegExp(r'^\d{8,}$').hasMatch(value)) return;
      if (seen.add(value)) ids.add(value);
    }

    for (final uri in [sourceUrl, finalUrl]) {
      for (final segment in uri.pathSegments) {
        add(segment);
      }
      for (final key in [
        'aweme_id',
        'item_id',
        'itemId',
        'modal_id',
        'group_id',
        'video_id',
      ]) {
        add(uri.queryParameters[key]);
      }
    }
    return ids;
  }

  static List<Uri> _collectDouyinImageUrls(
    dom.Document document,
    Uri base, {
    String? html,
  }) {
    final urls = <Uri>[];
    final seen = <String>{};

    void add(String? raw) {
      if (raw == null || raw.trim().isEmpty) return;
      for (final part in _srcsetParts(raw)) {
        final uri = _resolveImageUri(part, base);
        if (uri == null || !_looksLikeUsefulImage(uri)) continue;
        if (!_looksLikeDouyinImage(uri, base)) continue;
        if (seen.add(_douyinImageDedupeKey(uri))) urls.add(uri);
      }
    }

    for (final key in [
      'og:image',
      'og:image:url',
      'twitter:image',
      'twitter:image:src',
      'image',
    ]) {
      add(_metaContent(document, key));
    }
    for (final image in document.querySelectorAll('img, source')) {
      for (final attr in [
        'src',
        'srcset',
        'data-src',
        'data-original',
        'data-url',
      ]) {
        add(image.attributes[attr]);
      }
    }
    for (final text in _embeddedTexts(document, html)) {
      for (final uri in _extractUrlsFromText(text, base)) {
        if (!_looksLikeUsefulImage(uri)) continue;
        if (!_looksLikeDouyinImage(uri, base)) continue;
        if (seen.add(_douyinImageDedupeKey(uri))) urls.add(uri);
      }
    }
    return _sortVideoUrlsForQuality(urls);
  }

  static List<Uri> _collectDouyinVideoUrls(
    dom.Document document,
    Uri base, {
    String? html,
  }) {
    final structured = _collectDouyinStructuredVideoUrls(html, base);
    if (structured.isNotEmpty) return structured;

    final urls = <Uri>[];
    final seen = <String>{};

    void add(String? raw) {
      if (raw == null || raw.trim().isEmpty) return;
      final uri = _resolveImageUri(raw, base);
      if (uri == null || !_looksLikeUsefulVideo(uri)) return;
      if (!_looksLikeDouyinVideo(uri, base)) return;
      for (final candidate in _douyinVideoDownloadCandidates(uri)) {
        if (seen.add(_dedupeKey(candidate))) urls.add(candidate);
      }
    }

    for (final key in [
      'og:video',
      'og:video:url',
      'og:video:secure_url',
      'twitter:player:stream',
      'video',
    ]) {
      add(_metaContent(document, key));
    }
    for (final node in document.querySelectorAll('video, source, a')) {
      add(node.attributes['src']);
      add(node.attributes['data-src']);
      add(node.attributes['href']);
    }
    for (final text in _embeddedTexts(document, html)) {
      for (final uri in _extractUrlsFromText(text, base)) {
        if (!_looksLikeUsefulVideo(uri)) continue;
        if (!_looksLikeDouyinVideo(uri, base)) continue;
        if (seen.add(_dedupeKey(uri))) urls.add(uri);
      }
    }
    return _sortVideoUrlsForQuality(urls);
  }

  static List<Uri> _collectDouyinStructuredVideoUrls(String? html, Uri base) {
    if (html == null || html.isEmpty) return const <Uri>[];

    final scored = <_ScoredUri>[];
    final seenOccurrence = <String>{};
    var index = 0;
    final urlPattern = RegExp(r"""https?://[^\s"'<>\\]+""");

    for (final normalized in _decodedTextVariants(html)) {
      for (final match in urlPattern.allMatches(normalized)) {
        var raw = match.group(0) ?? '';
        raw = raw.replaceFirst(RegExp(r'[\]\)},.;]+$'), '');
        final uri = _resolveImageUri(raw, base);
        if (uri == null || !_looksLikeUsefulVideo(uri)) continue;
        if (!_looksLikeDouyinVideo(uri, base)) continue;

        final contextStart = match.start > 320 ? match.start - 320 : 0;
        final context = normalized.substring(contextStart, match.start);
        for (final candidate in _douyinVideoDownloadCandidates(uri)) {
          final occurrenceKey = _dedupeKey(candidate);
          if (!seenOccurrence.add(occurrenceKey)) continue;
          final score =
              _videoQualityScore(candidate) +
              _douyinVideoContextScore(context, candidate);
          scored.add(_ScoredUri(candidate, score, index++));
        }
      }
    }

    if (scored.isEmpty) return const <Uri>[];
    scored.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;
      return a.index.compareTo(b.index);
    });

    final urls = <Uri>[];
    final seenVideo = <String>{};
    for (final candidate in scored) {
      if (seenVideo.add(_videoDedupeKey(candidate.uri))) {
        urls.add(candidate.uri);
      }
    }
    return urls;
  }

  static Iterable<Uri> _douyinVideoDownloadCandidates(Uri uri) sync* {
    final clean = _douyinNoWatermarkPlayUri(uri);
    if (clean != null) yield clean;
    yield uri;
  }

  static Uri? _douyinNoWatermarkPlayUri(Uri uri) {
    var changed = false;
    final segments = <String>[];
    for (final segment in uri.pathSegments) {
      if (segment.toLowerCase() == 'playwm') {
        segments.add('play');
        changed = true;
      } else {
        segments.add(segment);
      }
    }
    if (!changed) return null;

    final query = <String, List<String>>{};
    for (final entry in uri.queryParametersAll.entries) {
      final key = entry.key.toLowerCase();
      if (key == 'wm' ||
          key == 'wmark' ||
          key == 'watermark' ||
          key == 'is_watermark' ||
          key == 'water_mark') {
        continue;
      }
      query[entry.key] = entry.value;
    }

    final path = '/${segments.map(Uri.encodeComponent).join('/')}';
    return uri.replace(
      path: path,
      queryParameters: query.isEmpty ? null : query,
    );
  }

  static int _douyinVideoContextScore(String context, Uri uri) {
    final lower = context.toLowerCase();
    var score = 0;

    if (lower.contains('bit_rate') || lower.contains('bitrate')) {
      score += 1000;
    }
    if (lower.contains('play_addr') || lower.contains('playaddr')) {
      score += 900;
    }
    if (lower.contains('url_list') || lower.contains('urllist')) {
      score += 120;
    }
    if (lower.contains('download_addr') || lower.contains('downloadaddr')) {
      score += 80;
    }
    if (lower.contains('origin') || lower.contains('source')) {
      score += 500;
    }
    if (lower.contains('playwm') ||
        lower.contains('watermark') ||
        lower.contains('water_mark') ||
        lower.contains('downloadwm')) {
      score -= 5000;
    }
    if (_isLikelyWatermarkedVideoUrl(uri)) score -= 8000;

    return score;
  }

  static bool _looksLikeDouyinImage(Uri uri, Uri base) {
    final lower = uri.toString().toLowerCase();
    if (lower.contains('avatar') ||
        lower.contains('/user/') ||
        lower.contains('emoji') ||
        lower.contains('music-cover')) {
      return false;
    }
    final host = uri.host.toLowerCase();
    if (host.contains('douyinpic.com') ||
        host.contains('byteimg.com') ||
        host.contains('pstatp.com') ||
        host.contains('douyincdn.com')) {
      return true;
    }
    return _isLocalHost(base.host) && uri.host == base.host;
  }

  static bool _looksLikeDouyinVideo(Uri uri, Uri base) {
    final lower = uri.toString().toLowerCase();
    if (lower.contains('avatar') ||
        lower.contains('cover') ||
        lower.contains('music')) {
      return false;
    }
    final host = uri.host.toLowerCase();
    if (host.contains('douyinvod.com') ||
        host.contains('douyin.com') ||
        host.contains('iesdouyin.com') ||
        host.contains('snssdk.com') ||
        host.contains('bytevodd.com') ||
        host.contains('pstatp.com')) {
      return true;
    }
    if (lower.contains('/aweme/v1/play') || lower.contains('/video/tos')) {
      return true;
    }
    return _isLocalHost(base.host) &&
        uri.host == base.host &&
        (lower.contains('/aweme/') || lower.contains('/video/'));
  }

  static bool _looksLikeGoofishVideo(Uri uri) {
    final lower = uri.toString().toLowerCase();
    final host = uri.host.toLowerCase();
    if (lower.contains('avatar') ||
        lower.contains('cover') ||
        lower.contains('img.alicdn.com')) {
      return false;
    }
    return host.contains('cloud.video.taobao.com') ||
        host.contains('xianyu-video.alicdn.com') ||
        host.contains('video.taobao.com') ||
        _extensionFromVideoUrl(uri) != null;
  }

  static String _douyinImageDedupeKey(Uri uri) {
    final normalized = uri.replace(query: '', fragment: '');
    return normalized.toString();
  }

  static Iterable<String> _xiaohongshuEmbeddedTexts(
    dom.Document document,
    String? html,
  ) sync* {
    yield* _embeddedTexts(document, html);
  }

  static Iterable<String> _embeddedTexts(
    dom.Document document,
    String? html,
  ) sync* {
    final body = html ?? '';
    if (body.isNotEmpty) yield body;
    for (final script in document.querySelectorAll('script')) {
      final text = script.text.trim();
      if (text.isNotEmpty) yield text;
    }
  }

  static Iterable<Uri> _extractUrlsFromText(String text, Uri base) sync* {
    final urlPattern = RegExp(r"""https?://[^\s"'<>\\]+""");
    for (final normalized in _decodedTextVariants(text)) {
      for (final match in urlPattern.allMatches(normalized)) {
        var raw = match.group(0) ?? '';
        raw = raw.replaceFirst(RegExp(r'[\]\)},.;]+$'), '');
        final uri = _resolveImageUri(raw, base);
        if (uri != null) yield uri;
      }
    }
  }

  static Iterable<String> _decodedTextVariants(String text) sync* {
    final normalized = _decodeEscapedText(text);
    yield normalized;
    try {
      final decoded = Uri.decodeFull(normalized);
      if (decoded != normalized) yield _decodeEscapedText(decoded);
    } catch (_) {}
  }

  static String _firstEmbeddedString(String text, List<String> keys) {
    for (final normalized in _decodedTextVariants(text)) {
      for (final key in keys) {
        final escaped = RegExp.escape(key);
        final match = RegExp(
          '"$escaped"\\s*:\\s*"((?:\\\\.|[^"\\\\])*)"',
        ).firstMatch(normalized);
        if (match == null) continue;
        final value = _cleanText(_decodeEscapedText(match.group(1) ?? ''));
        if (value.isNotEmpty) return value;
      }
    }
    return '';
  }

  static bool _looksLikeXiaohongshuImage(Uri uri, Uri base) {
    final lower = uri.toString().toLowerCase();
    if (lower.contains('xhscdn.com') ||
        lower.contains('xhsimg.com') ||
        lower.contains('sns-webpic') ||
        lower.contains('sns-img')) {
      return true;
    }
    return _isLocalHost(base.host) && uri.host == base.host;
  }

  static bool _isLocalHost(String host) =>
      host == '127.0.0.1' || host == 'localhost' || host == '::1';

  static String _xiaohongshuImageDedupeKey(Uri uri) {
    final segments = uri.pathSegments;
    if (segments.isEmpty) return _dedupeKey(uri);
    final last = segments.last;
    final lower = uri.host.toLowerCase();
    final shouldStripStyle =
        last.contains('!') ||
        lower.contains('xhscdn.com') ||
        lower.contains('xhsimg.com');
    if (!shouldStripStyle) return _dedupeKey(uri);
    final fileId = last.split('!').first;
    return '${uri.scheme}://${uri.host}/${segments.take(segments.length - 1).join('/')}/$fileId';
  }

  static List<Uri> _sortVideoUrlsForQuality(List<Uri> urls) {
    final scored = <_ScoredUri>[
      for (var i = 0; i < urls.length; i++)
        _ScoredUri(urls[i], _videoQualityScore(urls[i]), i),
    ];
    scored.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;
      return a.index.compareTo(b.index);
    });
    return [for (final item in scored) item.uri];
  }

  static int _videoQualityScore(Uri uri) {
    final lower = uri.toString().toLowerCase();
    var score = 0;

    if (_isLikelyWatermarkedVideoUrl(uri)) score -= 8000;

    final ratio = uri.queryParameters['ratio']?.toLowerCase();
    score += _resolutionScore(ratio ?? '');

    for (final match in RegExp(
      r'(?<!\d)([1-9]\d{2,4})[x*_/-]([1-9]\d{2,4})(?!\d)',
    ).allMatches(lower)) {
      final width = int.tryParse(match.group(1) ?? '') ?? 0;
      final height = int.tryParse(match.group(2) ?? '') ?? 0;
      if (width > 0 && height > 0) {
        score += (width * height / 1000).round();
      }
    }

    score += _resolutionScore(lower);
    if (lower.contains('origin') ||
        lower.contains('original') ||
        lower.contains('/raw') ||
        lower.contains('source')) {
      score += 1200;
    }
    if (RegExp(r'/(uhd|4k)(/|_|-|\.)').hasMatch(lower)) score += 900;
    if (RegExp(r'/(hd|720p?)(/|_|-|\.)').hasMatch(lower)) score += 600;
    if (RegExp(r'/(sd|480p?)(/|_|-|\.)').hasMatch(lower)) score += 350;
    if (RegExp(r'/(ld|320p?)(/|_|-|\.)').hasMatch(lower)) score += 120;

    if (lower.contains('master')) score += 80;
    if (lower.contains('backup') || lower.contains('bak-')) score -= 50;
    if (lower.contains('preview') ||
        lower.contains('thumb') ||
        lower.contains('cover')) {
      score -= 500;
    }
    return score;
  }

  static bool _isLikelyWatermarkedVideoUrl(Uri uri) {
    final lower = uri.toString().toLowerCase();
    if (lower.contains('playwm') ||
        lower.contains('watermark') ||
        lower.contains('water_mark') ||
        lower.contains('/wm/') ||
        lower.contains('/watermark/')) {
      return true;
    }
    for (final entry in uri.queryParameters.entries) {
      final key = entry.key.toLowerCase();
      final value = entry.value.toLowerCase();
      if (key == 'wm' ||
          key == 'wmark' ||
          key == 'watermark' ||
          key == 'is_watermark' ||
          key == 'water_mark' ||
          value == 'watermark' ||
          value == 'playwm') {
        return true;
      }
    }
    return false;
  }

  static int _resolutionScore(String value) {
    final lower = value.toLowerCase();
    var score = 0;
    for (final match in RegExp(r'([1-9]\d{2,4})p').allMatches(lower)) {
      final height = int.tryParse(match.group(1) ?? '') ?? 0;
      score += height * 2;
    }
    if (lower.contains('2160') || lower.contains('4k')) score += 4320;
    if (lower.contains('1440')) score += 2880;
    if (lower.contains('1080')) score += 2160;
    if (lower.contains('720')) score += 1440;
    if (lower.contains('480')) score += 960;
    if (lower.contains('360')) score += 720;
    if (lower.contains('320')) score += 640;
    return score;
  }

  static String _videoDedupeKey(Uri uri) {
    final lower = uri.toString().toLowerCase();
    final videoId = uri.queryParameters['video_id'];
    if (videoId != null && videoId.isNotEmpty) return videoId;
    final segments = uri.pathSegments;
    if (segments.isEmpty) return _dedupeKey(uri);
    if (lower.contains('/stream/')) {
      final last = segments.last.toLowerCase();
      final grouped = last.replaceFirst(
        RegExp(r'_[0-9]{2,4}(\.(?:mp4|mov|m4v|webm))$'),
        r'$1',
      );
      return '${uri.host}/${segments.take(segments.length - 1).join('/')}/$grouped';
    }
    if (!lower.contains('/stream/') && _extensionFromVideoUrl(uri) == null) {
      return _dedupeKey(uri);
    }
    return segments.last.toLowerCase();
  }

  static PlatformImageUrl cleanPlatformImageUrl(Uri uri) {
    final filtered = <String, List<String>>{};
    var changed = false;

    uri.queryParametersAll.forEach((key, values) {
      final lowerKey = key.toLowerCase();
      final lowerValue = values.join(',').toLowerCase();
      final shouldRemove =
          lowerKey.contains('watermark') ||
          lowerKey == 'wm' ||
          lowerKey == 'wmark' ||
          lowerKey == 'image_process' ||
          lowerKey == 'imageprocess' ||
          lowerKey == 'x-oss-process' ||
          lowerKey == 'imageview2' ||
          lowerKey == 'imagemogr2' ||
          lowerValue.contains('watermark') ||
          lowerValue.contains('/wm/');
      if (shouldRemove) {
        changed = true;
      } else {
        filtered[key] = values;
      }
    });

    final cleanedPath = _cleanImagePath(uri.path);
    if (cleanedPath != uri.path) changed = true;

    final query = _queryString(filtered);
    var cleaned = Uri(
      scheme: uri.scheme,
      userInfo: uri.userInfo,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: cleanedPath,
      query: query.isEmpty ? null : query,
      fragment: uri.fragment.isEmpty ? null : uri.fragment,
    );
    if (cleaned.scheme == 'http' && _canUpgradeImageHost(cleaned.host)) {
      cleaned = cleaned.replace(scheme: 'https');
      changed = true;
    }

    return PlatformImageUrl(uri: cleaned, cleanedPlatformWatermark: changed);
  }

  static bool _canUpgradeImageHost(String host) {
    final lower = host.toLowerCase();
    return lower.contains('alicdn.com') ||
        lower.contains('jdimg.com') ||
        lower.contains('pinduoduo.com') ||
        lower.contains('douyinpic.com') ||
        lower.contains('byteimg.com') ||
        lower.contains('pstatp.com') ||
        lower.contains('douyincdn.com') ||
        lower.contains('xhscdn.com');
  }

  static Future<_FetchedHtml> _fetchHtml(HttpClient client, Uri url) async {
    final response = await _get(
      client,
      url,
      accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('页面访问失败：HTTP ${response.statusCode}', uri: url);
    }
    final bytes = await _readLimited(response, _maxHtmlBytes);
    final body = utf8.decode(bytes, allowMalformed: true);
    final finalUrl =
        response.redirects.isEmpty ? url : response.redirects.last.location;
    return _FetchedHtml(body: body, finalUrl: finalUrl);
  }

  static Future<HttpClientResponse> _get(
    HttpClient client,
    Uri url, {
    required String accept,
    Uri? referer,
  }) async {
    final request = await client.getUrl(url);
    request.followRedirects = true;
    request.maxRedirects = 5;
    request.headers.set(HttpHeaders.userAgentHeader, _userAgent);
    request.headers.set(HttpHeaders.acceptHeader, accept);
    request.headers.set(
      HttpHeaders.acceptLanguageHeader,
      'zh-CN,zh;q=0.9,en;q=0.8',
    );
    if (referer != null) {
      request.headers.set(HttpHeaders.refererHeader, referer.toString());
    }
    return request.close();
  }

  static Future<_GoofishDetail?> _fetchGoofishDetail(
    HttpClient client,
    String itemId,
  ) async {
    const api = 'mtop.taobao.idle.awesome.detail';
    const version = '1.0';
    const appKey = '12574478';
    final data = json.encode({'itemId': itemId});

    Future<_MtopResponse> request(String cookieHeader) async {
      final token = _mtopToken(cookieHeader);
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final sign =
          md5
              .convert(utf8.encode('$token&$timestamp&$appKey&$data'))
              .toString();
      final url = Uri.https('h5api.m.goofish.com', '/h5/$api/$version/', {
        'jsv': '2.7.3',
        'appKey': appKey,
        't': timestamp,
        'sign': sign,
        'api': api,
        'v': version,
        'type': 'originaljson',
        'dataType': 'json',
        'data': data,
      });
      final httpRequest = await client.getUrl(url);
      httpRequest.followRedirects = true;
      httpRequest.maxRedirects = 3;
      httpRequest.headers.set(HttpHeaders.userAgentHeader, _userAgent);
      httpRequest.headers.set(HttpHeaders.acceptHeader, 'application/json,*/*');
      httpRequest.headers.set(
        HttpHeaders.refererHeader,
        'https://h5.m.goofish.com/',
      );
      if (cookieHeader.isNotEmpty) {
        httpRequest.headers.set(HttpHeaders.cookieHeader, cookieHeader);
      }

      final response = await httpRequest.close();
      final bytes = await _readLimited(response, _maxHtmlBytes);
      final text = utf8.decode(bytes, allowMalformed: true);
      final cookies = response.cookies.map((c) => '${c.name}=${c.value}');
      final mergedCookie = [
        if (cookieHeader.isNotEmpty) cookieHeader,
        ...cookies,
      ].where((s) => s.trim().isNotEmpty).join('; ');
      return _MtopResponse(cookieHeader: mergedCookie, body: text);
    }

    try {
      final first = await request('');
      final second = await request(first.cookieHeader);
      final decoded = json.decode(second.body);
      if (decoded is! Map) return null;
      final ret = decoded['ret'];
      if (ret is List && ret.any((v) => v.toString().startsWith('SUCCESS'))) {
        final dataMap = decoded['data'];
        if (dataMap is Map) {
          return _parseGoofishDetail(Map<String, dynamic>.from(dataMap));
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static _GoofishDetail _parseGoofishDetail(Map<String, dynamic> data) {
    final item = _mapValue(data['itemDO']);
    final title = _firstNonEmpty([
      _stringValue(item['title']),
      _nestedString(data, [
        'flowData',
        'floating',
        'components',
        '2',
        'data',
        'title',
      ]),
    ]);
    final description = _firstNonEmpty([
      _stringValue(item['desc']),
      _nestedString(data, [
        'flowData',
        'body',
        'sections',
        '0',
        'components',
        '3',
        'data',
        'desc',
      ]),
    ]);
    final imageUrls = _goofishImageUrls(data, item);
    final copyText = _copyTextFromParts(title, description);
    final videoUrls = extractGoofishVideoUrls(data);
    return _GoofishDetail(
      title: title,
      description: description,
      copyText: copyText,
      imageUrls: imageUrls,
      videoUrls: videoUrls,
    );
  }

  static List<Uri> extractGoofishVideoUrls(Map<String, dynamic> data) {
    final urls = <Uri>[];
    final seen = <String>{};
    final base = Uri.parse('https://h5.m.goofish.com/');

    void add(dynamic value) {
      final raw = _stringValue(value);
      if (raw.isEmpty) return;
      final uri = _resolveImageUri(raw, base);
      if (uri == null || !_looksLikeUsefulVideo(uri)) return;
      if (!_looksLikeGoofishVideo(uri)) return;
      if (seen.add(_videoDedupeKey(uri))) urls.add(uri);
    }

    void addVideoPlayInfo(dynamic value) {
      if (value is! Map) return;
      for (final key in [
        'hd720pUrl',
        'sd480pUrl',
        'ld320pUrl',
        'hdUrl',
        'videoUrl',
        'playUrl',
      ]) {
        add(value[key]);
      }
    }

    void walk(dynamic value) {
      if (value is List) {
        for (final item in value) {
          walk(item);
        }
        return;
      }
      if (value is! Map) return;

      addVideoPlayInfo(value['videoPlayInfo']);
      addVideoPlayInfo(value['videoInfo']);
      addVideoPlayInfo(value['video']);
      for (final entry in value.entries) {
        final key = entry.key.toString().toLowerCase();
        final item = entry.value;
        if (key.contains('video') || key.contains('play')) {
          if (item is String) {
            add(item);
          } else {
            addVideoPlayInfo(item);
          }
        }
        walk(item);
      }
    }

    walk(data);
    return urls;
  }

  static List<Uri> _goofishImageUrls(
    Map<String, dynamic> data,
    Map<String, dynamic> item,
  ) {
    final urls = <Uri>[];
    final seen = <String>{};

    void add(dynamic value) {
      final raw = _stringValue(value);
      if (raw.isEmpty) return;
      final uri = _resolveImageUri(raw, Uri.parse('https://h5.m.goofish.com/'));
      if (uri == null || !_looksLikeUsefulImage(uri)) return;
      if (seen.add(_dedupeKey(uri))) urls.add(uri);
    }

    void addImageInfos(dynamic value) {
      if (value is! List) return;
      for (final entry in value) {
        if (entry is Map) add(entry['url']);
      }
    }

    addImageInfos(item['imageInfos']);
    final flowImageInfos = _nestedValue(data, [
      'flowData',
      'body',
      'sections',
      '0',
      'components',
      '6',
      'data',
      'imageInfos',
    ]);
    addImageInfos(flowImageInfos);

    if (urls.isEmpty) {
      add(_nestedValue(data, ['flowData', 'trackParams', 'mainPic']));
      add(
        _nestedValue(data, [
          'flowData',
          'floating',
          'components',
          '1',
          'data',
          'shareImageUrl',
        ]),
      );
    }
    return urls;
  }

  static String _mtopToken(String cookieHeader) {
    final match = RegExp(r'_m_h5_tk=([^_;]+)').firstMatch(cookieHeader);
    return match?.group(1) ?? '';
  }

  static Future<Uint8List> _readLimited(
    HttpClientResponse response,
    int maxBytes,
  ) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response) {
      builder.add(chunk);
      if (builder.length > maxBytes) {
        throw const HttpException('下载内容过大，已中止');
      }
    }
    return builder.takeBytes();
  }

  static String _metaContent(dom.Document document, String key) {
    final escaped = key.replaceAll('"', r'\"');
    final node =
        document.querySelector('meta[property="$escaped"]') ??
        document.querySelector('meta[name="$escaped"]') ??
        document.querySelector('meta[itemprop="$escaped"]');
    return _cleanText(node?.attributes['content'] ?? '');
  }

  static _JsonLdExtract _extractJsonLd(dom.Document document) {
    final texts = <String, List<String>>{};
    final images = <String>[];
    final videos = <String>[];
    for (final script in document.querySelectorAll('script')) {
      final type = (script.attributes['type'] ?? '').toLowerCase();
      if (!type.contains('ld+json')) continue;
      final raw = script.text.trim();
      if (raw.isEmpty) continue;
      try {
        final decoded = json.decode(raw);
        _walkJsonLd(decoded, texts, images, videos);
      } catch (_) {
        continue;
      }
    }
    return _JsonLdExtract(texts: texts, images: images, videos: videos);
  }

  static void _walkJsonLd(
    dynamic value,
    Map<String, List<String>> texts,
    List<String> images,
    List<String> videos,
  ) {
    if (value is List) {
      for (final item in value) {
        _walkJsonLd(item, texts, images, videos);
      }
      return;
    }
    if (value is! Map) return;

    for (final entry in value.entries) {
      final key = entry.key.toString();
      final lowerKey = key.toLowerCase();
      final item = entry.value;
      if (item is String) {
        if (lowerKey == 'name' ||
            lowerKey == 'headline' ||
            lowerKey == 'description') {
          texts.putIfAbsent(lowerKey, () => <String>[]).add(item);
        }
        if (lowerKey == 'image' || lowerKey == 'thumbnailurl') {
          images.add(item);
        }
        if (lowerKey == 'video' ||
            lowerKey == 'videourl' ||
            lowerKey == 'contenturl' ||
            lowerKey == 'embedurl') {
          videos.add(item);
        }
      } else if (item is List &&
          (lowerKey == 'image' || lowerKey == 'images')) {
        for (final image in item) {
          if (image is String) images.add(image);
          if (image is Map) _walkJsonLd(image, texts, images, videos);
        }
      } else if (item is List &&
          (lowerKey == 'video' || lowerKey == 'videos')) {
        for (final video in item) {
          if (video is String) videos.add(video);
          if (video is Map) _walkJsonLd(video, texts, images, videos);
        }
      } else {
        _walkJsonLd(item, texts, images, videos);
      }
    }
  }

  static List<Uri> _collectImageUrls(
    dom.Document document,
    _JsonLdExtract jsonLd,
    Uri base,
  ) {
    final urls = <Uri>[];
    final seen = <String>{};

    void addRaw(String? raw) {
      if (raw == null || raw.trim().isEmpty) return;
      for (final part in _srcsetParts(raw)) {
        final uri = _resolveImageUri(part, base);
        if (uri == null || !_looksLikeUsefulImage(uri)) continue;
        if (seen.add(_dedupeKey(uri))) urls.add(uri);
      }
    }

    for (final key in [
      'og:image',
      'og:image:url',
      'twitter:image',
      'twitter:image:src',
      'image',
    ]) {
      addRaw(_metaContent(document, key));
    }

    for (final image in jsonLd.images) {
      addRaw(image);
    }

    for (final image in document.querySelectorAll('img, source')) {
      for (final attr in [
        'src',
        'srcset',
        'data-src',
        'data-original',
        'data-lazy',
        'data-url',
        'data-ks-lazyload',
        'data-lazy-img',
      ]) {
        addRaw(image.attributes[attr]);
      }
    }

    return urls;
  }

  static List<Uri> _collectVideoUrls(
    dom.Document document,
    _JsonLdExtract jsonLd,
    Uri base, {
    String? html,
  }) {
    final urls = <Uri>[];
    final seen = <String>{};

    void addRaw(String? raw) {
      if (raw == null || raw.trim().isEmpty) return;
      final uri = _resolveImageUri(raw, base);
      if (uri == null || !_looksLikeUsefulVideo(uri)) return;
      if (seen.add(_dedupeKey(uri))) urls.add(uri);
    }

    for (final key in [
      'og:video',
      'og:video:url',
      'og:video:secure_url',
      'twitter:player:stream',
      'video',
    ]) {
      addRaw(_metaContent(document, key));
    }

    for (final video in jsonLd.videos) {
      addRaw(video);
    }

    for (final node in document.querySelectorAll('video, source, a')) {
      addRaw(node.attributes['src']);
      addRaw(node.attributes['data-src']);
      addRaw(node.attributes['href']);
    }

    for (final text in _embeddedTexts(document, html)) {
      for (final uri in _extractUrlsFromText(text, base)) {
        if (!_looksLikeUsefulVideo(uri)) continue;
        if (seen.add(_dedupeKey(uri))) urls.add(uri);
      }
    }

    return _sortVideoUrlsForQuality(urls);
  }

  static Iterable<String> _srcsetParts(String raw) sync* {
    for (final item in raw.split(',')) {
      final clean = item.trim();
      if (clean.isEmpty) continue;
      yield clean.split(RegExp(r'\s+')).first;
    }
  }

  static Uri? _resolveImageUri(String raw, Uri base) {
    var clean = _decodeEscapedText(raw).trim();
    if (clean.startsWith('data:')) return null;
    if (clean.startsWith('//')) clean = '${base.scheme}:$clean';
    final parsed = Uri.tryParse(clean);
    if (parsed == null) return null;
    return base.resolveUri(parsed);
  }

  static String _decodeEscapedText(String value) {
    var clean = value.trim();
    for (var i = 0; i < 2; i++) {
      clean = clean.replaceAllMapped(
        RegExp(r'\\u([0-9a-fA-F]{4})'),
        (match) => String.fromCharCode(int.parse(match.group(1)!, radix: 16)),
      );
      clean = clean.replaceAllMapped(
        RegExp(r'\\x([0-9a-fA-F]{2})'),
        (match) => String.fromCharCode(int.parse(match.group(1)!, radix: 16)),
      );
      clean = clean
          .replaceAll(r'\/', '/')
          .replaceAll(r'\\/', '/')
          .replaceAll('&amp;', '&')
          .replaceAll('&quot;', '"')
          .replaceAll('&#34;', '"')
          .replaceAll('&#39;', "'");
    }
    return clean;
  }

  static bool _looksLikeUsefulImage(Uri uri) {
    final lower = uri.toString().toLowerCase();
    if (lower.contains('favicon') ||
        lower.contains('/icon') ||
        lower.contains('sprite') ||
        lower.contains('loading') ||
        lower.contains('blank.gif') ||
        lower.contains('avatar') ||
        lower.contains('logo')) {
      return false;
    }
    if (_extensionFromUrl(uri) != null) return true;
    return lower.contains('.jpg') ||
        lower.contains('.jpeg') ||
        lower.contains('.png') ||
        lower.contains('.webp') ||
        lower.contains('.gif') ||
        lower.contains('alicdn.com') ||
        lower.contains('jdimg.com') ||
        lower.contains('pinduoduo.com') ||
        lower.contains('douyinpic.com') ||
        lower.contains('byteimg.com') ||
        lower.contains('pstatp.com') ||
        lower.contains('douyincdn.com') ||
        lower.contains('xhscdn.com') ||
        lower.contains('xhsimg.com');
  }

  static bool _looksLikeUsefulVideo(Uri uri) {
    final lower = uri.toString().toLowerCase();
    if (lower.contains('avatar') ||
        lower.contains('logo') ||
        lower.contains('icon')) {
      return false;
    }
    if (_extensionFromVideoUrl(uri) != null) return true;
    return lower.contains('sns-video') ||
        lower.contains('/stream/') && lower.contains('xhscdn.com') ||
        lower.contains('/aweme/v1/play') ||
        lower.contains('/video/tos') ||
        lower.contains('douyinvod.com') ||
        lower.contains('bytevodd.com') ||
        lower.contains('cloud.video.taobao.com') ||
        lower.contains('xianyu-video.alicdn.com') ||
        lower.contains('video.taobao.com');
  }

  static Future<_DownloadedImages> _downloadImages(
    HttpClient client,
    List<Uri> candidates, {
    required String docDir,
    required int maxImages,
    required Uri referer,
  }) async {
    final images = <ImportedMaterialImage>[];
    final seen = <String>{};
    var cleanedUrlCount = 0;
    final stamp = DateTime.now().microsecondsSinceEpoch;

    for (final original in candidates) {
      if (images.length >= maxImages) break;
      final cleaned = cleanPlatformImageUrl(original);
      if (cleaned.cleanedPlatformWatermark) cleanedUrlCount++;

      final key = _dedupeKey(cleaned.uri);
      if (!seen.add(key)) continue;

      final saved = await _downloadImage(
        client,
        cleaned.uri,
        docDir: docDir,
        index: images.length,
        stamp: stamp,
        referer: referer,
      );
      if (saved == null) continue;

      images.add(
        ImportedMaterialImage(
          originalUrl: original,
          downloadedUrl: cleaned.uri,
          savedPath: saved,
          cleanedPlatformWatermark: cleaned.cleanedPlatformWatermark,
        ),
      );
    }

    return _DownloadedImages(images: images, cleanedUrlCount: cleanedUrlCount);
  }

  static Future<_DownloadedVideos> _downloadVideos(
    HttpClient client,
    List<Uri> candidates, {
    required String docDir,
    required int maxVideos,
    required Uri referer,
  }) async {
    final videos = <ImportedMaterialVideo>[];
    final seen = <String>{};
    final stamp = DateTime.now().microsecondsSinceEpoch;

    for (final original in _sortVideoUrlsForQuality(candidates)) {
      if (videos.length >= maxVideos) break;
      if (!seen.add(_videoDedupeKey(original))) continue;

      final saved = await _downloadVideo(
        client,
        original,
        docDir: docDir,
        index: videos.length,
        stamp: stamp,
        referer: referer,
      );
      if (saved == null) continue;

      videos.add(
        ImportedMaterialVideo(
          originalUrl: original,
          downloadedUrl: original,
          savedPath: saved,
        ),
      );
    }

    return _DownloadedVideos(videos: videos);
  }

  static Future<String?> _downloadImage(
    HttpClient client,
    Uri url, {
    required String docDir,
    required int index,
    required int stamp,
    required Uri referer,
  }) async {
    try {
      final response = await _get(
        client,
        url,
        accept: 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
        referer: referer,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final contentType = response.headers.contentType;
      final looksLikeImage =
          contentType?.primaryType == 'image' ||
          _extensionFromUrl(url) != null ||
          contentType?.mimeType == 'application/octet-stream' &&
              _looksLikeUsefulImage(url);
      if (!looksLikeImage) return null;

      final bytes = await _readLimited(response, _maxImageBytes);
      if (bytes.isEmpty) return null;

      final ext =
          _extensionFromContentType(contentType) ??
          _extensionFromUrl(url) ??
          '.jpg';
      final dir = Directory(docDir);
      if (!await dir.exists()) await dir.create(recursive: true);
      final file = File('$docDir/import_${stamp}_$index$ext');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _downloadVideo(
    HttpClient client,
    Uri url, {
    required String docDir,
    required int index,
    required int stamp,
    required Uri referer,
  }) async {
    try {
      final response = await _get(
        client,
        url,
        accept: 'video/mp4,video/*,*/*;q=0.8',
        referer: referer,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final contentType = response.headers.contentType;
      final looksLikeVideo =
          contentType?.primaryType == 'video' ||
          _extensionFromVideoUrl(url) != null ||
          contentType?.mimeType == 'application/octet-stream' &&
              _looksLikeUsefulVideo(url);
      if (!looksLikeVideo) return null;

      final bytes = await _readLimited(response, _maxVideoBytes);
      if (bytes.isEmpty) return null;

      final ext =
          _extensionFromVideoContentType(contentType) ??
          _extensionFromVideoUrl(url) ??
          '.mp4';
      final dir = Directory(docDir);
      if (!await dir.exists()) await dir.create(recursive: true);
      final file = File('$docDir/import_${stamp}_video_$index$ext');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  static String _copyTextFromParts(String title, String description) {
    final parts = <String>[];
    for (final text in [title, description]) {
      final clean = _cleanText(text);
      if (clean.isEmpty || parts.contains(clean)) continue;
      parts.add(clean);
    }
    return parts.join('\n\n').trim();
  }

  static Map<String, dynamic> _mapValue(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static String _stringValue(dynamic value) =>
      value == null ? '' : _cleanText(value.toString());

  static num _numValue(dynamic value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value) ?? 0;
    return 0;
  }

  static dynamic _nestedValue(dynamic root, List<String> path) {
    dynamic current = root;
    for (final segment in path) {
      if (current is Map) {
        current = current[segment];
      } else if (current is List) {
        final index = int.tryParse(segment);
        if (index == null || index < 0 || index >= current.length) return null;
        current = current[index];
      } else {
        return null;
      }
    }
    return current;
  }

  static String _nestedString(dynamic root, List<String> path) =>
      _stringValue(_nestedValue(root, path));

  static String _copyText(
    String title,
    String description,
    dom.Document document,
  ) {
    final parts = <String>[];
    void add(String text) {
      final clean = _cleanText(text);
      if (clean.isEmpty || parts.contains(clean)) return;
      parts.add(clean);
    }

    add(title);
    add(description);
    if (parts.isEmpty) {
      final body = _cleanText(document.body?.text ?? '');
      if (body.isNotEmpty) {
        add(body.length > 500 ? '${body.substring(0, 500)}...' : body);
      }
    }
    return parts.join('\n\n').trim();
  }

  static String _firstNonEmpty(Iterable<String?> values) {
    for (final value in values) {
      final clean = _cleanText(value ?? '');
      if (clean.isNotEmpty) return clean;
    }
    return '';
  }

  static String _cleanText(String text) =>
      text.replaceAll('\u00a0', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  static String _cleanImagePath(String path) {
    var cleaned = path;
    cleaned = cleaned.replaceFirstMapped(
      RegExp(r'(\.(?:jpg|jpeg|png|webp))_[^/]+$', caseSensitive: false),
      (match) => match.group(1)!,
    );
    cleaned = cleaned.replaceFirstMapped(
      RegExp(
        r'_\d+x\d+(?:q\d+)?(\.(?:jpg|jpeg|png|webp))$',
        caseSensitive: false,
      ),
      (match) => match.group(1)!,
    );
    return cleaned;
  }

  static String _queryString(Map<String, List<String>> queryParameters) {
    final parts = <String>[];
    for (final entry in queryParameters.entries) {
      for (final value in entry.value) {
        parts.add(
          '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(value)}',
        );
      }
    }
    return parts.join('&');
  }

  static String _dedupeKey(Uri uri) {
    final normalized = uri.replace(fragment: '');
    return normalized.toString();
  }

  static String? _extensionFromContentType(ContentType? type) {
    final subtype = type?.subType.toLowerCase();
    if (subtype == null) return null;
    if (subtype.contains('jpeg') || subtype.contains('jpg')) return '.jpg';
    if (subtype.contains('png')) return '.png';
    if (subtype.contains('webp')) return '.webp';
    if (subtype.contains('gif')) return '.gif';
    return null;
  }

  static String? _extensionFromVideoContentType(ContentType? type) {
    final subtype = type?.subType.toLowerCase();
    if (subtype == null) return null;
    if (subtype.contains('mp4')) return '.mp4';
    if (subtype.contains('quicktime') || subtype.contains('mov')) return '.mov';
    if (subtype.contains('webm')) return '.webm';
    if (subtype.contains('x-m4v')) return '.m4v';
    return null;
  }

  static String? _extensionFromUrl(Uri uri) {
    final path = uri.path.toLowerCase();
    for (final ext in ['.jpg', '.jpeg', '.png', '.webp', '.gif']) {
      if (path.endsWith(ext)) return ext == '.jpeg' ? '.jpg' : ext;
    }
    if (RegExp(r'(?:^|[_!])(?:h5_)?\d*jpg$').hasMatch(path)) return '.jpg';
    if (RegExp(r'(?:^|[_!])(?:h5_)?\d*png$').hasMatch(path)) return '.png';
    if (RegExp(r'(?:^|[_!])(?:h5_)?\d*webp$').hasMatch(path)) return '.webp';
    if (RegExp(r'!(?:nd|h5|style)_[^/]*(?:jpg|jpeg)').hasMatch(path)) {
      return '.jpg';
    }
    if (RegExp(r'!(?:nd|h5|style)_[^/]*png').hasMatch(path)) return '.png';
    if (RegExp(r'!(?:nd|h5|style)_[^/]*webp').hasMatch(path)) return '.webp';
    return null;
  }

  static String? _extensionFromVideoUrl(Uri uri) {
    final path = uri.path.toLowerCase();
    for (final ext in ['.mp4', '.mov', '.m4v', '.webm']) {
      if (path.endsWith(ext)) return ext;
    }
    return null;
  }
}

class _FetchedHtml {
  final String body;
  final Uri finalUrl;

  const _FetchedHtml({required this.body, required this.finalUrl});
}

class _MtopResponse {
  final String cookieHeader;
  final String body;

  const _MtopResponse({required this.cookieHeader, required this.body});
}

class _GoofishDetail {
  final String title;
  final String description;
  final String copyText;
  final List<Uri> imageUrls;
  final List<Uri> videoUrls;

  const _GoofishDetail({
    required this.title,
    required this.description,
    required this.copyText,
    required this.imageUrls,
    required this.videoUrls,
  });
}

class _DownloadedImages {
  final List<ImportedMaterialImage> images;
  final int cleanedUrlCount;

  const _DownloadedImages({
    required this.images,
    required this.cleanedUrlCount,
  });
}

class _DownloadedVideos {
  final List<ImportedMaterialVideo> videos;

  const _DownloadedVideos({required this.videos});
}

class _ScoredUri {
  final Uri uri;
  final int score;
  final int index;

  const _ScoredUri(this.uri, this.score, this.index);
}

class _JsonLdExtract {
  final Map<String, List<String>> texts;
  final List<String> images;
  final List<String> videos;

  const _JsonLdExtract({
    required this.texts,
    required this.images,
    required this.videos,
  });

  Iterable<String> textsForKeys(Set<String> keys) sync* {
    for (final key in keys) {
      yield* texts[key.toLowerCase()] ?? const <String>[];
    }
  }
}
