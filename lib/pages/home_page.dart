import 'package:flutter/material.dart';

import '../components/index.dart';
import '../main.dart';
import '../models.dart';
import '../theme/colors.dart';
import '../utils/utils.dart';
import 'ai_report_page.dart';
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
  List<DailyStat> daily = const [];
  List<Device> stagnant = const [];

  @override
  void initState() {
    super.initState();
    refresh();
  }

  void refresh() {
    if (!mounted) return;
    setState(() {
      stats = gStorage.computeStats();
      daily = gStorage.getDailyStats(days: 7);
      stagnant =
          gStorage.getDevices().where((item) => item.isStagnant).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final margin = stats.gmv == 0 ? 0.0 : stats.grossProfit / stats.gmv * 100;
    return PageScaffold(
      title: Text(
        '货脉',
        style: TextStyle(
          color: C.t1,
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
      ),
      subtitle: Text(
        '经营控制台  ·  ${fmtDate(DateTime.now())}',
        style: TextStyle(
          color: C.t2,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      action: _HudIconButton(icon: Icons.refresh_rounded, onTap: refresh),
      child: _HomeTelemetryView(
        stats: stats,
        margin: margin,
        daily: daily,
        stagnantCount: stagnant.length,
        onReceive: () => _push(const ScanPage()),
        onPrice: () => _push(const MarketPricePage()),
        onSell: () => _push(const SellPage()),
        onInventory: () => _push(const StagnantListPage()),
        onPatrol: () => _push(const AiReportPage()),
      ),
    );
  }

  void _push(Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    ).then((_) => refresh());
  }
}

class _HomeTelemetryView extends StatelessWidget {
  final Stats stats;
  final double margin;
  final List<DailyStat> daily;
  final int stagnantCount;
  final VoidCallback onReceive;
  final VoidCallback onPrice;
  final VoidCallback onSell;
  final VoidCallback onInventory;
  final VoidCallback onPatrol;

  const _HomeTelemetryView({
    required this.stats,
    required this.margin,
    required this.daily,
    required this.stagnantCount,
    required this.onReceive,
    required this.onPrice,
    required this.onSell,
    required this.onInventory,
    required this.onPatrol,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _LaunchPanel(
        stats: stats,
        margin: margin,
        onReceive: onReceive,
        onPrice: onPrice,
        onSell: onSell,
      ),
      const SizedBox(height: 14),
      _MarsDataPanel(stats: stats, margin: margin, daily: daily),
      const SizedBox(height: 14),
      LayoutBuilder(
        builder: (context, box) {
          final inventory = _InventoryPanel(
            stats: stats,
            stagnantCount: stagnantCount,
            onTap: onInventory,
          );
          final patrol = _PatrolPanel(
            count: stats.pendingCount + stats.pendingQcCount,
            onTap: onPatrol,
          );
          if (box.maxWidth < 620) {
            return Column(
              children: [inventory, const SizedBox(height: 14), patrol],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: inventory),
              const SizedBox(width: 14),
              Expanded(child: patrol),
            ],
          );
        },
      ),
    ],
  );
}

class _LaunchPanel extends StatelessWidget {
  final Stats stats;
  final double margin;
  final VoidCallback onReceive;
  final VoidCallback onPrice;
  final VoidCallback onSell;

  const _LaunchPanel({
    required this.stats,
    required this.margin,
    required this.onReceive,
    required this.onPrice,
    required this.onSell,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final narrow = box.maxWidth < 620;
      return SizedBox(
        height: narrow ? 536 : 414,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(C.radiusXl),
          child: Material(
            color: const Color(0xFF0B0C12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/mission_pilot.jpg',
                    fit: BoxFit.cover,
                    alignment:
                        narrow
                            ? const Alignment(.18, -.24)
                            : const Alignment(.92, -.12),
                    filterQuality: FilterQuality.medium,
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors:
                            narrow
                                ? [
                                  const Color(
                                    0xFF0B0C12,
                                  ).withValues(alpha: .20),
                                  const Color(
                                    0xFF0B0C12,
                                  ).withValues(alpha: .70),
                                ]
                                : [
                                  const Color(
                                    0xFF0B0C12,
                                  ).withValues(alpha: .98),
                                  const Color(
                                    0xFF0B0C12,
                                  ).withValues(alpha: .72),
                                  const Color(
                                    0xFF0B0C12,
                                  ).withValues(alpha: .16),
                                ],
                        stops: narrow ? const [0, 1] : const [0, .60, 1],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _LaunchFramePainter(accent: C.purple),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(17),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const _HudLabel('SEATLR / OPS 01'),
                          const Spacer(),
                          _LivePill(active: stats.orderCount > 0),
                        ],
                      ),
                      const Spacer(),
                      SizedBox(
                        width: narrow ? double.infinity : box.maxWidth * .56,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '设备经营',
                              style: TextStyle(
                                color: C.t2,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'REAL TIME',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: .85),
                                fontSize: 25,
                                letterSpacing: 1.4,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '今日成交额',
                              style: TextStyle(
                                color: C.t2,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                yuan(stats.gmv),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 52,
                                  height: .92,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(height: 11),
                            Row(
                              children: [
                                Expanded(
                                  child: _HeroMetric(
                                    label: '毛利',
                                    value: yuan(stats.grossProfit),
                                    color: C.mint,
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: _HeroMetric(
                                    label: '毛利率',
                                    value: '${margin.toStringAsFixed(1)}%',
                                    color: C.purple,
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: _HeroMetric(
                                    label: '待发',
                                    value: '${stats.pendingCount}',
                                    color: C.orange,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 7,
                              runSpacing: 7,
                              children: [
                                _HudAction(
                                  icon: Icons.qr_code_scanner_rounded,
                                  label: '扫码收货',
                                  onTap: onReceive,
                                ),
                                _HudAction(
                                  icon: Icons.query_stats_rounded,
                                  label: '批发行情',
                                  onTap: onPrice,
                                ),
                                _HudAction(
                                  icon: Icons.point_of_sale_rounded,
                                  label: '销售登记',
                                  onTap: onSell,
                                  active: true,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _MarsDataPanel extends StatelessWidget {
  final Stats stats;
  final double margin;
  final List<DailyStat> daily;

  const _MarsDataPanel({
    required this.stats,
    required this.margin,
    required this.daily,
  });

  @override
  Widget build(BuildContext context) {
    final values =
        daily.isEmpty
            ? const <double>[0, 0, 0, 0, 0, 0, 0]
            : daily.map((item) => item.gmv.toDouble()).toList();
    final labels =
        daily.isEmpty
            ? const <String>['-6', '-5', '-4', '-3', '-2', '-1', 'TODAY']
            : daily.map((item) => item.date.substring(5)).toList();
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(C.radiusXl),
        border: Border.all(color: _marsRed.withValues(alpha: .45)),
        gradient: const LinearGradient(
          colors: [Color(0xFF6B3C4A), Color(0xFF2C1C2D), Color(0xFF14131C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _MarsSurfacePainter())),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _HudLabel('MY DATA / MARS-02'),
                    const Spacer(),
                    Text(
                      fmtDate(DateTime.now()),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .62),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  '经营数据',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .92),
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, box) {
                    final wide = box.maxWidth > 480;
                    final left = Column(
                      children: [
                        _MarsReadout(
                          icon: Icons.public_rounded,
                          label: '库存重力',
                          value: '${stats.inStockCount} 台',
                          note: 'IN STOCK',
                          color: const Color(0xFFFFE8DA),
                        ),
                        const SizedBox(height: 8),
                        _MarsReadout(
                          icon: Icons.thermostat_rounded,
                          label: '毛利温度',
                          value: '${margin.toStringAsFixed(1)}%',
                          note: 'MARGIN',
                          color: const Color(0xFFFFD4C5),
                        ),
                      ],
                    );
                    final chart = SizedBox(
                      height: 146,
                      child: CustomPaint(
                        painter: LineChartPainter(
                          values,
                          labels,
                          lineColor: const Color(0xFFFFA7C5),
                          showArea: true,
                        ),
                      ),
                    );
                    return wide
                        ? Row(
                          children: [
                            Expanded(child: left),
                            const SizedBox(width: 12),
                            Expanded(child: chart),
                          ],
                        )
                        : Column(
                          children: [left, const SizedBox(height: 10), chart],
                        );
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _PulseReadout(
                        icon: Icons.favorite_rounded,
                        label: '订单脉冲',
                        value: '${stats.orderCount}',
                        unit: 'ORDERS',
                        color: const Color(0xFFFFB0C5),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: _PulseReadout(
                        icon: Icons.air_rounded,
                        label: '库存流量',
                        value: '${stats.inStockCount}',
                        unit: 'DEVICES',
                        color: const Color(0xFFFFD0BB),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryPanel extends StatelessWidget {
  final Stats stats;
  final int stagnantCount;
  final VoidCallback onTap;

  const _InventoryPanel({
    required this.stats,
    required this.stagnantCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => _HudPanel(
    accent: C.purple,
    onTap: onTap,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _HudLabel('STOCK STATUS'),
            const Spacer(),
            Icon(Icons.arrow_forward_rounded, color: C.t2, size: 18),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '库存资金',
                    style: TextStyle(
                      color: C.t2,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      yuan(stats.capitalOccupied),
                      style: TextStyle(
                        color: C.t1,
                        fontSize: 28,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${stats.pendingQcCount} 台待质检  ·  $stagnantCount 台滞销',
                    style: TextStyle(
                      color: C.purple,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 70,
              height: 70,
              child: CustomPaint(
                painter: _GaugePainter(
                  color: stagnantCount > 0 ? C.orange : C.purple,
                  alert: stagnantCount > 0,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _PatrolPanel extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _PatrolPanel({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = count > 0 ? C.orange : C.mint;
    return _HudPanel(
      accent: color,
      onTap: onTap,
      child: Row(
        children: [
          SizedBox(
            width: 78,
            height: 70,
            child: CustomPaint(painter: _PulsePainter(color: color)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HudLabel(count > 0 ? 'ACTION REQUIRED' : 'AUTO PATROL'),
                const SizedBox(height: 7),
                Text(
                  count > 0 ? '有任务需要处理' : '巡店检查已完成',
                  style: TextStyle(
                    color: C.t1,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                _StatusDot(label: '$count 项待处理', color: color),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_rounded, color: color, size: 18),
        ],
      ),
    );
  }
}

class _HudPanel extends StatelessWidget {
  final Widget child;
  final Color accent;
  final VoidCallback? onTap;
  const _HudPanel({required this.child, required this.accent, this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(C.radiusLg),
      side: BorderSide(color: accent.withValues(alpha: .36)),
    ),
    clipBehavior: Clip.antiAlias,
    child: Ink(
      decoration: BoxDecoration(
        color: C.hudDark2,
        borderRadius: BorderRadius.circular(C.radiusLg),
      ),
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _HudCornerPainter(accent)),
            ),
            Padding(padding: const EdgeInsets.all(15), child: child),
          ],
        ),
      ),
    ),
  );
}

class _HudLabel extends StatelessWidget {
  final String text;
  const _HudLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color: C.t3,
      fontSize: 10,
      letterSpacing: 1.2,
      fontWeight: FontWeight.w900,
    ),
  );
}

class _LivePill extends StatelessWidget {
  final bool active;
  const _LivePill({required this.active});
  @override
  Widget build(BuildContext context) => _StatusDot(
    label: active ? 'LIVE' : 'STANDBY',
    color: active ? C.mint : C.t2,
  );
}

class _StatusDot extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusDot({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    ],
  );
}

class _HeroMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _HeroMetric({
    required this.label,
    required this.value,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(8, 8, 7, 8),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .28),
      borderRadius: BorderRadius.circular(C.radiusSm),
      border: Border.all(color: color.withValues(alpha: .42)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: .68),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),
  );
}

class _HudAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  const _HudAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 42,
    child: Material(
      color:
          active
              ? C.purple.withValues(alpha: .34)
              : Colors.black.withValues(alpha: .28),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(C.radiusSm),
        side: BorderSide(
          color: active ? C.purple : Colors.white.withValues(alpha: .42),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(C.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
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

class _HudIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HudIconButton({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 54,
    height: 54,
    child: Material(
      color: const Color(0xF4070810),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: C.purple.withValues(alpha: .45)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Icon(icon, color: Colors.white, size: 27),
      ),
    ),
  );
}

class _MarsReadout extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String note;
  final Color color;
  const _MarsReadout({
    required this.icon,
    required this.label,
    required this.value,
    required this.note,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .16),
      borderRadius: BorderRadius.circular(C.radiusSm),
      border: Border.all(color: color.withValues(alpha: .25)),
    ),
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: .70)),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                note,
                style: TextStyle(
                  color: color.withValues(alpha: .78),
                  fontSize: 9,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .72),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _PulseReadout extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;
  const _PulseReadout({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .16),
      borderRadius: BorderRadius.circular(C.radiusSm),
      border: Border.all(color: color.withValues(alpha: .24)),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .66),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: color,
                      fontSize: 20,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    unit,
                    style: TextStyle(
                      color: color.withValues(alpha: .78),
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _LaunchFramePainter extends CustomPainter {
  final Color accent;
  const _LaunchFramePainter({required this.accent});
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = accent.withValues(alpha: .68)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;
    const inset = 10.0;
    const length = 22.0;
    canvas.drawLine(
      const Offset(inset, inset),
      const Offset(inset + length, inset),
      paint,
    );
    canvas.drawLine(
      const Offset(inset, inset),
      const Offset(inset, inset + length),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - inset, inset),
      Offset(size.width - inset - length, inset),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - inset, inset),
      Offset(size.width - inset, inset + length),
      paint,
    );
    canvas.drawLine(
      Offset(inset, size.height - inset),
      Offset(inset + length, size.height - inset),
      paint,
    );
    canvas.drawLine(
      Offset(inset, size.height - inset),
      Offset(inset, size.height - inset - length),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - inset, size.height - inset),
      Offset(size.width - inset - length, size.height - inset),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - inset, size.height - inset),
      Offset(size.width - inset, size.height - inset - length),
      paint,
    );
    final guide =
        Paint()
          ..color = Colors.white.withValues(alpha: .12)
          ..strokeWidth = 1;
    canvas.drawLine(
      Offset(size.width * .07, size.height * .47),
      Offset(size.width * .93, size.height * .47),
      guide,
    );
  }

  @override
  bool shouldRepaint(covariant _LaunchFramePainter old) => old.accent != accent;
}

const _marsRed = Color(0xFFE9857E);

class _MarsSurfacePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final terrain =
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.transparent,
              const Color(0xFF7E3E50).withValues(alpha: .46),
              const Color(0xFF1D1524).withValues(alpha: .84),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, terrain);
    final line =
        Paint()
          ..color = _marsRed.withValues(alpha: .15)
          ..strokeWidth = 1;
    for (double y = size.height * .53; y < size.height; y += 19) {
      final path = Path()..moveTo(0, y);
      path.cubicTo(
        size.width * .22,
        y - 16,
        size.width * .48,
        y + 18,
        size.width * .72,
        y - 2,
      );
      path.cubicTo(
        size.width * .86,
        y - 11,
        size.width * .94,
        y + 8,
        size.width,
        y,
      );
      canvas.drawPath(path, line);
    }
    final grid =
        Paint()
          ..color = Colors.white.withValues(alpha: .06)
          ..strokeWidth = 1;
    for (double x = 18; x < size.width; x += 34)
      canvas.drawLine(
        Offset(x, size.height * .58),
        Offset(x + 20, size.height),
        grid,
      );
    final planet =
        Paint()
          ..color = _marsRed.withValues(alpha: .15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
    canvas.drawCircle(
      Offset(size.width * .78, size.height * .42),
      size.shortestSide * .22,
      planet,
    );
  }

  @override
  bool shouldRepaint(covariant _MarsSurfacePainter oldDelegate) => false;
}

class _HudCornerPainter extends CustomPainter {
  final Color accent;
  const _HudCornerPainter(this.accent);
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = accent.withValues(alpha: .54)
          ..strokeWidth = 1.1;
    const i = 8.0;
    const l = 17.0;
    canvas.drawLine(const Offset(i, i), const Offset(i + l, i), paint);
    canvas.drawLine(const Offset(i, i), const Offset(i, i + l), paint);
    canvas.drawLine(
      Offset(size.width - i, i),
      Offset(size.width - i - l, i),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - i, i),
      Offset(size.width - i, i + l),
      paint,
    );
    canvas.drawLine(
      Offset(i, size.height - i),
      Offset(i + l, size.height - i),
      paint,
    );
    canvas.drawLine(
      Offset(i, size.height - i),
      Offset(i, size.height - i - l),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - i, size.height - i),
      Offset(size.width - i - l, size.height - i),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - i, size.height - i),
      Offset(size.width - i, size.height - i - l),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _HudCornerPainter old) => old.accent != accent;
}

class _GaugePainter extends CustomPainter {
  final Color color;
  final bool alert;
  const _GaugePainter({required this.color, required this.alert});
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(
      center: center,
      radius: size.shortestSide * .34,
    );
    final base =
        Paint()
          ..color = C.border
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8;
    final active =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, .78, 4.75, false, base);
    canvas.drawArc(rect, .78, alert ? 3.8 : 2.7, false, active);
    canvas.drawCircle(center, 4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.color != color || old.alert != alert;
}

class _PulsePainter extends CustomPainter {
  final Color color;
  const _PulsePainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final line =
        Paint()
          ..color = color
          ..strokeWidth = 1.7
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
    final glow =
        Paint()
          ..color = color.withValues(alpha: .24)
          ..strokeWidth = 6
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final path =
        Path()
          ..moveTo(0, size.height * .62)
          ..lineTo(size.width * .17, size.height * .62)
          ..lineTo(size.width * .28, size.height * .36)
          ..lineTo(size.width * .41, size.height * .78)
          ..lineTo(size.width * .55, size.height * .18)
          ..lineTo(size.width * .68, size.height * .62)
          ..lineTo(size.width, size.height * .62);
    canvas.drawPath(path, glow);
    canvas.drawPath(path, line);
    canvas.drawLine(
      Offset(0, size.height * .62),
      Offset(size.width, size.height * .62),
      Paint()..color = Colors.white.withValues(alpha: .12),
    );
  }

  @override
  bool shouldRepaint(covariant _PulsePainter old) => old.color != color;
}
