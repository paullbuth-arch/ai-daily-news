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
      borderRadius: BorderRadius.circular(C.radiusXl),
      side: BorderSide(color: C.borderGlow.withValues(alpha: 0.36)),
    ),
    clipBehavior: Clip.antiAlias,
    child: Ink(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(C.radiusXl),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF2B2F3E),
            Color(0xFF141722),
            Color(0xFF202432),
            Color(0xFF3C4052),
          ],
          stops: [0, 0.42, 0.72, 1],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: _HelmetHudPainter()),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
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
                _HeroVisualModule(count: stats.inStockCount),
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
                            '货脉实时看板',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.90),
                              fontSize: 31,
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
                                fontSize: 54,
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

class _HelmetHudPainter extends CustomPainter {
  const _HelmetHudPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final silver =
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFE9EAF1).withValues(alpha: 0.22),
              const Color(0xFF9CA2B6).withValues(alpha: 0.12),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.24, size.height * 0.16),
              radius: size.width * 0.60,
            ),
          );
    canvas.drawRect(rect, silver);

    final terrain =
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0x004B526A), Color(0x824B526A), Color(0xD010121A)],
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
    for (double x = -size.width * 0.20; x < size.width; x += 42) {
      canvas.drawLine(
        Offset(x, size.height * 0.52),
        Offset(x + size.width * 0.16, size.height),
        grid,
      );
    }

    final orbit =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.13)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
    final center = Offset(size.width * 0.50, size.height * 0.08);
    for (final radius in [110.0, 166.0, 232.0, 304.0]) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        math.pi * 0.40,
        math.pi * 1.08,
        false,
        orbit,
      );
    }

    final scanner =
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.transparent,
              const Color(0xFFE9EAF8).withValues(alpha: 0.48),
              Colors.transparent,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(Rect.fromLTWH(0, 0, 1, size.height))
          ..strokeWidth = 1.4;
    final scanX = size.width - 42;
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

    final frame =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.24)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
    const inset = 12.0;
    const len = 28.0;
    canvas.drawLine(
      const Offset(inset, inset),
      const Offset(inset + len, inset),
      frame,
    );
    canvas.drawLine(
      const Offset(inset, inset),
      const Offset(inset, inset + len),
      frame,
    );
    canvas.drawLine(
      Offset(size.width - inset - len, inset),
      Offset(size.width - inset, inset),
      frame,
    );
    canvas.drawLine(
      Offset(size.width - inset, inset),
      Offset(size.width - inset, inset + len),
      frame,
    );
    canvas.drawLine(
      Offset(inset, size.height - inset - len),
      Offset(inset, size.height - inset),
      frame,
    );
    canvas.drawLine(
      Offset(inset, size.height - inset),
      Offset(inset + len, size.height - inset),
      frame,
    );
    canvas.drawLine(
      Offset(size.width - inset - len, size.height - inset),
      Offset(size.width - inset, size.height - inset),
      frame,
    );
    canvas.drawLine(
      Offset(size.width - inset, size.height - inset - len),
      Offset(size.width - inset, size.height - inset),
      frame,
    );

    final pulse =
        Paint()
          ..color = const Color(0xFF9C7DFF).withValues(alpha: 0.20)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(Offset(size.width * 0.18, size.height * 0.38), 28, pulse);

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

class _HeroVisualModule extends StatelessWidget {
  final int count;

  const _HeroVisualModule({required this.count});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 258,
    child: Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.34)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFF2F3F8),
              Color(0xFFD7DAE4),
              Color(0xFF8C94AA),
              Color(0xFF252533),
            ],
            stops: [0, 0.38, 0.70, 1],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(
              child: CustomPaint(painter: _DeviceCorePainter()),
            ),
            Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 88,
                  height: 23,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 8,
                        offset: Offset.zero,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 14,
              top: 42,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'S    E    A',
                    style: TextStyle(
                      color: const Color(0xFF11131D).withValues(alpha: 0.76),
                      fontSize: 10,
                      height: 1.0,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'T    L    R',
                    style: TextStyle(
                      color: const Color(0xFF11131D).withValues(alpha: 0.76),
                      fontSize: 10,
                      height: 1.0,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 72,
              child: Text(
                'INFORMATION AND ANALYSIS OF',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.74),
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 42,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'PLANETS IN REAL TIME',
                  maxLines: 1,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.94),
                    fontSize: 27,
                    height: 0.95,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 34,
              right: 34,
              bottom: 12,
              child: Container(
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF7F5FFF).withValues(alpha: 0.86),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFFE6DDFF).withValues(alpha: 0.82),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF9A78FF).withValues(alpha: 0.48),
                      blurRadius: 14,
                      offset: Offset.zero,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: CustomPaint(painter: _CtaFramePainter()),
                    ),
                    Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '$count UNITS LIVE',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DeviceCorePainter extends CustomPainter {
  const _DeviceCorePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final silverWash =
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.70),
              const Color(0xFFD9DCE8).withValues(alpha: 0.30),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.30, size.height * 0.22),
              radius: size.width * 0.62,
            ),
          );
    canvas.drawRect(rect, silverWash);

    final glow =
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFF896CFF).withValues(alpha: 0.68),
              const Color(0xFF27195E).withValues(alpha: 0.48),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.36, size.height * 0.44),
              radius: size.shortestSide * 0.54,
            ),
          );
    canvas.drawRect(rect, glow);

    final orbit =
        Paint()
          ..color = const Color(0xFF151824).withValues(alpha: 0.13)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
    final orbitCenter = Offset(size.width * 0.55, size.height * 0.06);
    for (final radius in [96.0, 142.0, 188.0, 242.0]) {
      canvas.drawArc(
        Rect.fromCircle(center: orbitCenter, radius: radius),
        math.pi * 0.62,
        math.pi * 1.18,
        false,
        orbit,
      );
    }

    final grain =
        Paint()
          ..color = const Color(0xFF202333).withValues(alpha: 0.10)
          ..strokeWidth = 1;
    for (double x = 9; x < size.width; x += 13) {
      for (double y = 9; y < size.height; y += 13) {
        canvas.drawCircle(Offset(x, y), 0.7, grain);
      }
    }

    final shadowShell =
        Paint()
          ..color = const Color(0xFF353947).withValues(alpha: 0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 36
          ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(size.width * 0.46, size.height * 0.47),
        width: size.width * 0.96,
        height: size.height * 1.04,
      ),
      math.pi * 0.58,
      math.pi * 1.48,
      false,
      shadowShell,
    );

    final shell =
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFFF4F5FA), Color(0xFFBAC0CE), Color(0xFF737D94)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(rect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 30
          ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(size.width * 0.46, size.height * 0.47),
        width: size.width * 0.92,
        height: size.height * 0.98,
      ),
      math.pi * 0.60,
      math.pi * 1.45,
      false,
      shell,
    );

    final shellEdge =
        Paint()
          ..color = const Color(0xFF171A24).withValues(alpha: 0.32)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(size.width * 0.46, size.height * 0.47),
        width: size.width * 0.92,
        height: size.height * 0.98,
      ),
      math.pi * 0.60,
      math.pi * 1.45,
      false,
      shellEdge,
    );

    final visor =
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFBBAAFF),
              const Color(0xFF6046D9),
              const Color(0xFF1A1230),
              const Color(0xFF06050B),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.34, size.height * 0.45),
              radius: size.shortestSide * 0.34,
            ),
          );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.34, size.height * 0.45),
        width: size.width * 0.34,
        height: size.height * 0.38,
      ),
      visor,
    );

    final visorEdge =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.46)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.34, size.height * 0.45),
        width: size.width * 0.37,
        height: size.height * 0.41,
      ),
      visorEdge,
    );

    final wire =
        Paint()
          ..color = const Color(0xFF7E65FF).withValues(alpha: 0.84)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2
          ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 5; i++) {
      final path =
          Path()
            ..moveTo(size.width * 0.25, size.height * (0.34 + i * 0.045))
            ..quadraticBezierTo(
              size.width * 0.57,
              size.height * (0.20 + i * 0.045),
              size.width * 0.88,
              size.height * (0.36 + i * 0.030),
            );
      canvas.drawPath(path, wire);
    }

    final lens =
        Paint()
          ..color = const Color(0xFF161821).withValues(alpha: 0.62)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7;
    final lensCenter = Offset(size.width * 0.73, size.height * 0.39);
    canvas.drawCircle(lensCenter, size.shortestSide * 0.17, lens);
    canvas.drawCircle(lensCenter, size.shortestSide * 0.08, lens);
    canvas.drawCircle(
      lensCenter,
      size.shortestSide * 0.035,
      Paint()..color = const Color(0xFF0A0B10).withValues(alpha: 0.86),
    );

    final screw =
        Paint()..color = const Color(0xFF11131D).withValues(alpha: 0.78);
    for (final p in [
      Offset(size.width * 0.54, size.height * 0.25),
      Offset(size.width * 0.58, size.height * 0.56),
      Offset(size.width * 0.78, size.height * 0.59),
      Offset(size.width * 0.47, size.height * 0.67),
    ]) {
      canvas.drawCircle(p, 3.2, screw);
      canvas.drawCircle(p, 1.0, Paint()..color = Colors.white24);
    }

    final neck =
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0x99C9CEDB), Color(0x773A4054)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(rect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 20
          ..strokeCap = StrokeCap.round;
    final neckPath =
        Path()
          ..moveTo(size.width * 0.45, size.height * 0.70)
          ..quadraticBezierTo(
            size.width * 0.42,
            size.height * 0.88,
            size.width * 0.55,
            size.height * 1.05,
          );
    canvas.drawPath(neckPath, neck);

    final frame =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.38)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
    const inset = 8.0;
    const len = 18.0;
    canvas.drawLine(
      const Offset(inset, inset),
      const Offset(inset + len, inset),
      frame,
    );
    canvas.drawLine(
      const Offset(inset, inset),
      const Offset(inset, inset + len),
      frame,
    );
    canvas.drawLine(
      Offset(size.width - inset - len, inset),
      Offset(size.width - inset, inset),
      frame,
    );
    canvas.drawLine(
      Offset(size.width - inset, inset),
      Offset(size.width - inset, inset + len),
      frame,
    );

    final shade =
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.18),
              Colors.black.withValues(alpha: 0.42),
            ],
            stops: const [0, 0.58, 1],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(rect);
    canvas.drawRect(rect, shade);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CtaFramePainter extends CustomPainter {
  const _CtaFramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final line =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.54)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
    final glow =
        Paint()
          ..color = const Color(0xFFD9CBFF).withValues(alpha: 0.48)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4;
    final mid = size.width / 2;
    final y = size.height / 2;
    final path =
        Path()
          ..moveTo(8, 7)
          ..lineTo(mid - 20, 7)
          ..lineTo(mid - 12, y)
          ..lineTo(mid + 12, y)
          ..lineTo(mid + 20, 7)
          ..lineTo(size.width - 8, 7)
          ..lineTo(size.width - 8, size.height - 7)
          ..lineTo(mid + 20, size.height - 7)
          ..lineTo(mid + 12, y)
          ..lineTo(mid - 12, y)
          ..lineTo(mid - 20, size.height - 7)
          ..lineTo(8, size.height - 7)
          ..close();
    canvas.drawPath(path, glow);
    canvas.drawPath(path, line);
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
          blurRadius: 6,
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
    decoration: BoxDecoration(
      color: const Color(0xFF100D15).withValues(alpha: 0.44),
      borderRadius: BorderRadius.circular(C.radiusMd),
      border: Border.all(color: color.withValues(alpha: 0.36)),
    ),
    child: Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(painter: _MetricFramePainter(color: color)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.66),
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
                    fontSize: 20,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _MetricFramePainter extends CustomPainter {
  final Color color;

  const _MetricFramePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 24 || size.height < 24) return;
    final line =
        Paint()
          ..color = color.withValues(alpha: 0.24)
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke;
    const inset = 6.0;
    const len = 12.0;
    canvas.drawLine(
      const Offset(inset, inset),
      const Offset(inset + len, inset),
      line,
    );
    canvas.drawLine(
      const Offset(inset, inset),
      const Offset(inset, inset + len),
      line,
    );
    canvas.drawLine(
      Offset(size.width - inset - len, inset),
      Offset(size.width - inset, inset),
      line,
    );
    canvas.drawLine(
      Offset(size.width - inset, inset),
      Offset(size.width - inset, inset + len),
      line,
    );
    canvas.drawLine(
      Offset(inset, size.height - inset - len),
      Offset(inset, size.height - inset),
      line,
    );
    canvas.drawLine(
      Offset(inset, size.height - inset),
      Offset(inset + len, size.height - inset),
      line,
    );
    canvas.drawLine(
      Offset(size.width - inset - len, size.height - inset),
      Offset(size.width - inset, size.height - inset),
      line,
    );
    canvas.drawLine(
      Offset(size.width - inset, size.height - inset - len),
      Offset(size.width - inset, size.height - inset),
      line,
    );
    final scan =
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.transparent,
              color.withValues(alpha: 0.28),
              Colors.transparent,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(Rect.fromLTWH(0, 0, 1, size.height))
          ..strokeWidth = 1;
    canvas.drawLine(
      Offset(size.width - 12, size.height * 0.22),
      Offset(size.width - 12, size.height * 0.78),
      scan,
    );
    canvas.drawLine(
      Offset(size.width * 0.12, size.height * 0.50),
      Offset(size.width * 0.88, size.height * 0.50),
      scan,
    );

    final faint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.055)
          ..strokeWidth = 1;
    for (double x = size.width * 0.18; x < size.width; x += 28) {
      canvas.drawLine(
        Offset(x, size.height * 0.62),
        Offset(x + size.width * 0.08, size.height),
        faint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MetricFramePainter oldDelegate) =>
      oldDelegate.color != color;
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
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(C.radiusMd),
      border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
    ),
    child: Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(painter: _MetricFramePainter(color: color)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
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
    height: 48,
    child: Material(
      color: Colors.black.withValues(alpha: 0.24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(C.radiusMd),
        side: BorderSide(color: color.withValues(alpha: 0.44)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _MetricFramePainter(color: color)),
            ),
            Center(
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
    gradient: LinearGradient(
      colors: [
        const Color(0xFF292D3C),
        const Color(0xFF11131C),
        color.withValues(alpha: 0.16),
        const Color(0xFF343A50),
      ],
      stops: const [0, 0.44, 0.74, 1],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderColor: color.withValues(alpha: 0.26),
    onTap: onTap,
    child: SizedBox(
      height: 104,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _MetricFramePainter(color: color)),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.24),
                borderRadius: BorderRadius.circular(C.radiusMd),
                border: Border.all(color: color.withValues(alpha: 0.34)),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.14),
                    blurRadius: 8,
                    offset: Offset.zero,
                  ),
                ],
              ),
              child: CustomPaint(
                painter: _PulseGlyphPainter(color: color),
                child: Icon(icon, color: color, size: 20),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 54,
            top: 0,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (subtitle != null)
            Positioned(
              left: 0,
              right: 54,
              top: 20,
              child: Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: C.t3,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 68,
            bottom: 20,
            child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 32,
                  height: 0.95,
                  color: C.t1,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Row(
              children: [
                Expanded(child: _AlertSignalBars(color: color)),
                const SizedBox(width: 10),
                Text(
                  'LIVE',
                  style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _AlertSignalBars extends StatelessWidget {
  final Color color;

  const _AlertSignalBars({required this.color});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 12,
    child: Row(
      children: List.generate(8, (index) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index == 7 ? 0 : 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: index < 5 ? 0.52 : 0.12),
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: color.withValues(alpha: 0.20)),
            ),
          ),
        );
      }),
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
      gradient: const LinearGradient(
        colors: [Color(0xFF252938), Color(0xFF11131C), Color(0xFF353A51)],
        stops: [0, 0.52, 1],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderColor: C.purple.withValues(alpha: 0.36),
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
          const SizedBox(height: 8),
          Container(
            height: 176,
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(C.radiusMd),
              border: Border.all(color: C.purple.withValues(alpha: 0.22)),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _MetricFramePainter(color: C.purple),
                  ),
                ),
                Positioned(
                  left: 2,
                  top: 0,
                  child: Text(
                    'PROFIT TRACE',
                    style: TextStyle(
                      color: C.purple.withValues(alpha: 0.88),
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Positioned(
                  right: 2,
                  top: 0,
                  child: Text(
                    'DISTANCE: 7D',
                    style: TextStyle(
                      color: C.t3,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Positioned.fill(
                  top: 18,
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
          ),
          const SizedBox(height: 10),
          _SignalReadouts(
            total: total,
            sampleCount: source.length,
            positive: total >= 0,
          ),
        ],
      ),
    );
  }
}

class _SignalReadouts extends StatelessWidget {
  final int total;
  final int sampleCount;
  final bool positive;

  const _SignalReadouts({
    required this.total,
    required this.sampleCount,
    required this.positive,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _SignalReadout(
          title: 'PROFIT SIGNAL',
          value: yuan(total),
          state: positive ? 'NORMAL' : 'ALERT',
          color: positive ? C.purple : C.red,
          painter: _WaveGlyphPainter(color: positive ? C.purple : C.red),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _SignalReadout(
          title: 'FLOW CYCLE',
          value: '$sampleCount',
          state: 'WINDOW',
          color: C.blue,
          painter: _PulseGlyphPainter(color: C.blue),
        ),
      ),
    ],
  );
}

class _SignalReadout extends StatelessWidget {
  final String title;
  final String value;
  final String state;
  final Color color;
  final CustomPainter painter;

  const _SignalReadout({
    required this.title,
    required this.value,
    required this.state,
    required this.color,
    required this.painter,
  });

  @override
  Widget build(BuildContext context) => Container(
    height: 94,
    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.20),
      borderRadius: BorderRadius.circular(C.radiusMd),
      border: Border.all(color: color.withValues(alpha: 0.30)),
    ),
    child: Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(painter: _MetricFramePainter(color: color)),
        ),
        Positioned(
          top: 2,
          left: 0,
          right: 0,
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Positioned(
          left: 0,
          bottom: 8,
          child: SizedBox(
            width: 76,
            height: 32,
            child: CustomPaint(painter: painter),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 16,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: C.t1,
                fontSize: 25,
                height: 0.92,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        Positioned(
          right: 1,
          bottom: 0,
          child: Text(
            state,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),
  );
}

class _WaveGlyphPainter extends CustomPainter {
  final Color color;

  const _WaveGlyphPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final dim =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.18)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(0, size.height * 0.70),
      Offset(size.width, size.height * 0.70),
      dim,
    );

    final glow =
        Paint()
          ..color = color.withValues(alpha: 0.25)
          ..strokeWidth = 6
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final line =
        Paint()
          ..color = color
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
    final path =
        Path()
          ..moveTo(2, size.height * 0.62)
          ..lineTo(size.width * 0.18, size.height * 0.62)
          ..lineTo(size.width * 0.26, size.height * 0.30)
          ..lineTo(size.width * 0.34, size.height * 0.82)
          ..lineTo(size.width * 0.44, size.height * 0.46)
          ..lineTo(size.width * 0.52, size.height * 0.68)
          ..lineTo(size.width * 0.68, size.height * 0.68)
          ..lineTo(size.width * 0.77, size.height * 0.24)
          ..lineTo(size.width * 0.86, size.height * 0.62)
          ..lineTo(size.width - 2, size.height * 0.62);
    canvas.drawPath(path, glow);
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _WaveGlyphPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _PulseGlyphPainter extends CustomPainter {
  final Color color;

  const _PulseGlyphPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final grid =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.14)
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke;
    for (final dx in [0.22, 0.50, 0.78]) {
      canvas.drawCircle(
        Offset(size.width * dx, size.height * 0.58),
        size.height * 0.18,
        grid,
      );
    }
    final glow =
        Paint()
          ..color = color.withValues(alpha: 0.26)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final line =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
    final rect = Rect.fromCenter(
      center: Offset(size.width * 0.50, size.height * 0.58),
      width: size.width * 0.86,
      height: size.height * 0.72,
    );
    canvas.drawArc(rect, -0.4, 3.8, false, glow);
    canvas.drawArc(rect, -0.4, 3.8, false, line);
    canvas.drawCircle(
      Offset(size.width * 0.50, size.height * 0.58),
      3.2,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _PulseGlyphPainter oldDelegate) =>
      oldDelegate.color != color;
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
      gradient: const LinearGradient(
        colors: [Color(0xFF222735), Color(0xFF11131B), Color(0xFF30364A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderColor: C.blue.withValues(alpha: 0.28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('渠道占比', icon: Icons.donut_large_rounded),
          const SizedBox(height: 4),
          Container(
            height: 78,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(C.radiusMd),
              border: Border.all(color: C.blue.withValues(alpha: 0.24)),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _MetricFramePainter(color: C.blue),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  child: Text(
                    'CHANNEL DATA',
                    style: TextStyle(
                      color: C.blue,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      yuan(total),
                      style: TextStyle(
                        color: C.t1,
                        fontSize: 30,
                        height: 0.95,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 5,
                  child: SizedBox(
                    width: 92,
                    height: 34,
                    child: CustomPaint(
                      painter: _WaveGlyphPainter(color: C.blue),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...entries.asMap().entries.map((e) {
            final color = colors[e.key % colors.length];
            final value = e.value.value;
            final pct = total == 0 ? 0.0 : value / total;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(C.radiusMd),
                  border: Border.all(color: color.withValues(alpha: 0.20)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(C.radiusSm),
                        border: Border.all(
                          color: color.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Icon(
                        Icons.storefront_outlined,
                        color: color,
                        size: 18,
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
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Text(
                                '${(pct * 100).toStringAsFixed(0)}%',
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 7),
                          _HudProgress(value: pct, color: color),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _HudProgress extends StatelessWidget {
  final double value;
  final Color color;

  const _HudProgress({required this.value, required this.color});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 12,
    child: Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.055),
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
          ),
        ),
        FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: value.clamp(0.0, 1.0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.22),
                  blurRadius: 8,
                  offset: Offset.zero,
                ),
              ],
            ),
          ),
        ),
        Positioned.fill(
          child: Row(
            children: List.generate(
              7,
              (index) => Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(vertical: 1),
                    color: Colors.black.withValues(alpha: 0.25),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
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
    final status = hasTasks ? '$openTaskCount TASKS' : 'NORMAL';
    final title = hasTasks ? '待处理巡店任务' : '自动巡店正常';
    final subtitle = hasTasks ? '今日自动巡店已生成经营待办' : '今日没有硬风险，可以继续生成经营复盘';
    return GlassPanel(
      padding: const EdgeInsets.all(14),
      radius: C.radiusLg,
      gradient: const LinearGradient(
        colors: [Color(0xFF202432), Color(0xFF0E1018), Color(0xFF2B3043)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderColor: color.withValues(alpha: hasTasks ? 0.34 : 0.22),
      onTap: onTap,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _MetricFramePainter(color: color)),
          ),
          Row(
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: CustomPaint(
                  painter: _AiCorePainter(color: color, active: hasTasks),
                  child: Icon(
                    hasTasks ? Icons.rule_rounded : Icons.verified_outlined,
                    color: color,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AUTO PATROL',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
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
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    constraints: const BoxConstraints(
                      minWidth: 58,
                      maxWidth: 72,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(C.radiusSm),
                      border: Border.all(color: color.withValues(alpha: 0.24)),
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
                  const SizedBox(height: 8),
                  Icon(Icons.chevron_right_rounded, color: C.t2),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AiCorePainter extends CustomPainter {
  final Color color;
  final bool active;

  const _AiCorePainter({required this.color, required this.active});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final glow =
        Paint()
          ..color = color.withValues(alpha: active ? 0.24 : 0.14)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center, size.shortestSide * 0.38, glow);

    final ring =
        Paint()
          ..color = color.withValues(alpha: 0.36)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
    for (final r in [0.28, 0.42]) {
      canvas.drawCircle(center, size.shortestSide * r, ring);
    }

    final tick =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.34)
          ..strokeWidth = 1;
    for (int i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final a = Offset(
        center.dx + math.cos(angle) * size.shortestSide * 0.34,
        center.dy + math.sin(angle) * size.shortestSide * 0.34,
      );
      final b = Offset(
        center.dx + math.cos(angle) * size.shortestSide * 0.45,
        center.dy + math.sin(angle) * size.shortestSide * 0.45,
      );
      canvas.drawLine(a, b, tick);
    }
  }

  @override
  bool shouldRepaint(covariant _AiCorePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.active != active;
}
