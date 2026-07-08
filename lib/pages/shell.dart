import 'dart:async';

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
        color: C.nav,
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
                color: C.isLight ? C.hudDark : C.primary,
                borderRadius: BorderRadius.circular(C.radiusLg),
              ),
              child: Icon(
                Icons.tablet_mac_rounded,
                color: C.isLight ? C.purple : Colors.black,
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
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: C.nav,
      border: Border(top: BorderSide(color: C.navBorder)),
    ),
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 70,
        child: Row(
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
      ),
    ),
  );
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: AnimatedContainer(
            duration: C.fast,
            constraints: const BoxConstraints(minWidth: 54, minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color:
                  primary
                      ? primaryBg
                      : active
                      ? selectedBg
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(C.radiusMd),
              border:
                  active && !primary
                      ? Border.all(
                        color:
                            C.isLight
                                ? C.purple.withValues(alpha: 0.32)
                                : C.primary.withValues(alpha: 0.24),
                      )
                      : C.isLight && primary
                      ? Border.all(color: Colors.transparent)
                      : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  active ? item.activeIcon : item.icon,
                  color: primary ? primaryFg : fg,
                  size: primary ? 23 : 21,
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
                active && !primary
                    ? C.isLight
                        ? C.purple.withValues(alpha: 0.32)
                        : C.primary.withValues(alpha: 0.24)
                    : Colors.transparent,
          ),
        ),
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
