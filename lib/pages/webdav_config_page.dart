import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../theme/colors.dart';
import '../components/index.dart';
import '../utils/utils.dart';
import '../main.dart';
import '../webdav_service.dart';
import '../ai_service.dart';
import '../auth_service.dart';
import '../backup_service.dart';

class WebDavConfigPage extends StatefulWidget {
  const WebDavConfigPage({Key? key}) : super(key: key);
  @override
  State<WebDavConfigPage> createState() => _WebDavConfigPageState();
}

class _WebDavConfigPageState extends State<WebDavConfigPage> {
  late TextEditingController _urlCtrl;
  late TextEditingController _userCtrl;
  late TextEditingController _passCtrl;
  bool _obscurePass = true;
  bool _testing = false;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    final c = WebDavService.getConfig(gStorage);
    _urlCtrl = TextEditingController(text: c.url);
    _userCtrl = TextEditingController(text: c.username);
    _passCtrl = TextEditingController(text: c.password);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lastSync = WebDavService.lastSyncTime(gStorage);
    return appScaffold(
      context,
      'WebDAV 云同步',
      ListView(
        padding: const EdgeInsets.all(14),
        children: [
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('服务器地址', style: TextStyle(fontSize: 13, color: C.t2)),
                const SizedBox(height: 8),
                AppFormField(
                  controller: _urlCtrl,
                  label: '服务器地址',
                  hint: 'https://dav.jianguoyun.com/dav/',
                  icon: Icons.dns_outlined,
                ),
                const SizedBox(height: 12),
                Text('账号', style: TextStyle(fontSize: 13, color: C.t2)),
                const SizedBox(height: 8),
                AppFormField(
                  controller: _userCtrl,
                  label: '账号',
                  hint: '坚果云账号或邮箱',
                  icon: Icons.person_outline_rounded,
                ),
                const SizedBox(height: 12),
                Text('密码（应用密码）', style: TextStyle(fontSize: 13, color: C.t2)),
                const SizedBox(height: 8),
                AppFormField(
                  controller: _passCtrl,
                  label: '应用密码',
                  hint: '坚果云需用应用密码',
                  icon: Icons.lock_outline_rounded,
                  obscureText: _obscurePass,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePass ? Icons.visibility_off : Icons.visibility,
                      color: C.t3,
                      size: 18,
                    ),
                    onPressed:
                        () => setState(() => _obscurePass = !_obscurePass),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_testing)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(color: C.t3),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _testConnection,
                style: OutlinedButton.styleFrom(
                  foregroundColor: C.t3,
                  side: const BorderSide(color: C.t3),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                child: const Text(
                  '测试连接',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          const SizedBox(height: 10),
          if (_syncing)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(color: C.t3),
              ),
            )
          else
            primaryBtn('保存配置', _save),
          const SizedBox(height: 16),
          // 同步操作区
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '☁️ 云同步',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: C.t1,
                  ),
                ),
                const SizedBox(height: 8),
                if (lastSync != null)
                  Text(
                    '上次同步：${lastSync.month}/${lastSync.day} ${lastSync.hour.toString().padLeft(2, '0')}:${lastSync.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(fontSize: 11, color: C.t3),
                  )
                else
                  Text('从未同步', style: TextStyle(fontSize: 11, color: C.t3)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _syncing ? null : _upload,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: C.cyan,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          '⬆️ 上传',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _syncing ? null : _download,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: C.bgCard,
                          foregroundColor: C.t1,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                          side: BorderSide(color: C.border),
                        ),
                        child: Text('⬇️ 下载', style: TextStyle(fontSize: 13)),
                      ),
                    ),
                  ],
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
                  '• 坚果云：地址填 https://dav.jianguoyun.com/dav/\n• 密码需用「应用密码」（坚果云官网→安全选项→添加应用）\n• 免费版每月1GB上传流量，数据才几KB，完全够用\n• 上传=把本地数据推到云端\n• 下载=从云端拉取覆盖本地（会自动备份当前数据）',
                  style: TextStyle(fontSize: 11, color: C.t2, height: 1.8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  WebDavConfig _buildConfig() => WebDavConfig(
    url: _urlCtrl.text.trim(),
    username: _userCtrl.text.trim(),
    password: _passCtrl.text.trim(),
  );

  void _testConnection() async {
    final cfg = _buildConfig();
    if (!cfg.isValid) {
      toast(context, '请填写完整配置');
      return;
    }
    setState(() => _testing = true);
    final err = await WebDavService.testConnection(cfg);
    if (!mounted) return;
    setState(() => _testing = false);
    toast(context, err == null ? '✅ 连接成功' : '❌ $err');
  }

  void _save() async {
    final cfg = _buildConfig();
    if (!cfg.isValid) {
      toast(context, '请填写完整配置');
      return;
    }
    await WebDavService.saveConfig(gStorage, cfg);
    if (!mounted) return;
    toast(context, 'WebDAV配置已保存');
    Navigator.pop(context);
  }

  void _upload() async {
    final cfg = WebDavService.getConfig(gStorage);
    if (!cfg.isValid) {
      toast(context, '请先保存配置');
      return;
    }
    setState(() => _syncing = true);
    final tmp = File(
      '${(await getTemporaryDirectory()).path}/ipad_boss_data_sync.json',
    );
    await tmp.writeAsString(json.encode(storagePayloadForSync(gStorage)));
    final err = await WebDavService.upload(config: cfg, dataPath: tmp.path);
    if (err == null) await WebDavService.uploadTimestamp(config: cfg);
    await WebDavService.markSynced(gStorage);
    if (!mounted) return;
    setState(() => _syncing = false);
    toast(context, err == null ? '⬆️ 已上传到云端' : '❌ $err');
  }

  void _download() async {
    final cfg = WebDavService.getConfig(gStorage);
    if (!cfg.isValid) {
      toast(context, '请先保存配置');
      return;
    }
    // 二次确认
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: C.bgCard,
            title: Text('下载确认', style: TextStyle(color: C.t1, fontSize: 16)),
            content: Text(
              '从云端下载数据会覆盖当前本地数据。系统会自动备份当前数据。',
              style: TextStyle(color: C.t2, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('取消', style: TextStyle(color: C.t2)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('下载', style: TextStyle(color: C.t3)),
              ),
            ],
          ),
    );
    if (ok != true) return;
    setState(() => _syncing = true);
    final token = AuthService.token;
    final email = AuthService.email;
    final localSettings = snapshotLocalOnlySettings(gStorage);
    // 先备份当前数据
    await BackupService.backupCurrent(
      docDir: gDocDir,
      outDir: (await getTemporaryDirectory()).path,
    );
    final dlResult = await WebDavService.download(config: cfg);
    final bytes = dlResult.data;
    final err = dlResult.errMsg;
    if (bytes != null) {
      await File('$gDocDir/ipad_boss_data.json').writeAsBytes(bytes);
      await gStorage.load();
      await restoreLocalOnlySettings(gStorage, localSettings);
      if (token != null && token.isNotEmpty) {
        await AuthService.login(gStorage, token, email ?? '');
      }
      // 同步 AI 配置
      AiService.setConfig(
        AiConfig.fromMap(
          gStorage.getSettings()['aiConfig'] as Map<String, dynamic>?,
        ),
      );
      await WebDavService.markSynced(gStorage);
    }
    if (!mounted) return;
    setState(() => _syncing = false);
    if (err != null) {
      toast(context, '❌ $err');
    } else {
      toast(context, '⬇️ 已从云端恢复');
      setState(() {});
    }
  }
}
