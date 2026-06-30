// API 服务层 —— 与后端通信
import 'dart:convert';
import 'dart:io';
import 'storage.dart';

class ApiService {
  static const String baseUrl = 'https://deepsell.wiki';

  // ====== HTTP 请求 ======
  static Future<Map<String, dynamic>> _request({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    String? token,
    List<File>? files,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 30);

      final req = await client.openUrl(method, uri);
      req.headers.set('Accept', 'application/json');

      if (token != null) {
        req.headers.set('Authorization', 'Bearer $token');
      }

      if (files != null && files.isNotEmpty) {
        // Multipart upload
        final boundary = 'boundary_${DateTime.now().millisecondsSinceEpoch}';
        req.headers.set('Content-Type', 'multipart/form-data; boundary=$boundary');
        final sink = req as HttpClientRequest;
        // Write each file
        for (final file in files) {
          sink.write('--$boundary\r\n');
          sink.write('Content-Disposition: form-data; name="files"; filename="${file.uri.pathSegments.last}"\r\n');
          sink.write('Content-Type: image/jpeg\r\n\r\n');
          sink.add(await file.readAsBytes());
          sink.write('\r\n');
        }
        sink.write('--$boundary--\r\n');
      } else if (body != null) {
        req.headers.contentType = ContentType.json;
        req.write(json.encode(body));
      }

      final resp = await req.close().timeout(const Duration(seconds: 60));
      final raw = await resp.transform(utf8.decoder).join();
      client.close();

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return json.decode(raw) as Map<String, dynamic>;
      }
      // Try to parse error
      try {
        final err = json.decode(raw) as Map<String, dynamic>;
        return {'error': err['error'] ?? '请求失败(${resp.statusCode})'};
      } catch (_) {
        return {'error': '请求失败(${resp.statusCode})'};
      }
    } catch (e) {
      return {'error': '网络异常：$e'};
    }
  }

  // ====== 认证 API ======

  /// 发送验证码
  static Future<String?> sendCode(String email) async {
    final r = await _request(method: 'POST', path: '/api/send-code', body: {'email': email});
    return r['error'] as String?;
  }

  /// 注册
  static Future<Map<String, dynamic>> register(String email, String password, String code) async {
    return await _request(method: 'POST', path: '/api/register', body: {'email': email, 'password': password, 'code': code});
  }

  /// 登录
  static Future<Map<String, dynamic>> login(String email, String password) async {
    return await _request(method: 'POST', path: '/api/login', body: {'email': email, 'password': password});
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
  static Future<Map<String, dynamic>?> fetchData(String token) async {
    final r = await _request(method: 'GET', path: '/api/data', token: token);
    if (r['error'] != null) return null;
    return r;
  }

  /// 保存业务数据
  static Future<String?> saveData(String token, Map<String, dynamic> data) async {
    final r = await _request(method: 'POST', path: '/api/data', token: token, body: data);
    return r['error'] as String?;
  }

  /// 上传图片
  static Future<List<String>?> uploadImages(String token, List<File> files) async {
    final r = await _request(method: 'POST', path: '/api/upload', token: token, files: files);
    if (r['error'] != null) return null;
    final urls = r['urls'] as List;
    return urls.cast<String>();
  }
}
