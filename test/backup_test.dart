import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive.dart';
import 'package:ipad_boss_app/storage.dart';
import 'package:ipad_boss_app/models.dart';
import 'package:ipad_boss_app/backup_service.dart';

void main() {
  late Directory tmp;
  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('boss_bak_');
  });
  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  group('BackupService 导出/导入', () {
    test('导出生成 zip 含 manifest/data/images', () async {
      final docDir = '${tmp.path}/doc';
      await Directory(docDir).create();
      final st = Storage('$docDir/ipad_boss_data.json');
      await st.load();
      await st.addDevice(
        Device(
          id: 'd1',
          serial: 'F1',
          model: 'iPad Air 5',
          capacity: '64G',
          color: '银',
          network: 'WiFi',
          condition: '95新',
          purchaseCost: 235000,
          purchaseDate: '2026-06-01',
          createdAt: '2026-06-01',
          imagePath: '$docDir/dev_1.jpg',
        ),
      );
      await File('$docDir/dev_1.jpg').writeAsBytes([1, 2, 3]);
      final outDir = '${tmp.path}/out';
      await Directory(outDir).create();
      final zipPath = await BackupService.export(
        docDir: docDir,
        storage: st,
        outDir: outDir,
      );
      expect(await File(zipPath).exists(), true);
      final arc = ZipDecoder().decodeBytes(await File(zipPath).readAsBytes());
      expect(arc.findFile('manifest.json'), isNotNull);
      expect(arc.findFile('data/ipad_boss_data.json'), isNotNull);
      expect(arc.findFile('images/dev_1.jpg'), isNotNull);
    });

    test('导入后数据与图片还原、imagePath 重写为新 docDir', () async {
      // 源 docDir 准备数据 + 图片
      final src = '${tmp.path}/src';
      await Directory(src).create();
      final st1 = Storage('$src/ipad_boss_data.json');
      await st1.load();
      await st1.addDevice(
        Device(
          id: 'd1',
          serial: 'F1',
          model: 'iPad Air 5',
          capacity: '64G',
          color: '银',
          network: 'WiFi',
          condition: '95新',
          purchaseCost: 235000,
          purchaseDate: '2026-06-01',
          createdAt: '2026-06-01',
          status: 'sold',
          sellPrice: 290000,
          sellDate: '2026-06-10',
          imagePath: '$src/dev_1.jpg;$src/cover_d1.jpg',
        ),
      );
      await File('$src/dev_1.jpg').writeAsBytes([1]);
      await File('$src/cover_d1.jpg').writeAsBytes([2]);
      final outDir = '${tmp.path}/out';
      await Directory(outDir).create();
      final zip = await BackupService.export(
        docDir: src,
        storage: st1,
        outDir: outDir,
      );

      // 目标 docDir（模拟新设备，路径不同）
      final dst = '${tmp.path}/dst';
      await Directory(dst).create();
      final st2 = Storage('$dst/ipad_boss_data.json');
      await st2.load();
      final summary = await BackupService.import(
        zipPath: zip,
        docDir: dst,
        storage: st2,
      );

      expect(summary['deviceCount'], 1);
      expect(await File('$dst/dev_1.jpg').exists(), true);
      expect(await File('$dst/cover_d1.jpg').exists(), true);
      final d = st2.getDevices().first;
      // imagePath 各段应已重写为 dst 路径
      expect(d.imagePath!.contains('$dst/dev_1.jpg'), true);
      expect(d.imagePath!.contains('$dst/cover_d1.jpg'), true);
      expect(d.model, 'iPad Air 5');
    });

    test('导入前自动备份生成 .bak', () async {
      final docDir = '${tmp.path}/d2';
      await Directory(docDir).create();
      final st = Storage('$docDir/ipad_boss_data.json');
      await st.load();
      // 先写入一些数据
      await st.addDevice(
        Device(
          id: 'x1',
          serial: 'X1',
          model: 'iPad 9',
          capacity: '64G',
          color: '银',
          network: 'WiFi',
          condition: '95新',
          purchaseCost: 100000,
          purchaseDate: '2026-06-01',
          createdAt: '2026-06-01',
        ),
      );
      final outDir = '${tmp.path}/o2';
      await Directory(outDir).create();
      final bak = await BackupService.backupCurrent(
        docDir: docDir,
        outDir: outDir,
      );
      expect(bak, isNotNull);
      expect(File(bak!).existsSync(), true);
    });

    test('导入前会拒绝结构错误的备份数据', () async {
      final docDir = '${tmp.path}/bad-dst';
      await Directory(docDir).create();
      final st = Storage('$docDir/ipad_boss_data.json');
      await st.load();

      final badData = '{"devices":{}}'.codeUnits;
      final archive =
          Archive()..addFile(
            ArchiveFile('data/ipad_boss_data.json', badData.length, badData),
          );
      final zipPath = '${tmp.path}/bad.zip';
      await File(zipPath).writeAsBytes(ZipEncoder().encode(archive)!);

      expect(
        () =>
            BackupService.import(zipPath: zipPath, docDir: docDir, storage: st),
        throwsFormatException,
      );
    });
  });

  group('备份提醒', () {
    test('从未备份应提醒', () async {
      final docDir = '${tmp.path}/d3';
      await Directory(docDir).create();
      final st = Storage('$docDir/ipad_boss_data.json');
      await st.load();
      expect(BackupService.shouldRemindBackup(st), true);
    });

    test('刚备份不应提醒', () async {
      final docDir = '${tmp.path}/d4';
      await Directory(docDir).create();
      final st = Storage('$docDir/ipad_boss_data.json');
      await st.load();
      await BackupService.markBackupDone(st);
      expect(BackupService.shouldRemindBackup(st), false);
    });

    test('lastBackupTime 返回正确时间', () async {
      final docDir = '${tmp.path}/d5';
      await Directory(docDir).create();
      final st = Storage('$docDir/ipad_boss_data.json');
      await st.load();
      expect(BackupService.lastBackupTime(st), isNull);
      await BackupService.markBackupDone(st);
      final t = BackupService.lastBackupTime(st);
      expect(t, isNotNull);
      expect(DateTime.now().difference(t!).inSeconds < 5, true);
    });
  });
}
