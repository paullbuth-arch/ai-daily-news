import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../backup_service.dart';
import '../storage.dart';

/// 公共目录里的一个备份文件。
class AutoBackupEntry {
  final String name;
  final String uri;
  final int size;
  final DateTime modified;

  const AutoBackupEntry({
    required this.name,
    required this.uri,
    required this.size,
    required this.modified,
  });

  String get sizeLabel {
    if (size <= 0) return '未知大小';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  String get timeLabel =>
      '${modified.year}-${_two(modified.month)}-${_two(modified.day)} '
      '${_two(modified.hour)}:${_two(modified.minute)}';

  static String _two(int v) => v.toString().padLeft(2, '0');
}

/// 自动备份 —— 把数据定期写入手机公共目录。
///
/// **为什么是公共目录**：App 私有目录 `/data/data/<包名>/` 在卸载时会被系统
/// 直接清空，而公共的 Download / Documents 不会。这是"单机使用、怕丢数据"
/// 场景下最关键的一道保险，配合清单里的 `hasFragileUserData`（卸载时系统会
/// 问"是否保留应用数据"）双保险。
///
/// **为什么默认不含图片**：图片动辄几百 MB，高频写入会拖慢 App。这里只备份
/// 数据文件（几十 KB），图片仍走「导出备份（分享）」手动做完整打包。不含图片
/// 的备份依然是合法 zip，[BackupService.import] 可直接读取。
///
/// **为什么不在数据文件里记状态**：把"上次备份时间"写进 settings 会触发
/// 数据文件变更 → 又一次备份，形成反馈循环。所以这里改为**无状态**判断：
/// 用备份文件名自带的时间戳当作上次备份时间。
class AutoBackupService {
  static const MethodChannel _channel = MethodChannel('ipad_boss_app/gallery');

  /// 自动备份文件名前缀。只轮转清理自己产生的文件，用户手动放进来的不动。
  static const String fileNamePrefix = '货脉自动备份_';

  /// 两次自动备份的最小间隔。
  static const Duration minInterval = Duration(minutes: 10);

  /// 公共目录里保留的自动备份份数。
  static const int keepCount = 10;

  static StreamSubscription<void>? _changeSub;
  static Timer? _debounce;
  static bool _running = false;

  /// 启动：立刻尝试一次，之后在数据变化（防抖）时再尝试。
  static void start({required Storage storage, required String docDir}) {
    _changeSub?.cancel();
    _changeSub = storage.changes.listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(seconds: 8), () {
        runIfNeeded(storage: storage, docDir: docDir);
      });
    });
    runIfNeeded(storage: storage, docDir: docDir);
  }

  static Future<void> stop() async {
    _debounce?.cancel();
    _debounce = null;
    await _changeSub?.cancel();
    _changeSub = null;
  }

  /// 必要时执行一次自动备份。
  ///
  /// 跳过条件：数据文件自上次备份后没变过，或距上次备份不足 [minInterval]。
  /// [force] 为 true 时忽略节流（用户在界面上手动点"立即备份"用）。
  ///
  /// 返回 null 表示备份成功，否则返回跳过/失败的原因。
  static Future<String?> runIfNeeded({
    required Storage storage,
    required String docDir,
    bool force = false,
  }) async {
    if (_running) return '上一次备份还在进行中';
    _running = true;
    try {
      final dataFile = File('$docDir/${BackupService.kDataFile}');
      if (!await dataFile.exists()) return '还没有数据文件';

      List<AutoBackupEntry> existing;
      try {
        existing = await listBackups();
      } catch (e) {
        return '无法读取公共目录：$e';
      }

      final last = existing.isEmpty ? null : existing.first.modified;
      if (last != null && !force) {
        final dataMtime = await dataFile.lastModified();
        if (!dataMtime.isAfter(last)) return '数据没有变化';
        if (DateTime.now().difference(last) < minInterval) {
          return '距上次备份不足 ${minInterval.inMinutes} 分钟';
        }
      }

      final tmpDir = await getTemporaryDirectory();
      final zipPath = await BackupService.export(
        docDir: docDir,
        storage: storage,
        outDir: tmpDir.path,
        includeImages: false,
      );

      try {
        await _channel.invokeMethod<String>('exportBackupToDocuments', {
          'srcPath': zipPath,
          'fileName': buildFileName(DateTime.now()),
        });
      } on PlatformException catch (e) {
        return '写入公共目录失败：${e.message ?? e.code}';
      } finally {
        try {
          await File(zipPath).delete();
        } catch (_) {}
      }

      try {
        await prune();
      } catch (_) {
        // 清理失败不影响备份本身
      }
      return null;
    } catch (e) {
      return '自动备份失败：$e';
    } finally {
      _running = false;
    }
  }

  /// 列出公共目录里所有备份 zip（含用户手动放入的），按时间倒序。
  static Future<List<AutoBackupEntry>> listBackups() async {
    final raw = await _channel.invokeListMethod<dynamic>('listBackupDocuments');
    final out = <AutoBackupEntry>[];
    for (final item in raw ?? const <dynamic>[]) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final name = '${map['name'] ?? ''}';
      final uri = '${map['uri'] ?? ''}';
      if (name.isEmpty || uri.isEmpty) continue;
      out.add(
        AutoBackupEntry(
          name: name,
          uri: uri,
          size: (map['size'] as num?)?.toInt() ?? 0,
          modified: DateTime.fromMillisecondsSinceEpoch(
            (map['dateModified'] as num?)?.toInt() ?? 0,
          ),
        ),
      );
    }
    out.sort((a, b) => b.modified.compareTo(a.modified));
    return out;
  }

  /// 把公共目录里的备份复制回应用缓存，返回本地绝对路径。
  ///
  /// Dart 的 `File` 读不了 `content://` uri（API 29+ 在公共目录里就是这个形式），
  /// 所以恢复前必须先落到本地再交给 [BackupService.import]。
  static Future<String?> copyToLocal(AutoBackupEntry entry) =>
      _channel.invokeMethod<String>('copyBackupToCache', {
        'uri': entry.uri,
        'fileName': entry.name,
      });

  /// 只保留最近 [keepCount] 份**自动**备份，其余删除。
  /// 手动放进目录的文件（前缀不匹配）不受影响。
  static Future<int> prune() async {
    final entries = await listBackups();
    final auto = entries.where((e) => e.name.startsWith(fileNamePrefix)).toList();
    if (auto.length <= keepCount) return 0;

    var removed = 0;
    for (final entry in auto.skip(keepCount)) {
      try {
        final ok = await _channel.invokeMethod<bool>(
          'deleteBackupDocument',
          {'uri': entry.uri},
        );
        if (ok == true) removed++;
      } catch (_) {}
    }
    return removed;
  }

  static String buildFileName(DateTime now) =>
      '$fileNamePrefix${now.year}${_two(now.month)}${_two(now.day)}_'
      '${_two(now.hour)}${_two(now.minute)}${_two(now.second)}.zip';

  static String _two(int v) => v.toString().padLeft(2, '0');
}
