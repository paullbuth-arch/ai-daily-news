// 应用内更新服务
// 支持检测远端版本 + 下载 APK + 调用系统安装器
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';

/// 远端版本信息
class UpdateInfo {
  final String version; // 版本名，如 "1.6.1"
  final int buildNumber; // 构建号，如 7
  final String apkUrl; // APK 下载地址
  final String changelog; // 更新说明
  final String sha256; // 可选：APK SHA256，用于下载后校验

  const UpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.apkUrl,
    this.changelog = '',
    this.sha256 = '',
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) => UpdateInfo(
    version: _asString(json['version']),
    buildNumber: _asInt(json['buildNumber']),
    apkUrl: _asString(json['apkUrl']),
    changelog: _asString(json['changelog']),
    sha256: _asString(json['sha256'] ?? json['sha256Hash']),
  );
}

class UpdateCheckException implements Exception {
  final String message;
  const UpdateCheckException(this.message);

  @override
  String toString() => message;
}

class ApkInstallResult {
  final bool success;
  final bool permissionRequired;
  final String message;

  const ApkInstallResult({
    required this.success,
    this.permissionRequired = false,
    this.message = '',
  });
}

class UpdateService {
  /// 默认更新检查 URL
  static const String defaultCheckUrl = 'https://deepsell.wiki/api/version';
  static const String fallbackCheckUrl = String.fromEnvironment(
    'DEEPSELL_FALLBACK_VERSION_URL',
  );
  static const bool allowInsecureIpFallback = bool.fromEnvironment(
    'DEEPSELL_ALLOW_INSECURE_IP_FALLBACK',
    defaultValue: false,
  );

  /// 当前版本信息（从 pubspec.yaml 读取）
  static String get currentVersion => '2.9.5';
  static int get currentBuild => 24;
  static bool allowInsecureCertificates = false;

  /// 检查远端更新
  /// [checkUrl] 指向一个返回 JSON 的 API：{"version":"1.6.1","buildNumber":7,"apkUrl":"https://...","changelog":"..."}
  /// 返回 null 表示无更新，否则返回 UpdateInfo
  static Future<UpdateInfo?> check({String? checkUrl}) async {
    final urls =
        checkUrl == null
            ? [
              defaultCheckUrl,
              if (allowInsecureIpFallback && fallbackCheckUrl.isNotEmpty)
                fallbackCheckUrl,
            ]
            : [checkUrl];
    final errors = <String>[];
    for (final url in urls) {
      HttpClient? client;
      try {
        final uri = Uri.parse(url);
        client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 15);
        client.userAgent = 'ipadboss-update-checker';
        // 不验证 SSL 证书（兼容低版本 Android 证书库）
        client.badCertificateCallback =
            (cert, host, port) =>
                allowInsecureCertificates ||
                (allowInsecureIpFallback &&
                    fallbackCheckUrl.isNotEmpty &&
                    host == Uri.parse(fallbackCheckUrl).host);
        final req = await client.getUrl(uri);
        req.headers.set('Accept', 'application/json');
        final resp = await req.close();
        final raw = await resp.transform(utf8.decoder).join();

        if (resp.statusCode != 200) {
          errors.add('HTTP ${resp.statusCode}');
          continue;
        }

        final data = json.decode(raw) as Map<String, dynamic>;
        final info = UpdateInfo.fromJson(data);
        if (info.version.isEmpty || info.apkUrl.isEmpty) {
          errors.add('更新信息不完整');
          continue;
        }

        // 比较版本
        if (_isRemoteNewer(info)) return info;
        return null;
      } catch (e) {
        errors.add(e.toString());
        continue;
      } finally {
        client?.close(force: true);
      }
    }
    throw UpdateCheckException(
      errors.isEmpty ? '无法连接更新服务器' : '无法连接更新服务器：${errors.last}',
    );
  }

  /// 下载 APK 到本地
  /// 返回本地文件路径，失败返回 null
  /// [onProgress] 可选进度回调 (0.0 - 1.0)
  static Future<String?> downloadApk(
    String url, {
    String? fileName,
    String? expectedSha256,
    void Function(double)? onProgress,
  }) async {
    for (final candidate in downloadCandidatesFor(url)) {
      final path = await _downloadSingleApk(
        candidate,
        fileName: fileName,
        expectedSha256: expectedSha256,
        onProgress: onProgress,
      );
      if (path != null) return path;
    }
    return null;
  }

  static Future<String?> _downloadSingleApk(
    String url, {
    String? fileName,
    String? expectedSha256,
    void Function(double)? onProgress,
  }) async {
    HttpClient? client;
    try {
      final uri = Uri.parse(url);
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 30);
      // 不验证 SSL 证书（兼容低版本 Android）
      client.badCertificateCallback =
          (cert, host, port) =>
              allowInsecureCertificates ||
              (allowInsecureIpFallback &&
                  fallbackCheckUrl.isNotEmpty &&
                  host == Uri.parse(fallbackCheckUrl).host);
      final req = await client.getUrl(uri);
      req.headers.set('Accept', '*/*');
      final resp = await req.close();
      if (resp.statusCode != 200) return null;

      final contentLength = resp.contentLength;

      // 保存到应用文档目录
      final dir = await getApplicationDocumentsDirectory();
      final name = fileName ?? 'ipad_boss_update.apk';
      final file = File('${dir.path}/$name');
      final sink = file.openWrite();

      // 分块写入 + 进度回调
      int received = 0;
      await for (final chunk in resp) {
        sink.add(chunk);
        received += chunk.length;
        if (onProgress != null && contentLength > 0) {
          onProgress(received / contentLength);
        }
      }
      await sink.flush();
      await sink.close();

      if (await file.exists() &&
          (contentLength <= 0 || await file.length() == contentLength)) {
        if (expectedSha256 != null && expectedSha256.trim().isNotEmpty) {
          final ok = await _verifySha256(file, expectedSha256);
          if (!ok) {
            try {
              await file.delete();
            } catch (_) {}
            return null;
          }
        }
        return file.path;
      }
      return null;
    } catch (e) {
      print('Download error: $e');
      return null;
    } finally {
      client?.close(force: true);
    }
  }

  static List<String> downloadCandidatesFor(String apkUrl) {
    final urls = <String>[apkUrl];
    if (allowInsecureIpFallback && fallbackCheckUrl.isNotEmpty) {
      try {
        final original = Uri.parse(apkUrl);
        final fallback = Uri.parse(fallbackCheckUrl);
        if (original.hasScheme &&
            fallback.hasScheme &&
            fallback.host.isNotEmpty) {
          final candidate = original.replace(
            scheme: fallback.scheme,
            host: fallback.host,
          );
          final candidateText = candidate.toString();
          if (!urls.contains(candidateText)) urls.add(candidateText);
        }
      } catch (_) {}
    }
    return urls;
  }

  /// 安装 APK（通过 Android MethodChannel）
  static Future<ApkInstallResult> installApk(String path) async {
    try {
      const channel = MethodChannel('ipad_boss_app/gallery');
      final result = await channel.invokeMethod<Map>('installApk', {
        'path': path,
      });
      return ApkInstallResult(
        success: result?['success'] == true,
        permissionRequired: result?['permissionRequired'] == true,
        message: _asString(result?['message']),
      );
    } catch (e) {
      return ApkInstallResult(success: false, message: e.toString());
    }
  }

  static bool _isRemoteNewer(UpdateInfo info) {
    if (info.buildNumber > currentBuild) return true;
    if (info.buildNumber > 0) return false;
    return _compareVersion(info.version, currentVersion) > 0;
  }

  static int _compareVersion(String a, String b) {
    final left = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final right = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final maxLength = left.length > right.length ? left.length : right.length;
    for (var i = 0; i < maxLength; i++) {
      final l = i < left.length ? left[i] : 0;
      final r = i < right.length ? right[i] : 0;
      if (l != r) return l.compareTo(r);
    }
    return 0;
  }

  static Future<bool> _verifySha256(File file, String expected) async {
    final normalized = expected.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    final digest = sha256.convert(await file.readAsBytes()).toString();
    return digest == normalized;
  }
}

String _asString(Object? value) => value?.toString().trim() ?? '';

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
