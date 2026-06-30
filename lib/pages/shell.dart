import 'package:flutter/material.dart';
import '../theme/colors.dart';
import 'home_page.dart';
import 'stock_page.dart';
import 'scan_page.dart';
import 'order_page.dart';
import 'me_page.dart';

/// 主框架（侧边栏 / 底部导航自适应）
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
    final isWide = MediaQuery.of(context).size.width >= 820;
    final pages = <Widget>[
      HomePage(key: _homeKey),
      StockPage(key: _stockKey),
      const SizedBox(),
      OrderPage(key: _orderKey),
      const MePage(),
    ];
    if (isWide) {
      return Scaffold(
        backgroundColor: C.bg,
        body: Row(
          children: [
            _SideNav(index: _index, onTap: _onTap),
            Expanded(child: IndexedStack(index: _index, children: pages)),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: C.bg,
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: _BottomNav(index: _index, onTap: _onTap),
    );
  }
}

// ────────────── 导航定义 ──────────────
class _NavItem {
  final IconData icon;
  final IconData iconFilled;
  final String label;
  const _NavItem(this.icon, this.iconFilled, this.label);
}

const _navItems = [
  _NavItem(Icons.dashboard_outlined, Icons.dashboard, '看板'),
  _NavItem(Icons.inventory_2_outlined, Icons.inventory_2, '库存'),
  _NavItem(Icons.qr_code_scanner_rounded, Icons.qr_code_scanner_rounded, '收货'),
  _NavItem(Icons.receipt_long_outlined, Icons.receipt_long, '订单'),
  _NavItem(Icons.apps_outlined, Icons.apps, '更多'),
];

// ────────────── 侧边栏导航（平板/宽屏） ──────────────
class _SideNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _SideNav({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) => SafeArea(
    right: false,
    child: Container(
      width: 240,
      decoration: BoxDecoration(
        color: C.nav,
        border: Border(right: BorderSide(color: C.navBorder, width: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo 区域
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: C.metricGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: C.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.tablet_mac_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '机掌柜',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: C.t1,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Business Cockpit',
                      style: TextStyle(fontSize: 10, color: C.t3, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 导航项
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              children: [
                _sideNavItem(0),
                _sideNavItem(1),
                const SizedBox(height: 8),
                // 收货按钮（突出显示）
                _scanButton(),
                const SizedBox(height: 8),
                _sideNavItem(3),
                _sideNavItem(4),
              ],
            ),
          ),

          const Spacer(),

          // 底部版本信息
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: C.cardMuted,
                borderRadius: BorderRadius.circular(C.radiusMd),
                border: Border.all(color: C.line, width: 0.5),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: C.t3, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'v2.1.0 · 经营工作台',
                    style: TextStyle(fontSize: 11, color: C.t3, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _sideNavItem(int i) {
    final item = _navItems[i];
    final on = index == i;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap(i),
          borderRadius: BorderRadius.circular(C.radiusMd),
          child: AnimatedContainer(
            duration: C.fast,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: on ? C.selected : Colors.transparent,
              borderRadius: BorderRadius.circular(C.radiusMd),
            ),
            child: Row(
              children: [
                // 选中指示条
                AnimatedContainer(
                  duration: C.fast,
                  width: 3,
                  height: 20,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: on ? C.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Icon(
                  on ? item.iconFilled : item.icon,
                  color: on ? C.selectedText : C.t2,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: on ? FontWeight.w800 : FontWeight.w500,
                    color: on ? C.selectedText : C.t2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _scanButton() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap(2),
          borderRadius: BorderRadius.circular(C.radiusMd),
          child: Ink(
            decoration: BoxDecoration(
              gradient: C.metricGradient,
              borderRadius: BorderRadius.circular(C.radiusMd),
              boxShadow: [
                BoxShadow(
                  color: C.primary.withOpacity(0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    '扫码收货',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

// ────────────── 底部导航（手机） ──────────────
class _BottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: C.nav,
      border: Border(top: BorderSide(color: C.navBorder, width: 0.8)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_navItems.length, (i) => _bottomItem(i)),
        ),
      ),
    ),
  );

  Widget _bottomItem(int i) {
    final item = _navItems[i];
    final on = index == i;
    // 收货按钮特殊样式
    if (i == 2) {
      return Expanded(
        child: GestureDetector(
          onTap: () => onTap(i),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: C.metricGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: C.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: C.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(i),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: C.fast,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                on ? item.iconFilled : item.icon,
                color: on ? C.primary : C.t3,
                size: 22,
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: on ? FontWeight.w800 : FontWeight.w500,
                  color: on ? C.primary : C.t3,
                ),
              ),
              if (on)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Container(
                    width: 16,
                    height: 2.5,
                    decoration: BoxDecoration(
                      color: C.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
