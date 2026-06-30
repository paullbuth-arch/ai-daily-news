import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ipad_boss_app/main.dart' as app;
import 'package:ipad_boss_app/storage.dart';
import 'package:ipad_boss_app/utils/utils.dart';

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
    settings['aiConfig'] = {'model': 'glm-4.7-flash'};
    await storage.saveSettings(settings);

    final payload = storagePayloadForSync(storage);
    final syncSettings = payload['settings'] as Map<String, dynamic>;

    expect(syncSettings.containsKey('auth_token'), false);
    expect(syncSettings.containsKey('auth_email'), false);
    expect(syncSettings.containsKey('webdavConfig'), false);
    expect(syncSettings['aiConfig'], {'model': 'glm-4.7-flash'});
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
}
