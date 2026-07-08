import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../components/index.dart';
import '../utils/utils.dart';
import '../models.dart';
import '../ai_service.dart';
import '../main.dart';
import '../services/automation_service.dart';
import '../services/xianyu_copy_service.dart';
import 'detail_page.dart';
import 'market_price_page.dart';
import 'order_detail_page.dart';
import 'purchase_decision_page.dart';
import 'restock_suggestion_page.dart';
import 'stagnant_list_page.dart';

class AiReportPage extends StatefulWidget {
  const AiReportPage({Key? key}) : super(key: key);
  @override
  State<AiReportPage> createState() => _AiReportPageState();
}

class _AiReportPageState extends State<AiReportPage> {
  String? report;
  bool loading = false;
  final Set<String> _busyTaskIds = <String>{};

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
    final plan = AutomationService.buildPlan(gStorage);
    final actions = plan.openTasks;
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
          _SectionHeader(title: '今天先做什么', subtitle: _taskSubtitle(plan)),
          const SizedBox(height: 10),
          if (actions.isEmpty)
            _buildCompletedCard(plan)
          else
            ...actions.map(_buildActionCard),
          const SizedBox(height: 2),
          _buildFocusModels(devices),
          const SizedBox(height: 2),
          _buildAiBriefCard(stats),
          const SizedBox(height: 12),
        ],
      ),
      trailing:
          plan.completedCount > 0
              ? RoundIconButton(
                icon: Icons.restart_alt_rounded,
                onTap: _clearCompletedTasks,
                color: C.t2,
                background: Colors.white.withValues(alpha: 0.07),
              )
              : null,
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
              Expanded(
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
                style: TextStyle(
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

  String _taskSubtitle(AutomationPlan plan) {
    final open = plan.openTasks.length;
    if (open == 0) return '今日任务已清空';
    final parts = <String>[
      if (plan.criticalCount > 0) '${plan.criticalCount}急',
      if (plan.warningCount > 0) '${plan.warningCount}提醒',
      '共$open项',
      if (plan.completedCount > 0) '已完成${plan.completedCount}',
    ];
    return parts.join(' · ');
  }

  Future<void> _clearCompletedTasks() async {
    await AutomationService.clearCompletedToday(gStorage);
    if (!mounted) return;
    setState(() {});
    toast(context, '已恢复今日完成项');
  }

  Future<void> _markTaskDone(AutomationTask task) async {
    await AutomationService.markCompleted(gStorage, task.id);
    if (!mounted) return;
    setState(() {});
    toast(context, '已从今日清单移除');
  }

  Future<void> _openPage(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) setState(() {});
  }

  Future<void> _runTaskAction(AutomationTask task) async {
    switch (task.actionKind) {
      case AutomationActionKind.openDevice:
        final device = _deviceById(task.deviceId);
        if (device == null) {
          toast(context, '设备已经不在库存里');
          return;
        }
        await _openPage(DetailPage(device: device));
        break;
      case AutomationActionKind.openOrder:
        final order = _orderById(task.orderId);
        if (order == null) {
          toast(context, '订单已经不存在');
          return;
        }
        await _openPage(OrderDetailPage(order: order));
        break;
      case AutomationActionKind.openMarketPrice:
        await _openPage(const MarketPricePage());
        break;
      case AutomationActionKind.openPurchaseDecision:
        await _openPage(
          PurchaseDecisionPage(
            initialModel: task.model,
            initialCostFen: task.suggestedPriceFen,
          ),
        );
        break;
      case AutomationActionKind.openRestock:
        await _openPage(const RestockSuggestionPage());
        break;
      case AutomationActionKind.openStagnantList:
        await _openPage(const StagnantListPage());
        break;
      case AutomationActionKind.applyPriceCut:
        await _applyPriceTask(task);
        break;
      case AutomationActionKind.generateCopy:
        await _generateCopyTask(task);
        break;
      case AutomationActionKind.none:
        await _markTaskDone(task);
        break;
    }
  }

  Future<void> _applyPriceTask(AutomationTask task) async {
    final device = _deviceById(task.deviceId);
    final price = task.suggestedPriceFen ?? 0;
    if (device == null || price <= 0) {
      await _openPage(const StagnantListPage());
      return;
    }
    final ok = await confirmAction(
      context,
      title: '套用建议价格',
      message:
          '${device.model} ${device.capacity}\n'
          '${device.sellPrice > 0 ? '当前售价 ${yuan(device.sellPrice)}\n' : ''}'
          '建议调整为 ${yuan(price)}。确认后会更新设备售价，并标记为已处理。',
      confirmText: '确认调整',
      confirmColor: C.orange,
    );
    if (!ok) return;
    await _withTaskBusy(task, () async {
      device.sellPrice = price;
      if (device.status == 'in_stock') device.status = 'listed';
      await gStorage.updateDevice(device);
      await AutomationService.markCompleted(gStorage, task.id);
    });
    if (!mounted) return;
    toast(context, '已更新 ${device.model} 售价为 ${yuan(price)}');
  }

  Future<void> _generateCopyTask(AutomationTask task) async {
    final device = _deviceById(task.deviceId);
    if (device == null) {
      toast(context, '设备已经不在库存里');
      return;
    }
    await _withTaskBusy(task, () async {
      try {
        final reference = XianyuCopyService.buildReferenceContext(
          gStorage,
          model: device.model,
          condition: device.condition,
        );
        final desc = await AiService.generateDescription(
          model: device.model,
          capacity: device.capacity,
          color: device.color,
          network: device.network,
          condition: device.condition,
          batteryHealth: device.batteryHealth,
          cycleCount: device.cycleCount,
          idLockClean: device.idLockClean,
          accessories: device.accessories,
          copywritingReference: reference,
          previousDescription: device.description ?? '',
        );
        if (!mounted) return;
        if (desc.startsWith('AI调用') || desc.startsWith('AI返回')) {
          toast(context, desc);
          return;
        }
        device.description = desc;
        await gStorage.updateDevice(device);
        await AutomationService.markCompleted(gStorage, task.id);
        if (!mounted) return;
        toast(context, '已补好 ${device.model} 的闲鱼文案');
      } catch (e) {
        if (mounted) toast(context, '文案生成失败：$e');
      }
    });
  }

  Future<void> _withTaskBusy(
    AutomationTask task,
    Future<void> Function() run,
  ) async {
    if (_busyTaskIds.contains(task.id)) return;
    setState(() => _busyTaskIds.add(task.id));
    try {
      await run();
    } finally {
      if (mounted) setState(() => _busyTaskIds.remove(task.id));
    }
  }

  Device? _deviceById(String? id) {
    if (id == null) return null;
    for (final device in gStorage.getDevices()) {
      if (device.id == id) return device;
    }
    return null;
  }

  Order? _orderById(String? id) {
    if (id == null) return null;
    for (final order in gStorage.getOrders()) {
      if (order.id == id) return order;
    }
    return null;
  }

  Widget _buildCompletedCard(AutomationPlan plan) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: GlassPanel(
      padding: const EdgeInsets.all(16),
      radius: 18,
      color: C.mint.withValues(alpha: 0.10),
      borderColor: C.mint.withValues(alpha: 0.26),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: C.mint.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_outline_rounded,
              color: C.mint,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              plan.completedCount > 0 ? '今日巡店任务已处理完' : '今天没有硬风险',
              style: TextStyle(
                color: C.t1,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          smallBtn(
            '恢复',
            _clearCompletedTasks,
            color: C.mint,
            icon: Icons.restart_alt_rounded,
          ),
        ],
      ),
    ),
  );

  Widget _buildActionCard(AutomationTask task) {
    final color = _taskColor(task);
    final urgent = task.impact == AutomationImpact.critical;
    final busy = _busyTaskIds.contains(task.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassPanel(
        padding: const EdgeInsets.all(14),
        radius: 18,
        color: urgent ? color.withValues(alpha: 0.10) : const Color(0xDE0B0F16),
        borderColor: color.withValues(alpha: urgent ? 0.35 : 0.18),
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
                    color: color.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_taskIcon(task), color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: TextStyle(
                          color: C.t1,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        task.reason,
                        style: TextStyle(
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
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 92),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          task.metric,
                          style: TextStyle(
                            color: color,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      task.detail,
                      style: TextStyle(
                        color: C.t3,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              task.summary,
              style: TextStyle(
                color: C.t3,
                fontSize: 11.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (task.lines.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...task.lines.map(
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
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          line,
                          style: TextStyle(
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
            if (task.hasAction || task.impact != AutomationImpact.success) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    if (busy) _BusyChip(color: color),
                    if (task.hasAction && !busy)
                      smallBtn(
                        task.actionLabel!,
                        () => _runTaskAction(task),
                        color: color,
                        icon: _actionIcon(task.actionKind),
                      ),
                    if (!busy && task.impact != AutomationImpact.success)
                      smallBtn(
                        '完成',
                        () => _markTaskDone(task),
                        color: C.t3,
                        icon: Icons.check_rounded,
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _taskColor(AutomationTask task) {
    if (task.impact == AutomationImpact.critical) return C.red;
    if (task.impact == AutomationImpact.success) return C.mint;
    switch (task.kind) {
      case AutomationTaskKind.marketPrice:
        return C.blue;
      case AutomationTaskKind.orderRisk:
        return C.cyan;
      case AutomationTaskKind.restock:
        return C.mint;
      case AutomationTaskKind.staleStock:
        return C.red;
      case AutomationTaskKind.purchaseGuard:
        return C.red;
      case AutomationTaskKind.listingPipeline:
      case AutomationTaskKind.supplierRisk:
      case AutomationTaskKind.dataHealth:
        return C.orange;
    }
  }

  IconData _taskIcon(AutomationTask task) {
    switch (task.kind) {
      case AutomationTaskKind.staleStock:
        return Icons.trending_down_rounded;
      case AutomationTaskKind.listingPipeline:
        return Icons.edit_note_rounded;
      case AutomationTaskKind.marketPrice:
        return Icons.price_change_outlined;
      case AutomationTaskKind.purchaseGuard:
        return Icons.do_not_disturb_alt_rounded;
      case AutomationTaskKind.supplierRisk:
        return Icons.handshake_outlined;
      case AutomationTaskKind.orderRisk:
        return Icons.local_shipping_outlined;
      case AutomationTaskKind.restock:
        return Icons.playlist_add_check_rounded;
      case AutomationTaskKind.dataHealth:
        return task.impact == AutomationImpact.success
            ? Icons.check_circle_outline_rounded
            : Icons.fact_check_outlined;
    }
  }

  IconData _actionIcon(AutomationActionKind kind) {
    switch (kind) {
      case AutomationActionKind.applyPriceCut:
        return Icons.trending_down_rounded;
      case AutomationActionKind.generateCopy:
        return Icons.auto_awesome_rounded;
      case AutomationActionKind.openMarketPrice:
        return Icons.price_change_outlined;
      case AutomationActionKind.openPurchaseDecision:
        return Icons.calculate_outlined;
      case AutomationActionKind.openRestock:
        return Icons.playlist_add_check_rounded;
      case AutomationActionKind.openOrder:
        return Icons.receipt_long_outlined;
      case AutomationActionKind.openDevice:
        return Icons.tablet_mac_rounded;
      case AutomationActionKind.openStagnantList:
        return Icons.inventory_2_outlined;
      case AutomationActionKind.none:
        return Icons.check_rounded;
    }
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
          Text(
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
            Text(
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
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: C.purple,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
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
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(minHeight: 3, color: C.purple),
            )
          else if (report != null)
            Text(
              report!,
              style: TextStyle(
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
              style: TextStyle(color: C.t2, fontSize: 12, height: 1.5),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: loading ? null : _gen,
              icon: Icon(Icons.refresh_rounded, size: 18),
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

class _BusyChip extends StatelessWidget {
  final Color color;

  const _BusyChip({required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 13,
          height: 13,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '处理中',
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
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
          style: TextStyle(
            color: C.t1,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      Text(
        subtitle,
        style: TextStyle(
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
          style: TextStyle(
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
                style: TextStyle(
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
                style: TextStyle(color: C.t3, fontSize: 10.5),
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
