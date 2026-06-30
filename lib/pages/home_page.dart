import 'package:flutter/material.dart';
import '../components/index.dart';
import '../theme/colors.dart';
import '../utils/utils.dart';
import '../models.dart';
import '../main.dart';
import 'ai_report_page.dart';
import 'detail_page.dart';
import 'market_price_page.dart';
import 'scan_page.dart';
import 'sell_page.dart';
import 'stagnant_list_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  Stats stats = Stats();
  List<Device> stagnant = [];
  List<DailyStat> daily = [];
  Map<String, int> channelGmv = {};

  @override
  void initState() {
    super.initState();
    refresh();
  }

  void refresh() {
    setState(() {
      stats = gStorage.computeStats();
      stagnant = gStorage.getDevices().where((d) => d.isStagnant).toList();
      daily = gStorage.getDailyStats(days: 7);
      channelGmv = gStorage.getChannelGmv();
    });
  }

  @override
  Widget build(BuildContext context) {
    final margin = stats.gmv > 0 ? stats.grossProfit / stats.gmv * 100 : 0.0;
    return PageScaffold(
      title: const Text(
        '机掌柜',
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w900,
          color: C.t1,
        ),
      ),
      subtitle: Text(
        '今日 ${stats.orderCount} 单 · 在售 ${stats.inStockCount} 台 · ${fmtDate(DateTime.now())}',
        style: const TextStyle(
          fontSize: 12,
          color: C.t2,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeroPhoneCard(
            stats: stats,
            margin: margin,
            onSearch: _openHomeSearch,
            onTune: _openQuickPanel,
            onScan: () => _push(const ScanPage()),
            onPrice: () => _push(const MarketPricePage()),
            onSell: () => _push(const SellPage()),
          ),
          const SizedBox(height: 14),
          _AttentionStrip(
            stats: stats,
            stagnant: stagnant,
            onStagnantTap: () => _push(const StagnantListPage()),
          ),
          const SizedBox(height: 14),
          _TrendPanel(daily: daily),
          const SizedBox(height: 14),
          if (channelGmv.isNotEmpty) _ChannelPanel(channelGmv: channelGmv),
          const SizedBox(height: 14),
          _AiPanel(onTap: () => _push(const AiReportPage())),
        ],
      ),
    );
  }

  void _push(Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    ).then((_) => refresh());
  }

  Future<void> _openHomeSearch() async {
    final ctrl = TextEditingController();
    var query = '';
    final devices = gStorage.getDevices();
    await showAppFormSheet<void>(
      context: context,
      title: '搜索库存',
      subtitle: '按型号、容量、序列号快速定位设备',
      initialChildSize: 0.72,
      child: StatefulBuilder(
        builder: (context, setSheet) {
          final kw = query.trim().toLowerCase();
          final results =
              (kw.isEmpty
                      ? devices
                      : devices.where(
                        (d) =>
                            d.model.toLowerCase().contains(kw) ||
                            d.serial.toLowerCase().contains(kw) ||
                            d.capacity.toLowerCase().contains(kw) ||
                            d.color.toLowerCase().contains(kw),
                      ))
                  .take(12)
                  .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppFormField(
                controller: ctrl,
                label: '搜索型号、序列号、容量',
                icon: Icons.search_rounded,
                autofocus: true,
                onChanged: (v) => setSheet(() => query = v),
              ),
              const SizedBox(height: 14),
              if (results.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                    child: Text(
                      '没有匹配的库存设备',
                      style: TextStyle(
                        color: C.t2,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                )
              else
                ...results.map(
                  (d) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SearchResultTile(
                      device: d,
                      onTap: () {
                        Navigator.pop(context);
                        _push(DetailPage(device: d));
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
    ctrl.dispose();
  }

  Future<void> _openQuickPanel() async {
    await showAppFormSheet<void>(
      context: context,
      title: '经营快捷入口',
      subtitle: '把常用判断集中到这里',
      initialChildSize: 0.5,
      maxChildSize: 0.72,
      child: Column(
        children: [
          _QuickPanelAction(
            icon: Icons.auto_awesome_rounded,
            title: 'AI 经营日报',
            subtitle: '汇总库存、订单和利润',
            color: C.purple,
            onTap: () {
              Navigator.pop(context);
              _push(const AiReportPage());
            },
          ),
          _QuickPanelAction(
            icon: Icons.warning_amber_rounded,
            title: '滞销库存',
            subtitle: '查看超过周转阈值的设备',
            color: C.red,
            onTap: () {
              Navigator.pop(context);
              _push(const StagnantListPage());
            },
          ),
          _QuickPanelAction(
            icon: Icons.query_stats_rounded,
            title: '今日批发价',
            subtitle: '查行情和采购参考价',
            color: C.mint,
            onTap: () {
              Navigator.pop(context);
              _push(const MarketPricePage());
            },
          ),
        ],
      ),
    );
  }
}

class _HeroPhoneCard extends StatelessWidget {
  final Stats stats;
  final double margin;
  final VoidCallback onSearch;
  final VoidCallback onTune;
  final VoidCallback onScan;
  final VoidCallback onPrice;
  final VoidCallback onSell;

  const _HeroPhoneCard({
    required this.stats,
    required this.margin,
    required this.onSearch,
    required this.onTune,
    required this.onScan,
    required this.onPrice,
    required this.onSell,
  });

  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: EdgeInsets.zero,
    radius: 30,
    borderColor: Colors.white.withOpacity(0.16),
    color: const Color(0xEE080A10),
    child: Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: _HeroTexturePainter())),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _CircleTool(icon: Icons.search_rounded, onTap: onSearch),
                  const Spacer(),
                  Container(
                    width: 84,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  const Spacer(),
                  _CircleTool(icon: Icons.tune_rounded, onTap: onTune),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                '今日经营舱',
                style: TextStyle(
                  fontSize: 13,
                  color: C.t2,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: Text(
                  yuan(stats.gmv),
                  style: const TextStyle(
                    fontSize: 46,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    color: C.t1,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '今日毛利 ${yuan(stats.grossProfit)} · 毛利率 ${margin.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 12,
                  color: C.t2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder:
                    (context, box) => Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: (box.maxWidth - 10) / 2,
                          child: _MiniMetric(
                            label: '今日订单',
                            value: '${stats.orderCount}',
                            tint: C.purple,
                          ),
                        ),
                        SizedBox(
                          width: (box.maxWidth - 10) / 2,
                          child: _MiniMetric(
                            label: '在售设备',
                            value: '${stats.inStockCount}',
                            tint: C.cyan,
                          ),
                        ),
                        SizedBox(
                          width: box.maxWidth,
                          child: _MiniMetric(
                            label: '资金占用',
                            value: yuan(stats.capitalOccupied),
                            tint: C.mint,
                          ),
                        ),
                      ],
                    ),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, box) {
                  final half = (box.maxWidth - 10) / 2;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: half,
                        child: _PastelPill(
                          label: '扫码收货',
                          sub: '快速录入',
                          icon: Icons.qr_code_scanner_rounded,
                          color: C.cyan,
                          onTap: onScan,
                        ),
                      ),
                      SizedBox(
                        width: half,
                        child: _PastelPill(
                          label: '批发价',
                          sub: '行情参考',
                          icon: Icons.query_stats_rounded,
                          color: C.mint,
                          onTap: onPrice,
                        ),
                      ),
                      SizedBox(
                        width: box.maxWidth,
                        child: _PastelPill(
                          label: '售出设备',
                          sub: '生成订单并计算利润',
                          icon: Icons.point_of_sale_outlined,
                          color: C.purple,
                          onTap: onSell,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _HeroTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final topGlow =
        Paint()
          ..shader = RadialGradient(
            colors: [C.cyan.withOpacity(0.28), Colors.transparent],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.18, 0),
              radius: size.width * 0.95,
            ),
          );
    canvas.drawRect(Offset.zero & size, topGlow);

    final band =
        Paint()
          ..shader = LinearGradient(
            colors: [Colors.white.withOpacity(0.08), Colors.transparent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(Offset.zero & size);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          -20,
          size.height * 0.34,
          size.width + 40,
          size.height * 0.46,
        ),
        const Radius.circular(36),
      ),
      band,
    );

    final linePaint =
        Paint()
          ..color = Colors.white.withOpacity(0.055)
          ..strokeWidth = 1;
    for (double y = size.height * 0.68; y < size.height - 16; y += 16) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CircleTool extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleTool({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.10),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.10)),
        ),
        child: Icon(icon, color: C.t1, size: 21),
      ),
    ),
  );
}

class _SearchResultTile extends StatelessWidget {
  final Device device;
  final VoidCallback onTap;

  const _SearchResultTile({required this.device, required this.onTap});

  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: const EdgeInsets.all(13),
    radius: 20,
    color: const Color(0xE60C0F16),
    onTap: onTap,
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            color: C.cyan,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.tablet_mac_rounded,
            color: Colors.black,
            size: 21,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${device.model} ${device.capacity}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: C.t1,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${device.condition} · ${device.color} · ${device.serial.isEmpty ? "无序列号" : device.serial}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: C.t2,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: C.t3),
      ],
    ),
  );
}

class _QuickPanelAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickPanelAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: GlassPanel(
      padding: const EdgeInsets.all(13),
      radius: 20,
      color: color.withOpacity(0.12),
      borderColor: color.withOpacity(0.22),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.black, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: C.t1,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: C.t2,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: C.t2),
        ],
      ),
    ),
  );
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color tint;

  const _MiniMetric({
    required this.label,
    required this.value,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.07),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withOpacity(0.08)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: C.t3,
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
              fontSize: 18,
              color: tint,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),
  );
}

class _PastelPill extends StatelessWidget {
  final String label;
  final String sub;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _PastelPill({
    required this.label,
    required this.sub,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 11, 10, 11),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.black.withOpacity(0.50),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 19),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _AttentionStrip extends StatelessWidget {
  final Stats stats;
  final List<Device> stagnant;
  final VoidCallback onStagnantTap;

  const _AttentionStrip({
    required this.stats,
    required this.stagnant,
    required this.onStagnantTap,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _AlertTile(
          icon: Icons.inventory_2_outlined,
          title: '待质检',
          value: '${stats.pendingQcCount}',
          color: C.cyan,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _AlertTile(
          icon: Icons.local_shipping_outlined,
          title: '待发货',
          value: '${stats.pendingCount}',
          color: C.mint,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _AlertTile(
          icon: Icons.warning_amber_rounded,
          title: '滞销',
          value: '${stagnant.length}',
          color: C.red,
          onTap: onStagnantTap,
        ),
      ),
    ],
  );
}

class _AlertTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _AlertTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: const EdgeInsets.all(12),
    radius: 18,
    onTap: onTap,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 19),
        const SizedBox(height: 10),
        Text(
          value,
          style: const TextStyle(
            fontSize: 21,
            color: C.t1,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            color: C.t2,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _TrendPanel extends StatelessWidget {
  final List<DailyStat> daily;

  const _TrendPanel({required this.daily});

  @override
  Widget build(BuildContext context) {
    final data = daily.map((d) => d.profit.toDouble()).toList();
    final labels =
        daily
            .map((d) => d.date.length > 5 ? d.date.substring(5) : d.date)
            .toList();
    final total = daily.fold<int>(0, (sum, d) => sum + d.profit);
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.07),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.timeline_rounded,
                  color: C.cyan,
                  size: 16,
                ),
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  '毛利时间线',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: C.t1,
                  ),
                ),
              ),
              StatusChip('7日 ${yuan(total)}', C.cyan),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 150,
            child: CustomPaint(
              painter: LineChartPainter(data, labels, lineColor: C.cyan),
              size: Size.infinite,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelPanel extends StatelessWidget {
  final Map<String, int> channelGmv;

  const _ChannelPanel({required this.channelGmv});

  @override
  Widget build(BuildContext context) {
    final total = channelGmv.values.fold<int>(0, (a, b) => a + b);
    final colors = [C.cyan, C.purple, C.mint, C.orange, C.blue];
    final entries = channelGmv.entries.toList();
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('渠道占比', icon: Icons.donut_large_rounded),
          const SizedBox(height: 4),
          ...entries.asMap().entries.map((e) {
            final color = colors[e.key % colors.length];
            final value = e.value.value;
            final pct = total == 0 ? 0.0 : value / total;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.storefront_outlined,
                      color: color,
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                e.value.key,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: C.t1,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Text(
                              '${(pct * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(
                                color: C.t2,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 7,
                            backgroundColor: Colors.white.withOpacity(0.07),
                            valueColor: AlwaysStoppedAnimation(color),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _AiPanel extends StatelessWidget {
  final VoidCallback onTap;

  const _AiPanel({required this.onTap});

  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: const EdgeInsets.all(16),
    radius: 22,
    color: C.purple.withOpacity(0.16),
    borderColor: C.purple.withOpacity(0.24),
    onTap: onTap,
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: C.purple,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: Colors.black,
            size: 23,
          ),
        ),
        const SizedBox(width: 13),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI 经营日报',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: C.t1,
                ),
              ),
              SizedBox(height: 3),
              Text(
                '汇总库存、订单和利润，生成今日判断',
                style: TextStyle(
                  fontSize: 12,
                  color: C.t2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: C.t2),
      ],
    ),
  );
}
