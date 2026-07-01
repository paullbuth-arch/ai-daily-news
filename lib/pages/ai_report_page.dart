import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../components/index.dart';
import '../utils/utils.dart';
import '../models.dart';
import '../ai_service.dart';
import '../main.dart';
import 'detail_page.dart';
import 'market_price_page.dart';
import 'order_detail_page.dart';
import 'stagnant_list_page.dart';

class AiReportPage extends StatefulWidget {
  const AiReportPage({Key? key}) : super(key: key);
  @override
  State<AiReportPage> createState() => _AiReportPageState();
}

class _AiReportPageState extends State<AiReportPage> {
  String? report;
  bool loading = false;

  Future<void> _gen() async {
    setState(() => loading = true);
    final s = gStorage.computeStats();
    final stg =
        gStorage
            .getDevices()
            .where((d) => d.isStagnant)
            .map((d) => '${d.model} ${d.capacity} · ${d.stockDays}天')
            .toList();

    final r = await AiService.dailyReport(
      gmv: s.gmv,
      grossProfit: s.grossProfit,
      orderCount: s.orderCount,
      inStock: s.inStockCount,
      stagnant: s.stagnantCount,
      capital: s.capitalOccupied,
      stagnantModels: stg,
    );
    if (!mounted) return;
    setState(() {
      report = r;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final stats = gStorage.computeStats();
    final devices = gStorage.getDevices();
    final orders =
        gStorage.getOrders().where((o) => o.status != 'cancelled').toList();
    final actions = _buildActions(stats, devices, orders);
    final week = _weekSummary();
    final staleCapital = devices
        .where((d) => d.isStagnant)
        .fold<int>(0, (sum, d) => sum + d.purchaseCost);

    return appScaffold(
      context,
      '今日经营动作台',
      ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _buildSnapshot(stats, week, staleCapital),
          const SizedBox(height: 2),
          _SectionHeader(
            title: '今天先做什么',
            subtitle: '${actions.where((a) => a.priority <= 2).length} 项需要处理',
          ),
          const SizedBox(height: 10),
          ...actions.map(_buildActionCard),
          const SizedBox(height: 2),
          _buildFocusModels(devices),
          const SizedBox(height: 2),
          _buildAiBriefCard(stats),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildSnapshot(Stats s, _WeekSummary week, int staleCapital) {
    final margin = s.gmv > 0 ? s.grossProfit / s.gmv * 100 : 0.0;
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      radius: 20,
      color: const Color(0xEA0B0F16),
      borderColor: Colors.white.withValues(alpha: 0.11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '经营快照',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: C.t1,
                  ),
                ),
              ),
              Text(
                _clockText(),
                style: const TextStyle(
                  fontSize: 11,
                  color: C.t3,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _MetricBlock('今日GMV', yuan(s.gmv), C.cyan)),
              _MetricDivider(),
              Expanded(
                child: _MetricBlock(
                  '今日毛利',
                  yuan(s.grossProfit),
                  s.grossProfit >= 0 ? C.mint : C.red,
                ),
              ),
              _MetricDivider(),
              Expanded(child: _MetricBlock('订单', '${s.orderCount}单', C.purple)),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoPill('毛利率 ${margin.toStringAsFixed(1)}%', C.t2),
              _InfoPill('在售 ${s.inStockCount} 台', C.cyan),
              _InfoPill(
                '滞销 ${s.stagnantCount} 台',
                s.stagnantCount > 0 ? C.red : C.t2,
              ),
              _InfoPill('占用 ${yuan(s.capitalOccupied)}', C.orange),
              _InfoPill(
                '滞销占用 ${yuan(staleCapital)}',
                staleCapital > 0 ? C.red : C.t2,
              ),
              _InfoPill(
                '7日毛利 ${yuan(week.profit)}',
                week.profit >= 0 ? C.mint : C.red,
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<_OpsAction> _buildActions(
    Stats stats,
    List<Device> devices,
    List<Order> orders,
  ) {
    final inStock =
        devices
            .where((d) => d.status == 'in_stock' || d.status == 'listed')
            .toList();
    final unpriced =
        inStock.where((d) => d.sellPrice <= 0).toList()
          ..sort((a, b) => b.purchaseCost.compareTo(a.purchaseCost));
    final stagnant =
        inStock.where((d) => d.isStagnant).toList()
          ..sort((a, b) => b.stockDays.compareTo(a.stockDays));
    final todayKey = _dateKey(DateTime.now());
    final todayOrders =
        orders.where((o) => o.createdAt.startsWith(todayKey)).toList();
    final lowProfitOrders =
        todayOrders.where((o) => o.netProfit < 15000).toList()
          ..sort((a, b) => a.netProfit.compareTo(b.netProfit));
    final pendingOrders = orders.where((o) => o.status == 'pending').toList();
    final actions = <_OpsAction>[];

    if (unpriced.isNotEmpty) {
      final capital = unpriced.fold<int>(0, (sum, d) => sum + d.purchaseCost);
      actions.add(
        _OpsAction(
          priority: 1,
          icon: Icons.edit_note_rounded,
          color: C.orange,
          title: '先补齐定价与描述',
          value: '${unpriced.length}台',
          detail: '占用 ${yuan(capital)}',
          reason: '未定价设备无法判断毛利，也不适合直接导出闲鱼资料。',
          action: '处理首台',
          lines:
              unpriced
                  .take(3)
                  .map(
                    (d) =>
                        '${d.model} ${d.capacity} · 成本${yuan(d.purchaseCost)}',
                  )
                  .toList(),
          onTap:
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DetailPage(device: unpriced.first),
                ),
              ).then((_) => setState(() {})),
        ),
      );
    }

    if (stagnant.isNotEmpty) {
      final capital = stagnant.fold<int>(0, (sum, d) => sum + d.purchaseCost);
      actions.add(
        _OpsAction(
          priority: 1,
          icon: Icons.trending_down_rounded,
          color: C.red,
          title: '处理滞销资金',
          value: '${stagnant.length}台',
          detail: '压住 ${yuan(capital)}',
          reason: '超过15天还没动销，今天要降价、换标题图，或转快速出货价。',
          action: '打开滞销列表',
          lines:
              stagnant
                  .take(3)
                  .map((d) => '${d.model} ${d.capacity} · 已在库${d.stockDays}天')
                  .toList(),
          onTap:
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StagnantListPage()),
              ).then((_) => setState(() {})),
        ),
      );
    }

    if (pendingOrders.isNotEmpty) {
      actions.add(
        _OpsAction(
          priority: 2,
          icon: Icons.local_shipping_outlined,
          color: C.cyan,
          title: '核对待发货订单',
          value: '${pendingOrders.length}单',
          detail: '避免漏发',
          reason: '待发货订单会拖慢回款和售后响应，先确认物流与买家信息。',
          action: '处理首单',
          lines:
              pendingOrders
                  .take(3)
                  .map((o) => '${o.deviceName} · ${yuan(o.amount)}')
                  .toList(),
          onTap:
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderDetailPage(order: pendingOrders.first),
                ),
              ).then((_) => setState(() {})),
        ),
      );
    }

    if (lowProfitOrders.isNotEmpty) {
      final min = lowProfitOrders.first.netProfit;
      actions.add(
        _OpsAction(
          priority: min < 0 ? 1 : 2,
          icon: Icons.warning_amber_rounded,
          color: min < 0 ? C.red : C.orange,
          title: min < 0 ? '复盘亏损订单' : '复盘低毛利订单',
          value: '${lowProfitOrders.length}单',
          detail: '最低 ${yuan(min)}',
          reason: '低毛利通常来自拿货过高、维修漏算或平台手续费漏算。',
          action: null,
          lines:
              lowProfitOrders
                  .take(3)
                  .map((o) => '${o.deviceName} · 净利${yuan(o.netProfit)}')
                  .toList(),
        ),
      );
    }

    if (!gStorage.isMarketPriceUpdatedToday() && inStock.isNotEmpty) {
      actions.add(
        _OpsAction(
          priority: 3,
          icon: Icons.price_change_outlined,
          color: C.blue,
          title: '补今日批发价',
          value: '未更新',
          detail: '影响采购判断',
          reason: '采购决策会用今日行情做校验，批发价缺失时只能靠历史均值。',
          action: '录入行情',
          lines: const ['至少录入主力型号，采购页会自动带入。'],
          onTap:
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MarketPricePage()),
              ).then((_) => setState(() {})),
        ),
      );
    }

    if (actions.isEmpty) {
      actions.add(
        _OpsAction(
          priority: 4,
          icon: Icons.check_circle_outline_rounded,
          color: C.mint,
          title: '今天没有硬风险',
          value: '正常',
          detail: '继续巡检',
          reason: '先看主力型号有没有低库存，再把新到货的标题图和描述补齐。',
          action: null,
          lines: const ['建议保留15分钟做价格巡检，避免采购价跑偏。'],
        ),
      );
    }

    actions.sort((a, b) => a.priority.compareTo(b.priority));
    return actions.take(5).toList();
  }

  Widget _buildActionCard(_OpsAction a) {
    final urgent = a.priority <= 1;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassPanel(
        padding: const EdgeInsets.all(14),
        radius: 18,
        color:
            urgent ? a.color.withValues(alpha: 0.10) : const Color(0xDE0B0F16),
        borderColor: a.color.withValues(alpha: urgent ? 0.35 : 0.18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: a.color.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(a.icon, color: a.color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.title,
                        style: const TextStyle(
                          color: C.t1,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        a.reason,
                        style: const TextStyle(
                          color: C.t2,
                          fontSize: 12,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      a.value,
                      style: TextStyle(
                        color: a.color,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      a.detail,
                      style: const TextStyle(
                        color: C.t3,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (a.lines.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...a.lines.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: a.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          line,
                          style: const TextStyle(
                            color: C.t2,
                            fontSize: 11.5,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (a.onTap != null && a.action != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: smallBtn(a.action!, a.onTap!, color: a.color),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFocusModels(List<Device> devices) {
    final stale =
        devices.where((d) => d.isStagnant).toList()
          ..sort((a, b) => b.purchaseCost.compareTo(a.purchaseCost));
    final profitModels = gStorage.getProfitByModel().take(3).toList();
    return GlassPanel(
      padding: const EdgeInsets.all(14),
      radius: 18,
      color: const Color(0xD80B0F16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '型号观察',
            style: TextStyle(
              color: C.t1,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          if (stale.isNotEmpty) ...[
            _TinyTitle('优先清库存', C.red),
            const SizedBox(height: 7),
            ...stale
                .take(3)
                .map(
                  (d) => _ModelLine(
                    name: '${d.model} ${d.capacity}',
                    meta: '${d.stockDays}天 · 成本${yuan(d.purchaseCost)}',
                    value: d.sellPrice > 0 ? yuan(d.sellPrice) : '未定价',
                    color: C.red,
                  ),
                ),
            const SizedBox(height: 10),
          ],
          if (profitModels.isNotEmpty) ...[
            _TinyTitle('赚钱型号', C.mint),
            const SizedBox(height: 7),
            ...profitModels.map(
              (m) => _ModelLine(
                name: m['model'] as String,
                meta: '${m['count']}台 · 成交${yuan(m['revenue'] as int)}',
                value: yuan(m['profit'] as int),
                color: (m['profit'] as int) >= 0 ? C.mint : C.red,
              ),
            ),
          ],
          if (stale.isEmpty && profitModels.isEmpty)
            const Text(
              '暂时没有足够的型号数据。先完成几单销售记录，这里会自动变成型号雷达。',
              style: TextStyle(color: C.t2, fontSize: 12, height: 1.5),
            ),
        ],
      ),
    );
  }

  Widget _buildAiBriefCard(Stats s) {
    return GlassPanel(
      padding: const EdgeInsets.all(14),
      radius: 18,
      color: const Color(0xDA0D111A),
      borderColor: C.purple.withValues(alpha: 0.22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: C.purple.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: C.purple,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI复盘',
                      style: TextStyle(
                        color: C.t1,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '本地动作在上面，AI只补判断依据',
                      style: TextStyle(color: C.t3, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(minHeight: 3, color: C.purple),
            )
          else if (report != null)
            Text(
              report!,
              style: const TextStyle(
                color: C.t2,
                fontSize: 12.5,
                height: 1.65,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            Text(
              s.orderCount == 0 && s.inStockCount == 0
                  ? '先录入库存或订单，AI复盘才会有真实上下文。'
                  : '需要更像老板口吻的复盘时再点这里，不影响上面的本地行动清单。',
              style: const TextStyle(color: C.t2, fontSize: 12, height: 1.5),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: loading ? null : _gen,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(report == null ? '生成AI复盘' : '重新复盘'),
              style: OutlinedButton.styleFrom(
                foregroundColor: C.purple,
                side: BorderSide(color: C.purple.withValues(alpha: 0.45)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: const StadiumBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  _WeekSummary _weekSummary() {
    final daily = gStorage.getDailyStats(days: 7);
    final profit = daily.fold<int>(0, (sum, d) => sum + d.profit);
    final gmv = daily.fold<int>(0, (sum, d) => sum + d.gmv);
    final activeDays = daily.where((d) => d.gmv > 0 || d.profit != 0).length;
    return _WeekSummary(gmv: gmv, profit: profit, activeDays: activeDays);
  }

  String _clockText() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _OpsAction {
  final int priority;
  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String detail;
  final String reason;
  final String? action;
  final List<String> lines;
  final VoidCallback? onTap;

  const _OpsAction({
    required this.priority,
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.detail,
    required this.reason,
    required this.action,
    required this.lines,
    this.onTap,
  });
}

class _WeekSummary {
  final int gmv;
  final int profit;
  final int activeDays;

  const _WeekSummary({
    required this.gmv,
    required this.profit,
    required this.activeDays,
  });
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: C.t1,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      Text(
        subtitle,
        style: const TextStyle(
          color: C.t3,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _MetricBlock extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricBlock(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: C.t3,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),
  );
}

class _MetricDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 38,
    color: Colors.white.withValues(alpha: 0.08),
  );
}

class _InfoPill extends StatelessWidget {
  final String text;
  final Color color;

  const _InfoPill(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: color.withValues(alpha: 0.18)),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
    ),
  );
}

class _TinyTitle extends StatelessWidget {
  final String text;
  final Color color;

  const _TinyTitle(this.text, this.color);

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(Icons.circle, size: 8, color: color),
      const SizedBox(width: 6),
      Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    ],
  );
}

class _ModelLine extends StatelessWidget {
  final String name;
  final String meta;
  final String value;
  final Color color;

  const _ModelLine({
    required this.name,
    required this.meta,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: C.t1,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                meta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: C.t3, fontSize: 10.5),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}
