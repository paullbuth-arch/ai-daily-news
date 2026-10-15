// 应用内更新服务
// 更新方式：由用户自行获取 APK，App 负责调起系统安装器完成安装。
// 不再依赖任何远端版本检查接口。
import 'package:flutter/services.dart';

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
  /// 当前版本信息。构建脚本会从 pubspec.yaml 注入，测试/调试时使用兜底值。
  static const String _definedVersion = String.fromEnvironment(
    'DEEPSELL_APP_VERSION',
    defaultValue: '2.11.0',
  );
  static const int _definedBuild = int.fromEnvironment(
    'DEEPSELL_APP_BUILD',
    defaultValue: 36,
  );
  static String get currentVersion => _definedVersion;
  static int get currentBuild => _definedBuild;

  /// 安装 APK（通过 Android MethodChannel）
  ///
  /// [path] 必须是本应用可读的 APK 文件路径。file_picker 选中的文件会被复制
  /// 到应用缓存目录，该目录已在 file_paths.xml 的 <cache-path> 中授权给
  /// FileProvider，因此可以直接传给原生层。
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
}

String _asString(Object? value) => value?.toString().trim() ?? '';
