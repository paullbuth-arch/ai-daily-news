import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../components/index.dart';
import '../theme/colors.dart';
import '../utils/utils.dart';
import '../models.dart';
import '../main.dart';
import '../services/device_export_service.dart';
import '../services/ecommerce_material_import_service.dart';
import '../services/automation_service.dart';
import 'ai_report_page.dart';
import 'market_price_page.dart';
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
  List<DailyStat> weekly = [];
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
      weekly = gStorage.getCurrentMonthWeeklyStats();
      channelGmv = gStorage.getChannelGmv();
    });
  }

  @override
  Widget build(BuildContext context) {
    final margin = stats.gmv > 0 ? stats.grossProfit / stats.gmv * 100 : 0.0;
    final automationPlan = AutomationService.buildPlan(gStorage);
    return PageScaffold(
      title: Text(
        '货脉',
        style: TextStyle(
          fontSize: C.isLight ? 24 : 26,
          fontWeight: FontWeight.w900,
          color: C.t1,
        ),
      ),
      subtitle: Text(
        '今日 ${stats.orderCount} 单 · 在售 ${stats.inStockCount} 台 · ${fmtDate(DateTime.now())}',
        style: TextStyle(
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
            onSearch: null,
            onTune: null,
            onScan: _openLinkMaterialImport,
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
          _TrendPanel(daily: daily, weekly: weekly),
          const SizedBox(height: 14),
          if (channelGmv.isNotEmpty) _ChannelPanel(channelGmv: channelGmv),
          const SizedBox(height: 14),
          _AiPanel(
            openTaskCount: automationPlan.openTasks.length,
            criticalCount: automationPlan.criticalCount,
            onTap: () => _push(const AiReportPage()),
          ),
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

  void _openLinkMaterialImport() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _LinkMaterialImportPage()),
    );
  }
}

class _HeroPhoneCard extends StatelessWidget {
  final Stats stats;
  final double margin;
  final VoidCallback? onSearch;
  final VoidCallback? onTune;
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
  Widget build(BuildContext context) {
    if (C.isLight) {
      return _OperationsDashboardCard(
        stats: stats,
        margin: margin,
        onScan: onScan,
        onPrice: onPrice,
        onSell: onSell,
      );
    }
    return GlassPanel(
      padding: EdgeInsets.zero,
      radius: C.radiusXl,
      gradient: C.heroGradient,
      borderColor: C.isLight ? C.navBorder : C.primary.withValues(alpha: 0.24),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _CommandHeroPainter(C.isLight)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _CommandBadge(
                                icon: Icons.sensors_rounded,
                                label: 'HUOMAI OPS',
                                color: C.primary,
                              ),
                              _CommandBadge(
                                icon: Icons.bolt_rounded,
                                label: 'LIVE',
                                color: C.orange,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '今日经营',
                            style: TextStyle(
                              fontSize: 13,
                              color: C.t2,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          FittedBox(
                            alignment: Alignment.centerLeft,
                            fit: BoxFit.scaleDown,
                            child: Text(
                              yuan(stats.gmv),
                              style: TextStyle(
                                fontSize: 44,
                                height: 1,
                                fontWeight: FontWeight.w900,
                                color: C.t1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '毛利 ${yuan(stats.grossProfit)} · 毛利率 ${margin.toStringAsFixed(1)}%',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: C.t2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        StatusChip('${stats.orderCount} 单', C.primary),
                        const SizedBox(height: 8),
                        Container(
                          width: 68,
                          height: 42,
                          decoration: BoxDecoration(
                            color:
                                C.isLight
                                    ? const Color(0xFF090B0A)
                                    : C.primary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(C.radiusMd),
                            border: Border.all(
                              color:
                                  C.isLight
                                      ? const Color(0xFF090B0A)
                                      : C.primary.withValues(alpha: 0.24),
                            ),
                          ),
                          child: Icon(
                            Icons.tablet_mac_rounded,
                            color: C.isLight ? C.selected : C.primary,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, box) {
                    final compact = box.maxWidth < 430;
                    final width =
                        compact
                            ? (box.maxWidth - 8) / 2
                            : (box.maxWidth - 16) / 3;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        SizedBox(
                          width: width,
                          child: _MiniMetric(
                            label: '在售',
                            value: '${stats.inStockCount} 台',
                            tint: C.primary,
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _MiniMetric(
                            label: '库存资金',
                            value: yuan(stats.capitalOccupied),
                            tint: C.orange,
                          ),
                        ),
                        SizedBox(
                          width: compact ? box.maxWidth : width,
                          child: _MiniMetric(
                            label: '今日毛利',
                            value: yuan(stats.grossProfit),
                            tint: stats.grossProfit >= 0 ? C.green : C.red,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, box) {
                    final wide = box.maxWidth >= 520;
                    final itemWidth =
                        wide ? (box.maxWidth - 16) / 3 : box.maxWidth;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        SizedBox(
                          width: itemWidth,
                          child: _PastelPill(
                            label: '链接素材',
                            sub: '下载图片/视频，复制文案',
                            icon: Icons.link_rounded,
                            color: C.primary,
                            onTap: onScan,
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _PastelPill(
                            label: '批发行情',
                            sub: '导入报价，辅助收货',
                            icon: Icons.query_stats_rounded,
                            color: C.blue,
                            onTap: onPrice,
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _PastelPill(
                            label: '售出登记',
                            sub: '生成订单并算利润',
                            icon: Icons.point_of_sale_outlined,
                            color: C.green,
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
}

class _OperationsDashboardCard extends StatelessWidget {
  final Stats stats;
  final double margin;
  final VoidCallback onScan;
  final VoidCallback onPrice;
  final VoidCallback onSell;

  const _OperationsDashboardCard({
    required this.stats,
    required this.margin,
    required this.onScan,
    required this.onPrice,
    required this.onSell,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(C.radiusLg),
      side: BorderSide(color: C.purple.withValues(alpha: 0.38)),
    ),
    clipBehavior: Clip.antiAlias,
    child: Ink(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(C.radiusLg),
        gradient: const LinearGradient(
          colors: [Color(0xFF28212B), Color(0xFF15131C), Color(0xFF5A2730)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _MarsHudPainter())),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _DashboardBadge(
                      icon: Icons.sensors_rounded,
                      label: 'HUOMAI OPS',
                      color: C.purple,
                    ),
                    const SizedBox(width: 8),
                    _DashboardBadge(
                      icon: Icons.receipt_long_rounded,
                      label: '${stats.orderCount} 单',
                      color: C.pink,
                    ),
                    const Spacer(),
                    Text(
                      fmtDate(DateTime.now()),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      flex: 7,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MY DATA',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.90),
                              fontSize: 25,
                              height: 0.95,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '今日经营',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.64),
                              fontSize: 12,
                              height: 1,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            alignment: Alignment.centerLeft,
                            fit: BoxFit.scaleDown,
                            child: Text(
                              yuan(stats.gmv),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 46,
                                height: 0.92,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 5,
                      child: Row(
                        children: [
                          Expanded(
                            child: _DashboardCount(
                              label: '在售',
                              value: '${stats.inStockCount} 台',
                              color: C.purple,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _DashboardCount(
                              label: '待发',
                              value: '${stats.pendingCount} 单',
                              color: C.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _DashboardMetric(
                        label: '毛利',
                        value: yuan(stats.grossProfit),
                        color: stats.grossProfit >= 0 ? C.green : C.red,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DashboardMetric(
                        label: '毛利率',
                        value: '${margin.toStringAsFixed(1)}%',
                        color: C.pink,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DashboardMetric(
                        label: '库存资金',
                        value: yuan(stats.capitalOccupied),
                        color: C.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _DashboardAction(
                        label: '链接素材',
                        icon: Icons.link_rounded,
                        color: C.purple,
                        onTap: onScan,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DashboardAction(
                        label: '批发行情',
                        icon: Icons.query_stats_rounded,
                        color: C.blue,
                        onTap: onPrice,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DashboardAction(
                        label: '售出登记',
                        icon: Icons.point_of_sale_outlined,
                        color: C.green,
                        onTap: onSell,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _MarsHudPainter extends CustomPainter {
  const _MarsHudPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final planet =
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFFAAA2).withValues(alpha: 0.34),
              const Color(0xFFD76A66).withValues(alpha: 0.18),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.78, size.height * 0.33),
              radius: size.width * 0.48,
            ),
          );
    canvas.drawRect(rect, planet);

    final terrain =
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0x006D2732), Color(0x8C6D2732), Color(0xC0180C12)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(
            Rect.fromLTWH(
              0,
              size.height * 0.45,
              size.width,
              size.height * 0.55,
            ),
          );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.45, size.width, size.height * 0.55),
      terrain,
    );

    final grid =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.055)
          ..strokeWidth = 1;
    for (double y = size.height * 0.55; y < size.height; y += 18) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    for (double x = 16; x < size.width; x += 34) {
      canvas.drawLine(
        Offset(x, size.height * 0.54),
        Offset(x - size.width * 0.10, size.height),
        grid,
      );
    }

    final orbit =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.09)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
    final center = Offset(size.width * 0.80, size.height * 0.16);
    for (final radius in [96.0, 148.0, 206.0]) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        math.pi * 0.60,
        math.pi * 0.94,
        false,
        orbit,
      );
    }

    final scanner =
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.transparent,
              const Color(0xFFFFD7E0).withValues(alpha: 0.45),
              Colors.transparent,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(Rect.fromLTWH(0, 0, 1, size.height))
          ..strokeWidth = 1.4;
    final scanX = size.width - 38;
    canvas.drawLine(
      Offset(scanX, size.height * 0.16),
      Offset(scanX, size.height * 0.72),
      scanner,
    );
    canvas.drawLine(
      Offset(scanX + 12, size.height * 0.20),
      Offset(scanX + 12, size.height * 0.62),
      scanner,
    );

    final glow =
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFA884FF).withValues(alpha: 0.24),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.28, size.height * 0.82),
              radius: size.width * 0.42,
            ),
          );
    canvas.drawRect(rect, glow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DashboardBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _DashboardBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.28),
      borderRadius: BorderRadius.circular(C.radiusSm),
      border: Border.all(color: color.withValues(alpha: 0.42)),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.12),
          blurRadius: 8,
          offset: Offset.zero,
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: color == C.purple ? Colors.white : color,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _DashboardCount extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DashboardCount({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(C.radiusMd),
      border: Border.all(color: color.withValues(alpha: 0.36)),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.10),
          blurRadius: 10,
          offset: Offset.zero,
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.62),
            fontSize: 10,
            height: 1,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          alignment: Alignment.centerLeft,
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),
  );
}

class _DashboardMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DashboardMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
    decoration: BoxDecoration(
      color: const Color(0xFF6D3038).withValues(alpha: 0.30),
      borderRadius: BorderRadius.circular(C.radiusMd),
      border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.58),
            fontSize: 10,
            height: 1,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          alignment: Alignment.centerLeft,
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 17,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),
  );
}

class _DashboardAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DashboardAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 46,
    child: Material(
      color: Colors.black.withValues(alpha: 0.22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(C.radiusMd),
        side: BorderSide(color: color.withValues(alpha: 0.44)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: C.t1,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CommandBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _CommandBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final primary = C.isLight && color == C.primary;
    final bg =
        C.isLight
            ? primary
                ? C.selected
                : color.withValues(alpha: 0.10)
            : color.withValues(alpha: 0.12);
    final fg = primary ? C.selectedText : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(C.radiusSm),
        border: Border.all(
          color:
              primary
                  ? C.selectedText.withValues(alpha: 0.16)
                  : color.withValues(alpha: C.isLight ? 0.18 : 0.28),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: fg, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommandHeroPainter extends CustomPainter {
  final bool isLight;

  const _CommandHeroPainter(this.isLight);

  @override
  void paint(Canvas canvas, Size size) {
    final accent =
        Paint()
          ..color = (isLight ? const Color(0xFF090B0A) : C.primary).withValues(
            alpha: isLight ? 0.08 : 0.18,
          )
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke;
    const cut = 24.0;
    canvas.drawLine(const Offset(0, cut), const Offset(cut, 0), accent);
    canvas.drawLine(
      Offset(size.width - cut, 0),
      Offset(size.width, cut),
      accent,
    );
    canvas.drawLine(
      Offset(0, size.height - cut),
      Offset(cut, size.height),
      accent,
    );
    canvas.drawLine(
      Offset(size.width - cut, size.height),
      Offset(size.width, size.height - cut),
      accent,
    );

    final grid =
        Paint()
          ..color = (isLight ? const Color(0xFF090B0A) : Colors.white)
              .withValues(alpha: isLight ? 0.035 : 0.035)
          ..strokeWidth = 1;
    for (double y = 44; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final beam =
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.transparent,
              (isLight ? C.selected : C.primary).withValues(
                alpha: isLight ? 0.55 : 0.25,
              ),
              Colors.transparent,
            ],
          ).createShader(Rect.fromLTWH(0, 0, size.width, 1))
          ..strokeWidth = 1;
    canvas.drawLine(Offset(0, 64), Offset(size.width, 64), beam);

    if (isLight) {
      final wash =
          Paint()
            ..color = C.selected.withValues(alpha: 0.30)
            ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width - 104, -34, 138, 82),
          const Radius.circular(28),
        ),
        wash,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CommandHeroPainter oldDelegate) =>
      oldDelegate.isLight != isLight;
}

class _LinkMaterialImportPage extends StatelessWidget {
  const _LinkMaterialImportPage();

  @override
  Widget build(BuildContext context) => appScaffold(
    context,
    '链接素材下载',
    ListView(
      padding: EdgeInsets.fromLTRB(
        AppLayout.pageHorizontal(context),
        4,
        AppLayout.pageHorizontal(context),
        AppLayout.scrollBottomPadding(context),
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        _LinkMaterialIntro(),
        SizedBox(height: 14),
        _LinkMaterialImportSheet(),
      ],
    ),
  );
}

class _LinkMaterialIntro extends StatelessWidget {
  const _LinkMaterialIntro();

  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: const EdgeInsets.all(14),
    radius: 14,
    color: C.bgCardMuted,
    borderColor: C.border,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.download_for_offline_rounded, color: C.primary, size: 22),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            '复制商品链接或分享口令后解析，图片/视频保存到相册，文案复制到剪贴板。',
            style: TextStyle(
              color: C.t2,
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _LinkMaterialImportSheet extends StatefulWidget {
  const _LinkMaterialImportSheet();

  @override
  State<_LinkMaterialImportSheet> createState() =>
      _LinkMaterialImportSheetState();
}

class _LinkMaterialImportSheetState extends State<_LinkMaterialImportSheet> {
  static const int _maxImages = 80;

  final _linkCtrl = TextEditingController();
  bool _busy = false;
  EcommerceMaterialImportResult? _result;
  int? _savedImageCount;
  int? _savedVideoCount;
  bool _copiedText = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pasteFromClipboard(silent: true);
    });
  }

  @override
  void dispose() {
    _linkCtrl.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard({bool silent = false}) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (!mounted) return;
    if (text.isEmpty) {
      if (!silent) toast(context, '剪贴板里没有可用文本');
      return;
    }
    setState(() => _linkCtrl.text = text);
    if (!silent) toast(context, '已读取剪贴板');
  }

  void _clearInput() {
    setState(() {
      _linkCtrl.clear();
      _result = null;
      _savedImageCount = null;
      _savedVideoCount = null;
      _copiedText = false;
      _saveError = null;
    });
    toast(context, '已清空输入内容');
  }

  Future<void> _importMaterial() async {
    final raw = _linkCtrl.text.trim();
    if (raw.isEmpty) {
      toast(context, '请先复制或粘贴商品链接');
      return;
    }

    setState(() {
      _busy = true;
      _saveError = null;
    });

    try {
      final result = await EcommerceMaterialImportService.importFromText(
        raw,
        docDir: gDocDir,
        maxImages: _maxImages,
      );

      final copyText = result.copyText.trim();
      final copiedText = copyText.isNotEmpty;
      if (copiedText) {
        await Clipboard.setData(ClipboardData(text: copyText));
      }

      var savedImages = 0;
      var savedVideos = 0;
      String? saveError;
      final imagePaths = result.images.map((image) => image.savedPath).toList();
      if (imagePaths.isNotEmpty) {
        try {
          savedImages = await DeviceExportService.saveImagesToGallery(
            paths: imagePaths,
            albumName: '货脉链接素材',
          );
        } catch (e) {
          saveError = _friendlyError(e);
        }
      }
      final videoPaths = result.videos.map((video) => video.savedPath).toList();
      if (videoPaths.isNotEmpty) {
        try {
          savedVideos = await DeviceExportService.saveVideosToGallery(
            paths: videoPaths,
            albumName: '货脉链接素材',
          );
        } catch (e) {
          final message = _friendlyError(e);
          saveError = saveError == null ? message : '$saveError；$message';
        }
      }

      if (!mounted) return;
      setState(() {
        _result = result;
        _savedImageCount = savedImages;
        _savedVideoCount = savedVideos;
        _copiedText = copiedText;
        _saveError = saveError;
      });

      final parts = <String>[];
      if (savedImages > 0) parts.add('已保存$savedImages张图到相册');
      if (savedVideos > 0) parts.add('已保存$savedVideos个视频到相册');
      if (copiedText) parts.add('文案已复制');
      if (parts.isEmpty) parts.add('已解析链接，但没有拿到可保存素材');
      if (saveError != null) {
        toast(context, '解析成功，相册保存失败：$saveError');
      } else {
        toast(context, parts.join('，'));
      }
    } catch (e) {
      if (!mounted) return;
      toast(context, '解析下载失败：${_friendlyError(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyError(Object error) => error
      .toString()
      .replaceFirst(RegExp(r'^FormatException:\s*'), '')
      .replaceFirst(RegExp(r'^HttpException:\s*'), '')
      .replaceFirst(RegExp(r'^PlatformException\([^,]+,\s*'), '')
      .replaceFirst(RegExp(r',\s*null,\s*null\)$'), '');

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppFormField(
        controller: _linkCtrl,
        label: '商品链接或分享口令',
        hint: '支持闲鱼、小红书，以及可公开访问的商品页',
        icon: Icons.link_rounded,
        keyboardType: TextInputType.multiline,
        maxLines: 4,
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _clearInput,
              icon: Icon(Icons.clear_rounded, size: 17),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              label: const Text('清空内容'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed: _busy ? null : _importMaterial,
              icon:
                  _busy
                      ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: C.primaryButtonFg,
                        ),
                      )
                      : Icon(Icons.download_rounded, size: 17),
              style: FilledButton.styleFrom(
                backgroundColor: C.primaryButtonBg,
                foregroundColor: C.primaryButtonFg,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: C.primaryButtonBorder),
                ),
              ),
              label: Text(_busy ? '解析中' : '解析下载'),
            ),
          ),
        ],
      ),
      if (_result != null) ...[
        const SizedBox(height: 14),
        _LinkImportResultCard(
          result: _result!,
          savedImageCount: _savedImageCount ?? 0,
          savedVideoCount: _savedVideoCount ?? 0,
          copiedText: _copiedText,
          saveError: _saveError,
        ),
      ],
    ],
  );
}

class _LinkImportResultCard extends StatelessWidget {
  final EcommerceMaterialImportResult result;
  final int savedImageCount;
  final int savedVideoCount;
  final bool copiedText;
  final String? saveError;

  const _LinkImportResultCard({
    required this.result,
    required this.savedImageCount,
    required this.savedVideoCount,
    required this.copiedText,
    this.saveError,
  });

  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: const EdgeInsets.all(12),
    radius: 14,
    color: C.bgCard,
    borderColor: C.border,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ImportBadge(
              icon: Icons.storefront_outlined,
              label: result.platform,
              color: C.primary,
            ),
            _ImportBadge(
              icon: Icons.photo_library_outlined,
              label: '图片 $savedImageCount/${result.images.length}',
              color: C.mint,
            ),
            if (result.videos.isNotEmpty || result.candidateVideoCount > 0)
              _ImportBadge(
                icon: Icons.play_circle_outline_rounded,
                label:
                    '视频 $savedVideoCount/${result.videos.isNotEmpty ? result.videos.length : result.candidateVideoCount}',
                color: C.orange,
              ),
            _ImportBadge(
              icon:
                  copiedText
                      ? Icons.content_copy_rounded
                      : Icons.text_snippet_outlined,
              label: copiedText ? '文案已复制' : '未提取到文案',
              color: copiedText ? C.purple : C.orange,
            ),
          ],
        ),
        if (result.title.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            result.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: C.t1,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              height: 1.35,
            ),
          ),
        ],
        if (result.images.isNotEmpty || result.videos.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount:
                  (result.images.length + result.videos.length) > 12
                      ? 12
                      : result.images.length + result.videos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index >= result.images.length) {
                  final video = result.videos[index - result.images.length];
                  return _VideoPreviewTile(path: video.savedPath);
                }
                final image = result.images[index];
                return LocalImageThumb(
                  path: image.savedPath,
                  width: 72,
                  height: 72,
                  radius: 8,
                  alignment: Alignment.center,
                );
              },
            ),
          ),
        ],
        if (saveError != null) ...[
          const SizedBox(height: 9),
          _ImportNote(icon: Icons.error_outline_rounded, text: saveError!),
        ],
        ...result.warnings
            .take(2)
            .map(
              (warning) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _ImportNote(
                  icon: Icons.info_outline_rounded,
                  text: warning,
                ),
              ),
            ),
      ],
    ),
  );
}

class _VideoPreviewTile extends StatelessWidget {
  final String path;

  const _VideoPreviewTile({required this.path});

  @override
  Widget build(BuildContext context) {
    final name = path.split(Platform.pathSeparator).last;
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: C.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: C.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.play_circle_fill_rounded, color: C.orange, size: 26),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: C.t3,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _ImportBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: color.withValues(alpha: 0.28)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _ImportNote extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ImportNote({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 15, color: C.t3),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: C.t3,
            fontSize: 11,
            height: 1.35,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
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
      color: C.isLight ? C.bgCardMuted : C.bgSurface,
      borderRadius: BorderRadius.circular(C.radiusMd),
      border: Border.all(color: C.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: C.t3,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
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
  Widget build(BuildContext context) {
    final primary = C.isLight && color == C.primary;
    final tileBg =
        C.isLight
            ? primary
                ? C.bgCard
                : C.bgCardMuted
            : color.withValues(alpha: 0.12);
    final tileBorder =
        C.isLight
            ? primary
                ? C.selected.withValues(alpha: 0.55)
                : color.withValues(alpha: 0.20)
            : color.withValues(alpha: 0.26);
    final iconBg = primary ? C.selected : color;
    final iconFg = C.isLight && !primary ? Colors.white : Colors.black;
    final arrow = primary ? C.selectedText : color;
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: tileBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(C.radiusMd),
          side: BorderSide(color: tileBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(C.radiusSm),
                  ),
                  child: Icon(icon, color: iconFg, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: C.t1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: C.t2.withValues(alpha: 0.88),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded, color: arrow, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
  Widget build(BuildContext context) {
    final devices =
        gStorage
            .getDevices()
            .where((d) => d.status == 'in_stock' || d.status == 'listed')
            .toList();
    final priced = devices.where((d) => d.sellPrice > 0).toList();
    final estimatedProfit = priced.fold<int>(0, (sum, d) {
      final cost = d.purchaseCost + (d.repairCost ?? 0);
      final profit = d.sellPrice - cost;
      return profit > 0 ? sum + profit : sum;
    });
    final avgStockDays =
        devices.isEmpty
            ? 0
            : (devices.fold<int>(0, (sum, d) => sum + d.stockDays) /
                    devices.length)
                .round();
    final agingCount = stagnant.length;

    return LayoutBuilder(
      builder: (context, box) {
        final columns = box.maxWidth >= 520 ? 3 : 1;
        final itemWidth = (box.maxWidth - (columns - 1) * 8) / columns;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SizedBox(
              width: itemWidth,
              child: _AlertTile(
                icon: Icons.account_balance_wallet_outlined,
                title: '库存资金',
                value: yuan(stats.capitalOccupied),
                subtitle: '${devices.length} 台在库/在售',
                color: C.orange,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _AlertTile(
                icon: Icons.trending_up_rounded,
                title: '预估毛利',
                value: yuan(estimatedProfit),
                subtitle: '${priced.length} 台已定价',
                color: C.green,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _AlertTile(
                icon: Icons.schedule_rounded,
                title: '平均库龄',
                value: '${avgStockDays}天',
                subtitle: agingCount > 0 ? '$agingCount 台超过15天' : '周转正常',
                color: agingCount > 0 ? C.orange : C.blue,
                onTap: onStagnantTap,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AlertTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String? subtitle;
  final Color color;
  final VoidCallback? onTap;

  const _AlertTile({
    required this.icon,
    required this.title,
    required this.value,
    this.subtitle,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: const EdgeInsets.all(12),
    radius: C.radiusLg,
    color: C.bgCard,
    onTap: onTap,
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(C.radiusSm),
          ),
          child: Icon(icon, color: color, size: 18),
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
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    color: C.t1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  color: C.t2,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: C.t3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _TrendPanel extends StatefulWidget {
  final List<DailyStat> daily;
  final List<DailyStat> weekly;

  const _TrendPanel({required this.daily, required this.weekly});

  @override
  State<_TrendPanel> createState() => _TrendPanelState();
}

class _TrendPanelState extends State<_TrendPanel> {
  bool weeklyMode = false;

  @override
  Widget build(BuildContext context) {
    final source = weeklyMode ? widget.weekly : widget.daily;
    final data = source.map((d) => d.profit.toDouble()).toList();
    final labels =
        source
            .map((d) => d.date.length > 5 ? d.date.substring(5) : d.date)
            .toList();
    final total = source.fold<int>(0, (sum, d) => sum + d.profit);
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      radius: C.radiusLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: SectionTitle('毛利时间线', icon: Icons.timeline_rounded),
              ),
              _TrendToggle(
                weeklyMode: weeklyMode,
                onChanged: (value) => setState(() => weeklyMode = value),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              StatusChip(
                weeklyMode ? '本月 ${yuan(total)}' : '7日 ${yuan(total)}',
                C.primary,
              ),
              const SizedBox(width: 8),
              Text(
                weeklyMode ? '按月内自然周聚合' : '最近 7 天净利',
                style: TextStyle(
                  color: C.t3,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 150,
            child: CustomPaint(
              painter: LineChartPainter(
                data,
                labels,
                lineColor: C.primary,
                showPointLabels: true,
              ),
              size: Size.infinite,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendToggle extends StatelessWidget {
  final bool weeklyMode;
  final ValueChanged<bool> onChanged;

  const _TrendToggle({required this.weeklyMode, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: C.bgSurface,
      borderRadius: BorderRadius.circular(C.radiusMd),
      border: Border.all(color: C.border),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _item('日', !weeklyMode, () => onChanged(false)),
        _item('周', weeklyMode, () => onChanged(true)),
      ],
    ),
  );

  Widget _item(String label, bool selected, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: C.fast,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color:
                selected
                    ? (C.isLight ? C.selected : C.primary)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(C.radiusSm),
          ),
          child: Text(
            label,
            style: TextStyle(
              color:
                  selected ? (C.isLight ? C.selectedText : Colors.black) : C.t2,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
}

class _ChannelPanel extends StatelessWidget {
  final Map<String, int> channelGmv;

  const _ChannelPanel({required this.channelGmv});

  @override
  Widget build(BuildContext context) {
    final total = channelGmv.values.fold<int>(0, (a, b) => a + b);
    final colors = [C.primary, C.blue, C.green, C.orange, C.purple];
    final entries = channelGmv.entries.toList();
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      radius: C.radiusLg,
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
                      color: color.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(C.radiusSm),
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
                                style: TextStyle(
                                  color: C.t1,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Text(
                              '${(pct * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
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
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.08,
                            ),
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
  final int openTaskCount;
  final int criticalCount;

  const _AiPanel({
    required this.onTap,
    required this.openTaskCount,
    required this.criticalCount,
  });

  @override
  Widget build(BuildContext context) {
    final hasTasks = openTaskCount > 0;
    final color = criticalCount > 0 ? C.red : (hasTasks ? C.orange : C.mint);
    final status = hasTasks ? '$openTaskCount项' : '正常';
    final subtitle =
        hasTasks
            ? '${criticalCount > 0 ? '$criticalCount项急需处理 · ' : ''}今日自动巡店已生成待办'
            : '今日没有硬风险，可继续生成经营复盘';
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      radius: C.radiusLg,
      color: C.bgCard,
      borderColor: color.withValues(alpha: hasTasks ? 0.30 : 0.18),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(C.radiusLg),
            ),
            child: Icon(
              hasTasks ? Icons.rule_rounded : Icons.verified_outlined,
              color: color,
              size: 23,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '自动巡店',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: C.t1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: C.t2,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            constraints: const BoxConstraints(minWidth: 42, maxWidth: 58),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withValues(alpha: 0.18)),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                status,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: C.t2),
        ],
      ),
    );
  }
}
