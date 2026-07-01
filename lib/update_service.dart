// 应用内更新服务
// 支持检测远端版本 + 下载 APK + 调用系统安装器
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// 远端版本信息
class UpdateInfo {
  final String version; // 版本名，如 "1.6.1"
  final int buildNumber; // 构建号，如 7
  final String apkUrl; // APK 下载地址
  final String changelog; // 更新说明

  const UpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.apkUrl,
    this.changelog = '',
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) => UpdateInfo(
    version: json['version'] as String? ?? '',
    buildNumber: json['buildNumber'] as int? ?? 0,
    apkUrl: json['apkUrl'] as String? ?? '',
    changelog: json['changelog'] as String? ?? '',
  );
}

class UpdateService {
  /// 默认更新检查 URL
  static const String defaultCheckUrl = 'https://deepsell.wiki/api/version';

  /// 当前版本信息（从 pubspec.yaml 读取）
  static String get currentVersion => '2.7.0';
  static int get currentBuild => 17;
  static bool allowInsecureCertificates = false;

  /// 检查远端更新
  /// [checkUrl] 指向一个返回 JSON 的 API：{"version":"1.6.1","buildNumber":7,"apkUrl":"https://...","changelog":"..."}
  /// 返回 null 表示无更新，否则返回 UpdateInfo
  static Future<UpdateInfo?> check({String? checkUrl}) async {
    try {
      final url = checkUrl ?? defaultCheckUrl;
      final uri = Uri.parse(url);
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 15);
      client.userAgent = 'ipadboss-update-checker';
      // 不验证 SSL 证书（兼容低版本 Android 证书库）
      if (allowInsecureCertificates) {
        client.badCertificateCallback = (cert, host, port) => true;
      }
      final req = await client.getUrl(uri);
      req.headers.set('Accept', 'application/json');
      final resp = await req.close();
      final raw = await resp.transform(utf8.decoder).join();
      client.close();

      if (resp.statusCode != 200) {
        print('Update check failed: HTTP ${resp.statusCode}');
        return null;
      }

      final data = json.decode(raw) as Map<String, dynamic>;
      final info = UpdateInfo.fromJson(data);
      if (info.version.isEmpty || info.apkUrl.isEmpty) return null;

      // 比较版本
      if (info.buildNumber > currentBuild) return info;
      return null;
    } catch (e) {
      print('Update check error: $e');
      return null;
    }
  }

  /// 下载 APK 到本地
  /// 返回本地文件路径，失败返回 null
  /// [onProgress] 可选进度回调 (0.0 - 1.0)
  static Future<String?> downloadApk(
    String url, {
    String? fileName,
    void Function(double)? onProgress,
  }) async {
    try {
      final uri = Uri.parse(url);
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 30);
      // 不验证 SSL 证书（兼容低版本 Android）
      if (allowInsecureCertificates) {
        client.badCertificateCallback = (cert, host, port) => true;
      }
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
      client.close();

      if (await file.exists() &&
          (contentLength <= 0 || await file.length() == contentLength)) {
        return file.path;
      }
      return null;
    } catch (e) {
      print('Download error: $e');
      return null;
    }
  }

  /// 安装 APK（通过 Android MethodChannel）
  static Future<bool> installApk(String path) async {
    try {
      const channel = MethodChannel('ipad_boss_app/gallery');
      final result = await channel.invokeMethod<Map>('installApk', {
        'path': path,
      });
      return result?['success'] == true;
    } catch (e) {
      return false;
    }
  }
}
