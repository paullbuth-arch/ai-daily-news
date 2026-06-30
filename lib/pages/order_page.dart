import 'package:flutter/material.dart';
import '../components/index.dart';
import '../theme/colors.dart';
import '../utils/utils.dart';
import '../models.dart';
import '../main.dart';
import 'order_detail_page.dart';
import 'sell_page.dart';

class OrderPage extends StatefulWidget {
  const OrderPage({Key? key}) : super(key: key);

  @override
  State<OrderPage> createState() => OrderPageState();
}

class OrderPageState extends State<OrderPage> {
  int tab = 0;
  final tabs = ['全部', '待发货', '已发货', '已完成', '售后'];
  final statusMap = ['all', 'pending', 'shipped', 'done', 'aftersale'];

  void refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    var orders = gStorage.getOrders();
    final total = orders.length;
    if (statusMap[tab] != 'all') {
      orders = orders.where((o) => o.status == statusMap[tab]).toList();
    }
    final revenue = orders.fold<int>(0, (s, o) => s + o.amount);
    final profit = orders.fold<int>(0, (s, o) => s + o.netProfit);
    final horizontal = AppLayout.pageHorizontal(context);
    final bottomPadding = AppLayout.scrollBottomPadding(context);

    return Stack(
      children: [
        const AppBackdrop(),
        SafeArea(
          child: CustomScrollView(
            cacheExtent: 700,
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '订单时间线',
                                    style: TextStyle(
                                      fontSize: AppLayout.titleSize(context),
                                      fontWeight: FontWeight.w900,
                                      color: C.t1,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    '累计 $total 单 · 当前 ${orders.length} 单',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: C.t2,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            RoundIconButton(
                              icon: Icons.add_shopping_cart_outlined,
                              color: Colors.black,
                              background: C.cyan,
                              onTap:
                                  () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const SellPage(),
                                    ),
                                  ).then((_) => refresh()),
                            ),
                          ],
                        ),
                      ),
                      _OrderSummary(
                        revenue: revenue,
                        profit: profit,
                        count: orders.length,
                      ),
                      const SizedBox(height: 14),
                      _SegmentedTabs(
                        tabs: tabs,
                        current: tab,
                        onTap: (i) => setState(() => tab = i),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed:
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SellPage(),
                                ),
                              ).then((_) => refresh()),
                          icon: const Icon(
                            Icons.point_of_sale_outlined,
                            size: 18,
                          ),
                          label: const Text('售出设备并生成订单'),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (orders.isEmpty) ...[
                        const _EmptyOrders(),
                        SizedBox(height: bottomPadding),
                      ],
                    ],
                  ),
                ),
              ),
              if (orders.isNotEmpty)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontal,
                    0,
                    horizontal,
                    bottomPadding,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, i) {
                      final order = orders[i];
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: i == orders.length - 1 ? 0 : 12,
                        ),
                        child: RepaintBoundary(
                          child: _OrderTimelineCard(
                            order: order,
                            onTap:
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) => OrderDetailPage(order: order),
                                  ),
                                ).then((_) => refresh()),
                          ),
                        ),
                      );
                    }, childCount: orders.length),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OrderSummary extends StatelessWidget {
  final int revenue;
  final int profit;
  final int count;

  const _OrderSummary({
    required this.revenue,
    required this.profit,
    required this.count,
  });

  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: const EdgeInsets.all(18),
    radius: 26,
    color: const Color(0xEA0A0D14),
    child: Row(
      children: [
        Expanded(child: _SummaryItem('成交额', yuan(revenue), C.cyan)),
        Container(width: 1, height: 42, color: Colors.white.withOpacity(0.08)),
        Expanded(
          child: _SummaryItem('净利', yuan(profit), profit >= 0 ? C.mint : C.red),
        ),
        Container(width: 1, height: 42, color: Colors.white.withOpacity(0.08)),
        Expanded(child: _SummaryItem('订单', '$count', C.purple)),
      ],
    ),
  );
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryItem(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: C.t3,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        FittedBox(
          alignment: Alignment.centerLeft,
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 20,
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SegmentedTabs extends StatelessWidget {
  final List<String> tabs;
  final int current;
  final ValueChanged<int> onTap;

  const _SegmentedTabs({
    required this.tabs,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: const EdgeInsets.all(4),
    radius: 24,
    child: Row(
      children: List.generate(tabs.length, (i) {
        final selected = i == current;
        return Expanded(
          child: GestureDetector(
            onTap: () => onTap(i),
            child: AnimatedContainer(
              duration: C.fast,
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                tabs[i],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: selected ? Colors.black : C.t2,
                ),
              ),
            ),
          ),
        );
      }),
    ),
  );
}

class _OrderTimelineCard extends StatelessWidget {
  final Order order;
  final VoidCallback onTap;

  const _OrderTimelineCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final profitColor = order.netProfit >= 0 ? C.mint : C.red;
    return GlassPanel(
      padding: const EdgeInsets.all(14),
      radius: 22,
      color: const Color(0xE60C0F16),
      onTap: onTap,
      child: Row(
        children: [
          Column(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: C.cyan.withOpacity(0.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.tablet_mac_rounded,
                  color: C.cyan,
                  size: 21,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 2,
                height: 34,
                color: Colors.white.withOpacity(0.08),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        order.deviceName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: C.t1,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    StatusChip(
                      _statusText(order.status),
                      _statusColor(order.status),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  '${order.buyer} · ${order.channel} · ${order.createdAt}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: C.t2,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _ValuePill(
                      label: '成交',
                      value: yuan(order.amount),
                      color: C.cyan,
                    ),
                    const SizedBox(width: 8),
                    _ValuePill(
                      label: '净利',
                      value: yuan(order.netProfit),
                      color: profitColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: C.t3),
        ],
      ),
    );
  }

  String _statusText(String status) =>
      {
        'pending': '待发货',
        'shipped': '已发货',
        'done': '已完成',
        'aftersale': '售后',
        'cancelled': '作废',
      }[status] ??
      status;

  Color _statusColor(String status) =>
      {
        'pending': C.orange,
        'shipped': C.cyan,
        'done': C.mint,
        'aftersale': C.red,
        'cancelled': C.t3,
      }[status] ??
      C.t2;
}

class _ValuePill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ValuePill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: color.withOpacity(0.14),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withOpacity(0.20)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: color.withOpacity(0.76),
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders();

  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: const EdgeInsets.all(24),
    radius: 24,
    child: const Column(
      children: [
        Icon(Icons.receipt_long_outlined, color: C.t3, size: 36),
        SizedBox(height: 12),
        Text(
          '暂无订单',
          style: TextStyle(
            color: C.t1,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 5),
        Text('售出设备后会自动生成订单', style: TextStyle(color: C.t2, fontSize: 12)),
      ],
    ),
  );
}
