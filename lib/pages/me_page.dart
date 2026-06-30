import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/colors.dart';
import '../components/index.dart';
import '../utils/utils.dart';
import '../storage.dart';
import '../models.dart';
import '../main.dart';
import '../update_service.dart';
import '../backup_service.dart';
import 'scan_page.dart';
import 'sell_page.dart';
import 'ai_report_page.dart';
import 'market_price_page.dart';
import 'purchase_decision_page.dart';
import 'agent_manager_page.dart';
import 'finance_page.dart';
import 'customer_page.dart';
import 'repair_page.dart';
import 'analytics_page.dart';
import 'backup_page.dart';
import 'webdav_config_page.dart';
import 'ai_config_page.dart';
import 'settings_page.dart';
import 'report_page.dart';

class MePage extends StatefulWidget {
  const MePage({Key? key}) : super(key: key);
  @override
  State<MePage> createState() => _MePageState();
}

class _MePageState extends State<MePage> {
  bool _backupReminded = false;
  File? _avatarImage;
  String _avatarEmoji = '📱';
  List<Color> _avatarGradientColors = [C.primary, C.purple];
  String _displayName = '老板 · 老张';
  String _shopName = '张记二手iPad';
  final ImagePicker _picker = ImagePicker();

  LinearGradient get _avatarGradient => LinearGradient(colors: _avatarGradientColors);

  void _refresh() => setState(() {});

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _checkBackupReminder();
  }

  void _loadProfile() {
    final settings = gStorage.getSettings();
    _displayName = (settings['userDisplayName'] as String?) ?? '老板 · 老张';
    _shopName = (settings['userShopName'] as String?) ?? '张记二手iPad';
    _avatarEmoji = (settings['userAvatarEmoji'] as String?) ?? '📱';
    final gradientStr = settings['userAvatarGradient'] as String?;
    if (gradientStr != null) {
      final parts = gradientStr.split(',');
      if (parts.length == 2) {
        _avatarGradientColors = [
          Color(int.parse(parts[0])),
          Color(int.parse(parts[1])),
        ];
      }
    }
    final avatarPath = settings['userAvatarPath'] as String?;
    if (avatarPath != null && avatarPath.isNotEmpty) {
      final f = File(avatarPath);
      if (f.existsSync()) _avatarImage = f;
    }
  }

  void _saveProfile() {
    final settings = gStorage.getSettings();
    settings['userDisplayName'] = _displayName;
    settings['userShopName'] = _shopName;
    settings['userAvatarEmoji'] = _avatarEmoji;
    settings['userAvatarGradient'] =
        '${_avatarGradientColors[0].value},${_avatarGradientColors[1].value}';
    settings['userAvatarPath'] = _avatarImage?.path ?? '';
    gStorage.saveSettings(settings);
  }

  void _editProfile() {
    showModalBottomSheet(
      context: context,
      backgroundColor: C.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(C.radiusXl)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: C.line, borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text('更换头像',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: C.t1),
              ),
              const SizedBox(height: 16),
              _avatarOption(Icons.camera_alt, C.brand2, '拍照', () async {
                Navigator.pop(ctx);
                await _pickImage(ImageSource.camera);
              }),
              _avatarOption(Icons.photo_library, C.brand2, '从相册选择', () async {
                Navigator.pop(ctx);
                await _pickImage(ImageSource.gallery);
              }),
              Divider(color: C.line, height: 24),
              _avatarOption(Icons.emoji_emotions, C.orange, '随机头像表情', () {
                Navigator.pop(ctx);
                _randomEmojiAvatar();
              }),
              _avatarOption(Icons.palette, C.purple, '随机渐变色头像', () {
                Navigator.pop(ctx);
                _randomGradientAvatar();
              }),
              if (_avatarImage != null) ...[
                Divider(color: C.line, height: 24),
                _avatarOption(Icons.delete, C.red, '清除自定义头像', () {
                  Navigator.pop(ctx);
                  _clearAvatar();
                }, destructive: true),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarOption(IconData icon, Color color, String label, VoidCallback onTap, {bool destructive = false}) =>
      ListTile(
        leading: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        title: Text(label, style: TextStyle(color: destructive ? C.red : C.t1, fontWeight: FontWeight.w600)),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(C.radiusMd)),
      );

  Future<void> _pickImage(ImageSource source) async {
    try {
      final xfile = await _picker.pickImage(source: source, maxWidth: 256, maxHeight: 256);
      if (xfile != null) {
        final dest = '$gDocDir/avatar.jpg';
        await File(xfile.path).copy(dest);
        setState(() {
          _avatarImage = File(dest);
          _avatarEmoji = '';
        });
        _saveProfile();
      }
    } catch (e) {
      toast(context, '选择图片失败：$e');
    }
  }

  void _randomEmojiAvatar() {
    final emojis = ['📱', '👤', '😎', '🦸', '🧑‍💼', '👨‍💻', '🫅', '🧙', '🎅', '🤴', '👸', '🦊', '🐯', '🦁'];
    setState(() {
      _avatarEmoji = emojis[DateTime.now().millisecondsSinceEpoch % emojis.length];
      _avatarImage = null;
    });
    _saveProfile();
  }

  void _randomGradientAvatar() {
    final gradients = [
      [C.primary, C.purple],
      [C.blue, C.teal],
      [C.pink, C.purple],
      [C.orange, const Color(0xFFF97316)],
      [C.green, const Color(0xFF059669)],
      [const Color(0xFFEC4899), const Color(0xFFF97316)],
    ];
    setState(() {
      _avatarGradientColors = gradients[DateTime.now().millisecondsSinceEpoch % gradients.length];
      _avatarImage = null;
    });
    _saveProfile();
  }

  void _clearAvatar() {
    setState(() {
      _avatarImage = null;
      _avatarEmoji = '📱';
    });
    _saveProfile();
  }

  void _editName() {
    final nameCtrl = TextEditingController(text: _displayName);
    final shopCtrl = TextEditingController(text: _shopName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(C.radiusLg)),
        title: Text('编辑资料', style: TextStyle(color: C.t1, fontSize: 16, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: TextStyle(color: C.t1),
              decoration: InputDecoration(
                labelText: '昵称', labelStyle: TextStyle(color: C.t2),
                filled: true, fillColor: C.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(C.radiusSm),
                  borderSide: BorderSide(color: C.line),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: shopCtrl,
              style: TextStyle(color: C.t1),
              decoration: InputDecoration(
                labelText: '店铺名', labelStyle: TextStyle(color: C.t2),
                filled: true, fillColor: C.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(C.radiusSm),
                  borderSide: BorderSide(color: C.line),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: C.t2)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _displayName = nameCtrl.text;
                _shopName = shopCtrl.text;
              });
              _saveProfile();
              toast(context, '已保存');
            },
            style: TextButton.styleFrom(foregroundColor: C.primary),
            child: const Text('保存', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _checkBackupReminder() {
    if (!_backupReminded && BackupService.shouldRemindBackup(gStorage)) {
      _backupReminded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: C.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(C.radiusLg)),
            title: Text('备份提醒', style: TextStyle(color: C.t1, fontSize: 16, fontWeight: FontWeight.w800)),
            content: Text(
              BackupService.lastBackupTime(gStorage) == null
                  ? '您还没有备份过数据。建议立即导出备份，以防换机/丢失导致数据丢失。'
                  : '已超过7天未备份，建议导出最新备份。',
              style: TextStyle(color: C.t2, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('下次再说', style: TextStyle(color: C.t2)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const BackupPage()),
                  ).then((_) => _refresh());
                },
                style: TextButton.styleFrom(foregroundColor: C.primary),
                child: const Text('去备份', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = gStorage.computeStats();
    final orders = gStorage.getOrders();
    return PageScaffold(
      child: Column(
        children: [
          // ─── 个人资料卡片 ───
          Padding(
            padding: const EdgeInsets.fromLTRB(C.sp16, 8, C.sp16, C.sp16),
            child: Container(
              padding: const EdgeInsets.all(C.sp16),
              decoration: BoxDecoration(
                color: C.card,
                borderRadius: BorderRadius.circular(C.radiusLg),
                border: Border.all(color: C.line, width: 0.8),
                boxShadow: C.cardShadow,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _editProfile,
                    child: Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        gradient: _avatarGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: _avatarGradientColors[0].withOpacity(0.3),
                            blurRadius: 8, offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: _avatarImage != null
                            ? Image.file(_avatarImage!, fit: BoxFit.cover, width: 56, height: 56)
                            : Center(child: Text(_avatarEmoji, style: const TextStyle(fontSize: 26))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: GestureDetector(
                      onTap: _editName,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _displayName,
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: C.t1),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Text(
                                _shopName,
                                style: TextStyle(fontSize: 12, color: C.t2, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: C.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'v${UpdateService.currentVersion}',
                                  style: TextStyle(
                                    fontSize: 9, color: C.primary, fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _editName,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: C.primary.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.edit_outlined, color: C.primary, size: 17),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── 快速统计 ───
          Padding(
            padding: const EdgeInsets.fromLTRB(C.sp16, 0, C.sp16, C.sp16),
            child: Row(
              children: [
                Expanded(child: _statCard(yuan(s.grossProfit), '今日毛利', C.green)),
                const SizedBox(width: 8),
                Expanded(child: _statCard('${s.inStockCount}', '在售台数', C.primary)),
                const SizedBox(width: 8),
                Expanded(child: _statCard('${orders.length}', '累计订单', C.purple)),
              ],
            ),
          ),

          // ─── 功能菜单（分组） ───
          _MenuGroup(
            title: '经营分析',
            icon: Icons.insights,
            items: [
              _MenuItem(Icons.analytics_outlined, 'KPI 看板', C.primary,
                () => _nav(const AnalyticsPage())),
              _MenuItem(Icons.bar_chart_rounded, '统计报表', C.purple,
                () => _nav(const ReportPage())),
              _MenuItem(Icons.auto_awesome_rounded, 'AI 经营日报', C.blue,
                () => _nav(const AiReportPage())),
              _MenuItem(Icons.query_stats_rounded, '今日批发价', C.teal,
                () => _nav(const MarketPricePage())),
            ],
          ),

          _MenuGroup(
            title: '业务操作',
            icon: Icons.bolt,
            items: [
              _MenuItem(Icons.rule_rounded, '采购决策', C.orange,
                () => _nav(const PurchaseDecisionPage())),
              _MenuItem(Icons.qr_code_scanner_rounded, '扫码收货', C.primary,
                () => _nav(const ScanPage())),
              _MenuItem(Icons.point_of_sale_outlined, '售出设备', C.green,
                () => _nav(const SellPage())),
            ],
          ),

          _MenuGroup(
            title: '管理中心',
            icon: Icons.hub,
            items: [
              _MenuItem(Icons.groups_2_outlined, '代理管理', C.pink,
                () => _nav(const AgentManagerPage())),
              _MenuItem(Icons.account_balance_wallet_outlined, '财务中心', C.green,
                () => _nav(const FinancePage())),
              _MenuItem(Icons.contacts_outlined, '客户管理', C.orange,
                () => _nav(const CustomerPage())),
              _MenuItem(Icons.build_circle_outlined, '翻新维修', C.brand2,
                () => _nav(const RepairPage())),
            ],
          ),

          _MenuGroup(
            title: '系统与数据',
            icon: Icons.settings,
            items: [
              _MenuItem(Icons.archive_outlined, '备份与恢复', C.green,
                () => _nav(const BackupPage())),
              _MenuItem(Icons.cloud_sync_outlined, 'WebDAV 云同步', C.blue,
                () => _nav(const WebDavConfigPage())),
              _MenuItem(Icons.memory_rounded, 'AI 配置', C.purple,
                () => _nav(const AiConfigPage())),
              _MenuItem(Icons.settings_outlined, '设置', C.t2,
                () => _nav(SettingsPage()), last: true),
            ],
          ),

          const SizedBox(height: 24),
          Text(
            '机掌柜 v${UpdateService.currentVersion}\n数据本地持久化 · AI可配置 · WebDAV云同步',
            textAlign: TextAlign.center,
            style: TextStyle(color: C.t3, fontSize: 11, height: 1.6, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _nav(Widget page) {
    Navigator.push(
      context, MaterialPageRoute(builder: (_) => page),
    ).then((_) => _refresh());
  }

  Widget _statCard(String value, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(
      color: C.card,
      borderRadius: BorderRadius.circular(C.radiusMd),
      border: Border.all(color: C.line, width: 0.8),
      boxShadow: C.elevationSm,
    ),
    child: Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: C.t2, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

/// 菜单分组
class _MenuGroup extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<_MenuItem> items;

  const _MenuGroup({
    required this.title,
    required this.icon,
    required this.items,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(C.sp16, 0, C.sp16, C.sp12),
    decoration: BoxDecoration(
      color: C.card,
      borderRadius: BorderRadius.circular(C.radiusLg),
      border: Border.all(color: C.line, width: 0.8),
      boxShadow: C.cardShadow,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 分组标题
        Padding(
          padding: const EdgeInsets.fromLTRB(C.sp16, C.sp14, C.sp16, C.sp8),
          child: Row(
            children: [
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  color: C.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, color: C.primary, size: 14),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: C.t2,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        // 菜单项
        ...items.asMap().entries.map((e) {
          final item = e.value;
          final isLast = e.key == items.length - 1;
          return _MenuRow(item: item, isLast: isLast);
        }),
      ],
    ),
  );
}

/// 菜单项行
class _MenuRow extends StatelessWidget {
  final _MenuItem item;
  final bool isLast;

  const _MenuRow({required this.item, required this.isLast});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: item.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: C.sp16, vertical: 13),
        decoration: BoxDecoration(
          border: isLast ? null : Border(
            bottom: BorderSide(color: C.divider, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.icon, color: item.color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w600, color: C.t1,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: C.t3, size: 18),
          ],
        ),
      ),
    ),
  );
}

class _MenuItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool last;

  const _MenuItem(this.icon, this.label, this.color, this.onTap, {this.last = false});
}
