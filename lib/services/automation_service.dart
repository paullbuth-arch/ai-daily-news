import '../models.dart';
import '../storage.dart';

enum AutomationTaskKind {
  staleStock,
  listingPipeline,
  marketPrice,
  purchaseGuard,
  supplierRisk,
  orderRisk,
  restock,
  dataHealth,
}

enum AutomationImpact { critical, warning, info, success }

enum AutomationActionKind {
  none,
  openDevice,
  openOrder,
  openMarketPrice,
  openPurchaseDecision,
  openRestock,
  openStagnantList,
  applyPriceCut,
  generateCopy,
}

class AutomationTask {
  final String id;
  final AutomationTaskKind kind;
  final AutomationImpact impact;
  final int priority;
  final String title;
  final String summary;
  final String metric;
  final String detail;
  final String reason;
  final List<String> lines;
  final AutomationActionKind actionKind;
  final String? actionLabel;
  final String? deviceId;
  final String? orderId;
  final String? model;
  final int? suggestedPriceFen;

  const AutomationTask({
    required this.id,
    required this.kind,
    required this.impact,
    required this.priority,
    required this.title,
    required this.summary,
    required this.metric,
    required this.detail,
    required this.reason,
    this.lines = const <String>[],
    this.actionKind = AutomationActionKind.none,
    this.actionLabel,
    this.deviceId,
    this.orderId,
    this.model,
    this.suggestedPriceFen,
  });

  bool get hasAction =>
      actionKind != AutomationActionKind.none && actionLabel != null;
}

class AutomationPlan {
  final List<AutomationTask> tasks;
  final Set<String> completedTaskIds;

  const AutomationPlan({
    required this.tasks,
    this.completedTaskIds = const <String>{},
  });

  List<AutomationTask> get openTasks =>
      tasks.where((task) => !completedTaskIds.contains(task.id)).toList();

  int get criticalCount =>
      openTasks
          .where((task) => task.impact == AutomationImpact.critical)
          .length;

  int get warningCount =>
      openTasks.where((task) => task.impact == AutomationImpact.warning).length;

  int get completedCount => completedTaskIds.length;

  bool get hasHardRisks => criticalCount > 0;
}

class AutomationService {
  AutomationService._();

  static const String completedTasksSettingKey = 'automationCompletedTasks';

  static AutomationPlan buildPlan(
    Storage storage, {
    DateTime? now,
    int limit = 8,
  }) {
    final today = now ?? DateTime.now();
    final devices = storage.getDevices();
    final orders =
        storage.getOrders().where((o) => o.status != 'cancelled').toList();
    final tasks = <AutomationTask>[];

    tasks.addAll(_staleStockTasks(storage, devices, today));
    tasks.addAll(_listingPipelineTasks(devices, today));
    tasks.addAll(_marketPriceTasks(storage, devices, today));
    tasks.addAll(_purchaseGuardTasks(storage, devices, today));
    tasks.addAll(_restockTasks(devices, today));
    tasks.addAll(_supplierRiskTasks(storage, today));
    tasks.addAll(_orderRiskTasks(orders, today));
    tasks.addAll(_dataHealthTasks(devices, today));

    if (tasks.isEmpty) {
      tasks.add(
        AutomationTask(
          id: 'clear:${_dateKey(today)}',
          kind: AutomationTaskKind.dataHealth,
          impact: AutomationImpact.success,
          priority: 90,
          title: '今天没有硬风险',
          summary: '继续巡检行情和新入库素材',
          metric: '正常',
          detail: '可复盘',
          reason: '库存、订单、行情和资料暂时没有明显阻塞点。',
          lines: const ['建议保留15分钟做价格巡检，避免采购价跑偏。'],
        ),
      );
    }

    tasks.sort((a, b) {
      final byPriority = a.priority.compareTo(b.priority);
      if (byPriority != 0) return byPriority;
      return a.title.compareTo(b.title);
    });

    return AutomationPlan(
      tasks: tasks.take(limit).toList(),
      completedTaskIds: completedTaskIds(storage, now: today),
    );
  }

  static Future<void> markCompleted(
    Storage storage,
    String taskId, {
    DateTime? now,
  }) async {
    final today = _dateKey(now ?? DateTime.now());
    final settings = Map<String, dynamic>.from(storage.getSettings());
    final raw = settings[completedTasksSettingKey];
    final map =
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final ids =
        (map[today] as List?)
            ?.map((item) => item.toString())
            .where((item) => item.isNotEmpty)
            .toSet() ??
        <String>{};
    ids.add(taskId);
    map[today] = ids.toList()..sort();

    final keep = map.keys.toList()..sort();
    while (keep.length > 14) {
      map.remove(keep.removeAt(0));
    }

    settings[completedTasksSettingKey] = map;
    await storage.saveSettings(settings);
  }

  static Future<void> clearCompletedToday(
    Storage storage, {
    DateTime? now,
  }) async {
    final today = _dateKey(now ?? DateTime.now());
    final settings = Map<String, dynamic>.from(storage.getSettings());
    final raw = settings[completedTasksSettingKey];
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw)..remove(today);
      if (map.isEmpty) {
        settings.remove(completedTasksSettingKey);
      } else {
        settings[completedTasksSettingKey] = map;
      }
      await storage.saveSettings(settings);
    }
  }

  static Set<String> completedTaskIds(Storage storage, {DateTime? now}) {
    final today = _dateKey(now ?? DateTime.now());
    final raw = storage.getSettings()[completedTasksSettingKey];
    if (raw is! Map) return <String>{};
    final list = raw[today];
    if (list is! List) return <String>{};
    return list
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toSet();
  }

  static List<AutomationTask> _staleStockTasks(
    Storage storage,
    List<Device> devices,
    DateTime now,
  ) {
    final stale =
        devices.where((d) => d.isStagnant).toList()..sort((a, b) {
          final byDays = b.stockDays.compareTo(a.stockDays);
          if (byDays != 0) return byDays;
          return b.purchaseCost.compareTo(a.purchaseCost);
        });
    if (stale.isEmpty) return const <AutomationTask>[];

    final first = stale.first;
    final capital = stale.fold<int>(0, (sum, d) => sum + d.purchaseCost);
    final suggested = recommendedStalePrice(first, storage);
    return [
      AutomationTask(
        id: 'stale:${first.id}:${_dateKey(now)}',
        kind: AutomationTaskKind.staleStock,
        impact: AutomationImpact.critical,
        priority: 10,
        title: '处理滞销资金',
        summary: '${stale.length} 台超过15天未动销',
        metric: '${stale.length}台',
        detail: '压住 ${_yuan(capital)}',
        reason: '先处理库存天数最长、资金占用最高的机器，避免继续拖慢周转。',
        lines:
            stale
                .take(3)
                .map(
                  (d) =>
                      '${d.model} ${d.capacity} · ${d.stockDays}天 · 售价${_priceOrUnset(d.sellPrice)}',
                )
                .toList(),
        actionKind:
            suggested > 0
                ? AutomationActionKind.applyPriceCut
                : AutomationActionKind.openStagnantList,
        actionLabel: suggested > 0 ? '首台调到${_yuan(suggested)}' : '打开滞销列表',
        deviceId: first.id,
        suggestedPriceFen: suggested > 0 ? suggested : null,
      ),
    ];
  }

  static List<AutomationTask> _listingPipelineTasks(
    List<Device> devices,
    DateTime now,
  ) {
    final listed =
        devices
            .where((d) => d.status == 'in_stock' || d.status == 'listed')
            .toList();
    final unpriced = listed.where((d) => d.sellPrice <= 0).toList();
    final missingCopy =
        listed.where((d) => (d.description ?? '').trim().isEmpty).toList();
    final missingMedia =
        listed.where((d) => (d.imagePath ?? '').trim().isEmpty).toList();
    if (unpriced.isEmpty && missingCopy.isEmpty && missingMedia.isEmpty) {
      return const <AutomationTask>[];
    }

    final target =
        missingCopy.isNotEmpty
            ? missingCopy.first
            : unpriced.isNotEmpty
            ? unpriced.first
            : missingMedia.first;
    final lines = <String>[
      if (unpriced.isNotEmpty) '未定价 ${unpriced.length} 台',
      if (missingCopy.isNotEmpty) '缺闲鱼文案 ${missingCopy.length} 台',
      if (missingMedia.isNotEmpty) '缺实拍/报告素材 ${missingMedia.length} 台',
    ];
    return [
      AutomationTask(
        id: 'pipeline:${target.id}:${_dateKey(now)}',
        kind: AutomationTaskKind.listingPipeline,
        impact:
            unpriced.isNotEmpty
                ? AutomationImpact.critical
                : AutomationImpact.warning,
        priority: unpriced.isNotEmpty ? 12 : 24,
        title: '补齐上架流水线',
        summary: '定价、文案、素材缺口会卡住发布',
        metric:
            '${unpriced.length + missingCopy.length + missingMedia.length}项',
        detail: '${listed.length}台在库',
        reason: '机器入库后要能直接上架，缺文案或缺素材都会让库存静止。',
        lines: lines,
        actionKind:
            missingCopy.isNotEmpty
                ? AutomationActionKind.generateCopy
                : AutomationActionKind.openDevice,
        actionLabel: missingCopy.isNotEmpty ? '补首台文案' : '处理首台',
        deviceId: target.id,
      ),
    ];
  }

  static List<AutomationTask> _marketPriceTasks(
    Storage storage,
    List<Device> devices,
    DateTime now,
  ) {
    final inStock =
        devices
            .where((d) => d.status == 'in_stock' || d.status == 'listed')
            .toList();
    if (inStock.isEmpty || storage.isMarketPriceUpdatedToday()) {
      return const <AutomationTask>[];
    }
    final models = inStock.map((d) => d.model).toSet().length;
    return [
      AutomationTask(
        id: 'market:${_dateKey(now)}',
        kind: AutomationTaskKind.marketPrice,
        impact: AutomationImpact.warning,
        priority: 18,
        title: '补今日批发价',
        summary: '采购和降价判断缺少今日行情锚点',
        metric: '未更新',
        detail: '$models个型号',
        reason: '没有今日行情时，采购报价和滞销降价只能靠历史均值，容易慢半拍。',
        lines: const ['优先录入主力型号和正在谈的采购型号。'],
        actionKind: AutomationActionKind.openMarketPrice,
        actionLabel: '录入行情',
      ),
    ];
  }

  static List<AutomationTask> _purchaseGuardTasks(
    Storage storage,
    List<Device> devices,
    DateTime now,
  ) {
    final risky = <Device>[];
    for (final d in devices.where(
      (d) => d.status == 'in_stock' || d.status == 'listed',
    )) {
      final market = storage.getMarketPrice(d.model);
      final price = (market?['price'] as int?) ?? 0;
      if (price <= 0) continue;
      if (d.purchaseCost >= price - 15000) risky.add(d);
    }
    if (risky.isEmpty) return const <AutomationTask>[];
    risky.sort((a, b) => b.purchaseCost.compareTo(a.purchaseCost));
    final first = risky.first;
    final market = storage.getMarketPrice(first.model);
    final marketPrice = (market?['price'] as int?) ?? 0;
    return [
      AutomationTask(
        id: 'guard:${first.model}:${_dateKey(now)}',
        kind: AutomationTaskKind.purchaseGuard,
        impact: AutomationImpact.critical,
        priority: 20,
        title: '暂停高位收货',
        summary: '${risky.length} 台库存成本贴近今日批发价',
        metric: '${risky.length}台',
        detail: '先压价',
        reason: '现有库存成本已经接近行情，再按同价收货会压缩利润空间。',
        lines:
            risky
                .take(3)
                .map(
                  (d) =>
                      '${d.model} ${d.capacity} · 成本${_yuan(d.purchaseCost)} · 行情${_yuan((storage.getMarketPrice(d.model)?['price'] as int?) ?? 0)}',
                )
                .toList(),
        actionKind: AutomationActionKind.openPurchaseDecision,
        actionLabel: '打开报价器',
        model: first.model,
        suggestedPriceFen: marketPrice > 0 ? marketPrice - 5000 : null,
      ),
    ];
  }

  static List<AutomationTask> _restockTasks(
    List<Device> devices,
    DateTime now,
  ) {
    final sold30 = <String, int>{};
    final stock = <String, int>{};
    final cutoff = now.subtract(const Duration(days: 30));
    for (final d in devices) {
      if (d.status == 'in_stock' || d.status == 'listed') {
        stock[d.model] = (stock[d.model] ?? 0) + 1;
      }
      if (d.status == 'sold' && _isAfterOrEqual(d.sellDate, cutoff)) {
        sold30[d.model] = (sold30[d.model] ?? 0) + 1;
      }
    }
    final candidates =
        sold30.entries.where((entry) {
            final current = stock[entry.key] ?? 0;
            return entry.value >= 2 && current <= (entry.value / 2).ceil();
          }).toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    if (candidates.isEmpty) return const <AutomationTask>[];
    final first = candidates.first;
    return [
      AutomationTask(
        id: 'restock:${first.key}:${_dateKey(now)}',
        kind: AutomationTaskKind.restock,
        impact: AutomationImpact.info,
        priority: 42,
        title: '可补主力型号',
        summary: '近30天动销快，当前库存偏低',
        metric: '${first.value}台',
        detail: '近30天',
        reason: '补货建议只提示方向，最终还要回到报价器看今日行情和压价线。',
        lines:
            candidates
                .take(3)
                .map(
                  (e) =>
                      '${e.key} · 近30天售${e.value}台 · 在售${stock[e.key] ?? 0}台',
                )
                .toList(),
        actionKind: AutomationActionKind.openRestock,
        actionLabel: '看补货建议',
        model: first.key,
      ),
    ];
  }

  static List<AutomationTask> _supplierRiskTasks(
    Storage storage,
    DateTime now,
  ) {
    final suppliers =
        storage.getSupplierStats().where((s) {
          final count = (s['count'] as int?) ?? 0;
          final afterSaleRate = (s['afterSaleRate'] as num?)?.toDouble() ?? 0;
          final avgProfit = (s['avgProfit'] as int?) ?? 0;
          return count >= 3 && (afterSaleRate >= 0.2 || avgProfit < 12000);
        }).toList();
    if (suppliers.isEmpty) return const <AutomationTask>[];
    suppliers.sort((a, b) {
      final ar = (a['afterSaleRate'] as num).toDouble();
      final br = (b['afterSaleRate'] as num).toDouble();
      return br.compareTo(ar);
    });
    final first = suppliers.first;
    final rate = ((first['afterSaleRate'] as num).toDouble() * 100).round();
    return [
      AutomationTask(
        id: 'supplier:${first['channel']}:${_dateKey(now)}',
        kind: AutomationTaskKind.supplierRisk,
        impact: AutomationImpact.warning,
        priority: 46,
        title: '供应商要降风险',
        summary: '${first['channel']} 售后或利润异常',
        metric: '$rate%',
        detail: '售后率',
        reason: '采购渠道的售后率和均利会直接影响真实净利，谈价时要带进去。',
        lines:
            suppliers
                .take(3)
                .map(
                  (s) =>
                      '${s['channel']} · ${s['count']}台 · 均利${_yuan(s['avgProfit'] as int)} · 售后${(((s['afterSaleRate'] as num).toDouble()) * 100).round()}%',
                )
                .toList(),
      ),
    ];
  }

  static List<AutomationTask> _orderRiskTasks(
    List<Order> orders,
    DateTime now,
  ) {
    final pending = orders.where((o) => o.status == 'pending').toList();
    if (pending.isNotEmpty) {
      return [
        AutomationTask(
          id: 'pending:${pending.first.id}:${_dateKey(now)}',
          kind: AutomationTaskKind.orderRisk,
          impact: AutomationImpact.warning,
          priority: 16,
          title: '核对待发货订单',
          summary: '待发货会拖慢回款和售后响应',
          metric: '${pending.length}单',
          detail: '待处理',
          reason: '先确认物流、买家信息和设备状态，避免订单卡在中间。',
          lines:
              pending
                  .take(3)
                  .map((o) => '${o.deviceName} · ${_yuan(o.amount)}')
                  .toList(),
          actionKind: AutomationActionKind.openOrder,
          actionLabel: '处理首单',
          orderId: pending.first.id,
        ),
      ];
    }

    final today = _dateKey(now);
    final lowProfit =
        orders
            .where((o) => o.createdAt.startsWith(today) && o.netProfit < 15000)
            .toList()
          ..sort((a, b) => a.netProfit.compareTo(b.netProfit));
    if (lowProfit.isEmpty) return const <AutomationTask>[];
    return [
      AutomationTask(
        id: 'low-profit:${lowProfit.first.id}:${_dateKey(now)}',
        kind: AutomationTaskKind.orderRisk,
        impact:
            lowProfit.first.netProfit < 0
                ? AutomationImpact.critical
                : AutomationImpact.warning,
        priority: lowProfit.first.netProfit < 0 ? 14 : 36,
        title: lowProfit.first.netProfit < 0 ? '复盘亏损订单' : '复盘低毛利订单',
        summary: '今天有订单利润低于安全线',
        metric: '${lowProfit.length}单',
        detail: '最低${_yuan(lowProfit.first.netProfit)}',
        reason: '低毛利通常来自拿货过高、维修漏算或平台手续费漏算。',
        lines:
            lowProfit
                .take(3)
                .map((o) => '${o.deviceName} · 净利${_yuan(o.netProfit)}')
                .toList(),
        actionKind: AutomationActionKind.openOrder,
        actionLabel: '看首单',
        orderId: lowProfit.first.id,
      ),
    ];
  }

  static List<AutomationTask> _dataHealthTasks(
    List<Device> devices,
    DateTime now,
  ) {
    final issues = <String>[];
    final bySerial = <String, int>{};
    for (final d in devices) {
      final serial = d.serial.trim().toUpperCase();
      if (serial.isNotEmpty && serial != '未填写') {
        bySerial[serial] = (bySerial[serial] ?? 0) + 1;
      }
      if (d.batteryHealth < 50 || d.batteryHealth > 100) {
        issues.add('${d.model} ${d.capacity} 电池健康异常：${d.batteryHealth}%');
      }
      if (d.cycleCount < 0 || d.cycleCount > 3000) {
        issues.add('${d.model} ${d.capacity} 循环次数异常：${d.cycleCount}');
      }
    }
    for (final entry in bySerial.entries) {
      if (entry.value > 1) issues.add('序列号重复：${entry.key}');
    }
    if (issues.isEmpty) return const <AutomationTask>[];
    return [
      AutomationTask(
        id: 'data-health:${_dateKey(now)}',
        kind: AutomationTaskKind.dataHealth,
        impact: AutomationImpact.warning,
        priority: 50,
        title: '数据体检有异常',
        summary: '有字段可能影响报价或售后判断',
        metric: '${issues.length}项',
        detail: '需复核',
        reason: '基础数据错了，AI 后面的定价、文案和采购建议都会被带偏。',
        lines: issues.take(4).toList(),
      ),
    ];
  }

  static int recommendedStalePrice(Device device, Storage storage) {
    final current = device.sellPrice;
    final market =
        (storage.getMarketPrice(device.model)?['price'] as int?) ?? 0;
    final base =
        current > 0
            ? current
            : market > 0
            ? market
            : calcAutoPrice(device.purchaseCost);
    if (base <= 0) return 0;
    final cutRate =
        device.stockDays >= 45
            ? 0.10
            : device.stockDays >= 30
            ? 0.07
            : 0.04;
    final suggested = (base * (1 - cutRate)).round();
    final floor = device.purchaseCost + 8000;
    final target = _roundToYuan(suggested < floor ? floor : suggested);
    if (current > 0 && target >= current) return 0;
    return target;
  }

  static bool _isAfterOrEqual(String? raw, DateTime cutoff) {
    if (raw == null || raw.isEmpty) return false;
    try {
      final date = DateTime.parse(raw);
      return date.isAfter(cutoff) || _dateKey(date) == _dateKey(cutoff);
    } catch (_) {
      return false;
    }
  }

  static int _roundToYuan(int fen) => ((fen / 100).round()) * 100;

  static String _priceOrUnset(int fen) => fen > 0 ? _yuan(fen) : '未定价';

  static String _yuan(int fen) => '¥${(fen / 100).round()}';

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
