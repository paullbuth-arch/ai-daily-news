// WebDAV 云同步服务 —— 纯Dart，用HttpClient实现PUT/GET
// 兼容坚果云等标准WebDAV服务，零第三方依赖
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'storage.dart';

/// WebDAV 下载结果
class WebDavDownloadResult {
  final Uint8List? data;
  final String? errMsg;
  const WebDavDownloadResult(this.data, this.errMsg);
}

class WebDavConfig {
  final String url; // 如 https://dav.jianguoyun.com/dav/
  final String username;
  final String password; // 坚果云用应用密码

  const WebDavConfig({this.url = '', this.username = '', this.password = ''});

  bool get isValid =>
      url.isNotEmpty && username.isNotEmpty && password.isNotEmpty;

  factory WebDavConfig.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const WebDavConfig();
    return WebDavConfig(
      url: (m['url'] as String?) ?? '',
      username: (m['username'] as String?) ?? '',
      password: (m['password'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'url': url,
    'username': username,
    'password': password,
  };
}

class WebDavService {
  static const kRemoteFile = 'ipad_boss_data.json';
  static const kTimestampFile = 'ipad_boss_sync_ts.txt';
  static const kRemoteDir = '货脉';
  static const kLegacyRemoteDir = '机掌柜';

  static String _normalizedBaseUrl(String url) =>
      url.endsWith('/') ? url : '$url/';

  static Uri _remoteUri(String baseUrl, String dir, String file) =>
      Uri.parse('$baseUrl$dir/$file');

  /// 上传数据到 WebDAV
  /// [dataPath] = 本地 data.json 路径
  static Future<String?> upload({
    required WebDavConfig config,
    required String dataPath,
  }) async {
    if (!config.isValid) return '配置无效';
    try {
      final file = File(dataPath);
      if (!await file.exists()) return '本地数据文件不存在';
      final bytes = await file.readAsBytes();
      final baseUrl = _normalizedBaseUrl(config.url);
      final uri = _remoteUri(baseUrl, kRemoteDir, kRemoteFile);

      // 先创建目录（忽略错误，可能已存在）
      await _mkcol(config, '$baseUrl$kRemoteDir/');

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 15);
      final req = await client.openUrl('PUT', uri);
      _setAuth(req, config);
      req.headers.contentType = ContentType.json;
      req.add(bytes);
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      client.close();
      if (resp.statusCode >= 200 && resp.statusCode < 300) return null; // 成功
      return '上传失败(${resp.statusCode})：${body.length > 100 ? body.substring(0, 100) : body}';
    } catch (e) {
      return '上传异常：$e';
    }
  }

  /// 从 WebDAV 下载数据
  /// 返回下载结果：成功时 data 非 null，失败时 errMsg 非 null
  static Future<WebDavDownloadResult> download({
    required WebDavConfig config,
  }) async {
    if (!config.isValid) return WebDavDownloadResult(null, '配置无效');
    try {
      final baseUrl = _normalizedBaseUrl(config.url);
      WebDavDownloadResult? lastError;
      for (final dir in const [kRemoteDir, kLegacyRemoteDir]) {
        final result = await _downloadFromDir(config, baseUrl, dir);
        if (result.data != null) return result;
        lastError = result;
      }
      return lastError ?? WebDavDownloadResult(null, '云端无数据（首次同步请先上传）');
    } catch (e) {
      return WebDavDownloadResult(null, '下载异常：$e');
    }
  }

  static Future<WebDavDownloadResult> _downloadFromDir(
    WebDavConfig config,
    String baseUrl,
    String dir,
  ) async {
    try {
      final uri = _remoteUri(baseUrl, dir, kRemoteFile);
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 15);
      final req = await client.openUrl('GET', uri);
      _setAuth(req, config);
      final resp = await req.close();
      if (resp.statusCode == 404) {
        client.close();
        return WebDavDownloadResult(null, '云端无数据（首次同步请先上传）');
      }
      if (resp.statusCode != 200) {
        client.close();
        return WebDavDownloadResult(null, '下载失败(${resp.statusCode})');
      }
      final bytes = await resp
          .fold<BytesBuilder>(BytesBuilder(), (b, d) => b..add(d))
          .then((b) => b.takeBytes());
      client.close();
      return WebDavDownloadResult(Uint8List.fromList(bytes), null);
    } catch (e) {
      return WebDavDownloadResult(null, '下载异常：$e');
    }
  }

  /// 上传时间戳文件（记录最后同步时间）
  static Future<String?> uploadTimestamp({required WebDavConfig config}) async {
    if (!config.isValid) return '配置无效';
    try {
      final baseUrl = _normalizedBaseUrl(config.url);
      final uri = _remoteUri(baseUrl, kRemoteDir, kTimestampFile);
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final req = await client.openUrl('PUT', uri);
      _setAuth(req, config);
      req.headers.contentType = ContentType.text;
      req.write(DateTime.now().toIso8601String());
      final resp = await req.close();
      client.close();
      if (resp.statusCode >= 200 && resp.statusCode < 300) return null;
      return '时间戳上传失败(${resp.statusCode})';
    } catch (e) {
      return '时间戳上传异常：$e';
    }
  }

  /// 测试连接：用 PROPFIND 验证连通性和认证（比 GET 更符合 WebDAV 标准）
  /// 部分 WebDAV 服务对 GET 返回 403 但对 PROPFIND 正常响应
  static Future<String?> testConnection(WebDavConfig config) async {
    if (!config.isValid) return '配置无效';
    try {
      final baseUrl = config.url.endsWith('/') ? config.url : '${config.url}/';
      final uri = Uri.parse(baseUrl);
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 15);
      final req = await client.openUrl('PROPFIND', uri);
      _setAuth(req, config);
      req.headers.set('Depth', '0');
      req.headers.contentType = ContentType(
        'application',
        'xml',
        charset: 'utf-8',
      );
      // PROPFIND 需要请求体（标准 WebDAV）
      req.write(
        '<?xml version="1.0"?><a:propfind xmlns:a="DAV:"><a:prop><a:resourcetype/></a:prop></a:propfind>',
      );
      final resp = await req.close();
      await resp.drain<void>();
      client.close();
      // 207=Multi-Status(WebDAV正常), 200/201/204/404=正常, 301/302/307=重定向(可能OK)
      if (resp.statusCode == 401) return '认证失败：账号或密码错误';
      if (resp.statusCode == 403) {
        // 403 时尝试 OPTIONS 兜底
        return _testWithOptions(config);
      }
      if (resp.statusCode < 500) return null; // 2xx/3xx/404/207 都算成功
      return '服务器错误(${resp.statusCode})';
    } catch (e) {
      // 如果 PROPFIND 失败（某些服务器不支持），降级为 OPTIONS
      return await _testWithOptions(config);
    }
  }

  /// 用 OPTIONS 方法兜底测试连接
  static Future<String?> _testWithOptions(WebDavConfig config) async {
    try {
      final baseUrl = config.url.endsWith('/') ? config.url : '${config.url}/';
      final uri = Uri.parse(baseUrl);
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final req = await client.openUrl('OPTIONS', uri);
      _setAuth(req, config);
      final resp = await req.close();
      await resp.drain<void>();
      client.close();
      if (resp.statusCode == 401) return '认证失败：账号或密码错误';
      if (resp.statusCode < 500) return null; // 任何非500都算连通
      return '服务器错误(${resp.statusCode})';
    } catch (e) {
      return '连接异常：$e';
    }
  }

  static void _setAuth(HttpClientRequest req, WebDavConfig config) {
    final auth = base64Encode(
      utf8.encode('${config.username}:${config.password}'),
    );
    req.headers.set('Authorization', 'Basic $auth');
  }

  static Future<void> _mkcol(WebDavConfig config, String path) async {
    try {
      final uri = Uri.parse(path);
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final req = await client.openUrl('MKCOL', uri);
      _setAuth(req, config);
      await req.close();
      client.close();
    } catch (_) {}
  }

  // ===== 同步管理 =====

  /// 从 Storage 读取 WebDAV 配置
  static WebDavConfig getConfig(Storage s) {
    return WebDavConfig.fromMap(
      s.getSettings()['webdavConfig'] as Map<String, dynamic>?,
    );
  }

  /// 保存 WebDAV 配置到 Storage
  static Future<void> saveConfig(Storage s, WebDavConfig c) async {
    final settings = s.getSettings();
    settings['webdavConfig'] = c.toMap();
    await s.saveSettings(settings);
  }

  /// 最后同步时间
  static DateTime? lastSyncTime(Storage s) {
    final v = s.getSettings()['lastWebDavSync'] as String?;
    return v == null ? null : DateTime.tryParse(v);
  }

  static Future<void> markSynced(Storage s) async {
    final st = s.getSettings();
    st['lastWebDavSync'] = DateTime.now().toIso8601String();
    await s.saveSettings(st);
  }

  static Future<String> ensureSyncDeviceId(Storage s) async {
    final st = s.getSettings();
    final existing = st['syncDeviceId'] as String?;
    if (existing != null && existing.isNotEmpty) return existing;
    final id = 'device_${DateTime.now().microsecondsSinceEpoch}';
    st['syncDeviceId'] = id;
    await s.saveSettings(st);
    return id;
  }

  static Map<String, dynamic>? extractSyncMeta(Uint8List bytes) {
    try {
      final decoded = json.decode(utf8.decode(bytes));
      if (decoded is! Map) return null;
      final settings = decoded['settings'];
      if (settings is! Map) return null;
      final meta = settings['syncMeta'];
      if (meta is Map<String, dynamic>) return meta;
      if (meta is Map) return Map<String, dynamic>.from(meta);
      return null;
    } catch (_) {
      return null;
    }
  }
}
