import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../components/page_scaffold.dart';
import '../theme/colors.dart';
import '../main.dart';
import 'home_page.dart';
import 'stock_page.dart';
import 'scan_page.dart';
import 'order_page.dart';
import 'me_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({Key? key}) : super(key: key);

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  final _homeKey = GlobalKey<HomePageState>();
  final _stockKey = GlobalKey<StockPageState>();
  final _orderKey = GlobalKey<OrderPageState>();
  StreamSubscription<void>? _dataSub;

  @override
  void initState() {
    super.initState();
    _dataSub = gStorage.changes.listen((_) => _refreshDataPages());
  }

  @override
  void dispose() {
    _dataSub?.cancel();
    super.dispose();
  }

  void _refreshDataPages() {
    _homeKey.currentState?.refresh();
    _stockKey.currentState?.refresh();
    _orderKey.currentState?.refresh();
  }

  void _onTap(int i) {
    if (i == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ScanPage()),
      ).then((_) => _refreshDataPages());
      return;
    }
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final wide = AppLayout.hasSideDock(context);
    final pages = <Widget>[
      HomePage(key: _homeKey),
      StockPage(key: _stockKey),
      const SizedBox(),
      OrderPage(key: _orderKey),
      const MePage(),
    ];

    if (wide) {
      return Scaffold(
        backgroundColor: C.bgDeep,
        body: Row(
          children: [
            _SideDock(index: _index, onTap: _onTap),
            Expanded(child: _ShellPages(index: _index, children: pages)),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: C.bgDeep,
      extendBody: true,
      body: _ShellPages(index: _index, children: pages),
      bottomNavigationBar: _BottomDock(index: _index, onTap: _onTap),
    );
  }
}

class _ShellPages extends StatelessWidget {
  final int index;
  final List<Widget> children;

  const _ShellPages({required this.index, required this.children});

  @override
  Widget build(BuildContext context) =>
      IndexedStack(index: index, children: children);
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(this.icon, this.activeIcon, this.label);
}

const _items = [
  _NavItem(Icons.space_dashboard_outlined, Icons.space_dashboard_rounded, '看板'),
  _NavItem(Icons.inventory_2_outlined, Icons.inventory_2_rounded, '库存'),
  _NavItem(Icons.add_business_outlined, Icons.add_business_rounded, '收货'),
  _NavItem(Icons.receipt_long_outlined, Icons.receipt_long_rounded, '订单'),
  _NavItem(Icons.person_outline_rounded, Icons.person_rounded, '我的'),
];

class _SideDock extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;

  const _SideDock({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) => SafeArea(
    right: false,
    child: Container(
      width: 96,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [C.nav, C.bgCard.withValues(alpha: 0.94), C.nav],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(right: BorderSide(color: C.navBorder)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: C.isLight ? C.purpleGradient : C.cyanGradient,
                borderRadius: BorderRadius.circular(C.radiusLg),
                border: Border.all(color: C.purple.withValues(alpha: 0.40)),
              ),
              child: Icon(
                Icons.tablet_mac_rounded,
                color: C.isLight ? C.hudDark : Colors.black,
              ),
            ),
            const SizedBox(height: 22),
            ...List.generate(_items.length, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _RailButton(
                  item: _items[i],
                  active: index == i,
                  primary: i == 2,
                  onTap: () => onTap(i),
                ),
              );
            }),
            const Spacer(),
            RoundIconButton(
              icon: Icons.search_rounded,
              onTap: () {},
              color: C.isLight ? C.purple : C.t2,
              background: C.isLight ? C.hudDark : C.bgSurface,
              size: 44,
            ),
          ],
        ),
      ),
    ),
  );
}

class _BottomDock extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;

  const _BottomDock({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: SizedBox(
        height: 88,
        child: Material(
          color: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(C.radiusXl),
            side: BorderSide(color: C.borderGlow.withValues(alpha: 0.34)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xF7242836),
                        Color(0xFB090A11),
                        Color(0xF733384C),
                      ],
                      stops: [0, 0.52, 1],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(C.radiusXl),
                  ),
                ),
              ),
              const Positioned.fill(
                child: CustomPaint(painter: _DockPainter()),
              ),
              Row(
                children: List.generate(_items.length, (i) {
                  return Expanded(
                    child: _BottomNavButton(
                      item: _items[i],
                      active: index == i,
                      primary: i == 2,
                      onTap: () => onTap(i),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _DockPainter extends CustomPainter {
  const _DockPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final grid =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.055)
          ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += size.width / 5) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 18; y < size.height; y += 22) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final scan =
        Paint()
          ..shader = const LinearGradient(
            colors: [
              Color(0x00FFFFFF),
              Color(0x99F4EDFF),
              Color(0x889A7AFF),
              Color(0x00FFFFFF),
            ],
          ).createShader(Rect.fromLTWH(0, 0, size.width, 1))
          ..strokeWidth = 1.4;
    canvas.drawLine(const Offset(12, 9), Offset(size.width - 12, 9), scan);
    canvas.drawLine(
      Offset(size.width * 0.16, size.height - 11),
      Offset(size.width * 0.84, size.height - 11),
      scan,
    );

    final orbit =
        Paint()
          ..color = const Color(0xFFC9BBFF).withValues(alpha: 0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
    final center = Offset(size.width * 0.50, size.height * 0.44);
    for (final radius in [44.0, 72.0, 104.0]) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        math.pi * 0.05,
        math.pi * 0.90,
        false,
        orbit,
      );
    }

    final glow =
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFF9C78FF).withValues(alpha: 0.22),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(center: center, radius: size.width * 0.28),
          );
    canvas.drawRect(Offset.zero & size, glow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BottomNavButton extends StatelessWidget {
  final _NavItem item;
  final bool active;
  final bool primary;
  final VoidCallback onTap;

  const _BottomNavButton({
    required this.item,
    required this.active,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selectedFg = C.isLight ? C.purple : C.primary;
    final selectedBg =
        C.isLight ? C.selected : C.primary.withValues(alpha: 0.12);
    final primaryFg = active ? C.purple : C.t2;
    final primaryAccent = C.isLight ? C.cyan : C.primary;
    final fg = active ? selectedFg : C.t3;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: AnimatedContainer(
            duration: C.fast,
            constraints: BoxConstraints(
              minWidth: primary ? 64 : 54,
              minHeight: primary ? 66 : 56,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
            decoration: BoxDecoration(
              gradient:
                  primary
                      ? LinearGradient(
                        colors: [
                          const Color(0xFF0A0911),
                          primaryAccent.withValues(alpha: active ? 0.30 : 0.18),
                          const Color(0xFF202332),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                      : null,
              color:
                  primary
                      ? null
                      : active
                      ? selectedBg
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(C.radiusMd),
              border: Border.all(
                color:
                    primary
                        ? primaryAccent.withValues(alpha: active ? 0.50 : 0.34)
                        : active
                        ? C.purple.withValues(alpha: 0.38)
                        : Colors.white.withValues(alpha: 0.08),
              ),
              boxShadow:
                  active || primary
                      ? [
                        BoxShadow(
                          color: (primary ? primaryAccent : selectedFg)
                              .withValues(alpha: active ? 0.20 : 0.10),
                          blurRadius: 10,
                          offset: Offset.zero,
                        ),
                      ]
                      : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomPaint(
                  painter: _DockCellPainter(
                    color: primary ? primaryAccent : fg,
                    active: active || primary,
                  ),
                  child: SizedBox(
                    width: primary ? 34 : 28,
                    height: primary ? 28 : 24,
                    child: Icon(
                      active ? item.activeIcon : item.icon,
                      color: primary ? primaryFg : fg,
                      size: primary ? 22 : 20,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: primary ? primaryFg : fg,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DockCellPainter extends CustomPainter {
  final Color color;
  final bool active;

  const _DockCellPainter({required this.color, required this.active});

  @override
  void paint(Canvas canvas, Size size) {
    if (!active) return;
    final line =
        Paint()
          ..color = color.withValues(alpha: 0.30)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
    final rect = Rect.fromLTWH(3, 3, size.width - 6, size.height - 6);
    canvas.drawArc(rect, -math.pi * 0.12, math.pi * 1.08, false, line);
    canvas.drawLine(
      Offset(size.width * 0.18, size.height - 2),
      Offset(size.width * 0.82, size.height - 2),
      line,
    );
  }

  @override
  bool shouldRepaint(covariant _DockCellPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.active != active;
}

class _RailButton extends StatelessWidget {
  final _NavItem item;
  final bool active;
  final bool primary;
  final VoidCallback onTap;

  const _RailButton({
    required this.item,
    required this.active,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final selectedFg = C.isLight ? C.purple : C.primary;
    final selectedBg =
        C.isLight ? C.selected : C.primary.withValues(alpha: 0.12);
    final primaryBg =
        C.isLight
            ? active
                ? C.hudDark
                : Colors.transparent
            : C.primary;
    final primaryFg =
        C.isLight
            ? active
                ? C.purple
                : C.t3
            : Colors.black;
    final fg = active ? selectedFg : C.t3;
    return Tooltip(
      message: item.label,
      child: Material(
        color:
            primary
                ? primaryBg
                : active
                ? selectedBg
                : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(C.radiusMd),
          side: BorderSide(
            color:
                active
                    ? C.isLight
                        ? C.purple.withValues(alpha: 0.32)
                        : C.primary.withValues(alpha: 0.24)
                    : Colors.transparent,
          ),
        ),
        shadowColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: double.infinity,
            height: 58,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  active ? item.activeIcon : item.icon,
                  color: primary ? primaryFg : fg,
                  size: 22,
                ),
                const SizedBox(height: 4),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: primary ? primaryFg : fg,
                    fontSize: 10,
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
}
