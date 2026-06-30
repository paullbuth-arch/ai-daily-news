// 认证服务 —— Token 管理 + 登录状态
import 'storage.dart';

class AuthService {
  static String? _token;
  static String? _email;
  static bool _initialized = false;

  /// 是否已登录
  static bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  /// 获取 Token
  static String? get token => _token;

  /// 获取邮箱
  static String? get email => _email;

  /// 是否已初始化
  static bool get initialized => _initialized;

  /// 初始化：从本地存储加载 Token
  static Future<void> init(Storage storage) async {
    if (_initialized) return;
    final settings = storage.getSettings();
    _token = settings['auth_token'] as String?;
    _email = settings['auth_email'] as String?;
    _initialized = true;
  }

  /// 保存登录状态
  static Future<void> login(Storage storage, String token, String email) async {
    _token = token;
    _email = email;
    final settings = storage.getSettings();
    settings['auth_token'] = token;
    settings['auth_email'] = email;
    await storage.saveSettings(settings);
  }

  /// 退出登录
  static Future<void> logout(Storage storage) async {
    _token = null;
    _email = null;
    final settings = storage.getSettings();
    settings.remove('auth_token');
    settings.remove('auth_email');
    await storage.saveSettings(settings);
  }
}
