import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../components/index.dart';
import '../utils/utils.dart';
import '../storage.dart';
import '../models.dart';
import '../main.dart';
import 'sell_page.dart';
import 'order_detail_page.dart';

class OrderPage extends StatefulWidget {
  const OrderPage({Key? key}) : super(key: key);
  @override
  State<OrderPage> createState() => OrderPageState();
}

class OrderPageState extends State<OrderPage> {
  int tab = 0;
  final tabs = ['全部', '已发货', '已完成', '售后'];
  final statusMap = ['all', 'shipped', 'done', 'aftersale'];

  void refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    var orders = gStorage.getOrders();
    if (statusMap[tab] != 'all') {
      orders = orders.where((o) => o.status == statusMap[tab]).toList();
    }
    return PageScaffold(
      title: Text(
        '订单管理',
        style: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w900,
          color: C.t1,
        ),
      ),
      subtitle: Text(
        '累计${gStorage.getOrders().length}单 · 当前筛选${orders.length}单',
        style: TextStyle(fontSize: 12, color: C.t2),
      ),
      action: IconButton(
        tooltip: '售出设备',
        icon: Icon(Icons.point_of_sale_outlined, color: C.cyan),
        onPressed:
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SellPage()),
            ).then((_) => refresh()),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: C.bgCard,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: C.border),
            ),
            child: Row(
              children: List.generate(tabs.length, (i) {
                final on = tab == i;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => tab = i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: on ? C.cyan.withOpacity(0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: on ? C.cyan.withOpacity(0.3) : Colors.transparent,
                          width: on ? 1.2 : 0,
                        ),
                      ),
                      child: Text(
                        tabs[i],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                          color: on ? C.cyan : C.t2,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SellPage()),
                    ).then((_) => refresh()),
                icon: const Icon(Icons.add_shopping_cart_outlined, size: 18),
                label: const Text('售出设备并生成订单'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: C.cyan,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
            ),
          ),
          if (orders.isEmpty) _emptyOrders() else ...orders.map(_orderCard),
        ],
      ),
    );
  }

  Widget _emptyOrders() => Padding(
    padding: const EdgeInsets.only(top: 46),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: C.cyan.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: C.cyan.withOpacity(0.15)),
            ),
            child: Icon(Icons.receipt_long_outlined, color: C.t3, size: 26),
          ),
          const SizedBox(height: 12),
          Text(
            '暂无订单',
            style: TextStyle(
              color: C.t1,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text('售出设备后会自动生成订单', style: TextStyle(color: C.t2, fontSize: 12)),
        ],
      ),
    ),
  );

  Widget _orderCard(Order o) {
    final sc = _sc(o.status);
    final stText =
        {
          'shipped': '已发货',
          'done': '已完成',
          'aftersale': '售后',
          'cancelled': '已作废',
        }[o.status] ??
        o.status;
    final profitColor = o.netProfit >= 0 ? C.neonGreen : C.neonRed;
    return GestureDetector(
      onTap:
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => OrderDetailPage(order: o)),
          ).then((_) => refresh()),
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: C.bgCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: C.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  o.id,
                  style: TextStyle(
                    fontSize: 11,
                    color: C.t3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                StatusChip(stText, sc),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: C.bgCardMuted,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: C.border),
                  ),
                  child: Icon(Icons.tablet_mac_rounded, color: C.t2, size: 21),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        o.deviceName,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: C.t1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${o.buyer.isEmpty ? "未知买家" : o.buyer} · ${o.channel} · ${o.createdAt}',
                        style: TextStyle(fontSize: 10.5, color: C.t2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      yuan(o.amount),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: C.cyan,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '净利${yuan(o.netProfit)}',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: profitColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _sc(String s) =>
      s == 'shipped'
          ? C.cyan
          : (s == 'done' ? C.neonGreen : (s == 'aftersale' ? C.neonRed : C.t3));
}
