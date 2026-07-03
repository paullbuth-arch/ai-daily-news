import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'ai_service.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'backup_service.dart';
import 'storage.dart';
import 'utils/utils.dart';

class CloudRemoteData {
  final Map<String, dynamic>? data;
  final String? error;
  final int? statusCode;

  const CloudRemoteData({this.data, this.error, this.statusCode});

  bool get hasData => data != null;
  bool get isMissing => statusCode == 404;
}

class CloudSyncService {
  static const String lastCloudSyncKey = 'lastCloudSync';
  static const String _builtInToken = String.fromEnvironment(
    'DEEPSELL_SYNC_TOKEN',
  );
  static const String _builtInEmail = String.fromEnvironment(
    'DEEPSELL_SYNC_EMAIL',
  );
  static const String _builtInPassword = String.fromEnvironment(
    'DEEPSELL_SYNC_PASSWORD',
  );
  static const bool _privateOwnerSyncEnabled = bool.fromEnvironment(
    'DEEPSELL_PRIVATE_OWNER_SYNC',
    defaultValue: false,
  );
  static StreamSubscription<void>? _changeSub;
  static Timer? _debounce;
  static bool _syncing = false;

  static void startBackgroundSync({
    required Storage storage,
    required String docDir,
  }) {
    _changeSub?.cancel();
    _changeSub = storage.changes.listen((_) {
      if (_syncing) return;
      _debounce?.cancel();
      _debounce = Timer(const Duration(seconds: 6), () {
        syncNow(storage: storage, docDir: docDir, preferUpload: true);
      });
    });
    syncNow(storage: storage, docDir: docDir);
  }

  static Future<void> stopBackgroundSync() async {
    _debounce?.cancel();
    _debounce = null;
    await _changeSub?.cancel();
    _changeSub = null;
  }

  static Future<void> syncNow({
    required Storage storage,
    required String docDir,
    bool preferUpload = false,
  }) async {
    final auth = await _resolveSyncAuth(storage);
    if (auth == null || _syncing) return;
    final token = auth.token;

    _syncing = true;
    try {
      final remote = await fetchRemote(token);
      if (remote.error != null && !remote.isMissing) return;
      if (remote.isMissing || !remote.hasData) {
        await uploadLocal(token: token, storage: storage);
        return;
      }

      if (preferUpload) {
        await uploadLocal(token: token, storage: storage);
        return;
      }

      final localEmpty = localBusinessDataIsEmpty(storage);
      if (localEmpty) {
        await downloadRemote(
          token: token,
          email: auth.email,
          storage: storage,
          docDir: docDir,
          remoteData: remote.data!,
        );
        return;
      }

      final direction = await _directionFromTimestamps(
        storage: storage,
        docDir: docDir,
        remoteData: remote.data!,
      );
      if (direction == _SyncDirection.download) {
        await downloadRemote(
          token: token,
          email: auth.email,
          storage: storage,
          docDir: docDir,
          remoteData: remote.data!,
        );
      } else if (direction == _SyncDirection.upload) {
        await uploadLocal(token: token, storage: storage);
      }
    } catch (_) {
      // 静默同步不打断经营流程；下次数据变化或重启时会自动重试。
    } finally {
      _syncing = false;
    }
  }

  static DateTime? lastSyncTime(Storage storage) {
    final raw = storage.getSettings()[lastCloudSyncKey] as String?;
    return raw == null ? null : DateTime.tryParse(raw);
  }

  static Future<void> markSynced(Storage storage) async {
    final settings = storage.getSettings();
    settings[lastCloudSyncKey] = DateTime.now().toIso8601String();
    await storage.saveSettings(settings);
  }

  static Future<String> ensureSyncDeviceId(Storage storage) async {
    final settings = storage.getSettings();
    final existing = settings['syncDeviceId'] as String?;
    if (existing != null && existing.isNotEmpty) return existing;
    final id = 'device_${DateTime.now().microsecondsSinceEpoch}';
    settings['syncDeviceId'] = id;
    await storage.saveSettings(settings);
    return id;
  }

  static Future<CloudRemoteData> fetchRemote(String token) async {
    final result = await ApiService.fetchDataResult(token);
    final error = result['error'] as String?;
    final statusCode = result['statusCode'] as int?;
    if (error != null) {
      return CloudRemoteData(error: error, statusCode: statusCode);
    }

    final data = _unwrapData(result);
    try {
      Storage.validateDataMap(data);
    } catch (e) {
      return CloudRemoteData(error: '云端数据格式异常：$e');
    }
    return CloudRemoteData(data: data);
  }

  static Future<String?> uploadLocal({
    required String token,
    required Storage storage,
  }) async {
    await ensureSyncDeviceId(storage);
    final error = await ApiService.saveData(
      token,
      storagePayloadForSync(storage),
    );
    if (error != null) return error;
    await markSynced(storage);
    return null;
  }

  static Future<String?> downloadRemote({
    required String token,
    required String? email,
    required Storage storage,
    required String docDir,
    required Map<String, dynamic> remoteData,
  }) async {
    try {
      Storage.validateDataMap(remoteData);
    } catch (e) {
      return '云端数据校验失败：$e';
    }

    final localSettings = snapshotLocalOnlySettings(storage);
    final outDir = (await getTemporaryDirectory()).path;
    await BackupService.backupCurrent(docDir: docDir, outDir: outDir);
    storage.setFullData(remoteData);
    await storage.save();
    await restoreLocalOnlySettings(storage, localSettings);
    if (token.isNotEmpty) {
      await AuthService.login(storage, token, email ?? '');
    }
    AiService.setConfig(
      AiConfig.fromMap(
        storage.getSettings()['aiConfig'] as Map<String, dynamic>?,
      ),
    );
    AiService.setPromptRules(storage.getAiPromptRules());
    await markSynced(storage);
    return null;
  }

  static Map<String, dynamic>? extractSyncMeta(Map<String, dynamic>? data) {
    if (data == null) return null;
    final settings = data['settings'];
    if (settings is! Map) return null;
    final meta = settings['syncMeta'];
    if (meta is Map<String, dynamic>) return meta;
    if (meta is Map) return Map<String, dynamic>.from(meta);
    return null;
  }

  static Future<bool> hasConflict({
    required Storage storage,
    required String docDir,
    required Map<String, dynamic>? remoteData,
  }) async {
    final remoteMeta = extractSyncMeta(remoteData);
    final remoteUpdated = DateTime.tryParse(
      '${remoteMeta?['updatedAt'] ?? ''}',
    );
    if (remoteUpdated == null) return false;

    final localDeviceId = await ensureSyncDeviceId(storage);
    final remoteDeviceId = '${remoteMeta?['deviceId'] ?? ''}';
    final lastSync = lastSyncTime(storage);
    final dataFile = File('$docDir/ipad_boss_data.json');
    final localModified =
        await dataFile.exists() ? await dataFile.lastModified() : null;
    final remoteChangedAfterSync =
        lastSync == null || remoteUpdated.isAfter(lastSync);
    final localChangedAfterSync =
        lastSync == null ||
        (localModified != null && localModified.isAfter(lastSync));
    final deviceDiffers =
        remoteDeviceId.isNotEmpty && remoteDeviceId != localDeviceId;
    return remoteChangedAfterSync && localChangedAfterSync && deviceDiffers;
  }

  static bool localBusinessDataIsEmpty(Storage storage) {
    return storage.getDevices().isEmpty &&
        storage.getOrders().isEmpty &&
        storage.getAgents().isEmpty &&
        storage.getRepairOrders().isEmpty &&
        storage.getPurchaseOrders().isEmpty &&
        storage.getQCReports().isEmpty &&
        storage.getXianyuCopyExamples().isEmpty;
  }

  static String fmtSyncTime(DateTime? time) {
    if (time == null) return '从未同步';
    return '${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  static Future<_SyncAuth?> _resolveSyncAuth(Storage storage) async {
    if (_privateOwnerSyncEnabled && _builtInToken.isNotEmpty) {
      return _SyncAuth(
        token: _builtInToken,
        email: _builtInEmail.isEmpty ? null : _builtInEmail,
      );
    }

    final localToken = AuthService.token;
    if (localToken != null && localToken.isNotEmpty) {
      return _SyncAuth(token: localToken, email: AuthService.email);
    }

    if (!_privateOwnerSyncEnabled ||
        _builtInEmail.isEmpty ||
        _builtInPassword.isEmpty) {
      return null;
    }
    final result = await ApiService.login(_builtInEmail, _builtInPassword);
    final token = result['token'] as String?;
    if (token == null || token.isEmpty) return null;
    await AuthService.login(storage, token, _builtInEmail);
    return _SyncAuth(token: token, email: _builtInEmail);
  }

  static Future<_SyncDirection> _directionFromTimestamps({
    required Storage storage,
    required String docDir,
    required Map<String, dynamic> remoteData,
  }) async {
    final remoteMeta = extractSyncMeta(remoteData);
    final remoteUpdated = DateTime.tryParse(
      '${remoteMeta?['updatedAt'] ?? ''}',
    );
    final lastSync = lastSyncTime(storage);
    final file = File('$docDir/ipad_boss_data.json');
    final localModified =
        await file.exists() ? await file.lastModified() : null;

    final remoteChanged =
        remoteUpdated != null &&
        (lastSync == null || remoteUpdated.isAfter(lastSync));
    final localChanged =
        localModified != null &&
        (lastSync == null || localModified.isAfter(lastSync));

    if (remoteChanged && !localChanged) return _SyncDirection.download;
    if (localChanged && !remoteChanged) return _SyncDirection.upload;
    return _SyncDirection.none;
  }

  static Map<String, dynamic> _unwrapData(Map<String, dynamic> result) {
    final data = result['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return Map<String, dynamic>.from(result);
  }
}

enum _SyncDirection { none, upload, download }

class _SyncAuth {
  final String token;
  final String? email;

  const _SyncAuth({required this.token, required this.email});
}
