import 'package:flutter/material.dart';
import 'main.dart' as app;
import 'models.dart';

String yuan(int fen) => '¥${(fen / 100).toStringAsFixed(0)}';

class ReportPage extends StatefulWidget {
  const ReportPage({Key? key}) : super(key: key);

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  static const _tabs = ['运营', '库存', '质检', '维修', '销售', '采购'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: app.C.bg,
      appBar: AppBar(
        title: const Text(
          '统计报表',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: app.C.card,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          labelColor: app.C.brand,
          unselectedLabelColor: app.C.t2,
          indicatorColor: app.C.brand,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: const [
          _OpsReport(),
          _StockReport(),
          _QCReport(),
          _RepairReport(),
          _SalesReport(),
          _PurchaseReport(),
        ],
      ),
    );
  }
}

class _OpsReport extends StatelessWidget {
  const _OpsReport();

  @override
  Widget build(BuildContext context) {
    final storage = app.gStorage;
    final s = storage.computeStats();
    final monthly = storage.getMonthlyTrend();
    final avgProfit = storage.getAvgProfit();
    final turnoverRate = storage.getCapitalTurnoverRate();
    final yesterdayProfit = storage.getYesterdayProfit();
    final yesterdayOrders = storage.getYesterdayOrderCount();
    final yesterdayGmv = storage.getYesterdayGmv();

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _section('今日概览', [
          _kpiGrid([
            _kpiItem(
              'GMV',
              yuan(s.gmv),
              '昨日${yuan(yesterdayGmv)}',
              app.C.brand2,
            ),
            _kpiItem(
              '毛利',
              yuan(s.grossProfit),
              '昨日${yuan(yesterdayProfit)}',
              s.grossProfit >= yesterdayProfit ? app.C.green : app.C.red,
            ),
            _kpiItem('订单', '${s.orderCount}', '昨日$yesterdayOrders', app.C.blue),
            _kpiItem(
              '均利',
              yuan(avgProfit),
              '周转率${turnoverRate.toStringAsFixed(2)}',
              app.C.orange,
            ),
          ]),
        ]),
        _section('库存与资金', [
          _row(
            '在售库存',
            '${s.inStockCount} 台',
            '资金占用 ${yuan(s.capitalOccupied)}',
          ),
          _row(
            '滞销设备',
            '${s.stagnantCount} 台',
            '占比 ${s.inStockCount > 0 ? (s.stagnantCount * 100 / s.inStockCount).toStringAsFixed(0) : 0}%',
          ),
          _row('待发货', '${s.pendingCount} 单', '在途 ${s.shippedCount} 单'),
          _row('待处理', '${s.pendingQcCount} 台', '未定价设备'),
        ]),
        if (monthly.isNotEmpty)
          _section('近 12 月趋势', [
            ...monthly
                .take(12)
                .map(
                  (m) => _row(
                    m['month'] as String,
                    yuan(m['gmv'] as int),
                    '毛利 ${yuan(m['profit'] as int)} · ${m['count']} 单',
                  ),
                ),
          ]),
      ],
    );
  }
}

class _StockReport extends StatelessWidget {
  const _StockReport();

  @override
  Widget build(BuildContext context) {
    final devices = app.gStorage.getDevices();
    final inStock =
        devices
            .where((d) => d.status == 'in_stock' || d.status == 'listed')
            .toList();
    final sold = devices.where((d) => d.status == 'sold').toList();
    final totalCapital = inStock.fold<int>(0, (s, d) => s + d.purchaseCost);
    final stagnant = inStock.where((d) => d.isStagnant).toList();

    final byModel = <String, int>{};
    for (final d in inStock) {
      byModel[d.model] = (byModel[d.model] ?? 0) + 1;
    }
    final modelRows =
        byModel.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _section('库存总览', [
          _kpiGrid([
            _kpiItem(
              '在售',
              '${inStock.length}',
              '资金${yuan(totalCapital)}',
              app.C.brand2,
            ),
            _kpiItem('已售', '${sold.length}', '历史累计', app.C.green),
            _kpiItem(
              '滞销',
              '${stagnant.length}',
              '超 15 天',
              stagnant.isEmpty ? app.C.green : app.C.red,
            ),
            _kpiItem(
              '平均库龄',
              inStock.isEmpty
                  ? '0天'
                  : '${(inStock.fold<int>(0, (s, d) => s + d.stockDays) / inStock.length).round()}天',
              '',
              app.C.orange,
            ),
          ]),
        ]),
        if (modelRows.isNotEmpty)
          _section('型号分布', [
            ...modelRows
                .take(12)
                .map(
                  (e) => _row(
                    e.key,
                    '${e.value} 台',
                    '${(e.value * 100 / inStock.length).toStringAsFixed(0)}%',
                  ),
                ),
          ]),
      ],
    );
  }
}

class _QCReport extends StatelessWidget {
  const _QCReport();

  @override
  Widget build(BuildContext context) {
    final devices = app.gStorage.getDevices();
    final inStock = devices.where(_isStockDevice).toList();
    final pending = inStock.where((d) => d.sellPrice <= 0).toList();
    final idRisk = devices.where((d) => !d.idLockClean).length;
    final lowBattery = devices.where((d) => d.batteryHealth < 80).length;

    final gradeMap = <String, int>{'A': 0, 'B': 0, 'C': 0, 'D': 0};
    for (final d in devices) {
      final grade = _gradeForDevice(d);
      gradeMap[grade] = (gradeMap[grade] ?? 0) + 1;
    }
    final aRate =
        devices.isEmpty ? 0 : ((gradeMap['A'] ?? 0) * 100 / devices.length);

    final defectRows =
        <MapEntry<String, int>>[
          MapEntry('ID锁风险', idRisk),
          MapEntry('电池低于 80%', lowBattery),
          MapEntry('未定价库存', pending.length),
          MapEntry(
            '有维修成本',
            devices.where((d) => (d.repairCost ?? 0) > 0).length,
          ),
          MapEntry('循环次数偏高', devices.where((d) => d.cycleCount >= 800).length),
        ].where((e) => e.value > 0).toList();

    final recent =
        devices.toList()..sort(
          (a, b) => _safeDate(b.createdAt).compareTo(_safeDate(a.createdAt)),
        );

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _section('质检总览', [
          _kpiGrid([
            _kpiItem('设备数', '${devices.length}', '按现有库存资料判定', app.C.brand2),
            _kpiItem(
              '待判定',
              '${pending.length}',
              '在库且未定价',
              pending.isEmpty ? app.C.green : app.C.orange,
            ),
            _kpiItem(
              'A 品率',
              '${aRate.toStringAsFixed(0)}%',
              'A品 ${gradeMap['A'] ?? 0} 台',
              app.C.green,
            ),
            _kpiItem(
              '风险项',
              '${idRisk + lowBattery}',
              'ID锁/低电池',
              idRisk + lowBattery == 0 ? app.C.green : app.C.red,
            ),
          ]),
        ]),
        _section('品级判定', [
          ...gradeMap.entries.map((e) {
            final pct =
                devices.isEmpty
                    ? '0'
                    : (e.value * 100 / devices.length).toStringAsFixed(0);
            return _row(
              '${e.key} 品',
              '${e.value} 台',
              '$pct% · ${_gradeHint(e.key)}',
            );
          }),
        ]),
        if (defectRows.isNotEmpty)
          _section('异常分布', [
            ...defectRows.map((e) {
              final pct =
                  devices.isEmpty
                      ? '0'
                      : (e.value * 100 / devices.length).toStringAsFixed(0);
              return _row(e.key, '${e.value} 台', '$pct%');
            }),
          ]),
        if (recent.isNotEmpty)
          _section('最近入库判定', [
            ...recent.take(10).map((d) {
              final grade = _gradeForDevice(d);
              final tags = [
                d.condition,
                '电池${d.batteryHealth}%',
                d.idLockClean ? 'ID干净' : 'ID风险',
              ];
              return _row('${d.model} ${d.capacity}', grade, tags.join(' · '));
            }),
          ]),
      ],
    );
  }
}

class _RepairReport extends StatelessWidget {
  const _RepairReport();

  @override
  Widget build(BuildContext context) {
    final stats = app.gStorage.getRepairStats();
    final byType = stats['byType'] as Map<String, dynamic>;
    final countByType = byType['count'] as Map<String, int>;
    final costByType = byType['cost'] as Map<String, int>;
    final byStatus = stats['byStatus'] as Map<String, int>;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _section('维修总览', [
          _kpiGrid([
            _kpiItem('维修单', '${stats['total']}', '累计', app.C.brand2),
            _kpiItem('总成本', yuan(stats['totalCost'] as int), '维修支出', app.C.red),
            _kpiItem(
              '均成本',
              yuan(stats['avgCost'] as int),
              '单台平均',
              app.C.orange,
            ),
          ]),
        ]),
        if (countByType.isNotEmpty)
          _section('维修类型', [
            ...countByType.entries.map(
              (e) => _row(
                e.key,
                '${e.value} 单',
                '成本 ${yuan(costByType[e.key] ?? 0)}',
              ),
            ),
          ]),
        if (byStatus.isNotEmpty)
          _section('状态分布', [
            ...byStatus.entries.map((e) => _row(e.key, '${e.value} 单', '')),
          ]),
      ],
    );
  }
}

class _SalesReport extends StatelessWidget {
  const _SalesReport();

  @override
  Widget build(BuildContext context) {
    final orders =
        app.gStorage.getOrders().where((o) => o.status != 'cancelled').toList();
    final channelStats = app.gStorage.getSalesChannelStats();
    final totalGmv = orders.fold<int>(0, (s, o) => s + o.amount);
    final totalProfit = orders.fold<int>(0, (s, o) => s + o.netProfit);
    final grossMargin = totalGmv > 0 ? totalProfit / totalGmv * 100 : 0.0;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _section('销售总览', [
          _kpiGrid([
            _kpiItem('订单数', '${orders.length}', '有效订单', app.C.brand2),
            _kpiItem('累计 GMV', yuan(totalGmv), '', app.C.blue),
            _kpiItem(
              '累计毛利',
              yuan(totalProfit),
              '毛利率${grossMargin.toStringAsFixed(1)}%',
              app.C.green,
            ),
          ]),
        ]),
        if (channelStats.isNotEmpty)
          _section('渠道 GMV', [
            ...channelStats.map((c) {
              final gmv = c['gmv'] as int;
              final pct =
                  totalGmv > 0
                      ? (gmv * 100 / totalGmv).toStringAsFixed(0)
                      : '0';
              return _row(
                c['channel'] as String,
                yuan(gmv),
                '$pct% · ${c['count']} 单 · 毛利 ${yuan(c['profit'] as int)}',
              );
            }),
          ]),
      ],
    );
  }
}

class _PurchaseReport extends StatelessWidget {
  const _PurchaseReport();

  @override
  Widget build(BuildContext context) {
    final devices = app.gStorage.getDevices();
    final totalCost = devices.fold<int>(0, (s, d) => s + d.purchaseCost);
    final avgCost = devices.isEmpty ? 0 : totalCost ~/ devices.length;
    final now = DateTime.now();
    final monthPrefix = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final monthDevices =
        devices
            .where(
              (d) =>
                  d.purchaseDate.startsWith(monthPrefix) ||
                  d.createdAt.startsWith(monthPrefix),
            )
            .toList();
    final inStockCapital = devices
        .where(_isStockDevice)
        .fold<int>(0, (s, d) => s + d.purchaseCost);

    final channelMap = <String, Map<String, int>>{};
    for (final d in devices) {
      final channel =
          d.purchaseChannel.trim().isEmpty ? '未知渠道' : d.purchaseChannel.trim();
      channelMap.putIfAbsent(
        channel,
        () => {'count': 0, 'cost': 0, 'sold': 0, 'profit': 0},
      );
      final row = channelMap[channel]!;
      row['count'] = row['count']! + 1;
      row['cost'] = row['cost']! + d.purchaseCost;
      if (d.status == 'sold') {
        row['sold'] = row['sold']! + 1;
        row['profit'] = row['profit']! + d.netProfit;
      }
    }
    final channelRows =
        channelMap.entries.toList()
          ..sort((a, b) => b.value['cost']!.compareTo(a.value['cost']!));

    final recent =
        devices.toList()..sort((a, b) {
          final byPurchase = _safeDate(
            b.purchaseDate,
          ).compareTo(_safeDate(a.purchaseDate));
          if (byPurchase != 0) return byPurchase;
          return _safeDate(b.createdAt).compareTo(_safeDate(a.createdAt));
        });

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _section('采购总览', [
          _kpiGrid([
            _kpiItem('采购台数', '${devices.length}', '历史入库', app.C.brand2),
            _kpiItem('采购成本', yuan(totalCost), '累计投入', app.C.orange),
            _kpiItem('均采购价', yuan(avgCost), '单台平均', app.C.blue),
            _kpiItem(
              '本月入库',
              '${monthDevices.length}',
              '在库资金 ${yuan(inStockCapital)}',
              app.C.green,
            ),
          ]),
        ]),
        if (channelRows.isNotEmpty)
          _section('渠道结构', [
            ...channelRows.take(12).map((e) {
              final data = e.value;
              final count = data['count']!;
              final avg = count > 0 ? data['cost']! ~/ count : 0;
              final soldRate =
                  count > 0
                      ? (data['sold']! * 100 / count).toStringAsFixed(0)
                      : '0';
              return _row(
                e.key,
                '${count} 台',
                '成本${yuan(data['cost']!)} · 均价${yuan(avg)} · 售出$soldRate%',
              );
            }),
          ]),
        if (channelRows.any((e) => e.value['sold']! > 0))
          _section('渠道收益', [
            ...channelRows.where((e) => e.value['sold']! > 0).take(12).map((e) {
              final data = e.value;
              final avgProfit =
                  data['sold']! > 0 ? data['profit']! ~/ data['sold']! : 0;
              return _row(
                e.key,
                yuan(data['profit']!),
                '${data['sold']} 台已售 · 均利 ${yuan(avgProfit)}',
              );
            }),
          ]),
        if (recent.isNotEmpty)
          _section('最近采购', [
            ...recent.take(10).map((d) {
              final channel =
                  d.purchaseChannel.trim().isEmpty
                      ? '未知渠道'
                      : d.purchaseChannel.trim();
              return _row(
                '${d.model} ${d.capacity}',
                yuan(d.purchaseCost),
                '$channel · ${_dateText(d.purchaseDate)}',
              );
            }),
          ]),
      ],
    );
  }
}

bool _isStockDevice(Device d) => d.status == 'in_stock' || d.status == 'listed';

String _gradeForDevice(Device d) {
  if (!d.idLockClean) return 'D';
  final condition = d.condition.trim();
  final topCondition =
      condition.contains('全新') ||
      condition.contains('99') ||
      condition.contains('98') ||
      condition.contains('95');
  if (d.batteryHealth >= 90 && topCondition) return 'A';
  if (d.batteryHealth >= 80) return 'B';
  return 'C';
}

String _gradeHint(String grade) {
  switch (grade) {
    case 'A':
      return '高成色/高电池/ID干净';
    case 'B':
      return '可正常销售';
    case 'C':
      return '低电池或成色偏弱';
    case 'D':
      return 'ID锁风险';
  }
  return '';
}

DateTime _safeDate(String value) {
  try {
    return DateTime.parse(value);
  } catch (_) {
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

String _dateText(String value) {
  if (value.length >= 10) return value.substring(0, 10);
  return '日期未知';
}

Widget _section(String title, List<Widget> children) => Container(
  margin: const EdgeInsets.only(bottom: 12),
  padding: const EdgeInsets.all(14),
  decoration: BoxDecoration(
    color: app.C.card,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: app.C.line),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: app.C.t1,
        ),
      ),
      const SizedBox(height: 10),
      ...children,
    ],
  ),
);

Widget _kpiGrid(List<Widget> items) => LayoutBuilder(
  builder: (context, box) {
    final cols = box.maxWidth >= 700 ? 4 : 2;
    return GridView.count(
      crossAxisCount: cols,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: cols == 4 ? 2.3 : 2.0,
      children: items,
    );
  },
);

Widget _kpiItem(String label, String value, String sub, Color color) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: app.C.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: app.C.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10.5, color: app.C.t2),
          ),
          const SizedBox(height: 3),
          FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
          if (sub.isNotEmpty)
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 9.5, color: app.C.t3),
            ),
        ],
      ),
    );

Widget _row(String label, String value, String sub) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Row(
    children: [
      Expanded(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            color: app.C.t1,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      const SizedBox(width: 10),
      Text(
        value,
        style: TextStyle(
          fontSize: 12.5,
          color: app.C.t1,
          fontWeight: FontWeight.w800,
        ),
      ),
      if (sub.isNotEmpty) ...[
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 10.5, color: app.C.t3),
          ),
        ),
      ],
    ],
  ),
);
