import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../components/index.dart';
import '../utils/utils.dart';
import '../main.dart';
import '../backup_service.dart';
import '../ai_service.dart';
import '../services/auto_backup_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({Key? key}) : super(key: key);
  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  bool _busy = false;
  bool _hasBak = false;
  List<AutoBackupEntry> _autoBackups = const [];
  String? _autoBackupError;

  @override
  void initState() {
    super.initState();
    _checkBak();
    _loadAutoBackups();
  }

  void _checkBak() async {
    final bak = File('$gDocDir/ipad_boss_data.json.bak');
    final exists = await bak.exists();
    if (mounted) setState(() => _hasBak = exists);
  }

  void _loadAutoBackups() async {
    try {
      final list = await AutoBackupService.listBackups();
      if (!mounted) return;
      setState(() {
        _autoBackups = list;
        _autoBackupError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _autoBackupError = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final devices = gStorage.getDevices();
    final orders = gStorage.getOrders();
    final lastBak = BackupService.lastBackupTime(gStorage);
    return appScaffold(
      context,
      '备份与恢复',
      ListView(
        padding: const EdgeInsets.all(14),
        children: [
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '数据概览',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: C.t1,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _stat('${devices.length}', '设备', C.t3)),
                    const SizedBox(width: 8),
                    Expanded(child: _stat('${orders.length}', '订单', C.green)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _stat(
                        lastBak != null
                            ? '${DateTime.now().difference(lastBak).inDays}天前'
                            : '从未',
                        '上次备份',
                        C.orange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_busy)
            Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: C.t3),
              ),
            )
          else ...[
            primaryBtn('导出备份（分享）', _export),
            const SizedBox(height: 10),
            ghostBtn('导入恢复（从 zip）', _import),
            if (_hasBak) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _restoreBak,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: C.orange,
                    side: BorderSide(color: C.orange),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  child: const Text(
                    '恢复导入前的自动备份',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
          ],
          const SizedBox(height: 16),
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 16,
                      color: C.purple,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '自动备份（防卸载丢失）',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: C.t1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _autoBackupSummary(),
                  style: TextStyle(fontSize: 11, color: C.t2, height: 1.6),
                ),
                const SizedBox(height: 10),
                ghostBtn(
                  '立即备份一次',
                  _runAutoBackupNow,
                  icon: Icons.backup_outlined,
                ),
                const SizedBox(height: 8),
                ghostBtn(
                  '从自动备份恢复',
                  _restoreFromAutoBackup,
                  icon: Icons.settings_backup_restore_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '说明',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: C.t1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '• 自动备份：把数据（不含图片）写到手机公共目录，App 一有改动就更新，'
                  '只保留最近 ${AutoBackupService.keepCount} 份。卸载 App 后文件仍在，'
                  '重装后点「从自动备份恢复」即可找回。\n'
                  '• 导出：打包数据+图片为 zip，通过微信/网盘分享。'
                  '自动备份不含图片，换手机前请用这个导出完整备份。\n'
                  '• 导入：选择 zip 文件恢复数据，会自动备份当前数据为 .bak。\n'
                  '• 卸载 App 时若系统询问是否保留应用数据，选「保留」可双保险。',
                  style: TextStyle(fontSize: 11, color: C.t2, height: 1.8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String n, String l, Color c) => Container(
    padding: EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(
      color: C.bgDeep,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: C.border),
    ),
    child: Column(
      children: [
        Text(
          n,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c),
        ),
        SizedBox(height: 2),
        Text(l, style: TextStyle(fontSize: 10, color: C.t2)),
      ],
    ),
  );

  void _export() async {
    setState(() => _busy = true);
    try {
      final outDir = (await getTemporaryDirectory()).path;
      final zipPath = await BackupService.export(
        docDir: gDocDir,
        storage: gStorage,
        outDir: outDir,
      );
      await BackupService.markBackupDone(gStorage);
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      final origin =
          box == null
              ? const Rect.fromLTWH(0, 0, 1, 1)
              : box.localToGlobal(Offset.zero) & box.size;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(zipPath)],
          text: '货脉数据备份',
          sharePositionOrigin: origin,
        ),
      );
      setState(() {});
    } catch (e) {
      if (mounted) toast(context, '导出失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _import() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (result == null || result.files.single.path == null) return;
    final zipPath = result.files.single.path!;
    // 二次确认
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: C.bgCard,
            title: Text('确认导入', style: TextStyle(color: C.t1, fontSize: 16)),
            content: Text(
              '导入将覆盖当前所有数据。系统会自动备份当前数据为 .bak 文件，可随时恢复。\n\n确定要导入吗？',
              style: TextStyle(color: C.t2, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('取消', style: TextStyle(color: C.t2)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('确定导入', style: TextStyle(color: C.t3)),
              ),
            ],
          ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final outDir = (await getTemporaryDirectory()).path;
      await BackupService.backupCurrent(docDir: gDocDir, outDir: outDir);
      final summary = await BackupService.import(
        zipPath: zipPath,
        docDir: gDocDir,
        storage: gStorage,
      );
      // 导入后重新同步 AI 配置
      AiService.setConfig(
        AiConfig.fromMap(
          gStorage.getSettings()['aiConfig'] as Map<String, dynamic>?,
        ),
      );
      AiService.setPromptRules(gStorage.getAiPromptRules());
      if (!mounted) return;
      setState(() {
        _busy = false;
        _hasBak = true;
      });
      toast(
        context,
        '导入成功：${summary['deviceCount']}台设备 / ${summary['orderCount']}单 / ${summary['imageCount']}张图',
      );
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        toast(context, '导入失败：$e');
      }
    }
  }

  void _restoreBak() async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: C.bgCard,
            title: Text('恢复备份', style: TextStyle(color: C.t1, fontSize: 16)),
            content: Text(
              '将把数据恢复到导入前的状态。当前数据会被覆盖。',
              style: TextStyle(color: C.t2, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('取消', style: TextStyle(color: C.t2)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('恢复', style: TextStyle(color: C.orange)),
              ),
            ],
          ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final success = await BackupService.restoreBak(
        docDir: gDocDir,
        storage: gStorage,
      );
      AiService.setConfig(
        AiConfig.fromMap(
          gStorage.getSettings()['aiConfig'] as Map<String, dynamic>?,
        ),
      );
      AiService.setPromptRules(gStorage.getAiPromptRules());
      if (!mounted) return;
      setState(() => _busy = false);
      toast(context, success ? '已恢复到导入前状态' : '没有找到备份文件');
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        toast(context, '恢复失败：$e');
      }
    }
  }

  // ══════ 自动备份 ══════

  String _autoBackupSummary() {
    if (_autoBackupError != null) {
      return '读取公共目录失败：$_autoBackupError';
    }
    if (_autoBackups.isEmpty) {
      return '还没有自动备份。数据一有改动就会自动写一份到手机公共目录，'
          '卸载 App 也不会被清除。';
    }
    final newest = _autoBackups.first;
    final days = DateTime.now().difference(newest.modified).inDays;
    final ago = days <= 0 ? '今天' : '$days 天前';
    return '共 ${_autoBackups.length} 份，最新 $ago（${newest.timeLabel}，'
        '${newest.sizeLabel}）。文件在手机公共目录，卸载 App 不会被清除。';
  }

  Future<void> _runAutoBackupNow() async {
    setState(() => _busy = true);
    final error = await AutoBackupService.runIfNeeded(
      storage: gStorage,
      docDir: gDocDir,
      force: true,
    );
    _loadAutoBackups();
    if (!mounted) return;
    setState(() => _busy = false);
    if (error == null) {
      toast(context, '已备份到手机公共目录');
    } else {
      toast(context, '备份未完成：$error');
    }
  }

  Future<void> _restoreFromAutoBackup() async {
    setState(() => _busy = true);
    List<AutoBackupEntry> entries;
    try {
      entries = await AutoBackupService.listBackups();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      toast(context, '读取备份列表失败：$e');
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);

    if (entries.isEmpty) {
      toast(context, '手机公共目录里没有找到备份');
      return;
    }

    final picked = await showDialog<AutoBackupEntry>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: C.bgCard,
            title: Text('选择备份', style: TextStyle(color: C.t1, fontSize: 16)),
            content: SizedBox(
              width: 340,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: entries.length,
                itemBuilder: (_, i) {
                  final e = entries[i];
                  return ListTile(
                    dense: true,
                    title: Text(
                      e.timeLabel,
                      style: TextStyle(color: C.t1, fontSize: 13),
                    ),
                    subtitle: Text(
                      '${e.name}  ·  ${e.sizeLabel}',
                      style: TextStyle(color: C.t3, fontSize: 10),
                    ),
                    onTap: () => Navigator.pop(ctx, e),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('取消', style: TextStyle(color: C.t2)),
              ),
            ],
          ),
    );
    if (picked == null || !mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: C.bgCard,
            title: Text('确认恢复', style: TextStyle(color: C.t1, fontSize: 16)),
            content: Text(
              '将用 ${picked.timeLabel} 的备份覆盖当前所有数据。\n\n'
              '系统会先把当前数据备份成 .bak 文件，可随时回退。\n\n'
              '注意：自动备份不含图片，恢复后设备图片可能显示不出来，'
              '但库存、订单、财务等数据都在。\n\n确定要恢复吗？',
              style: TextStyle(color: C.t2, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('取消', style: TextStyle(color: C.t2)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('确定恢复', style: TextStyle(color: C.orange)),
              ),
            ],
          ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final localPath = await AutoBackupService.copyToLocal(picked);
      if (localPath == null) {
        throw Exception('无法读取该备份文件');
      }
      final outDir = (await getTemporaryDirectory()).path;
      await BackupService.backupCurrent(docDir: gDocDir, outDir: outDir);
      final summary = await BackupService.import(
        zipPath: localPath,
        docDir: gDocDir,
        storage: gStorage,
      );
      AiService.setConfig(
        AiConfig.fromMap(
          gStorage.getSettings()['aiConfig'] as Map<String, dynamic>?,
        ),
      );
      AiService.setPromptRules(gStorage.getAiPromptRules());
      if (!mounted) return;
      setState(() {
        _busy = false;
        _hasBak = true;
      });
      toast(
        context,
        '已恢复：${summary['deviceCount']}台设备 / ${summary['orderCount']}单',
      );
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        toast(context, '恢复失败：$e');
      }
    }
  }
}
