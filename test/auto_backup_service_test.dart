import 'package:flutter_test/flutter_test.dart';
import 'package:ipad_boss_app/services/auto_backup_service.dart';

void main() {
  group('自动备份文件名', () {
    test('补零到秒，并带可识别前缀', () {
      final name = AutoBackupService.buildFileName(
        DateTime(2026, 10, 15, 9, 5, 3),
      );
      expect(name, '货脉自动备份_20261015_090503.zip');
    });

    test('前缀与 .zip 后缀同时成立，轮转过滤才认得出来', () {
      final name = AutoBackupService.buildFileName(
        DateTime(2026, 1, 2, 23, 59, 59),
      );
      expect(name.startsWith(AutoBackupService.fileNamePrefix), isTrue);
      expect(name.endsWith('.zip'), isTrue);
    });

    test('保留份数是正数，否则轮转会删掉刚写的备份', () {
      expect(AutoBackupService.keepCount, greaterThan(0));
    });
  });

  group('备份条目展示', () {
    AutoBackupEntry entry({int size = 0, DateTime? modified}) => AutoBackupEntry(
      name: '货脉自动备份_20261015_093000.zip',
      uri: 'content://demo/1',
      size: size,
      modified: modified ?? DateTime(2026, 10, 15, 9, 30),
    );

    test('大小按量级格式化', () {
      expect(entry(size: 0).sizeLabel, '未知大小');
      expect(entry(size: 512).sizeLabel, '512 B');
      expect(entry(size: 2048).sizeLabel, '2.0 KB');
      expect(entry(size: 3 * 1024 * 1024).sizeLabel, '3.0 MB');
    });

    test('时间补零到分钟', () {
      final e = entry(modified: DateTime(2026, 1, 2, 3, 4));
      expect(e.timeLabel, '2026-01-02 03:04');
    });
  });
}
