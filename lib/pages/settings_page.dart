import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../theme/colors.dart';
import '../components/index.dart';
import '../utils/utils.dart';
import '../storage.dart';
import '../main.dart';
import '../update_service.dart';
import '../ai_service.dart';
import '../auth_service.dart';
import '../login_page.dart';
import '../api_service.dart';
import '../backup_service.dart';
import 'webdav_config_page.dart';
import 'ai_config_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _fileSize = '';
  bool _updateChecking = false;
  String? _updateError;
  double? _updateProgress;
  bool _cloudSyncing = false;
  String? _cloudError;

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
                _themeItem(Icons.dark_mode_outlined, '深色模式', ThemeMode.dark),
                _themeItem(Icons.light_mode_outlined, '浅色模式', ThemeMode.light),
                _themeItem(
                  Icons.brightness_auto_outlined,
                  '跟随系统',
                  ThemeMode.system,
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
                _row('应用名称', '机掌柜'),
                _row('版本', 'v${UpdateService.currentVersion}'),
                _row(
                  'AI引擎',
                  '${AiService.effectiveConfig.providerName} · ${AiService.effectiveConfig.model}',
                ),
                _row('数据存储', '本地JSON持久化 + WebDAV云同步'),
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
                  'WebDAV 云同步',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WebDavConfigPage()),
                  ),
                ),
                const SizedBox(height: 8),
                ghostBtn('检查更新', _checkUpdate),
                const SizedBox(height: 8),
                ghostBtn('云端同步', _cloudSync),
              ],
            ),
          ),
          if (_cloudSyncing)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: C.t3,
                  ),
                ),
              ),
            ),
          if (_cloudError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _cloudError!,
                style: TextStyle(fontSize: 11, color: C.t3),
                textAlign: TextAlign.center,
              ),
            ),
          // 登录状态
          CardBox(
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AuthService.isLoggedIn ? C.green : C.t3,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AuthService.isLoggedIn
                            ? '已登录：${AuthService.email}'
                            : '离线模式',
                        style: TextStyle(fontSize: 12, color: C.t1),
                      ),
                      Text(
                        AuthService.isLoggedIn ? '数据可同步到云端' : '登录后可同步数据到云端',
                        style: TextStyle(fontSize: 10, color: C.t3),
                      ),
                    ],
                  ),
                ),
                if (AuthService.isLoggedIn)
                  TextButton(
                    onPressed: _logout,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      '退出',
                      style: TextStyle(fontSize: 11, color: C.red),
                    ),
                  )
                else
                  TextButton(
                    onPressed:
                        () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                        ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      '登录',
                      style: TextStyle(fontSize: 11, color: C.t3),
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
                    const SizedBox(
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
                style: TextStyle(fontSize: 12, color: C.red),
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
            child: ghostBtn('清空所有数据（重新初始化）', () async {
              final ok = await showDialog<bool>(
                context: context,
                builder:
                    (ctx) => AlertDialog(
                      backgroundColor: C.bgCard,
                      title: const Text(
                        '确认清空',
                        style: TextStyle(color: C.red, fontSize: 16),
                      ),
                      content: Text(
                        '将删除所有设备、订单、代理、维修记录，且不可恢复。确定继续吗？',
                        style: TextStyle(color: C.t2, fontSize: 13),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text('取消', style: TextStyle(color: C.t2)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text('清空', style: TextStyle(color: C.red)),
                        ),
                      ],
                    ),
              );
              if (ok == true) {
                await gStorage.clearAll();
                await seedDemoData();
                _calcSize();
                setState(() {});
                toast(context, '数据已清空并重新初始化');
              }
            }),
          ),
        ],
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

  Widget _themeItem(IconData icon, String label, ThemeMode mode) {
    final on = gThemeMode == mode;
    return GestureDetector(
      onTap: () {
        gThemeMode = mode;
        final settings = gStorage.getSettings();
        settings['themeMode'] =
            mode == ThemeMode.light
                ? 'light'
                : mode == ThemeMode.system
                ? 'system'
                : 'dark';
        gStorage.saveSettings(settings);
        gOnThemeChange?.call();
        setState(() {});
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: on ? C.selected : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: on ? C.cyan.withOpacity(0.3) : C.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: on ? C.cyan : C.t2),
            SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: on ? C.cyan : C.t1,
              ),
            ),
            Spacer(),
            if (on)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: C.cyan,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 检查更新
  Future<void> _checkUpdate() async {
    setState(() {
      _updateChecking = true;
      _updateError = null;
      _updateProgress = null;
    });
    // 1. 检查远端版本
    final info = await UpdateService.check();
    if (!mounted) return;
    if (info == null) {
      setState(() {
        _updateChecking = false;
        _updateError = '当前已是最新版本（v${UpdateService.currentVersion}）';
      });
      return;
    }
    // 2. 有新版本 → 询问是否下载
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: C.bgCard,
            title: Text(
              '发现新版本 v${info.version}',
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
                  '新版本：v${info.version}',
                  style: TextStyle(
                    color: C.green,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (info.changelog.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('更新内容：', style: TextStyle(color: C.t2, fontSize: 12)),
                  Text(
                    info.changelog,
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
      info.apkUrl,
      onProgress: (p) {
        if (mounted) setState(() => _updateProgress = p);
      },
    );
    if (!mounted) return;
    if (apkPath == null) {
      setState(() {
        _updateProgress = null;
        _updateError = '下载失败，请检查网络后重试';
      });
      return;
    }
    setState(() => _updateProgress = null);
    // 4. 安装
    final installed = await UpdateService.installApk(apkPath);
    if (!mounted) return;
    if (!installed) {
      setState(() => _updateError = '安装失败，请在设置中手动开启「安装未知应用」权限');
    }
  }

  Future<void> _restoreLocalAuth(String token, String? email) async {
    await AuthService.login(gStorage, token, email ?? '');
  }

  /// 云端同步（用户选择下载或上传，避免无提示覆盖）
  Future<void> _cloudSync() async {
    if (!AuthService.isLoggedIn) {
      setState(() => _cloudError = '请先登录');
      return;
    }
    setState(() {
      _cloudSyncing = true;
      _cloudError = null;
    });
    final token = AuthService.token!;
    final email = AuthService.email;
    final localSettings = snapshotLocalOnlySettings(gStorage);
    final remoteResult = await ApiService.fetchDataResult(token);
    if (!mounted) return;

    final remoteError = remoteResult['error'] as String?;
    final remoteStatus = remoteResult['statusCode'] as int?;
    if (remoteError != null && remoteStatus != 404) {
      setState(() {
        _cloudSyncing = false;
        _cloudError = remoteError;
      });
      return;
    }

    if (remoteError != null) {
      final err = await ApiService.saveData(
        token,
        storagePayloadForSync(gStorage),
      );
      if (err != null) {
        setState(() {
          _cloudSyncing = false;
          _cloudError = err;
        });
        return;
      }
    } else {
      setState(() => _cloudSyncing = false);
      final action = await showDialog<String>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              backgroundColor: C.bgCard,
              title: Text(
                '云端已有数据',
                style: TextStyle(color: C.t1, fontSize: 16),
              ),
              content: Text(
                '请选择同步方向。下载会先自动备份当前本地数据；上传会用本机数据覆盖云端。',
                style: TextStyle(color: C.t2, fontSize: 13),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('取消', style: TextStyle(color: C.t2)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'download'),
                  child: Text('下载覆盖本地', style: TextStyle(color: C.t3)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'upload'),
                  child: Text('上传覆盖云端', style: TextStyle(color: C.orange)),
                ),
              ],
            ),
      );
      if (action == null) return;
      setState(() {
        _cloudSyncing = true;
        _cloudError = null;
      });
      if (action == 'download') {
        await BackupService.backupCurrent(
          docDir: gDocDir,
          outDir: (await getTemporaryDirectory()).path,
        );
        gStorage.setFullData(remoteResult);
        await gStorage.save();
        await restoreLocalOnlySettings(gStorage, localSettings);
        await _restoreLocalAuth(token, email);
        AiService.setConfig(
          AiConfig.fromMap(
            gStorage.getSettings()['aiConfig'] as Map<String, dynamic>?,
          ),
        );
      } else {
        final err = await ApiService.saveData(
          token,
          storagePayloadForSync(gStorage),
        );
        if (err != null) {
          if (!mounted) return;
          setState(() {
            _cloudSyncing = false;
            _cloudError = err;
          });
          return;
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _cloudSyncing = false;
    });
    toast(context, '✅ 云端同步完成');
  }

  /// 退出登录
  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: C.bgCard,
            title: Text('退出登录', style: TextStyle(color: C.t1, fontSize: 16)),
            content: Text(
              '退出后数据将保留在本地，登录后可恢复同步。确定退出？',
              style: TextStyle(color: C.t2, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('取消', style: TextStyle(color: C.t2)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('退出', style: TextStyle(color: C.red)),
              ),
            ],
          ),
    );
    if (ok == true) {
      await AuthService.logout(gStorage);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }
}
