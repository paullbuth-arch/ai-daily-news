import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../components/index.dart';
import '../utils/utils.dart';
import '../storage.dart';
import '../models.dart';
import '../main.dart';
import 'scan_page.dart';
import 'stagnant_list_page.dart';
import 'ai_report_page.dart';
import 'sell_page.dart';
import 'market_price_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);
  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  Stats? stats;
  List<Device> stagnant = [];
  List<DailyStat> daily = [];
  Map<String, int> channelGmv = {};
  int yesterdayProfit = 0;
  int yesterdayOrders = 0;
  int chartMode = 0; // 0=近7天, 1=当月, 2=近12月

  @override
  void initState() {
    super.initState();
    refresh();
  }

  void refresh() {
    final s = gStorage.computeStats();
    final stg = gStorage.getDevices().where((d) => d.isStagnant).toList();
    final dl = gStorage.getDailyStats(days: 7);
    final cg = gStorage.getChannelGmv();
    final yp = gStorage.getYesterdayProfit();
    final yo = gStorage.getYesterdayOrderCount();
    setState(() {
      stats = s;
      stagnant = stg;
      daily = dl;
      channelGmv = cg;
      yesterdayProfit = yp;
      yesterdayOrders = yo;
    });
  }

  _ChartData _chartData() {
    if (chartMode == 0) {
      final profit = daily.map((d) => d.profit.toDouble()).toList();
      final labels = daily.map((d) => d.date.substring(5)).toList();
      return _ChartData(
        profit, labels, '近7天毛利趋势',
        daily.fold(0, (a, d) => a + d.profit),
      );
    }
    if (chartMode == 1) {
      final now = DateTime.now();
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      final orders = gStorage.getOrders();
      final ms = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final profit = <double>[];
      final labels = <String>[];
      for (int i = 1; i <= daysInMonth; i++) {
        final ds = '$ms-${i.toString().padLeft(2, '0')}';
        int p = 0;
        for (final o in orders) {
          if (o.createdAt.startsWith(ds)) p += o.profit;
        }
        profit.add(p.toDouble());
        labels.add(i.toString());
      }
      final total = profit.fold<double>(0.0, (a, b) => a + b).toInt();
      return _ChartData(profit, labels, '当月每日毛利', total);
    }
    final monthly = gStorage.getMonthlyStats(months: 12);
    final profit = monthly.map((d) => d.profit.toDouble()).toList();
    final labels = monthly.map((d) => d.date.substring(5)).toList();
    final total = monthly.fold<int>(0, (a, d) => a + d.profit);
    return _ChartData(profit, labels, '近12月毛利趋势', total);
  }

  @override
  Widget build(BuildContext context) {
    final s = stats ?? Stats();
    final chart = _chartData();
    final yesterdayGmv = gStorage.getYesterdayGmv();
    final profitDiff = s.grossProfit - yesterdayProfit;
    final orderDiff = s.orderCount - yesterdayOrders;
    final gmvDiffPct =
        yesterdayGmv > 0 ? ((s.gmv - yesterdayGmv) / yesterdayGmv * 100) : null;
    final margin = s.gmv > 0 ? (s.grossProfit / s.gmv * 100) : 0.0;

    return PageScaffold(
      title: Text(
        '经营看板',
        style: TextStyle(
          fontSize: 24, fontWeight: FontWeight.w900, color: C.t1, letterSpacing: 0.5,
        ),
      ),
      subtitle: Text(
        gStorageReady
            ? '机掌柜 · 在售${s.inStockCount}台 · 今日${s.orderCount}单'
            : '加载中...',
        style: TextStyle(fontSize: 12, color: C.t2, fontWeight: FontWeight.w500),
      ),
      action: _refreshButton(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── 英雄指标卡（GMV） ───
          _HeroMetricCard(
            gmv: s.gmv,
            gmvPct: gmvDiffPct,
            profit: s.grossProfit,
            profitDiff: profitDiff,
            orders: s.orderCount,
            orderDiff: orderDiff,
            margin: margin,
          ),

          // ─── 状态指标网格 ───
          _StatusMetricsRow(stats: s),

          // ─── 趋势图表 ───
          _ChartSection(
            chart: chart,
            chartMode: chartMode,
            onModeChange: (m) => setState(() => chartMode = m),
          ),

          // ─── 资金 & 滞销 ───
          _AlertsRow(stats: s, onRefresh: refresh),

          // ─── 渠道占比 ───
          if (channelGmv.isNotEmpty) _ChannelSection(channelGmv: channelGmv),

          // ─── AI 经营日报 ───
          _AiReportEntry(
            onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const AiReportPage()),
            ),
          ),

          // ─── 滞销预警列表 ───
          if (stagnant.isNotEmpty)
            _StagnantSection(stagnant: stagnant, onRefresh: refresh),

          // ─── 快捷操作 ───
          _QuickActions(onRefresh: refresh),
        ],
      ),
    );
  }

  Widget _refreshButton() => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: refresh,
      borderRadius: BorderRadius.circular(C.radiusMd),
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: C.primary.withOpacity(0.06),
          borderRadius: BorderRadius.circular(C.radiusMd),
        ),
        child: Icon(Icons.refresh_rounded, color: C.primary, size: 20),
      ),
    ),
  );
}

// ═══════════════════════════════════════════════
// 子组件
// ═══════════════════════════════════════════════

/// 英雄指标卡（渐变背景，核心数据）
class _HeroMetricCard extends StatelessWidget {
  final int gmv;
  final double? gmvPct;
  final int profit;
  final int profitDiff;
  final int orders;
  final int orderDiff;
  final double margin;

  const _HeroMetricCard({
    required this.gmv,
    required this.gmvPct,
    required this.profit,
    required this.profitDiff,
    required this.orders,
    required this.orderDiff,
    required this.margin,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(C.sp16, 0, C.sp16, C.sp12),
    padding: const EdgeInsets.all(C.sp20),
    decoration: BoxDecoration(
      gradient: C.heroGradient,
      borderRadius: BorderRadius.circular(C.radiusXl),
      boxShadow: [
        BoxShadow(
          color: C.primary.withOpacity(0.3),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 顶部标签
        Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.payments_outlined, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '今日 GMV',
                  style: TextStyle(
                    fontSize: 12, color: Colors.white.withOpacity(0.8),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  fmtDate(DateTime.now()),
                  style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.5)),
                ),
              ],
            ),
            const Spacer(),
            if (gmvPct != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      gmvPct! >= 0 ? Icons.trending_up : Icons.trending_down,
                      color: Colors.white, size: 14,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${gmvPct!.abs().toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),

        // 核心 GMV 数字
        const SizedBox(height: 12),
        FittedBox(
          alignment: Alignment.centerLeft,
          fit: BoxFit.scaleDown,
          child: Text(
            yuan(gmv),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              height: 1.1,
            ),
          ),
        ),

        // 底部次级指标
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(C.radiusMd),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _heroSubMetric('今日毛利', yuan(profit),
                  profitDiff >= 0 ? '+${yuan(profitDiff.abs())}' : '-${yuan(profitDiff.abs())}'),
              _heroDivider(),
              _heroSubMetric('毛利率', '${margin.toStringAsFixed(1)}%', '经营效率'),
              _heroDivider(),
              _heroSubMetric('今日订单', '$orders',
                  orderDiff >= 0 ? '+$orderDiff' : '$orderDiff'),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _heroSubMetric(String label, String value, String sub) => Expanded(
    child: Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10, color: Colors.white.withOpacity(0.6), fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          sub,
          style: TextStyle(
            fontSize: 9.5, color: Colors.white.withOpacity(0.5), fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  Widget _heroDivider() => Container(
    width: 0.8, height: 32,
    color: Colors.white.withOpacity(0.15),
  );
}

/// 状态指标行（在售/待质检/在途/待发货）
class _StatusMetricsRow extends StatelessWidget {
  final Stats stats;
  const _StatusMetricsRow({required this.stats});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(C.sp16, 0, C.sp16, C.sp12),
    child: LayoutBuilder(
      builder: (context, box) {
        final items = [
          _StatusItem('${stats.inStockCount}', '在售设备', C.primary, Icons.inventory_2_outlined),
          _StatusItem('${stats.pendingQcCount}', '待质检', C.orange, Icons.fact_check_outlined),
          _StatusItem('${stats.shippedCount}', '在途', C.blue, Icons.local_shipping_outlined),
          _StatusItem('${stats.pendingCount}', '待发货', C.green, Icons.outbox_outlined),
        ];
        if (box.maxWidth < 520) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  SizedBox(width: 136, child: _buildCard(items[i])),
                  if (i != items.length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
          );
        }
        return Row(
          children: [
            for (int i = 0; i < items.length; i++) ...[
              Expanded(child: _buildCard(items[i])),
              if (i != items.length - 1) const SizedBox(width: 8),
            ],
          ],
        );
      },
    ),
  );

  Widget _buildCard(_StatusItem item) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    decoration: BoxDecoration(
      color: C.card,
      borderRadius: BorderRadius.circular(C.radiusMd),
      border: Border.all(color: C.line, width: 0.8),
      boxShadow: C.elevationSm,
    ),
    child: Row(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: item.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(item.icon, size: 18, color: item.color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: Text(
                  item.value,
                  style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w900, color: C.t1,
                  ),
                ),
              ),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 10.5, color: C.t2, fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _StatusItem {
  final String value;
  final String label;
  final Color color;
  final IconData icon;
  const _StatusItem(this.value, this.label, this.color, this.icon);
}

/// 趋势图表区域
class _ChartSection extends StatelessWidget {
  final _ChartData chart;
  final int chartMode;
  final ValueChanged<int> onModeChange;

  const _ChartSection({
    required this.chart,
    required this.chartMode,
    required this.onModeChange,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(C.sp16, 0, C.sp16, C.sp12),
    padding: const EdgeInsets.all(C.sp16),
    decoration: BoxDecoration(
      color: C.card,
      borderRadius: BorderRadius.circular(C.radiusLg),
      border: Border.all(color: C.line, width: 0.8),
      boxShadow: C.cardShadow,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题行
        Row(
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: C.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.show_chart, color: C.primary, size: 16),
            ),
            const SizedBox(width: 10),
            Text(
              chart.title,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: C.t1),
            ),
            const Spacer(),
            Text(
              '累计 ${yuan(chart.total)}',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.primary),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 周期切换
        Row(
          children: [
            _chartTab('近7天', 0),
            const SizedBox(width: 6),
            _chartTab('当月', 1),
            const SizedBox(width: 6),
            _chartTab('近12月', 2),
          ],
        ),
        const SizedBox(height: 12),

        // 图表
        SizedBox(
          height: 160,
          child: CustomPaint(
            painter: LineChartPainter(
              chart.profit, chart.labels, lineColor: C.primary,
            ),
            size: Size.infinite,
          ),
        ),
      ],
    ),
  );

  Widget _chartTab(String label, int mode) {
    final on = chartMode == mode;
    return GestureDetector(
      onTap: () => onModeChange(mode),
      child: AnimatedContainer(
        duration: C.fast,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: on ? C.selected : C.cardMuted,
          borderRadius: BorderRadius.circular(C.radiusSm),
          border: Border.all(
            color: on ? C.primary.withOpacity(0.3) : C.line,
            width: on ? 1.2 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: on ? C.selectedText : C.t2,
            fontWeight: on ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// 资金占用 & 滞销预警
class _AlertsRow extends StatelessWidget {
  final Stats stats;
  final VoidCallback onRefresh;

  const _AlertsRow({required this.stats, required this.onRefresh});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(C.sp16, 0, C.sp16, C.sp12),
    child: Row(
      children: [
        Expanded(
          child: _alertCard(
            icon: Icons.account_balance_wallet_outlined,
            label: '资金占用',
            value: yuan(stats.capitalOccupied),
            sub: '在售${stats.inStockCount}台',
            color: C.orange,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const StagnantListPage()),
            ).then((_) => onRefresh()),
            child: _alertCard(
              icon: Icons.warning_amber_rounded,
              label: '滞销预警',
              value: '${stats.stagnantCount}台',
              sub: stats.stagnantCount > 0 ? '点击处理 · 建议清仓' : '库存健康',
              color: stats.stagnantCount > 0 ? C.red : C.green,
              tappable: true,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _alertCard({
    required IconData icon,
    required String label,
    required String value,
    required String sub,
    required Color color,
    bool tappable = false,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    decoration: BoxDecoration(
      color: C.card,
      borderRadius: BorderRadius.circular(C.radiusMd),
      border: Border.all(color: C.line, width: 0.8),
      boxShadow: C.elevationSm,
    ),
    child: Row(
      children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5, color: C.t2, fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w900, color: color,
                  ),
                ),
              ),
              Text(
                sub, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 9.5, color: C.t3, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        if (tappable) Icon(Icons.chevron_right, color: C.t3, size: 18),
      ],
    ),
  );
}

/// 渠道占比
class _ChannelSection extends StatelessWidget {
  final Map<String, int> channelGmv;
  const _ChannelSection({required this.channelGmv});

  @override
  Widget build(BuildContext context) {
    final segColors = [C.primary, C.blue, C.purple, C.orange, C.pink, C.green];
    final entries = channelGmv.entries.toList();
    final total = channelGmv.values.fold<int>(0, (a, b) => a + b);
    final segments = entries
        .asMap()
        .entries
        .where((e) => e.value.value > 0)
        .map((e) => DonutSegment(e.value.value.toDouble(), segColors[e.key % segColors.length]))
        .toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(C.sp16, 0, C.sp16, C.sp12),
      padding: const EdgeInsets.all(C.sp16),
      decoration: BoxDecoration(
        color: C.card,
        borderRadius: BorderRadius.circular(C.radiusLg),
        border: Border.all(color: C.line, width: 0.8),
        boxShadow: C.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: C.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.pie_chart_outline, color: C.purple, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                '渠道占比',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: C.t1),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              SizedBox(
                width: 120, height: 120,
                child: CustomPaint(
                  painter: DonutPainter(segments, thickness: 16),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: entries.asMap().entries.map((e) {
                    final color = segColors[e.key % segColors.length];
                    final pct = total > 0
                        ? (e.value.value * 100 / total).toStringAsFixed(0)
                        : '0';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 10, height: 10,
                            decoration: BoxDecoration(
                              color: color, borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              e.value.key,
                              style: TextStyle(fontSize: 12, color: C.t1, fontWeight: FontWeight.w500),
                            ),
                          ),
                          // 进度条
                          Expanded(
                            flex: 2,
                            child: LayoutBuilder(
                              builder: (ctx, box) => Container(
                                height: 6,
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: FractionallySizedBox(
                                  widthFactor: total > 0 ? e.value.value / total : 0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 36,
                            child: Text(
                              '$pct%',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w800, color: C.t1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// AI 经营日报入口
class _AiReportEntry extends StatefulWidget {
  final VoidCallback onTap;
  const _AiReportEntry({required this.onTap});
  @override
  State<_AiReportEntry> createState() => _AiReportEntryState();
}

class _AiReportEntryState extends State<_AiReportEntry> {
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: widget.onTap,
    child: Container(
      margin: const EdgeInsets.fromLTRB(C.sp16, 0, C.sp16, C.sp12),
      padding: const EdgeInsets.all(C.sp16),
      decoration: BoxDecoration(
        color: C.card,
        borderRadius: BorderRadius.circular(C.radiusLg),
        border: Border.all(color: C.line, width: 0.8),
        boxShadow: C.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(C.radiusMd),
              boxShadow: [
                BoxShadow(
                  color: C.purple.withOpacity(0.25),
                  blurRadius: 8, offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI 经营日报',
                  style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w900, color: C.t1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '基于库存、订单与毛利，智能生成经营分析',
                  style: TextStyle(fontSize: 11, color: C.t3, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: C.t3, size: 22),
        ],
      ),
    ),
  );
}

/// 滞销预警列表
class _StagnantSection extends StatelessWidget {
  final List<Device> stagnant;
  final VoidCallback onRefresh;

  const _StagnantSection({required this.stagnant, required this.onRefresh});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(C.sp16, 0, C.sp16, C.sp12),
    padding: const EdgeInsets.all(C.sp16),
    decoration: BoxDecoration(
      color: C.card,
      borderRadius: BorderRadius.circular(C.radiusLg),
      border: Border.all(color: C.red.withOpacity(0.2), width: 1),
      boxShadow: C.cardShadow,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: C.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: C.red, size: 16),
            ),
            const SizedBox(width: 10),
            Text(
              '滞销预警',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: C.t1),
            ),
            const Spacer(),
            InkWell(
              onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const StagnantListPage()),
              ).then((_) => onRefresh()),
              borderRadius: BorderRadius.circular(C.radiusSm),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '全部',
                      style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600, color: C.red,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.chevron_right, color: C.red, size: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...stagnant.take(4).map((d) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: C.cardMuted,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: C.line, width: 0.5),
                ),
                child: Icon(Icons.tablet_mac_rounded, color: C.t2, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${d.model} ${d.capacity}',
                      style: TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700, color: C.t1,
                      ),
                    ),
                    Text(
                      '在库${d.stockDays}天 · 当前${yuan(d.sellPrice)}',
                      style: TextStyle(fontSize: 11, color: C.t2),
                    ),
                  ],
                ),
              ),
              const StatusChip('滞销', C.red),
            ],
          ),
        )),
      ],
    ),
  );
}

/// 快捷操作
class _QuickActions extends StatelessWidget {
  final VoidCallback onRefresh;
  const _QuickActions({required this.onRefresh});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(C.sp16, 0, C.sp16, C.sp12),
    padding: const EdgeInsets.all(C.sp16),
    decoration: BoxDecoration(
      color: C.card,
      borderRadius: BorderRadius.circular(C.radiusLg),
      border: Border.all(color: C.line, width: 0.8),
      boxShadow: C.cardShadow,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: C.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.bolt_rounded, color: C.primary, size: 16),
            ),
            const SizedBox(width: 10),
            Text(
              '快捷操作',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: C.t1),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _quickAction(
                Icons.qr_code_scanner_rounded, '扫码收货', C.primary,
                () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const ScanPage()),
                ).then((_) => onRefresh()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _quickAction(
                Icons.query_stats_rounded, '批发价', C.purple,
                () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const MarketPricePage()),
                ).then((_) => onRefresh()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _quickAction(
                Icons.point_of_sale_outlined, '售出', C.green,
                () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const SellPage()),
                ).then((_) => onRefresh()),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _quickAction(IconData icon, String label, Color color, VoidCallback onTap) =>
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(C.radiusMd),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.06),
              borderRadius: BorderRadius.circular(C.radiusMd),
              border: Border.all(color: color.withOpacity(0.15), width: 0.8),
            ),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, color: color, size: 17),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w800, color: C.t1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

// ═══════════════════════════════════════════════
// 数据类
// ═══════════════════════════════════════════════

class _ChartData {
  final List<double> profit;
  final List<String> labels;
  final String title;
  final int total;
  _ChartData(this.profit, this.labels, this.title, this.total);
}
