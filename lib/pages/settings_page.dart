import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../components/index.dart';
import '../utils/utils.dart';
import '../main.dart';
import '../update_service.dart';
import '../ai_service.dart';
import '../backup_service.dart';
import 'ai_config_page.dart';
import 'ai_prompt_rules_page.dart';
import 'xianyu_copywriting_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _fileSize = '';
  String? _updateError;
  bool _updateMessageIsError = false;

  @override
  void initState() {
    super.initState();
    _calcSize();
  }

  void _calcSize() async {
    try {
      final f = File('$gDocDir/ipad_boss_data.json');
      if (await f.exists()) {
        final s = await f.length();
        setState(() => _fileSize = '${(s / 1024).toStringAsFixed(1)}KB');
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final devices = gStorage.getDevices();
    final orders = gStorage.getOrders();
    final agents = gStorage.getAgents();
    return appScaffold(
      context,
      '设置',
      ListView(
        padding: const EdgeInsets.all(14),
        children: [
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('数据统计'),
                const SizedBox(height: 10),
                _row('设备总数', '${devices.length}台'),
                _row('订单总数', '${orders.length}单'),
                _row('代理总数', '${agents.length}人'),
                _row('数据文件大小', _fileSize.isEmpty ? '计算中...' : _fileSize),
                _row('存储路径', gDocDir, small: true),
              ],
            ),
          ),
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('主题'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _themeChoice(
                      Icons.light_mode_rounded,
                      '浅色',
                      ThemeMode.light,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '浅色主题使用浅灰绿背景、白色信息面板和酸橙强调色，适合白天核对库存与订单。',
                  style: TextStyle(fontSize: 11, color: C.t3, height: 1.45),
                ),
              ],
            ),
          ),
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('关于'),
                const SizedBox(height: 10),
                _row('应用名称', '货脉'),
                _row('版本', 'v${UpdateService.currentVersion}'),
                _row(
                  'AI引擎',
                  '${AiService.effectiveConfig.providerName} · ${AiService.effectiveConfig.model}',
                ),
                const SizedBox(height: 10),
                ghostBtn(
                  '配置 AI 引擎',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AiConfigPage()),
                  ),
                ),
                const SizedBox(height: 8),
                ghostBtn(
                  'AI 提示词/规则',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AiPromptRulesPage(),
                    ),
                  ),
                  icon: Icons.tune_rounded,
                ),
                const SizedBox(height: 8),
                ghostBtn(
                  '闲鱼文案经验库',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const XianyuCopywritingPage(),
                    ),
                  ),
                  icon: Icons.library_books_outlined,
                ),
                const SizedBox(height: 8),
                ghostBtn(
                  '选择安装包更新',
                  _pickAndInstallApk,
                  icon: Icons.system_update_alt_rounded,
                ),
              ],
            ),
          ),
          if (_updateError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _updateError!,
                style: TextStyle(
                  fontSize: 12,
                  color: _updateMessageIsError ? C.red : C.green,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ghostBtn('清空所有数据（重新初始化）', _resetAllData),
          ),
        ],
      ),
    );
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    if (gThemeMode == ThemeMode.light) return;
    final settings = gStorage.getSettings();
    settings['themeMode'] = 'light';
    await gStorage.saveSettings(settings);
    gThemeMode = ThemeMode.light;
    C.useLightTheme(true);
    gOnThemeChange?.call();
    if (mounted) setState(() {});
  }

  Widget _themeChoice(IconData icon, String label, ThemeMode mode) {
    if (mode == ThemeMode.dark) return const SizedBox.shrink();
    final selected = gThemeMode == mode;
    return Expanded(
      child: Material(
        color: selected ? C.hudDark : C.hudDark2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(C.radiusMd),
          side: BorderSide(color: selected ? C.primaryButtonBorder : C.hudLine),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _setThemeMode(mode),
          child: SizedBox(
            height: 44,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: selected ? C.purple : C.t3, size: 18),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? C.purple : C.t2,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String k, String v, {bool small = false}) => Padding(
    padding: EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(k, style: TextStyle(fontSize: 12, color: C.t2)),
        ),
        Expanded(
          child: Text(
            v,
            style: TextStyle(
              fontSize: small ? 10 : 12,
              color: C.t1,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  Future<void> _resetAllData() async {
    final devices = gStorage.getDevices();
    final orders = gStorage.getOrders();
    final imageCount = await _countLocalGeneratedFiles();
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: C.bgCard,
            title: Text('确认清空', style: TextStyle(color: C.red, fontSize: 16)),
            content: Text(
              '将清空 ${devices.length} 台设备、${orders.length} 单订单和 $imageCount 个本地素材文件，并恢复默认设置。\n\n执行前会先在本机生成一份 zip 自动备份；如果备份失败，将不会清空。',
              style: TextStyle(color: C.t2, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('取消', style: TextStyle(color: C.t2)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('彻底清空', style: TextStyle(color: C.red)),
              ),
            ],
          ),
    );
    if (ok != true) return;

    String backupPath;
    try {
      backupPath = await BackupService.export(
        docDir: gDocDir,
        storage: gStorage,
        outDir: gDocDir,
      );
    } catch (e) {
      if (!mounted) return;
      toast(context, '自动备份失败，已取消清空：$e');
      return;
    }

    await _deleteLocalGeneratedFiles();
    await gStorage.clearAll(markInitialized: true);
    final settings = gStorage.getSettings();
    settings['initialized'] = true;
    settings['themeMode'] = 'light';
    settings['aiConfig'] = AiConfig.defaultConfig().toMap();
    await gStorage.saveSettings(settings);
    AiService.setConfig(AiConfig.defaultConfig());
    AiService.setPromptRules({});
    gThemeMode = ThemeMode.light;
    gOnThemeChange?.call();
    _calcSize();
    if (!mounted) return;
    setState(() {});
    final backupName = backupPath.split(Platform.pathSeparator).last;
    toast(context, '数据已清空。清空前备份已保存：$backupName');
  }

  Future<int> _countLocalGeneratedFiles() async {
    final dir = Directory(gDocDir);
    if (!await dir.exists()) return 0;
    var count = 0;
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (_shouldDeleteLocalFile(name)) count++;
    }
    return count;
  }

  Future<void> _deleteLocalGeneratedFiles() async {
    final dir = Directory(gDocDir);
    if (!await dir.exists()) return;
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (!_shouldDeleteLocalFile(name)) continue;
      try {
        await entity.delete();
      } catch (_) {}
    }
  }

  bool _shouldDeleteLocalFile(String name) =>
      name.startsWith('about_') ||
      name.startsWith('dev_') ||
      name.startsWith('import_') ||
      name.startsWith('cover_') ||
      name == 'ipad_boss_data.json.bak';

  /// 选择本地 APK 安装包，调系统安装器完成更新
  Future<void> _pickAndInstallApk() async {
    setState(() {
      _updateError = null;
      _updateMessageIsError = false;
    });

    String? picked;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['apk'],
      );
      picked = result?.files.single.path;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _updateMessageIsError = true;
        _updateError = '选择文件失败：$e';
      });
      return;
    }

    // 用户取消选择
    if (picked == null || picked.isEmpty) return;

    final installResult = await UpdateService.installApk(picked);
    if (!mounted) return;
    if (!installResult.success) {
      setState(() {
        _updateMessageIsError = true;
        _updateError =
            installResult.permissionRequired
                ? '已打开权限设置。开启「安装未知应用」后，请回来重新选择安装包'
                : '安装失败，请确认所选文件是完整的 APK';
      });
    } else {
      setState(() {
        _updateMessageIsError = false;
        _updateError = '安装器已打开，请按系统提示完成更新';
      });
    }
  }
}
