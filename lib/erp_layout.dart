// ERP 侧边栏布局 + 库存增强功能
import 'package:flutter/material.dart';
import 'theme/colors.dart';
import 'main.dart' as app;

String yuan(int fen) => '¥${(fen / 100).toStringAsFixed(0)}';
void toast(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m, style: const TextStyle(fontSize: 13)), duration: const Duration(seconds: 2)));

// ======================================================================
// ERP 主布局：左侧导航 + 右侧内容区
// ======================================================================
class ErpShell extends StatefulWidget {
  final Widget child;
  const ErpShell({Key? key, required this.child}) : super(key: key);
  @override
  State<ErpShell> createState() => _ErpShellState();
}

class _ErpShellState extends State<ErpShell> {
  String _currentPage = 'dashboard';

  void navTo(String page) {
    setState(() { _currentPage = page; });
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 768;
    return Scaffold(
      backgroundColor: C.bgDeep,
      body: Row(children: [
        if (isWide) _buildSidebar(context),
        Expanded(child: widget.child),
      ]),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 220,
      decoration: BoxDecoration(color: C.bgCard, border: Border(right: BorderSide(color: C.border))),
      child: Column(children: [
        // Logo区
        Container(padding: const EdgeInsets.fromLTRB(16, 50, 16, 20), child: Row(children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(gradient: LinearGradient(colors: [C.t3, C.cyan]), borderRadius: BorderRadius.circular(10)), child: const Center(child: Text('📱', style: TextStyle(fontSize: 16)))),
          const SizedBox(width: 10),
          Text('爱管机', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: C.t1)),
        ])),
        // 菜单
        Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: 8), children: [
          _navItem('📊', '经营看板', 'dashboard'),
          _navItem('📱', '库存管理', 'inventory'),
          _navItem('📦', '销售管理', 'sales'),
          _navItem('💰', '财务管理', 'finance'),
          _navItem('👥', '客户管理', 'customer'),
          _navItem('🔧', '维修管理', 'repair'),
          _navItem('📊', '统计报表', 'reports'),
          _navItem('⚙️', '系统设置', 'settings'),
        ])),
      ]),
    );
  }

  Widget _navItem(String icon, String title, String page) {
    final active = _currentPage == page;
    return Container(margin: const EdgeInsets.only(bottom: 2), child: InkWell(
      onTap: () => navTo(page),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: active ? C.t3.withOpacity(0.12) : Colors.transparent, borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 10),
          Text(title, style: TextStyle(fontSize: 13, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? C.t3 : C.t1)),
        ]),
      ),
    ));
  }
}
