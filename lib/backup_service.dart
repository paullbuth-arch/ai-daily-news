// 备份/恢复服务层 —— 纯Dart，用archive包做zip压缩/解压
// 不依赖file_picker/share_plus/main.dart，确保可单元测试
import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'storage.dart';

class BackupService {
  static const kDataFile = 'ipad_boss_data.json';

  /// 导出。返回生成的 zip 绝对路径（写在 [outDir] 临时目录下）。
  static Future<String> export({
    required String docDir,
    required Storage storage,
    required String outDir,
  }) async {
    final archive = Archive();
    // 1) manifest
    final manifest = {
      'appVersion': '1.4.0',
      'exportTime': DateTime.now().toIso8601String(),
      'deviceCount': storage.getDevices().length,
      'orderCount': storage.getOrders().length,
    };
    final manifestBytes = utf8.encode(json.encode(manifest));
    archive.addFile(
      ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
    );
    // 2) data.json
    final dataFile = File('$docDir/$kDataFile');
    if (await dataFile.exists()) {
      final dataBytes = await dataFile.readAsBytes();
      archive.addFile(
        ArchiveFile('data/$kDataFile', dataBytes.length, dataBytes),
      );
    }
    // 3) 图片：扫描 gDocDir 下所有 about_*.jpg / dev_*.jpg / cover_*.png
    await _addImages(archive, docDir);
    // 4) 编码 zip
    final bytes = ZipEncoder().encode(archive);
    final name = '货脉备份_${_ts(DateTime.now())}.zip';
    final zipPath = '$outDir/$name';
    await File(zipPath).writeAsBytes(bytes!);
    return zipPath;
  }

  static Future<int> _addImages(Archive archive, String docDir) async {
    int n = 0;
    final dir = Directory(docDir);
    if (!await dir.exists()) return 0;
    await for (final e in dir.list()) {
      if (e is! File) continue;
      final name = p.basename(e.path);
      if (_isImageName(name)) {
        final imgBytes = await e.readAsBytes();
        archive.addFile(ArchiveFile('images/$name', imgBytes.length, imgBytes));
        n++;
      }
    }
    return n;
  }

  static bool _isImageName(String n) =>
      n.startsWith('about_') ||
      n.startsWith('dev_') ||
      n.startsWith('cover_') ||
      n.endsWith('.jpg') ||
      n.endsWith('.png') ||
      n.endsWith('.jpeg');

  /// 导入。返回 {deviceCount, orderCount, imageCount}。
  /// 流程：解压 → 先备份当前 data.json 为 .bak → 覆盖 data.json → 还原图片 → 重写 imagePath → reload。
  static Future<Map<String, int>> import({
    required String zipPath,
    required String docDir,
    required Storage storage,
  }) async {
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    // 1) 备份当前数据
    final cur = File('$docDir/$kDataFile');
    if (await cur.exists()) await cur.copy('$docDir/$kDataFile.bak');
    // 2) 覆盖 data.json
    final dataArc = archive.findFile('data/$kDataFile');
    if (dataArc != null) {
      await File(
        '$docDir/$kDataFile',
      ).writeAsBytes(dataArc.content as List<int>);
    }
    // 3) 还原图片（按 basename 写回 docDir）
    int imgCount = 0;
    for (final f in archive) {
      if (f.name.startsWith('images/')) {
        final bn = p.basename(f.name);
        await File('$docDir/$bn').writeAsBytes(f.content as List<int>);
        imgCount++;
      }
    }
    // 4) reload + 重写 imagePath（绝对路径跨设备可能不同，统一重写为新 docDir/basename）
    await storage.load();
    await _remapImagePaths(storage: storage, docDir: docDir);
    return {
      'deviceCount': storage.getDevices().length,
      'orderCount': storage.getOrders().length,
      'imageCount': imgCount,
    };
  }

  /// 把每台设备的 imagePath 各段重写为 {docDir}/{basename}，保证跨设备路径可用。
  static Future<void> _remapImagePaths({
    required Storage storage,
    required String docDir,
  }) async {
    final devices = storage.getDevices();
    for (final d in devices) {
      if (d.imagePath == null || d.imagePath!.isEmpty) continue;
      final segs = d.imagePath!.split(';').where((s) => s.isNotEmpty).toList();
      final newSegs = segs.map((s) => '$docDir/${p.basename(s)}').toList();
      final np = newSegs.join(';');
      if (np != d.imagePath) {
        d.imagePath = np;
        await storage.updateDevice(d);
      }
    }
  }

  /// 导入前自动备份（额外安全网，把当前 data.json 复制成带时间戳的副本）
  static Future<String?> backupCurrent({
    required String docDir,
    required String outDir,
  }) async {
    final cur = File('$docDir/$kDataFile');
    if (!await cur.exists()) return null;
    final path = '$outDir/货脉自动备份_${_ts(DateTime.now())}.json';
    await cur.copy(path);
    return path;
  }

  /// 恢复 .bak 文件（导入后如果数据有问题，可应急恢复）
  static Future<bool> restoreBak({
    required String docDir,
    required Storage storage,
  }) async {
    final bak = File('$docDir/$kDataFile.bak');
    if (!await bak.exists()) return false;
    await bak.copy('$docDir/$kDataFile');
    await storage.load();
    await _remapImagePaths(storage: storage, docDir: docDir);
    return true;
  }

  // ===== 备份提醒（7天） =====
  static DateTime? lastBackupTime(Storage s) {
    final v = s.getSettings()['lastBackupTime'] as String?;
    return v == null ? null : DateTime.tryParse(v);
  }

  static Future<void> markBackupDone(Storage s) async {
    final st = s.getSettings();
    st['lastBackupTime'] = DateTime.now().toIso8601String();
    await s.saveSettings(st);
  }

  /// 是否需要提醒备份（从未备份 或 超过7天）
  static bool shouldRemindBackup(Storage s) {
    final t = lastBackupTime(s);
    if (t == null) return true;
    return DateTime.now().difference(t).inDays >= 7;
  }

  static String _ts(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}_'
      '${d.hour.toString().padLeft(2, '0')}${d.minute.toString().padLeft(2, '0')}';
}
