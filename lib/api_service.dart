// API 服务层 —— 与后端通信
import 'dart:convert';
import 'dart:io';

class ApiService {
  static const String baseUrl = 'https://deepsell.wiki';
  static const String fallbackBaseUrl = String.fromEnvironment(
    'DEEPSELL_FALLBACK_BASE_URL',
  );
  static const bool allowInsecureIpFallback = bool.fromEnvironment(
    'DEEPSELL_ALLOW_INSECURE_IP_FALLBACK',
    defaultValue: false,
  );
  static const List<String> _baseUrls =
      allowInsecureIpFallback && fallbackBaseUrl != ''
          ? [baseUrl, fallbackBaseUrl]
          : [baseUrl];

  static Map<String, dynamic> _decodeJsonObject(String raw) {
    if (raw.trim().isEmpty) return {};
    final decoded = json.decode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return {'data': decoded};
  }

  static String _friendlyError(dynamic error) {
    final message = (error ?? '').toString();
    const map = {
      'Code invalid or expired': '验证码无效或已过期，请重新获取最新验证码',
      'Invalid email': '邮箱格式不正确',
      'Fill all fields': '请填写完整信息',
      'Password min 6 chars': '密码至少 6 位',
      'Email already registered': '该邮箱已注册，请直接登录',
      'Fill email and password': '请填写邮箱和密码',
      'Email not registered': '邮箱未注册',
      'Wrong password': '密码错误',
      'Not logged in': '登录已失效，请重新登录',
      'Token expired': '登录已过期，请重新登录',
    };
    return map[message] ?? message;
  }

  // ====== HTTP 请求 ======
  static Future<Map<String, dynamic>> _request({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    String? token,
    List<File>? files,
  }) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 30);
      client.badCertificateCallback =
          (cert, host, port) =>
              allowInsecureIpFallback &&
              fallbackBaseUrl.isNotEmpty &&
              host == Uri.parse(fallbackBaseUrl).host;

      Map<String, dynamic>? lastError;
      for (final origin in _baseUrls) {
        try {
          final uri = Uri.parse('$origin$path');
          final req = await client.openUrl(method, uri);
          req.headers.set('Accept', 'application/json');

          if (token != null) {
            req.headers.set('Authorization', 'Bearer $token');
          }

          if (files != null && files.isNotEmpty) {
            // Multipart upload
            final boundary =
                'boundary_${DateTime.now().millisecondsSinceEpoch}';
            req.headers.set(
              'Content-Type',
              'multipart/form-data; boundary=$boundary',
            );
            // Write each file
            for (final file in files) {
              req.write('--$boundary\r\n');
              req.write(
                'Content-Disposition: form-data; name="files"; filename="${file.uri.pathSegments.last}"\r\n',
              );
              req.write('Content-Type: image/jpeg\r\n\r\n');
              req.add(await file.readAsBytes());
              req.write('\r\n');
            }
            req.write('--$boundary--\r\n');
          } else if (body != null) {
            req.headers.contentType = ContentType.json;
            req.write(json.encode(body));
          }

          final resp = await req.close().timeout(const Duration(seconds: 60));
          final raw = await resp.transform(utf8.decoder).join();

          if (resp.statusCode >= 200 && resp.statusCode < 300) {
            client.close();
            return _decodeJsonObject(raw);
          }
          // Try to parse error
          try {
            final err = _decodeJsonObject(raw);
            final message = _friendlyError(
              err['error'] ?? '请求失败(${resp.statusCode})',
            );
            lastError = {'error': message, 'statusCode': resp.statusCode};
            if (resp.statusCode < 500) {
              client.close();
              return lastError;
            }
          } catch (_) {
            lastError = {
              'error': '请求失败(${resp.statusCode})',
              'statusCode': resp.statusCode,
            };
            if (resp.statusCode < 500) {
              client.close();
              return lastError;
            }
          }
        } catch (e) {
          lastError = {
            'error': origin == baseUrl ? '主域名连接异常，已尝试备用服务器：$e' : '备用服务器连接异常：$e',
          };
        }
      }
      client.close();
      return lastError ?? {'error': '网络异常：服务器无响应'};
    } catch (e) {
      return {'error': '网络异常：$e'};
    }
  }

  // ====== 认证 API ======

  /// 发送验证码
  static Future<String?> sendCode(String email) async {
    final r = await _request(
      method: 'POST',
      path: '/api/send-code',
      body: {'email': email},
    );
    return r['error'] as String?;
  }

  /// 注册
  static Future<Map<String, dynamic>> register(
    String email,
    String password,
    String code,
  ) async {
    return await _request(
      method: 'POST',
      path: '/api/register',
      body: {'email': email, 'password': password, 'code': code},
    );
  }

  /// 登录
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    return await _request(
      method: 'POST',
      path: '/api/login',
      body: {'email': email, 'password': password},
    );
  }

  /// 获取用户信息
  static Future<Map<String, dynamic>> getUser(String token) async {
    return await _request(method: 'GET', path: '/api/user', token: token);
  }

  /// 验证 Token
  static Future<bool> verifyToken(String token) async {
    final r = await _request(method: 'GET', path: '/api/verify', token: token);
    return r['valid'] == true;
  }

  // ====== 数据 API ======

  /// 获取业务数据
  static Future<Map<String, dynamic>> fetchDataResult(String token) async {
    final r = await _request(method: 'GET', path: '/api/data', token: token);
    final error = r['error'] as String?;
    if (error != null && error.contains('404')) {
      r['statusCode'] ??= 404;
    }
    return r;
  }

  static Future<Map<String, dynamic>?> fetchData(String token) async {
    final r = await fetchDataResult(token);
    if (r['error'] != null) return null;
    return r;
  }

  /// 保存业务数据
  static Future<String?> saveData(
    String token,
    Map<String, dynamic> data,
  ) async {
    final r = await _request(
      method: 'POST',
      path: '/api/data',
      token: token,
      body: data,
    );
    return r['error'] as String?;
  }

  /// 上传图片
  static Future<List<String>?> uploadImages(
    String token,
    List<File> files,
  ) async {
    final r = await _request(
      method: 'POST',
      path: '/api/upload',
      token: token,
      files: files,
    );
    if (r['error'] != null) return null;
    final urls = r['urls'] as List;
    return urls.cast<String>();
  }
}
