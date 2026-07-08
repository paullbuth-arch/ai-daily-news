import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../components/index.dart';
import '../utils/utils.dart';
import '../main.dart';
import '../update_service.dart';
import '../ai_service.dart';
import '../auth_service.dart';
import '../backup_service.dart';
import '../cloud_sync_service.dart';
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
  bool _updateChecking = false;
  String? _updateError;
  bool _updateMessageIsError = false;
  double? _updateProgress;

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
    final protectionSummary = CloudSyncService.protectionSummary(gStorage);
    final protectionError = CloudSyncService.lastSyncError(gStorage);
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
                    _themeChoice(Icons.dark_mode_rounded, '深色', ThemeMode.dark),
                    const SizedBox(width: 8),
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
                _row('数据保护', protectionSummary),
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
                ghostBtn('检查更新', _checkUpdate),
              ],
            ),
          ),
          CardBox(
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: protectionError == null ? C.green : C.orange,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        protectionError == null ? '后台保护正常' : '后台保护自动重试中',
                        style: TextStyle(fontSize: 12, color: C.t1),
                      ),
                      Text(
                        protectionError == null
                            ? '数据会先保存到本机，并在后台完成服务器保护。'
                            : '本机数据不受影响，后台会在下次数据变化或重启后继续尝试。',
                        style: TextStyle(fontSize: 10, color: C.t3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_updateChecking)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Column(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: C.t3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '正在检查更新...',
                      style: TextStyle(fontSize: 12, color: C.t2),
                    ),
                  ],
                ),
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
          if (_updateProgress != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: _updateProgress,
                    backgroundColor: C.border,
                    valueColor: AlwaysStoppedAnimation<Color>(C.t3),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '下载中... ${(_updateProgress! * 100).toStringAsFixed(0)}%',
                    style: TextStyle(fontSize: 11, color: C.t2),
                  ),
                ],
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
    if (gThemeMode == mode) return;
    final settings = gStorage.getSettings();
    settings['themeMode'] = mode == ThemeMode.light ? 'light' : 'dark';
    await gStorage.saveSettings(settings);
    gThemeMode = mode;
    C.useLightTheme(mode == ThemeMode.light);
    gOnThemeChange?.call();
    if (mounted) setState(() {});
  }

  Widget _themeChoice(IconData icon, String label, ThemeMode mode) {
    final selected = gThemeMode == mode;
    return Expanded(
      child: Material(
        color: selected ? C.primaryLight : C.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(C.radiusMd),
          side: BorderSide(color: selected ? C.primary : C.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _setThemeMode(mode),
          child: SizedBox(
            height: 44,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: selected ? C.primary : C.t3, size: 18),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? C.primary : C.t2,
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
    settings['themeMode'] = 'dark';
    settings['aiConfig'] = AiConfig.defaultConfig().toMap();
    await gStorage.saveSettings(settings);
    AiService.setConfig(AiConfig.defaultConfig());
    AiService.setPromptRules({});
    await AuthService.logout(gStorage);
    gThemeMode = ThemeMode.dark;
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

  /// 检查更新
  Future<void> _checkUpdate() async {
    setState(() {
      _updateChecking = true;
      _updateError = null;
      _updateMessageIsError = false;
      _updateProgress = null;
    });
    // 1. 检查远端版本
    UpdateInfo? info;
    try {
      info = await UpdateService.check();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _updateChecking = false;
        _updateMessageIsError = true;
        _updateError = '检查更新失败，请稍后重试';
      });
      return;
    }
    if (!mounted) return;
    if (info == null) {
      setState(() {
        _updateChecking = false;
        _updateMessageIsError = false;
        _updateError = '当前已是最新版本（v${UpdateService.currentVersion}）';
      });
      return;
    }
    final updateInfo = info;
    // 2. 有新版本 → 询问是否下载
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: C.bgCard,
            title: Text(
              '发现新版本 v${updateInfo.version}',
              style: TextStyle(color: C.t1, fontSize: 16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '当前版本：v${UpdateService.currentVersion}',
                  style: TextStyle(color: C.t2, fontSize: 12),
                ),
                Text(
                  '新版本：v${updateInfo.version}',
                  style: TextStyle(
                    color: C.green,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (updateInfo.changelog.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('更新内容：', style: TextStyle(color: C.t2, fontSize: 12)),
                  Text(
                    updateInfo.changelog,
                    style: TextStyle(color: C.t1, fontSize: 12),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('稍后', style: TextStyle(color: C.t2)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('立即更新', style: TextStyle(color: C.t3)),
              ),
            ],
          ),
    );
    if (ok != true) {
      setState(() => _updateChecking = false);
      return;
    }
    // 3. 下载 APK
    setState(() {
      _updateChecking = false;
      _updateProgress = 0.0;
    });
    final apkPath = await UpdateService.downloadApk(
      updateInfo.apkUrl,
      fileName: 'ipad_boss_${updateInfo.version}_${updateInfo.buildNumber}.apk',
      expectedSha256: updateInfo.sha256,
      onProgress: (p) {
        if (mounted) setState(() => _updateProgress = p);
      },
    );
    if (!mounted) return;
    if (apkPath == null) {
      setState(() {
        _updateProgress = null;
        _updateMessageIsError = true;
        _updateError = '下载失败，请检查网络后重试';
      });
      return;
    }
    setState(() => _updateProgress = null);
    // 4. 安装
    final installResult = await UpdateService.installApk(apkPath);
    if (!mounted) return;
    if (!installResult.success) {
      setState(() {
        _updateMessageIsError = true;
        _updateError =
            installResult.permissionRequired
                ? '已打开权限设置。开启「安装未知应用」后，请回来再点一次检查更新'
                : '安装失败，请稍后重试';
      });
    } else {
      setState(() {
        _updateMessageIsError = false;
        _updateError = '安装器已打开，请按系统提示完成更新';
      });
    }
  }
}
