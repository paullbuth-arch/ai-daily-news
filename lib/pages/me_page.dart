import 'package:flutter/material.dart';
import '../backup_service.dart';
import '../components/index.dart';
import '../main.dart';
import '../theme/colors.dart';
import '../update_service.dart';
import '../utils/utils.dart';
import 'agent_manager_page.dart';
import 'ai_config_page.dart';
import 'ai_report_page.dart';
import 'analytics_page.dart';
import 'backup_page.dart';
import 'customer_page.dart';
import 'finance_page.dart';
import 'market_price_page.dart';
import 'purchase_decision_page.dart';
import 'repair_page.dart';
import 'report_page.dart';
import 'scan_page.dart';
import 'sell_page.dart';
import 'settings_page.dart';
import 'webdav_config_page.dart';

class MePage extends StatefulWidget {
  const MePage({Key? key}) : super(key: key);

  @override
  State<MePage> createState() => _MePageState();
}

class _MePageState extends State<MePage> {
  bool _backupReminded = false;

  @override
  void initState() {
    super.initState();
    _checkBackupReminder();
  }

  void _refresh() => setState(() {});

  void _checkBackupReminder() {
    if (_backupReminded || !BackupService.shouldRemindBackup(gStorage)) return;
    _backupReminded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder:
            (ctx) => AlertDialog(
              backgroundColor: C.bgCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(C.radiusLg),
              ),
              title: const Text(
                '备份提醒',
                style: TextStyle(
                  color: C.t1,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              content: Text(
                BackupService.lastBackupTime(gStorage) == null
                    ? '还没有备份过数据，建议导出一份最新备份。'
                    : '已超过 7 天未备份，建议导出最新备份。',
                style: const TextStyle(color: C.t2, fontSize: 13),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('稍后'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _nav(const BackupPage());
                  },
                  child: const Text(
                    '去备份',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final stats = gStorage.computeStats();
    final orders = gStorage.getOrders();
    final settings = gStorage.getSettings();
    final displayName = (settings['userDisplayName'] as String?) ?? '老板';
    final shopName = (settings['userShopName'] as String?) ?? '二手 iPad 工作台';

    return PageScaffold(
      title: const Text(
        '工作区',
        style: TextStyle(
          fontSize: 25,
          fontWeight: FontWeight.w900,
          color: C.t1,
        ),
      ),
      subtitle: Text(
        '货脉 v${UpdateService.currentVersion}',
        style: const TextStyle(
          fontSize: 12,
          color: C.t2,
          fontWeight: FontWeight.w700,
        ),
      ),
      action: RoundIconButton(
        icon: Icons.settings_outlined,
        color: C.t1,
        onTap: () => _nav(SettingsPage()),
      ),
      child: Column(
        children: [
          GlassPanel(
            padding: const EdgeInsets.all(18),
            radius: 28,
            color: const Color(0xEA0A0D14),
            child: Row(
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    gradient: C.metricGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: C.cyan.withOpacity(0.20),
                        blurRadius: 22,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: Colors.black,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: C.t1,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        shopName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: C.t2,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusChip('PRO', C.cyan),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ProfileStat('今日毛利', yuan(stats.grossProfit), C.mint),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ProfileStat('在售', '${stats.inStockCount}', C.cyan),
              ),
              const SizedBox(width: 10),
              Expanded(child: _ProfileStat('订单', '${orders.length}', C.purple)),
            ],
          ),
          const SizedBox(height: 14),
          _MenuGroup(
            title: '经营分析',
            icon: Icons.insights_rounded,
            items: [
              _MenuItem(
                Icons.analytics_outlined,
                'KPI 看板',
                C.cyan,
                () => _nav(const AnalyticsPage()),
              ),
              _MenuItem(
                Icons.bar_chart_rounded,
                '统计报表',
                C.purple,
                () => _nav(const ReportPage()),
              ),
              _MenuItem(
                Icons.auto_awesome_rounded,
                'AI 经营日报',
                C.blue,
                () => _nav(const AiReportPage()),
              ),
              _MenuItem(
                Icons.query_stats_rounded,
                '今日批发价',
                C.mint,
                () => _nav(const MarketPricePage()),
              ),
            ],
          ),
          _MenuGroup(
            title: '业务操作',
            icon: Icons.bolt_rounded,
            items: [
              _MenuItem(
                Icons.rule_rounded,
                '采购决策',
                C.orange,
                () => _nav(const PurchaseDecisionPage()),
              ),
              _MenuItem(
                Icons.qr_code_scanner_rounded,
                '扫码收货',
                C.cyan,
                () => _nav(const ScanPage()),
              ),
              _MenuItem(
                Icons.point_of_sale_outlined,
                '售出设备',
                C.mint,
                () => _nav(const SellPage()),
              ),
            ],
          ),
          _MenuGroup(
            title: '管理中心',
            icon: Icons.hub_rounded,
            items: [
              _MenuItem(
                Icons.groups_2_outlined,
                '代理管理',
                C.purple,
                () => _nav(const AgentManagerPage()),
              ),
              _MenuItem(
                Icons.account_balance_wallet_outlined,
                '财务中心',
                C.mint,
                () => _nav(const FinancePage()),
              ),
              _MenuItem(
                Icons.contacts_outlined,
                '客户管理',
                C.orange,
                () => _nav(const CustomerPage()),
              ),
              _MenuItem(
                Icons.build_circle_outlined,
                '翻新维修',
                C.t2,
                () => _nav(const RepairPage()),
              ),
            ],
          ),
          _MenuGroup(
            title: '系统与数据',
            icon: Icons.settings_rounded,
            items: [
              _MenuItem(
                Icons.archive_outlined,
                '备份与恢复',
                C.mint,
                () => _nav(const BackupPage()),
              ),
              _MenuItem(
                Icons.cloud_sync_outlined,
                'WebDAV 云同步',
                C.blue,
                () => _nav(const WebDavConfigPage()),
              ),
              _MenuItem(
                Icons.memory_rounded,
                'AI 配置',
                C.purple,
                () => _nav(const AiConfigPage()),
              ),
              _MenuItem(
                Icons.settings_outlined,
                '设置',
                C.t2,
                () => _nav(SettingsPage()),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '数据本地持久化 · AI 可配置 · WebDAV 云同步',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: C.t3,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  void _nav(Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    ).then((_) => _refresh());
  }
}

class _ProfileStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ProfileStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
    radius: 18,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: C.t2,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        FittedBox(
          alignment: Alignment.centerLeft,
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),
  );
}

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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: GlassPanel(
      padding: const EdgeInsets.all(14),
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: C.cyan.withOpacity(0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: C.cyan, size: 17),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: C.t1,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map((item) => _MenuRow(item: item)),
        ],
      ),
    ),
  );
}

class _MenuRow extends StatelessWidget {
  final _MenuItem item;

  const _MenuRow({required this.item});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(item.icon, color: item.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.label,
                style: const TextStyle(
                  color: C.t1,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: C.t3, size: 20),
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

  const _MenuItem(this.icon, this.label, this.color, this.onTap);
}
