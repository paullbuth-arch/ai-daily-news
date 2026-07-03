import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ipad_boss_app/storage.dart';
import 'package:ipad_boss_app/utils/utils.dart';
import 'package:ipad_boss_app/webdav_service.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('boss_sync_');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('sync payload excludes local auth and WebDAV settings', () async {
    final storage = Storage('${tmp.path}/data.json');
    await storage.load();
    final settings = storage.getSettings();
    settings['auth_token'] = 'local-token';
    settings['auth_email'] = 'boss@example.com';
    settings['webdavConfig'] = {
      'url': 'https://dav.example.com/',
      'username': 'boss',
      'password': 'secret',
    };
    settings['syncDeviceId'] = 'local-device';
    settings['lastWebDavSync'] = '2026-07-01T10:00:00';
    settings['lastCloudSync'] = '2026-07-02T10:00:00';
    settings['aiConfig'] = {'model': 'GLM-4-Flash-250414'};
    await storage.saveSettings(settings);

    final payload = storagePayloadForSync(storage);
    final syncSettings = payload['settings'] as Map<String, dynamic>;

    expect(syncSettings.containsKey('auth_token'), false);
    expect(syncSettings.containsKey('auth_email'), false);
    expect(syncSettings.containsKey('webdavConfig'), false);
    expect(syncSettings.containsKey('syncDeviceId'), false);
    expect(syncSettings.containsKey('lastWebDavSync'), false);
    expect(syncSettings.containsKey('lastCloudSync'), false);
    expect(syncSettings['aiConfig'], {'model': 'GLM-4-Flash-250414'});
    expect(syncSettings['syncMeta']['deviceId'], 'local-device');
    expect(syncSettings['syncMeta']['schemaVersion'], 1);
  });

  test('local-only settings survive full data replacement', () async {
    final storage = Storage('${tmp.path}/data.json');
    await storage.load();
    await storage.saveSettings({
      'auth_token': 'local-token',
      'auth_email': 'boss@example.com',
      'webdavConfig': {
        'url': 'https://local.example.com/',
        'username': 'local',
        'password': 'local-secret',
      },
    });

    final localSettings = snapshotLocalOnlySettings(storage);
    storage.setFullData({
      'devices': [],
      'orders': [],
      'agents': [],
      'repairOrders': [],
      'settings': {
        'auth_token': 'remote-token',
        'auth_email': 'remote@example.com',
        'webdavConfig': {
          'url': 'https://remote.example.com/',
          'username': 'remote',
          'password': 'remote-secret',
        },
        'aiConfig': {'model': 'remote-model'},
      },
    });
    await storage.save();

    await restoreLocalOnlySettings(storage, localSettings);
    final settings = storage.getSettings();

    expect(settings['auth_token'], 'local-token');
    expect(settings['auth_email'], 'boss@example.com');
    expect(settings['webdavConfig'], {
      'url': 'https://local.example.com/',
      'username': 'local',
      'password': 'local-secret',
    });
    expect(settings['aiConfig'], {'model': 'remote-model'});
  });

  test(
    'restored report collections are retained while retired ERP collections are excluded',
    () async {
      final storage = Storage('${tmp.path}/data.json');
      await storage.load();
      storage.setFullData({
        'devices': [],
        'orders': [],
        'agents': [],
        'repairOrders': [],
        'repairParts': [],
        'settings': {},
        'purchaseOrders': [
          {'id': 'old-purchase'},
        ],
        'qcReports': [
          {'id': 'old-qc'},
        ],
        'allocations': [
          {'id': 'old-allocation'},
        ],
        'rentals': [
          {'id': 'old-rental'},
        ],
        'installmentPlans': [
          {'id': 'old-installment'},
        ],
        'deposits': [
          {'id': 'old-deposit'},
        ],
        'warehouses': [
          {'id': 'old-warehouse'},
        ],
        'transfers': [
          {'id': 'old-transfer'},
        ],
        'inventoryCounts': [
          {'id': 'old-count'},
        ],
        'otherInOuts': [
          {'id': 'old-other'},
        ],
      });

      final payload = storage.toFullMap();

      expect(payload.containsKey('purchaseOrders'), true);
      expect(payload.containsKey('qcReports'), true);

      for (final key in [
        'allocations',
        'rentals',
        'installmentPlans',
        'deposits',
        'warehouses',
        'transfers',
        'inventoryCounts',
        'otherInOuts',
      ]) {
        expect(payload.containsKey(key), false);
      }
    },
  );

  test('webdav sync metadata can be extracted from remote payload', () async {
    final bytes = utf8.encode(
      json.encode({
        'devices': [],
        'orders': [],
        'agents': [],
        'repairOrders': [],
        'repairParts': [],
        'purchaseOrders': [],
        'qcReports': [],
        'xianyuCopyExamples': [],
        'settings': {
          'syncMeta': {
            'updatedAt': '2026-07-01T10:00:00.000',
            'deviceId': 'device-a',
          },
        },
      }),
    );

    final meta = WebDavService.extractSyncMeta(Uint8List.fromList(bytes));
    expect(meta?['deviceId'], 'device-a');
    expect(meta?['updatedAt'], '2026-07-01T10:00:00.000');
  });
}
