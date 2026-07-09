// 文件存储层 —— 零依赖，用dart:io + JSON持久化
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'models.dart';

class Storage {
  final String _path;
  Map<String, dynamic> _cache = {};
  final StreamController<void> _changes = StreamController<void>.broadcast();

  Storage(this._path);

  Stream<void> get changes => _changes.stream;

  static const int schemaVersion = 1;

  static const Set<String> _requiredCollections = {
    'devices',
    'orders',
    'agents',
    'repairOrders',
    'repairParts',
    'purchaseOrders',
    'qcReports',
    'xianyuCopyExamples',
  };

  static const Set<String> _retiredCollections = {
    'allocations',
    'rentals',
    'installmentPlans',
    'deposits',
    'warehouses',
    'transfers',
    'inventoryCounts',
    'otherInOuts',
  };

  Map<String, dynamic> _emptyData() => {
    'schemaVersion': schemaVersion,
    'devices': [],
    'orders': [],
    'agents': [],
    'repairOrders': [],
    'repairParts': [],
    'purchaseOrders': [],
    'qcReports': [],
    'xianyuCopyExamples': [],
    'settings': {},
  };

  static Map<String, dynamic> normalizeDataMap(Map data) {
    final normalized = <String, dynamic>{};
    for (final entry in data.entries) {
      normalized[entry.key.toString()] = entry.value;
    }
    normalized['schemaVersion'] ??= schemaVersion;

    for (final key in _requiredCollections) {
      final value = normalized[key];
      if (value == null) {
        normalized[key] = [];
      } else if (value is! List) {
        throw FormatException('数据结构错误：$key 不是列表');
      }
    }

    final settings = normalized['settings'];
    if (settings == null) {
      normalized['settings'] = <String, dynamic>{};
    } else if (settings is Map) {
      normalized['settings'] = Map<String, dynamic>.from(settings);
    } else {
      throw const FormatException('数据结构错误：settings 不是对象');
    }
    return normalized;
  }

  static void validateDataMap(Map data) {
    normalizeDataMap(data);
  }

  void _dropRetiredCollections() {
    for (final key in _retiredCollections) {
      _cache.remove(key);
    }
  }

  void _ensureSchema() {
    _cache = normalizeDataMap(_cache);
  }

  Future<Map<String, dynamic>> _readDataFile(File file) async {
    final raw = await file.readAsString();
    final decoded = json.decode(raw);
    if (decoded is! Map) {
      throw const FormatException('数据文件根节点不是对象');
    }
    return normalizeDataMap(decoded);
  }

  /// 数据文件结构：{ devices: [...], orders: [...], agents: [...], repairOrders: [...], settings: {...} }
  Future<void> load() async {
    try {
      final file = File(_path);
      if (await file.exists()) {
        _cache = await _readDataFile(file);
        _dropRetiredCollections();
      } else {
        _cache = _emptyData();
      }
    } catch (e) {
      final bak = File('$_path.bak');
      try {
        if (await bak.exists()) {
          _cache = await _readDataFile(bak);
          _dropRetiredCollections();
        } else {
          _cache = _emptyData();
        }
      } catch (_) {
        _cache = _emptyData();
      }
    }
  }

  Future<void> _flush() async {
    final file = File(_path);
    final parent = file.parent;
    if (!await parent.exists()) await parent.create(recursive: true);
    _ensureSchema();
    _dropRetiredCollections();

    final raw = json.encode(_cache);
    final decoded = json.decode(raw);
    if (decoded is! Map) {
      throw const FormatException('数据文件根节点不是对象');
    }
    validateDataMap(decoded);

    final tmp = File('$_path.tmp');
    final bak = File('$_path.bak');
    await tmp.writeAsString(raw);
    await _readDataFile(tmp);

    if (await file.exists()) {
      await file.copy(bak.path);
    }

    try {
      await tmp.copy(file.path);
      if (await tmp.exists()) await tmp.delete();
      if (!_changes.isClosed) _changes.add(null);
    } catch (_) {
      if (await bak.exists()) {
        await bak.copy(file.path);
      }
      rethrow;
    }
  }

  List<Device> getDevices() {
    final list = _cache['devices'] as List? ?? [];
    return list.map((e) => Device.fromJson(e as Map<String, dynamic>)).toList();
  }

  List<Order> getOrders() {
    final list = _cache['orders'] as List? ?? [];
    return list.map((e) => Order.fromJson(e as Map<String, dynamic>)).toList();
  }

  Map<String, dynamic> getSettings() {
    final s = _cache['settings'];
    if (s == null) return {};
    if (s is Map<String, dynamic>) return s;
    return Map<String, dynamic>.from(s);
  }

  Future<void> saveSettings(Map<String, dynamic> s) async {
    _cache['settings'] = s;
    await _flush();
  }

  Future<void> prepareForUserDataStartup() async {
    final settings = getSettings();
    if (settings['initialized'] == true) return;

    if (_hasNoBusinessData() || _hasOnlyBundledDemoData()) {
      await clearAll(markInitialized: true);
      return;
    }

    settings['initialized'] = true;
    await saveSettings(settings);
  }

  bool _hasNoBusinessData() =>
      _isCollectionEmpty('devices') &&
      _isCollectionEmpty('orders') &&
      _isCollectionEmpty('agents') &&
      _isCollectionEmpty('repairOrders') &&
      _isCollectionEmpty('repairParts') &&
      _isCollectionEmpty('purchaseOrders') &&
      _isCollectionEmpty('qcReports') &&
      _isCollectionEmpty('xianyuCopyExamples');

  bool _isCollectionEmpty(String key) {
    final value = _cache[key];
    return value is! List || value.isEmpty;
  }

  bool _hasOnlyBundledDemoData() {
    final hasAnyDemoData =
        _hasAnyCollectionItem('devices') ||
        _hasAnyCollectionItem('orders') ||
        _hasAnyCollectionItem('agents') ||
        _hasAnyCollectionItem('repairOrders');
    if (!hasAnyDemoData) return false;

    return _collectionIdsAllowed('devices', {
          'demo1',
          'demo2',
          'demo3',
          'demo4',
          'demo5',
        }) &&
        _collectionIdsAllowed('orders', {'o1', 'o2'}) &&
        _collectionIdsAllowed('agents', {'a1'}) &&
        _collectionIdsAllowed('repairOrders', {'r1'}) &&
        _isCollectionEmpty('repairParts') &&
        _isCollectionEmpty('purchaseOrders') &&
        _isCollectionEmpty('qcReports') &&
        _isCollectionEmpty('xianyuCopyExamples');
  }

  bool _hasAnyCollectionItem(String key) {
    final value = _cache[key];
    return value is List && value.isNotEmpty;
  }

  bool _collectionIdsAllowed(String key, Set<String> allowedIds) {
    final value = _cache[key];
    if (value is! List) return true;
    for (final item in value) {
      if (item is! Map) return false;
      final id = item['id'];
      if (id is! String || !allowedIds.contains(id)) return false;
    }
    return true;
  }

  Future<Device> addDevice(Device d) async {
    final list = getDevices();
    list.add(d);
    _cache['devices'] = list.map((e) => e.toJson()).toList();
    await _flush();
    return d;
  }

  Future<void> updateDevice(Device d) async {
    final list = getDevices();
    final idx = list.indexWhere((e) => e.id == d.id);
    if (idx >= 0) {
      list[idx] = d;
      _cache['devices'] = list.map((e) => e.toJson()).toList();
      await _flush();
    }
  }

  Future<void> deleteDevice(String id) async {
    final list = getDevices().where((e) => e.id != id).toList();
    _cache['devices'] = list.map((e) => e.toJson()).toList();
    await _flush();
  }

  // ====== 闲鱼文案经验库 ======
  String getXianyuCopyRules() {
    final settings = getSettings();
    return settings['xianyuCopyRules'] as String? ?? '';
  }

  Future<void> saveXianyuCopyRules(String rules) async {
    final settings = getSettings();
    settings['xianyuCopyRules'] = rules;
    await saveSettings(settings);
  }

  Map<String, String> getAiPromptRules() {
    final raw = getSettings()['aiPromptRules'];
    if (raw is! Map) return {};
    return raw.map((key, value) => MapEntry(key.toString(), value.toString()));
  }

  Future<void> saveAiPromptRules(Map<String, String> rules) async {
    final settings = getSettings();
    if (rules.isEmpty) {
      settings.remove('aiPromptRules');
    } else {
      settings['aiPromptRules'] = Map<String, String>.from(rules);
    }
    await saveSettings(settings);
  }

  List<XianyuCopyExample> getXianyuCopyExamples() {
    final list = _cache['xianyuCopyExamples'] as List? ?? [];
    return list
        .map((e) => XianyuCopyExample.fromJson(e as Map<String, dynamic>))
        .where((e) => e.text.trim().isNotEmpty)
        .toList();
  }

  Future<XianyuCopyExample> addXianyuCopyExample(
    XianyuCopyExample example,
  ) async {
    final list = getXianyuCopyExamples();
    list.insert(0, example);
    _cache['xianyuCopyExamples'] = list.map((e) => e.toJson()).toList();
    await _flush();
    return example;
  }

  Future<void> updateXianyuCopyExample(XianyuCopyExample example) async {
    final list = getXianyuCopyExamples();
    final idx = list.indexWhere((e) => e.id == example.id);
    if (idx >= 0) {
      list[idx] = example;
      _cache['xianyuCopyExamples'] = list.map((e) => e.toJson()).toList();
      await _flush();
    }
  }

  Future<void> deleteXianyuCopyExample(String id) async {
    final list = getXianyuCopyExamples().where((e) => e.id != id).toList();
    _cache['xianyuCopyExamples'] = list.map((e) => e.toJson()).toList();
    await _flush();
  }

  Future<int> importSoldDescriptionsAsCopyExamples({int limit = 20}) async {
    final existingTexts =
        getXianyuCopyExamples().map((e) => e.text.trim()).toSet();
    final sold =
        getDevices()
            .where(
              (d) =>
                  d.status == 'sold' && (d.description ?? '').trim().isNotEmpty,
            )
            .toList();
    sold.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    var imported = 0;
    for (final d in sold) {
      if (imported >= limit) break;
      final text = d.description!.trim();
      if (existingTexts.contains(text)) continue;
      existingTexts.add(text);
      await addXianyuCopyExample(
        XianyuCopyExample(
          id: 'copy_${DateTime.now().microsecondsSinceEpoch}_$imported',
          title: '${d.model} ${d.capacity}',
          model: d.model,
          condition: d.condition,
          text: text,
          tags: '已售导入',
          resultNote:
              d.sellPrice > 0
                  ? '已售出，成交价 ${(d.sellPrice / 100).round()} 元'
                  : '已售出',
          score: 4,
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
      imported++;
    }
    return imported;
  }

  Future<Order> addOrder(Order o) async {
    final list = getOrders();
    list.insert(0, o);
    _cache['orders'] = list.map((e) => e.toJson()).toList();
    await _flush();
    return o;
  }

  Future<void> updateOrder(Order o) async {
    final list = getOrders();
    final idx = list.indexWhere((e) => e.id == o.id);
    if (idx >= 0) {
      list[idx] = o;
      _cache['orders'] = list.map((e) => e.toJson()).toList();
      await _flush();
    }
  }

  // ====== 采购单（报表数据） ======
  List<PurchaseOrder> getPurchaseOrders() {
    final list = _cache['purchaseOrders'] as List? ?? [];
    return list
        .map((e) => PurchaseOrder.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PurchaseOrder> addPurchaseOrder(PurchaseOrder p) async {
    final list = getPurchaseOrders();
    list.insert(0, p);
    _cache['purchaseOrders'] = list.map((e) => e.toJson()).toList();
    await _flush();
    return p;
  }

  Future<void> updatePurchaseOrder(PurchaseOrder p) async {
    final list = getPurchaseOrders();
    final idx = list.indexWhere((e) => e.id == p.id);
    if (idx >= 0) {
      list[idx] = p;
      _cache['purchaseOrders'] = list.map((e) => e.toJson()).toList();
      await _flush();
    }
  }

  Future<void> deletePurchaseOrder(String id) async {
    final list = getPurchaseOrders().where((e) => e.id != id).toList();
    _cache['purchaseOrders'] = list.map((e) => e.toJson()).toList();
    await _flush();
  }

  // ====== 质检报告（报表数据） ======
  List<QCReport> getQCReports() {
    final list = _cache['qcReports'] as List? ?? [];
    return list
        .map((e) => QCReport.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  QCReport? getQCReportByDevice(String deviceId) {
    final reports =
        getQCReports().where((r) => r.deviceId == deviceId).toList();
    return reports.isEmpty ? null : reports.first;
  }

  Future<QCReport> addQCReport(QCReport r) async {
    final list = getQCReports();
    list.insert(0, r);
    _cache['qcReports'] = list.map((e) => e.toJson()).toList();
    await _flush();
    return r;
  }

  Future<void> updateQCReport(QCReport r) async {
    final list = getQCReports();
    final idx = list.indexWhere((e) => e.id == r.id);
    if (idx >= 0) {
      list[idx] = r;
      _cache['qcReports'] = list.map((e) => e.toJson()).toList();
      await _flush();
    }
  }

  // ====== 代理 ======
  List<Agent> getAgents() {
    final list = _cache['agents'] as List? ?? [];
    return list.map((e) => Agent.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Agent> addAgent(Agent a) async {
    final list = getAgents();
    list.add(a);
    _cache['agents'] = list.map((e) => e.toJson()).toList();
    await _flush();
    return a;
  }

  Future<void> updateAgent(Agent a) async {
    final list = getAgents();
    final idx = list.indexWhere((e) => e.id == a.id);
    if (idx >= 0) {
      list[idx] = a;
      _cache['agents'] = list.map((e) => e.toJson()).toList();
      await _flush();
    }
  }

  Future<void> deleteAgent(String id) async {
    final list = getAgents().where((e) => e.id != id).toList();
    _cache['agents'] = list.map((e) => e.toJson()).toList();
    await _flush();
  }

  // ====== 维修工单 ======
  List<RepairOrder> getRepairOrders() {
    final list = _cache['repairOrders'] as List? ?? [];
    return list
        .map((e) => RepairOrder.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<RepairOrder> addRepairOrder(RepairOrder r) async {
    final list = getRepairOrders();
    list.insert(0, r);
    _cache['repairOrders'] = list.map((e) => e.toJson()).toList();
    await _flush();
    return r;
  }

  Future<void> updateRepairOrder(RepairOrder r) async {
    final list = getRepairOrders();
    final idx = list.indexWhere((e) => e.id == r.id);
    if (idx >= 0) {
      list[idx] = r;
      _cache['repairOrders'] = list.map((e) => e.toJson()).toList();
      await _flush();
    }
  }

  Future<void> deleteRepairOrder(String id) async {
    final list = getRepairOrders().where((e) => e.id != id).toList();
    _cache['repairOrders'] = list.map((e) => e.toJson()).toList();
    await _flush();
  }

  /// 清空所有数据
  Future<void> clearAll({bool markInitialized = false}) async {
    _cache = _emptyData();
    if (markInitialized) {
      _cache['settings'] = <String, dynamic>{'initialized': true};
    }
    await _flush();
  }

  /// 计算今日统计
  Stats computeStats() {
    final devices = getDevices();
    final orders = getOrders();
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    int gmv = 0, grossProfit = 0, orderCount = 0;
    final channelGmv = <String, int>{};
    for (final o in orders) {
      if (o.status == 'cancelled') continue; // 作废订单不计入统计
      if (o.createdAt.startsWith(todayStr)) {
        gmv += o.amount;
        grossProfit += o.netProfit; // 净利（扣售后）
        orderCount++;
      }
      channelGmv[o.channel] = (channelGmv[o.channel] ?? 0) + o.amount;
    }

    int inStock = 0, stagnant = 0, capital = 0, pendingQc = 0;
    for (final d in devices) {
      if (d.status == 'in_stock' || d.status == 'listed') {
        inStock++;
        capital += d.purchaseCost;
        if (d.isStagnant) stagnant++;
        if (d.status == 'in_stock' && d.sellPrice == 0) pendingQc++;
      }
    }

    int pending = 0, shipped = 0;
    for (final o in orders) {
      if (o.status == 'pending') pending++;
      if (o.status == 'shipped') shipped++;
    }

    return Stats(
      gmv: gmv,
      grossProfit: grossProfit,
      orderCount: orderCount,
      inStockCount: inStock,
      stagnantCount: stagnant,
      capitalOccupied: capital,
      pendingCount: pending,
      shippedCount: shipped,
      pendingQcCount: pendingQc,
      channelGmv: channelGmv,
    );
  }

  /// 近7天每日统计（用于趋势图）
  List<DailyStat> getDailyStats({int days = 7}) {
    final orders = getOrders();
    final result = <DailyStat>[];
    final now = DateTime.now();
    for (int i = days - 1; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final ds =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      int gmv = 0, profit = 0;
      for (final o in orders) {
        if (o.status == 'cancelled') continue;
        if (o.createdAt.startsWith(ds)) {
          gmv += o.amount;
          profit += o.netProfit;
        }
      }
      result.add(DailyStat(date: ds, gmv: gmv, profit: profit));
    }
    return result;
  }

  /// 近 N 月每月统计（用于趋势图月度视图）
  /// 每项 date 为 "yyyy-MM"，profit 为该月毛利合计
  List<DailyStat> getMonthlyStats({int months = 12}) {
    final orders = getOrders();
    final result = <DailyStat>[];
    final now = DateTime.now();
    for (int i = months - 1; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      final ms = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      int profit = 0;
      for (final o in orders) {
        if (o.status == 'cancelled') continue;
        if (o.createdAt.startsWith(ms)) {
          profit += o.netProfit;
        }
      }
      result.add(DailyStat(date: ms, profit: profit));
    }
    return result;
  }

  /// 本月每周毛利（按自然月内第1/2/3...周聚合）
  List<DailyStat> getCurrentMonthWeeklyStats({DateTime? month}) {
    final orders = getOrders();
    final base = month ?? DateTime.now();
    final firstDay = DateTime(base.year, base.month, 1);
    final nextMonth = DateTime(base.year, base.month + 1, 1);
    final daysInMonth = nextMonth.difference(firstDay).inDays;
    final weeks = ((daysInMonth + firstDay.weekday - 1) / 7).ceil();
    final profits = List<int>.filled(weeks, 0);

    for (final o in orders) {
      if (o.status == 'cancelled') continue;
      DateTime? created;
      try {
        created = DateTime.parse(o.createdAt.substring(0, 10));
      } catch (_) {
        continue;
      }
      if (created.isBefore(firstDay) || !created.isBefore(nextMonth)) {
        continue;
      }
      final offset = created.difference(firstDay).inDays + firstDay.weekday - 1;
      final index = (offset / 7).floor().clamp(0, weeks - 1).toInt();
      profits[index] += o.netProfit;
    }

    return List.generate(
      weeks,
      (i) => DailyStat(date: '第${i + 1}周', profit: profits[i]),
    );
  }

  /// 昨日毛利（用于首页趋势箭头对比）
  int getYesterdayProfit() {
    final orders = getOrders();
    final y = DateTime.now().subtract(const Duration(days: 1));
    final ys =
        '${y.year}-${y.month.toString().padLeft(2, '0')}-${y.day.toString().padLeft(2, '0')}';
    int profit = 0;
    for (final o in orders) {
      if (o.status == 'cancelled') continue;
      if (o.createdAt.startsWith(ys)) profit += o.netProfit;
    }
    return profit;
  }

  /// 昨日订单数
  int getYesterdayOrderCount() {
    final orders = getOrders();
    final y = DateTime.now().subtract(const Duration(days: 1));
    final ys =
        '${y.year}-${y.month.toString().padLeft(2, '0')}-${y.day.toString().padLeft(2, '0')}';
    int n = 0;
    for (final o in orders) {
      if (o.status == 'cancelled') continue;
      if (o.createdAt.startsWith(ys)) n++;
    }
    return n;
  }

  /// 昨日GMV（分）
  int getYesterdayGmv() {
    final orders = getOrders();
    final y = DateTime.now().subtract(const Duration(days: 1));
    final ys =
        '${y.year}-${y.month.toString().padLeft(2, '0')}-${y.day.toString().padLeft(2, '0')}';
    int gmv = 0;
    for (final o in orders) {
      if (o.status == 'cancelled') continue;
      if (o.createdAt.startsWith(ys)) gmv += o.amount;
    }
    return gmv;
  }

  /// 各渠道GMV
  Map<String, int> getChannelGmv() {
    final orders = getOrders();
    final m = <String, int>{};
    for (final o in orders) {
      if (o.status == 'cancelled') continue;
      m[o.channel] = (m[o.channel] ?? 0) + o.amount;
    }
    return m;
  }

  /// 客户聚合（从订单buyer）
  List<Map<String, dynamic>> getCustomers() {
    final orders = getOrders();
    final map = <String, Map<String, dynamic>>{};
    for (final o in orders) {
      if (o.status == 'cancelled') continue;
      final key = o.buyer.isEmpty ? '未知客户' : o.buyer;
      if (!map.containsKey(key)) {
        map[key] = {
          'name': key,
          'count': 0,
          'totalAmount': 0,
          'lastDate': o.createdAt,
          'channels': <String>{},
        };
      }
      final c = map[key]!;
      c['count'] = (c['count'] as int) + 1;
      c['totalAmount'] = (c['totalAmount'] as int) + o.amount;
      if (o.createdAt.compareTo(c['lastDate'] as String) > 0) {
        c['lastDate'] = o.createdAt;
      }
      (c['channels'] as Set<String>).add(o.channel);
    }
    return map.values.toList()..sort(
      (a, b) => (b['totalAmount'] as int).compareTo(a['totalAmount'] as int),
    );
  }

  /// 按型号聚合利润
  List<Map<String, dynamic>> getProfitByModel() {
    final devices = getDevices().where((d) => d.status == 'sold').toList();
    final map = <String, Map<String, dynamic>>{};
    for (final d in devices) {
      final key = d.model;
      if (!map.containsKey(key)) {
        map[key] = {'model': key, 'count': 0, 'profit': 0, 'revenue': 0};
      }
      final m = map[key]!;
      m['count'] = (m['count'] as int) + 1;
      m['profit'] = (m['profit'] as int) + d.netProfit;
      m['revenue'] = (m['revenue'] as int) + d.sellPrice;
    }
    return map.values.toList()
      ..sort((a, b) => (b['profit'] as int).compareTo(a['profit'] as int));
  }

  // ====== 经营分析方法 ======

  /// 库存年龄分布：{0-7天, 8-15天, 16-30天, 30+天}
  Map<String, int> getInventoryAgeDist() {
    final devices =
        getDevices()
            .where((d) => d.status == 'in_stock' || d.status == 'listed')
            .toList();
    return {
      '0-7天': devices.where((d) => d.stockDays <= 7).length,
      '8-15天':
          devices.where((d) => d.stockDays > 7 && d.stockDays <= 15).length,
      '16-30天':
          devices.where((d) => d.stockDays > 15 && d.stockDays <= 30).length,
      '30天+': devices.where((d) => d.stockDays > 30).length,
    };
  }

  /// 平均单台利润（分）。已售非cancelled订单 netProfit 均值
  int getAvgProfit() {
    final orders = getOrders().where((o) => o.status != 'cancelled').toList();
    if (orders.isEmpty) return 0;
    return orders.fold<int>(0, (a, o) => a + o.netProfit) ~/ orders.length;
  }

  /// 平均周转天数。已售设备 sellDate - purchaseDate 均值
  int getAvgTurnoverDays() {
    final devices =
        getDevices()
            .where((d) => d.status == 'sold' && d.sellDate != null)
            .toList();
    if (devices.isEmpty) return 0;
    int total = 0, n = 0;
    for (final d in devices) {
      try {
        final p = DateTime.parse(d.purchaseDate);
        final s = DateTime.parse(d.sellDate!);
        total += s.difference(p).inDays;
        n++;
      } catch (_) {}
    }
    return n > 0 ? total ~/ n : 0;
  }

  /// 按型号聚合周转天数（已售设备）
  List<Map<String, dynamic>> getTurnoverByModel() {
    final devices =
        getDevices()
            .where((d) => d.status == 'sold' && d.sellDate != null)
            .toList();
    final map = <String, Map<String, dynamic>>{};
    for (final d in devices) {
      int days = 0;
      try {
        days =
            DateTime.parse(
              d.sellDate!,
            ).difference(DateTime.parse(d.purchaseDate)).inDays;
      } catch (_) {}
      final key = d.model;
      if (!map.containsKey(key)) {
        map[key] = {'model': key, 'count': 0, 'totalDays': 0};
      }
      final m = map[key]!;
      m['count'] = (m['count'] as int) + 1;
      m['totalDays'] = (m['totalDays'] as int) + days;
    }
    final result =
        map.values
            .map(
              (m) => {
                'model': m['model'],
                'count': m['count'],
                'avgDays':
                    (m['count'] as int) > 0
                        ? (m['totalDays'] as int) ~/ (m['count'] as int)
                        : 0,
              },
            )
            .toList();
    result.sort((a, b) => (a['avgDays'] as int).compareTo(b['avgDays'] as int));
    return result;
  }

  /// 供应商（采购渠道）分析：按 purchaseChannel 聚合已售设备，含售后率
  List<Map<String, dynamic>> getSupplierStats() {
    final devices = getDevices().where((d) => d.status == 'sold').toList();
    final orders = getOrders().where((o) => o.status != 'cancelled').toList();
    final map = <String, Map<String, dynamic>>{};
    for (final d in devices) {
      final key = d.purchaseChannel.isEmpty ? '未知渠道' : d.purchaseChannel;
      if (!map.containsKey(key)) {
        map[key] = {
          'channel': key,
          'count': 0,
          'profit': 0,
          'revenue': 0,
          'afterSaleCount': 0,
        };
      }
      final m = map[key]!;
      m['count'] = (m['count'] as int) + 1;
      m['profit'] = (m['profit'] as int) + d.netProfit;
      m['revenue'] = (m['revenue'] as int) + d.sellPrice;
      // 售后判定：该设备关联的订单有 afterSaleCost 或状态为 aftersale
      final hasAfterSale = orders.any(
        (o) =>
            o.deviceId == d.id &&
            (o.afterSaleCost != null && o.afterSaleCost! > 0 ||
                o.status == 'aftersale'),
      );
      if (hasAfterSale) m['afterSaleCount'] = (m['afterSaleCount'] as int) + 1;
    }
    final result =
        map.values
            .map(
              (m) => {
                'channel': m['channel'],
                'count': m['count'],
                'profit': m['profit'],
                'revenue': m['revenue'],
                'avgProfit':
                    (m['count'] as int) > 0
                        ? (m['profit'] as int) ~/ (m['count'] as int)
                        : 0,
                'afterSaleRate':
                    (m['count'] as int) > 0
                        ? (m['afterSaleCount'] as int) / (m['count'] as int)
                        : 0.0,
              },
            )
            .toList();
    result.sort((a, b) => (b['profit'] as int).compareTo(a['profit'] as int));
    return result;
  }

  /// 资金周转率 = 本月销售额 ÷ 当前在售库存资金占用
  double getCapitalTurnoverRate() {
    final now = DateTime.now();
    final ms = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final orders =
        getOrders()
            .where((o) => o.status != 'cancelled' && o.createdAt.startsWith(ms))
            .toList();
    final monthSales = orders.fold<int>(0, (a, o) => a + o.amount);
    final inStockDevices =
        getDevices()
            .where((d) => d.status == 'in_stock' || d.status == 'listed')
            .toList();
    if (inStockDevices.isEmpty) return 0;
    final capital = inStockDevices.fold<int>(0, (a, d) => a + d.purchaseCost);
    if (capital == 0) return 0;
    return monthSales / capital;
  }

  /// 按型号综合分析（采购决策用）。返回结构化指标 Map。
  Map<String, dynamic> getModelAnalysis(String model) {
    final all = getDevices().where((d) => d.model == model).toList();
    final sold = all.where((d) => d.status == 'sold').toList();
    final inStock =
        all
            .where((d) => d.status == 'in_stock' || d.status == 'listed')
            .toList();
    final stagnant = inStock.where((d) => d.isStagnant).length;

    int salesCount = sold.length;
    int avgProfit =
        sold.isEmpty
            ? 0
            : sold.fold<int>(0, (a, d) => a + d.netProfit) ~/ sold.length;
    int avgSell =
        sold.isEmpty
            ? 0
            : sold.fold<int>(0, (a, d) => a + d.sellPrice) ~/ sold.length;
    int avgCost =
        sold.isEmpty
            ? 0
            : sold.fold<int>(0, (a, d) => a + d.purchaseCost) ~/ sold.length;

    int totalDays = 0, n = 0;
    for (final d in sold) {
      try {
        totalDays +=
            DateTime.parse(
              d.sellDate!,
            ).difference(DateTime.parse(d.purchaseDate)).inDays;
        n++;
      } catch (_) {}
    }
    int avgTurnover = n > 0 ? totalDays ~/ n : 0;

    int totalSeen = sold.length + inStock.length;
    double stagnantRate = totalSeen > 0 ? stagnant / totalSeen : 0.0;

    // 供应商分布（仅已售）
    final supMap = <String, Map<String, dynamic>>{};
    for (final d in sold) {
      final k = d.purchaseChannel.isEmpty ? '未知渠道' : d.purchaseChannel;
      supMap.putIfAbsent(k, () => {'channel': k, 'count': 0, 'profit': 0});
      supMap[k]!['count'] = (supMap[k]!['count'] as int) + 1;
      supMap[k]!['profit'] = (supMap[k]!['profit'] as int) + d.netProfit;
    }
    final suppliers =
        supMap.values.toList()
          ..sort((a, b) => (b['profit'] as int).compareTo(a['profit'] as int));

    return {
      'model': model,
      'salesCount': salesCount,
      'inStockCount': inStock.length,
      'stagnantCount': stagnant,
      'stagnantRate': stagnantRate,
      'avgProfit': avgProfit, // 分
      'avgSellPrice': avgSell, // 分
      'avgPurchaseCost': avgCost, // 分
      'avgTurnoverDays': avgTurnover,
      'suppliers': suppliers, // [{channel,count,profit}]
      'hasHistory': salesCount > 0,
    };
  }

  /// 库存预警数据（统计报表使用）
  List<Map<String, dynamic>> checkAlerts() {
    final msgs = <Map<String, dynamic>>[];
    final devices = getDevices();
    final inStock =
        devices
            .where((d) => d.status == 'in_stock' || d.status == 'listed')
            .toList();

    final modelCount = <String, int>{};
    for (final d in inStock) {
      modelCount[d.model] = (modelCount[d.model] ?? 0) + 1;
    }
    for (final entry in modelCount.entries) {
      if (entry.value <= 5) {
        msgs.add({
          'type': 'low_stock',
          'model': entry.key,
          'count': entry.value,
          'threshold': 5,
        });
      }
    }

    final staleInStock = inStock.where((d) => d.stockDays >= 15).toList();
    if (staleInStock.isNotEmpty) {
      final modelStale = <String, int>{};
      for (final d in staleInStock) {
        modelStale[d.model] = (modelStale[d.model] ?? 0) + 1;
      }
      for (final entry in modelStale.entries) {
        msgs.add({
          'type': 'stagnant',
          'model': entry.key,
          'count': entry.value,
          'days': 15,
        });
      }
    }

    return msgs;
  }

  // ====== 市场行情（华强北批发价，每日手动录入） ======

  /// 获取某型号最新市场行情 {date, price}，无则返回 null
  Map<String, dynamic>? getMarketPrice(String model) {
    final prices = _getMarketPricesMap()[model] as List?;
    if (prices == null || prices.isEmpty) return null;
    final last = prices.last as Map<String, dynamic>;
    return {'date': last['date'], 'price': last['price']};
  }

  /// 获取某型号近 N 天行情历史（升序）
  List<Map<String, dynamic>> getMarketPriceHistory(
    String model, {
    int days = 30,
  }) {
    final prices = _getMarketPricesMap()[model] as List?;
    if (prices == null) return [];
    final list =
        prices.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    if (list.length > days) return list.sublist(list.length - days);
    return list;
  }

  /// 保存某��号今日行情（同日覆盖）
  Future<void> saveMarketPrice(String model, int priceFen) async {
    final settings = getSettings();
    final mp = _getMarketPricesMap();
    final today = _todayStr();
    final list =
        (mp[model] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];
    // 同日覆盖
    if (list.isNotEmpty && list.last['date'] == today) {
      list.last['price'] = priceFen;
    } else {
      list.add({'date': today, 'price': priceFen});
    }
    // 只保留近 90 天
    if (list.length > 90) list.removeRange(0, list.length - 90);
    mp[model] = list;
    settings['marketPrices'] = mp;
    await saveSettings(settings);
  }

  /// 所有型号最新行情 {model: {date, price}}
  Map<String, Map<String, dynamic>> getAllLatestMarketPrices() {
    final mp = _getMarketPricesMap();
    final result = <String, Map<String, dynamic>>{};
    for (final entry in mp.entries) {
      final list = entry.value as List?;
      if (list != null && list.isNotEmpty) {
        final last = list.last as Map<String, dynamic>;
        result[entry.key] = {'date': last['date'], 'price': last['price']};
      }
    }
    return result;
  }

  /// 今天是否已更新过任意行情
  bool isMarketPriceUpdatedToday() {
    final today = _todayStr();
    final mp = _getMarketPricesMap();
    for (final list in mp.values) {
      if (list is List && list.isNotEmpty) {
        final last = list.last as Map<String, dynamic>;
        if (last['date'] == today) return true;
      }
    }
    return false;
  }

  Map<String, dynamic> _getMarketPricesMap() {
    final s = getSettings();
    final mp = s['marketPrices'];
    if (mp == null) return {};
    if (mp is Map<String, dynamic>) return mp;
    return Map<String, dynamic>.from(mp);
  }

  String _todayStr() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  /// 导出完整数据（用于云端同步上传）
  Map<String, dynamic> toFullMap() {
    final data = Map<String, dynamic>.from(_cache);
    for (final key in _retiredCollections) {
      data.remove(key);
    }
    return data;
  }

  /// 用云端数据覆盖本地（用于云端同步下载）
  void setFullData(Map<String, dynamic> data) {
    _cache = normalizeDataMap(data);
    _dropRetiredCollections();
  }

  /// 直接刷写到文件
  Future<void> save() async => await _flush();

  // ====== ???? ======

  /// 质检统计：各品级数量 + 通过率
  Map<String, dynamic> getQCStats() {
    final reports = getQCReports();
    final passed = reports.where((r) => r.conclusion == '通过').length;
    final byGrade = <String, int>{};
    for (final r in reports) {
      byGrade[r.grade] = (byGrade[r.grade] ?? 0) + 1;
    }
    return {
      'total': reports.length,
      'passed': passed,
      'passRate': reports.isEmpty ? 0.0 : passed / reports.length,
      'byGrade': byGrade,
    };
  }

  /// 质检缺陷分布
  Map<String, int> getQCDefects() {
    final reports = getQCReports();
    final defects = <String, int>{};
    for (final r in reports) {
      if (r.screenCondition != '完美') defects['屏幕'] = (defects['屏幕'] ?? 0) + 1;
      if (r.frameCondition != '完美') defects['边框'] = (defects['边框'] ?? 0) + 1;
      if (r.backCondition != '完美') defects['背板'] = (defects['背板'] ?? 0) + 1;
      if (r.cameraCondition != '正常') defects['摄像头'] = (defects['摄像头'] ?? 0) + 1;
      if (!r.hasFaceId) defects['Face ID'] = (defects['Face ID'] ?? 0) + 1;
      if (!r.hasTouchId) defects['Touch ID'] = (defects['Touch ID'] ?? 0) + 1;
      if (!r.wifiOk) defects['WiFi'] = (defects['WiFi'] ?? 0) + 1;
      if (!r.bluetoothOk) defects['蓝牙'] = (defects['蓝牙'] ?? 0) + 1;
      if (!r.microphoneOk) defects['麦克风'] = (defects['麦克风'] ?? 0) + 1;
      if (!r.speakerOk) defects['扬声器'] = (defects['扬声器'] ?? 0) + 1;
    }
    return defects;
  }

  Map<String, dynamic> getRepairStats() {
    final repairs = getRepairOrders();
    final byType = <String, dynamic>{
      'count': <String, int>{},
      'cost': <String, int>{},
    };
    final byStatus = <String, int>{};
    int totalCost = 0;
    for (final r in repairs) {
      final tc = byType['count'] as Map<String, int>;
      tc[r.type] = (tc[r.type] ?? 0) + 1;
      final tco = byType['cost'] as Map<String, int>;
      tco[r.type] = (tco[r.type] ?? 0) + r.cost;
      byStatus[r.status] = (byStatus[r.status] ?? 0) + 1;
      totalCost += r.cost;
    }
    return {
      'total': repairs.length,
      'totalCost': totalCost,
      'avgCost': repairs.isEmpty ? 0 : totalCost ~/ repairs.length,
      'byType': byType,
      'byStatus': byStatus,
    };
  }

  /// 销售报表：渠道分析（含GMV+利润+订单数）
  List<Map<String, dynamic>> getSalesChannelStats() {
    final orders = getOrders().where((o) => o.status != 'cancelled').toList();
    final map = <String, Map<String, dynamic>>{};
    for (final o in orders) {
      final key = o.channel.isEmpty ? '未知渠道' : o.channel;
      if (!map.containsKey(key)) {
        map[key] = {'channel': key, 'gmv': 0, 'profit': 0, 'count': 0};
      }
      final m = map[key]!;
      m['gmv'] = (m['gmv'] as int) + o.amount;
      m['profit'] = (m['profit'] as int) + o.netProfit;
      m['count'] = (m['count'] as int) + 1;
    }
    return map.values.toList()
      ..sort((a, b) => (b['gmv'] as int).compareTo(a['gmv'] as int));
  }

  /// 采购分析：按平台/供应商聚合
  List<Map<String, dynamic>> getPurchaseChannelStats() {
    final pos = getPurchaseOrders();
    final map = <String, Map<String, dynamic>>{};
    for (final po in pos) {
      final key = po.sourcePlatform;
      if (!map.containsKey(key)) {
        map[key] = {
          'platform': key,
          'count': 0,
          'totalCost': 0,
          'returned': 0,
          'afterSale': 0,
        };
      }
      final m = map[key]!;
      m['count'] = (m['count'] as int) + 1;
      m['totalCost'] = (m['totalCost'] as int) + po.totalCost;
      m['returned'] = (m['returned'] as int) + po.returnedCount;
      m['afterSale'] = (m['afterSale'] as int) + (po.afterSaleAmount ?? 0);
    }
    return map.values.toList()..sort(
      (a, b) => (b['totalCost'] as int).compareTo(a['totalCost'] as int),
    );
  }

  /// 月度趋势（近12个月）
  List<Map<String, dynamic>> getMonthlyTrend() {
    final orders = getOrders().where((o) => o.status != 'cancelled').toList();
    final now = DateTime.now();
    final result = <Map<String, dynamic>>[];
    for (int i = 11; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      final ms = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      int gmv = 0, profit = 0, count = 0;
      for (final o in orders) {
        if (o.createdAt.startsWith(ms)) {
          gmv += o.amount;
          profit += o.netProfit;
          count++;
        }
      }
      result.add({'month': ms, 'gmv': gmv, 'profit': profit, 'count': count});
    }
    return result;
  }

  /// 今日运营快照
  Map<String, dynamic> getDailyOpsSnapshot() {
    final s = computeStats();
    final today = _todayStr();
    return {
      'gmv': s.gmv,
      'profit': s.grossProfit,
      'orders': s.orderCount,
      'inStock': s.inStockCount,
      'stagnant': s.stagnantCount,
      'capitalOccupied': s.capitalOccupied,
      'pendingOrders': s.pendingCount,
      'pendingQC': s.pendingQcCount,
      'date': today,
    };
  }
}
