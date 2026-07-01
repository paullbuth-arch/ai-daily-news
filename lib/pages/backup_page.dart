import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../components/index.dart';
import '../utils/utils.dart';
import '../main.dart';
import '../backup_service.dart';
import '../ai_service.dart';
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

  @override
  void initState() {
    super.initState();
    _checkBak();
  }

  void _checkBak() async {
    final bak = File('$gDocDir/ipad_boss_data.json.bak');
    final exists = await bak.exists();
    if (mounted) setState(() => _hasBak = exists);
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
            const Center(
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
                    side: const BorderSide(color: C.orange),
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
                  '• 导出：打包数据+图片为 zip，通过微信/网盘分享\n• 导入：选择 zip 文件恢复数据，会自动备份当前数据\n• 建议每周备份一次，换机前务必导出\n• 图片和数据一起打包，换手机不丢',
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
}
