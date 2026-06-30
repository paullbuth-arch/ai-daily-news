// 文件存储层 —— 零依赖，用dart:io + JSON持久化
import 'dart:io';
import 'dart:convert';
import 'models.dart';

class Storage {
  final String _path;
  Map<String, dynamic> _cache = {};

  Storage(this._path);

  /// 数据文件结构：{ devices: [...], orders: [...], agents: [...], repairOrders: [...], settings: {...} }
  Future<void> load() async {
    try {
      final file = File(_path);
      if (await file.exists()) {
        final raw = await file.readAsString();
        _cache = json.decode(raw) as Map<String, dynamic>;
      } else {
        _cache = {'devices': [], 'orders': [], 'agents': [], 'repairOrders': [],
        'purchaseOrders': [], 'qcReports': [], 'allocations': [],
        'rentals': [], 'installmentPlans': [], 'deposits': [],
        'warehouses': [], 'transfers': [], 'inventoryCounts': [],
        'otherInOuts': [], 'repairParts': [], 'settings': {}};
      }
    } catch (e) {
      _cache = {'devices': [], 'orders': [], 'agents': [], 'repairOrders': [],
        'purchaseOrders': [], 'qcReports': [], 'allocations': [],
        'rentals': [], 'installmentPlans': [], 'deposits': [],
        'warehouses': [], 'transfers': [], 'inventoryCounts': [],
        'otherInOuts': [], 'repairParts': [], 'settings': {}};
    }
  }

  Future<void> _flush() async {
    final file = File(_path);
    await file.writeAsString(json.encode(_cache));
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
    return list.map((e) => RepairOrder.fromJson(e as Map<String, dynamic>)).toList();
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
  Future<void> clearAll() async {
    _cache = {'devices': [], 'orders': [], 'agents': [], 'repairOrders': [],
      'purchaseOrders': [], 'qcReports': [], 'allocations': [],
      'rentals': [], 'installmentPlans': [], 'deposits': [],
      'warehouses': [], 'transfers': [], 'inventoryCounts': [],
      'otherInOuts': [], 'repairParts': [], 'settings': {}};
    await _flush();
  }

  /// 计算今日统计
  Stats computeStats() {
    final devices = getDevices();
    final orders = getOrders();
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

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
      final ds = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
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

  /// 昨日毛利（用于首页趋势箭头对比）
  int getYesterdayProfit() {
    final orders = getOrders();
    final y = DateTime.now().subtract(const Duration(days: 1));
    final ys = '${y.year}-${y.month.toString().padLeft(2, '0')}-${y.day.toString().padLeft(2, '0')}';
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
    final ys = '${y.year}-${y.month.toString().padLeft(2, '0')}-${y.day.toString().padLeft(2, '0')}';
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
    final ys = '${y.year}-${y.month.toString().padLeft(2, '0')}-${y.day.toString().padLeft(2, '0')}';
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
    return map.values.toList()
      ..sort((a, b) => (b['totalAmount'] as int).compareTo(a['totalAmount'] as int));
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
    final devices = getDevices().where((d) => d.status == 'in_stock' || d.status == 'listed').toList();
    return {
      '0-7天': devices.where((d) => d.stockDays <= 7).length,
      '8-15天': devices.where((d) => d.stockDays > 7 && d.stockDays <= 15).length,
      '16-30天': devices.where((d) => d.stockDays > 15 && d.stockDays <= 30).length,
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
    final devices = getDevices().where((d) => d.status == 'sold' && d.sellDate != null).toList();
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
    final devices = getDevices().where((d) => d.status == 'sold' && d.sellDate != null).toList();
    final map = <String, Map<String, dynamic>>{};
    for (final d in devices) {
      int days = 0;
      try {
        days = DateTime.parse(d.sellDate!).difference(DateTime.parse(d.purchaseDate)).inDays;
      } catch (_) {}
      final key = d.model;
      if (!map.containsKey(key)) {
        map[key] = {'model': key, 'count': 0, 'totalDays': 0};
      }
      final m = map[key]!;
      m['count'] = (m['count'] as int) + 1;
      m['totalDays'] = (m['totalDays'] as int) + days;
    }
    final result = map.values.map((m) => {
      'model': m['model'],
      'count': m['count'],
      'avgDays': (m['count'] as int) > 0 ? (m['totalDays'] as int) ~/ (m['count'] as int) : 0,
    }).toList();
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
        map[key] = {'channel': key, 'count': 0, 'profit': 0, 'revenue': 0, 'afterSaleCount': 0};
      }
      final m = map[key]!;
      m['count'] = (m['count'] as int) + 1;
      m['profit'] = (m['profit'] as int) + d.netProfit;
      m['revenue'] = (m['revenue'] as int) + d.sellPrice;
      // 售后判定：该设备关联的订单有 afterSaleCost 或状态为 aftersale
      final hasAfterSale = orders.any((o) => o.deviceId == d.id && (o.afterSaleCost != null && o.afterSaleCost! > 0 || o.status == 'aftersale'));
      if (hasAfterSale) m['afterSaleCount'] = (m['afterSaleCount'] as int) + 1;
    }
    final result = map.values.map((m) => {
      'channel': m['channel'],
      'count': m['count'],
      'profit': m['profit'],
      'revenue': m['revenue'],
      'avgProfit': (m['count'] as int) > 0 ? (m['profit'] as int) ~/ (m['count'] as int) : 0,
      'afterSaleRate': (m['count'] as int) > 0 ? (m['afterSaleCount'] as int) / (m['count'] as int) : 0.0,
    }).toList();
    result.sort((a, b) => (b['profit'] as int).compareTo(a['profit'] as int));
    return result;
  }

  /// 资金周转率 = 本月销售额 ÷ 平均库存资金占用
  double getCapitalTurnoverRate() {
    final now = DateTime.now();
    final ms = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final orders = getOrders().where((o) => o.status != 'cancelled' && o.createdAt.startsWith(ms)).toList();
    final monthSales = orders.fold<int>(0, (a, o) => a + o.amount);
    final inStockDevices = getDevices().where((d) => d.status == 'in_stock' || d.status == 'listed').toList();
    if (inStockDevices.isEmpty) return 0;
    final avgCapital = inStockDevices.fold<int>(0, (a, d) => a + d.purchaseCost) / inStockDevices.length;
    if (avgCapital == 0) return 0;
    return (monthSales / 100) / (avgCapital / 100);
  }

  /// 按型号综合分析（采购决策用）。返回结构化指标 Map。
  Map<String, dynamic> getModelAnalysis(String model) {
    final all = getDevices().where((d) => d.model == model).toList();
    final sold = all.where((d) => d.status == 'sold').toList();
    final inStock = all.where((d) => d.status == 'in_stock' || d.status == 'listed').toList();
    final stagnant = inStock.where((d) => d.isStagnant).length;

    int salesCount = sold.length;
    int avgProfit = sold.isEmpty ? 0 : sold.fold<int>(0, (a, d) => a + d.netProfit) ~/ sold.length;
    int avgSell = sold.isEmpty ? 0 : sold.fold<int>(0, (a, d) => a + d.sellPrice) ~/ sold.length;
    int avgCost = sold.isEmpty ? 0 : sold.fold<int>(0, (a, d) => a + d.purchaseCost) ~/ sold.length;

    int totalDays = 0, n = 0;
    for (final d in sold) {
      try {
        totalDays += DateTime.parse(d.sellDate!).difference(DateTime.parse(d.purchaseDate)).inDays;
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
    final suppliers = supMap.values.toList()
      ..sort((a, b) => (b['profit'] as int).compareTo(a['profit'] as int));

    return {
      'model': model,
      'salesCount': salesCount,
      'inStockCount': inStock.length,
      'stagnantCount': stagnant,
      'stagnantRate': stagnantRate,
      'avgProfit': avgProfit,        // 分
      'avgSellPrice': avgSell,       // 分
      'avgPurchaseCost': avgCost,    // 分
      'avgTurnoverDays': avgTurnover,
      'suppliers': suppliers,        // [{channel,count,profit}]
      'hasHistory': salesCount > 0,
    };
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
  List<Map<String, dynamic>> getMarketPriceHistory(String model, {int days = 30}) {
    final prices = _getMarketPricesMap()[model] as List?;
    if (prices == null) return [];
    final list = prices.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    if (list.length > days) return list.sublist(list.length - days);
    return list;
  }

  /// 保存某��号今日行情（同日覆盖）
  Future<void> saveMarketPrice(String model, int priceFen) async {
    final settings = getSettings();
    final mp = _getMarketPricesMap();
    final today = _todayStr();
    final list = (mp[model] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
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
  Map<String, dynamic> toFullMap() => Map<String, dynamic>.from(_cache);

  /// 用云端数据覆盖本地（用于云端同步下载）
  void setFullData(Map<String, dynamic> data) {
    _cache = Map<String, dynamic>.from(data);
  }

  /// 直接刷写到文件
  Future<void> save() async => await _flush();

  // ====== 采购单 ======
  List<PurchaseOrder> getPurchaseOrders() {
    final list = _cache['purchaseOrders'] as List? ?? [];
    return list.map((e) => PurchaseOrder.fromJson(e as Map<String, dynamic>)).toList();
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

  // ====== 质检报告 ======
  List<QCReport> getQCReports() {
    final list = _cache['qcReports'] as List? ?? [];
    return list.map((e) => QCReport.fromJson(e as Map<String, dynamic>)).toList();
  }

  QCReport? getQCReportByDevice(String deviceId) {
    final reports = getQCReports();
    final matched = reports.where((r) => r.deviceId == deviceId).toList();
    return matched.isEmpty ? null : matched.first;
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

  // ====== 分货记录 ======
  List<AllocationRecord> getAllocations() {
    final list = _cache['allocations'] as List? ?? [];
    return list.map((e) => AllocationRecord.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AllocationRecord> addAllocation(AllocationRecord a) async {
    final list = getAllocations();
    list.insert(0, a);
    _cache['allocations'] = list.map((e) => e.toJson()).toList();
    await _flush();
    return a;
  }

  Future<void> updateAllocation(AllocationRecord a) async {
    final list = getAllocations();
    final idx = list.indexWhere((e) => e.id == a.id);
    if (idx >= 0) {
      list[idx] = a;
      _cache['allocations'] = list.map((e) => e.toJson()).toList();
      await _flush();
    }
  }

  AllocationRecord? getActiveAllocation(String deviceId) {
    final list = getAllocations().where((a) => a.deviceId == deviceId && a.status == 'assigned').toList();
    return list.isEmpty ? null : list.first;
  }

  // ====== 租借记录 ======
  List<RentalRecord> getRentals() {
    final list = _cache['rentals'] as List? ?? [];
    return list.map((e) => RentalRecord.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<RentalRecord> addRental(RentalRecord r) async {
    final list = getRentals();
    list.insert(0, r);
    _cache['rentals'] = list.map((e) => e.toJson()).toList();
    await _flush();
    return r;
  }

  Future<void> updateRental(RentalRecord r) async {
    final list = getRentals();
    final idx = list.indexWhere((e) => e.id == r.id);
    if (idx >= 0) {
      list[idx] = r;
      _cache['rentals'] = list.map((e) => e.toJson()).toList();
      await _flush();
    }
  }

  Future<void> deleteRental(String id) async {
    final list = getRentals().where((e) => e.id != id).toList();
    _cache['rentals'] = list.map((e) => e.toJson()).toList();
    await _flush();
  }

  // ====== 分期付款 ======
  List<InstallmentPlan> getInstallmentPlans() {
    final list = _cache['installmentPlans'] as List? ?? [];
    return list.map((e) => InstallmentPlan.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<InstallmentPlan> addInstallmentPlan(InstallmentPlan p) async {
    final list = getInstallmentPlans();
    list.insert(0, p);
    _cache['installmentPlans'] = list.map((e) => e.toJson()).toList();
    await _flush();
    return p;
  }

  Future<void> updateInstallmentPlan(InstallmentPlan p) async {
    final list = getInstallmentPlans();
    final idx = list.indexWhere((e) => e.id == p.id);
    if (idx >= 0) {
      list[idx] = p;
      _cache['installmentPlans'] = list.map((e) => e.toJson()).toList();
      await _flush();
    }
  }

  // ====== 预付定金 ======
  List<DepositRecord> getDeposits() {
    final list = _cache['deposits'] as List? ?? [];
    return list.map((e) => DepositRecord.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<DepositRecord> addDeposit(DepositRecord d) async {
    final list = getDeposits();
    list.insert(0, d);
    _cache['deposits'] = list.map((e) => e.toJson()).toList();
    await _flush();
    return d;
  }

  Future<void> updateDeposit(DepositRecord d) async {
    final list = getDeposits();
    final idx = list.indexWhere((e) => e.id == d.id);
    if (idx >= 0) {
      list[idx] = d;
      _cache['deposits'] = list.map((e) => e.toJson()).toList();
      await _flush();
    }
  }

  // ====== 库存预警配置 ======
  InventoryAlertConfig getAlertConfig() {
    final s = getSettings();
    return InventoryAlertConfig.fromJson(s['alertConfig'] as Map<String, dynamic>? ?? {});
  }

  Future<void> saveAlertConfig(InventoryAlertConfig cfg) async {
    final s = getSettings();
    s['alertConfig'] = cfg.toJson();
    await saveSettings(s);
  }

  /// 检查并返回所有库存预警消息
  List<Map<String, dynamic>> checkAlerts() {
    final config = getAlertConfig();
    final msgs = <Map<String, dynamic>>[];
    if (!config.enableLowStockAlert && !config.enableStagnantAlert) return msgs;

    final devices = getDevices();
    final inStock = devices.where((d) => d.status == 'in_stock' || d.status == 'listed').toList();

    // 低库存预警：按型号聚合
    if (config.enableLowStockAlert) {
      final modelCount = <String, int>{};
      for (final d in inStock) {
        modelCount[d.model] = (modelCount[d.model] ?? 0) + 1;
      }
      for (final entry in modelCount.entries) {
        final threshold = config.modelThresholds[entry.key] ?? config.lowStockThreshold;
        if (entry.value <= threshold) {
          msgs.add({'type': 'low_stock', 'model': entry.key, 'count': entry.value, 'threshold': threshold});
        }
      }
    }

    // 滞销预警
    if (config.enableStagnantAlert) {
      final staleInStock = devices.where((d) => (d.status == 'in_stock' || d.status == 'listed') && d.stockDays >= config.stagnantDaysThreshold).toList();
      if (staleInStock.isNotEmpty) {
        final modelStale = <String, int>{};
        for (final d in staleInStock) {
          modelStale[d.model] = (modelStale[d.model] ?? 0) + 1;
        }
        for (final entry in modelStale.entries) {
          msgs.add({'type': 'stagnant', 'model': entry.key, 'count': entry.value, 'days': config.stagnantDaysThreshold});
        }
      }
    }

    return msgs;
  }

  /// 追踪设备：按 IMEI/序列号/平台编号/内部ID 搜索
  List<Device> searchDevices(String keyword) {
    if (keyword.trim().isEmpty) return [];
    final kw = keyword.trim().toLowerCase();
    return getDevices().where((d) =>
      d.serial.toLowerCase().contains(kw) ||
      d.model.toLowerCase().contains(kw) ||
      d.id.contains(kw)
    ).toList();
  }

  // ====== 报表统计方法 ======

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

  /// 维修统计：按类型 + 按状态
  Map<String, dynamic> getRepairStats() {
    final repairs = getRepairOrders();
    final byType = <String, dynamic>{'count': <String, int>{}, 'cost': <String, int>{}};
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
    return map.values.toList()..sort((a, b) => (b['gmv'] as int).compareTo(a['gmv'] as int));
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

  /// 采购分析：按平台/供应商聚合
  List<Map<String, dynamic>> getPurchaseChannelStats() {
    final pos = getPurchaseOrders();
    final map = <String, Map<String, dynamic>>{};
    for (final po in pos) {
      final key = po.sourcePlatform;
      if (!map.containsKey(key)) {
        map[key] = {'platform': key, 'count': 0, 'totalCost': 0, 'returned': 0, 'afterSale': 0};
      }
      final m = map[key]!;
      m['count'] = (m['count'] as int) + 1;
      m['totalCost'] = (m['totalCost'] as int) + po.totalCost;
      m['returned'] = (m['returned'] as int) + po.returnedCount;
      m['afterSale'] = (m['afterSale'] as int) + (po.afterSaleAmount ?? 0);
    }
    return map.values.toList()..sort((a, b) => (b['totalCost'] as int).compareTo(a['totalCost'] as int));
  }

  /// 今日运营数据快照
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

  // ====== 仓库管理 ======
  List<Warehouse> getWarehouses() {
    final list = _cache['warehouses'] as List? ?? [];
    return list.map((e) => Warehouse.fromJson(e as Map<String, dynamic>)).toList();
  }

  Warehouse? getWarehouse(String id) {
    try { return getWarehouses().firstWhere((w) => w.id == id); } catch (_) { return null; }
  }

  Future<Warehouse> addWarehouse(Warehouse w) async {
    final list = getWarehouses(); list.add(w);
    _cache['warehouses'] = list.map((e) => e.toJson()).toList();
    await _flush(); return w;
  }

  Future<void> updateWarehouse(Warehouse w) async {
    final list = getWarehouses();
    final idx = list.indexWhere((e) => e.id == w.id);
    if (idx >= 0) { list[idx] = w;
      _cache['warehouses'] = list.map((e) => e.toJson()).toList(); await _flush(); }
  }

  Future<void> deleteWarehouse(String id) async {
    _cache['warehouses'] = getWarehouses().where((w) => w.id != id).map((e) => e.toJson()).toList();
    await _flush();
  }

  /// 获取默认仓库（第一个），如无则创建
  Future<Warehouse> getDefaultWarehouse() async {
    final list = getWarehouses();
    if (list.isNotEmpty) return list.first;
    final w = Warehouse(id: _uid(), name: '默认仓库', createdAt: DateTime.now().toIso8601String());
    await addWarehouse(w); return w;
  }

  // ====== 库存调拨 ======
  List<WarehouseTransfer> getTransfers() {
    final list = _cache['transfers'] as List? ?? [];
    return list.map((e) => WarehouseTransfer.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<WarehouseTransfer> addTransfer(WarehouseTransfer t) async {
    final list = getTransfers(); list.insert(0, t);
    _cache['transfers'] = list.map((e) => e.toJson()).toList();
    await _flush(); return t;
  }

  Future<void> updateTransfer(WarehouseTransfer t) async {
    final list = getTransfers();
    final idx = list.indexWhere((e) => e.id == t.id);
    if (idx >= 0) { list[idx] = t;
      _cache['transfers'] = list.map((e) => e.toJson()).toList(); await _flush(); }
  }

  // ====== 盘点 ======
  List<InventoryCount> getInventoryCounts() {
    final list = _cache['inventoryCounts'] as List? ?? [];
    return list.map((e) => InventoryCount.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<InventoryCount> addInventoryCount(InventoryCount c) async {
    final list = getInventoryCounts(); list.insert(0, c);
    _cache['inventoryCounts'] = list.map((e) => e.toJson()).toList();
    await _flush(); return c;
  }

  Future<void> updateInventoryCount(InventoryCount c) async {
    final list = getInventoryCounts();
    final idx = list.indexWhere((e) => e.id == c.id);
    if (idx >= 0) { list[idx] = c;
      _cache['inventoryCounts'] = list.map((e) => e.toJson()).toList(); await _flush(); }
  }

  // ====== 其他出入库 ======
  List<OtherInOut> getOtherInOuts() {
    final list = _cache['otherInOuts'] as List? ?? [];
    return list.map((e) => OtherInOut.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<OtherInOut> addOtherInOut(OtherInOut o) async {
    final list = getOtherInOuts(); list.insert(0, o);
    _cache['otherInOuts'] = list.map((e) => e.toJson()).toList();
    await _flush(); return o;
  }

  // ====== 维修配件 ======
  List<RepairPart> getRepairParts() {
    final list = _cache['repairParts'] as List? ?? [];
    return list.map((e) => RepairPart.fromJson(e as Map<String, dynamic>)).toList();
  }

  List<RepairPart> getRepairPartsByOrder(String repairOrderId) {
    return getRepairParts().where((p) => p.repairOrderId == repairOrderId).toList();
  }

  Future<RepairPart> addRepairPart(RepairPart p) async {
    final list = getRepairParts(); list.add(p);
    _cache['repairParts'] = list.map((e) => e.toJson()).toList();
    await _flush(); return p;
  }

  Future<void> deleteRepairPart(String id) async {
    _cache['repairParts'] = getRepairParts().where((p) => p.id != id).map((e) => e.toJson()).toList();
    await _flush();
  }
}

String _uid() => DateTime.now().millisecondsSinceEpoch.toString();
