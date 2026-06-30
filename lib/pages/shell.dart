import 'package:flutter/material.dart';
import '../components/page_scaffold.dart';
import '../theme/colors.dart';
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

  void _onTap(int i) {
    if (i == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ScanPage()),
      ).then((_) {
        _homeKey.currentState?.refresh();
        _stockKey.currentState?.refresh();
        _orderKey.currentState?.refresh();
      });
      return;
    }
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 860;
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
        body: Stack(
          children: [
            const AppBackdrop(),
            Row(
              children: [
                _SideDock(index: _index, onTap: _onTap),
                Expanded(child: IndexedStack(index: _index, children: pages)),
              ],
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: C.bgDeep,
      extendBody: true,
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: _BottomDock(index: _index, onTap: _onTap),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(this.icon, this.activeIcon, this.label);
}

const _items = [
  _NavItem(Icons.home_outlined, Icons.home_rounded, '看板'),
  _NavItem(Icons.inventory_2_outlined, Icons.inventory_2_rounded, '库存'),
  _NavItem(Icons.add_rounded, Icons.add_rounded, '收货'),
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
    child: SizedBox(
      width: 104,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 0, 18),
        child: GlassPanel(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
          radius: 28,
          color: const Color(0xE60A0C12),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: C.cyan,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: C.cyan.withOpacity(0.28),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.tablet_mac_rounded,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 24),
              ...List.generate(_items.length, (i) {
                if (i == 2) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: _RoundNavButton(
                      item: _items[i],
                      active: false,
                      primary: true,
                      onTap: () => onTap(i),
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RoundNavButton(
                    item: _items[i],
                    active: index == i,
                    onTap: () => onTap(i),
                  ),
                );
              }),
              const Spacer(),
              RoundIconButton(
                icon: Icons.search_rounded,
                onTap: () {},
                color: C.t2,
                size: 44,
              ),
            ],
          ),
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
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        radius: 28,
        color: const Color(0xF00C0E15),
        child: SizedBox(
          height: 58,
          child: Row(
            children: List.generate(_items.length, (i) {
              final primary = i == 2;
              return Expanded(
                child: Center(
                  child: _RoundNavButton(
                    item: _items[i],
                    active: index == i,
                    primary: primary,
                    onTap: () => onTap(i),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    ),
  );
}

class _RoundNavButton extends StatelessWidget {
  final _NavItem item;
  final bool active;
  final bool primary;
  final VoidCallback onTap;

  const _RoundNavButton({
    required this.item,
    required this.active,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg =
        primary
            ? Colors.white
            : active
            ? C.cyan.withOpacity(0.18)
            : Colors.transparent;
    final fg =
        primary
            ? Colors.black
            : active
            ? C.cyan
            : C.t3;
    return Tooltip(
      message: item.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(26),
          child: AnimatedContainer(
            duration: C.fast,
            width: primary ? 54 : 44,
            height: primary ? 54 : 44,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: Border.all(
                color:
                    primary
                        ? Colors.white
                        : active
                        ? C.cyan.withOpacity(0.24)
                        : Colors.white.withOpacity(0.03),
              ),
              boxShadow:
                  primary
                      ? [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.20),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ]
                      : null,
            ),
            child: Icon(
              active ? item.activeIcon : item.icon,
              color: fg,
              size: primary ? 25 : 21,
            ),
          ),
        ),
      ),
    );
  }
}
