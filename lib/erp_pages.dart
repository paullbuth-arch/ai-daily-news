import 'package:flutter/material.dart';
import 'theme/colors.dart';
import 'main.dart' as app;
import 'storage.dart';

final Storage _s = app.gStorage;

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
      backgroundColor: C.bg,
      appBar: AppBar(
        title: const Text(
          '统计报表',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: C.card,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: C.brand2,
          labelColor: C.brand2,
          unselectedLabelColor: C.t2,
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
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

// ====== 1. 运营报表 ======
class _OpsReport extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = _s.computeStats();
    final monthly = _s.getMonthlyTrend();
    final yesterdayProfit = _s.getYesterdayProfit();
    final yesterdayOrders = _s.getYesterdayOrderCount();
    final yesterdayGmv = _s.getYesterdayGmv();
    final avgProfit = _s.getAvgProfit();
    final turnoverRate = _s.getCapitalTurnoverRate();

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // 今日概览
        _reportSection('📊 今日运营概览', [
          _kpiGrid([
            _kpiItem(
              '今日GMV',
              yuan(s.gmv),
              '昨日${yuan(yesterdayGmv)}',
              s.gmv >= yesterdayGmv ? C.green : C.red,
            ),
            _kpiItem(
              '今日毛利',
              yuan(s.grossProfit),
              '昨日${yuan(yesterdayProfit)}',
              s.grossProfit >= yesterdayProfit ? C.green : C.red,
            ),
            _kpiItem(
              '今日订单',
              '${s.orderCount}',
              '昨日$yesterdayOrders',
              C.brand2,
            ),
            _kpiItem(
              '平均单台利',
              yuan(avgProfit),
              '资金周转${turnoverRate.toStringAsFixed(2)}',
              C.orange,
            ),
          ]),
        ]),
        const SizedBox(height: 12),
        // 月度趋势
        _reportSection('📈 近12月趋势', [
          ...monthly.map(
            (m) => _trendRow(
              m['month'] as String,
              m['gmv'] as int,
              m['profit'] as int,
              m['count'] as int,
            ),
          ),
        ]),
        const SizedBox(height: 12),
        // 关键KPI
        _reportSection('🎯 关键指标', [
          _kpiRow(
            '在售库存',
            '${s.inStockCount} 台',
            '资金占用 ${yuan(s.capitalOccupied)}',
          ),
          _kpiRow(
            '滞销设备',
            '${s.stagnantCount} 台',
            '占比 ${s.inStockCount > 0 ? (s.stagnantCount * 100 / s.inStockCount).toStringAsFixed(0) : 0}%',
          ),
          _kpiRow('待发货', '${s.pendingCount} 单', '在途 ${s.shippedCount} 单'),
          _kpiRow('待质检', '${s.pendingQcCount} 台', '未定价需处理'),
        ]),
        const SizedBox(height: 20),
        const Text(
          '数据说明：GMV为成交总额，毛利已扣除售后费用、佣金、物流等成本',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, color: Color(0xFF888888)),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}

// ====== 2. 库存报表 ======
class _StockReport extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final devices = _s.getDevices();
    final inStock =
        devices
            .where((d) => d.status == 'in_stock' || d.status == 'listed')
            .toList();
    final ageDist = _s.getInventoryAgeDist();
    final turnoverByModel = _s.getTurnoverByModel().take(10).toList();
    final alerts = _s.checkAlerts();
    final modelCount = <String, int>{};
    for (final d in inStock) {
      modelCount[d.model] = (modelCount[d.model] ?? 0) + 1;
    }
    final topModels =
        modelCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final totalCapital = inStock.fold<int>(0, (s, d) => s + d.purchaseCost);

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // KPI
        _reportSection('📦 库存概览', [
          _kpiGrid([
            _kpiItem(
              '在售台数',
              '${inStock.length}',
              '资金${yuan(totalCapital)}',
              C.brand2,
            ),
            _kpiItem(
              '滞销',
              '${(ageDist['16-30天'] ?? 0) + (ageDist['30天+'] ?? 0)} 台',
              '预警${alerts.length}条',
              C.orange,
            ),
            _kpiItem(
              '平均库龄',
              inStock.isEmpty
                  ? '0天'
                  : '${(inStock.fold<int>(0, (s, d) => s + d.stockDays) / inStock.length).round()}天',
              '',
              C.blue,
            ),
            _kpiItem(
              '资金周转率',
              _s.getCapitalTurnoverRate().toStringAsFixed(2),
              '',
              C.green,
            ),
          ]),
        ]),
        const SizedBox(height: 12),
        // 库存年龄
        _reportSection('⏳ 库存年龄分布', [
          ...ageDist.entries.map((e) {
            final total = ageDist.values.fold<int>(0, (a, b) => a + b);
            final pct = total > 0 ? e.value / total : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        e.key,
                        style: TextStyle(fontSize: 12, color: C.t2),
                      ),
                      Text(
                        '${e.value}台',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: C.t1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: C.bg,
                      valueColor: AlwaysStoppedAnimation(
                        e.key.contains('30')
                            ? C.red
                            : (e.key.contains('16')
                                ? C.orange
                                : (e.key.contains('8')
                                    ? C.brand2
                                    : C.green)),
                      ),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );
          }),
        ]),
        const SizedBox(height: 12),
        // 型号排行
        if (topModels.isNotEmpty)
          _reportSection('📱 型号库存排行', [
            ...topModels
                .take(10)
                .toList()
                .asMap()
                .entries
                .map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          alignment: Alignment.center,
                          child: Text(
                            '${e.key + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              color: e.key < 3 ? C.brand2 : C.t3,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            e.value.key,
                            style: TextStyle(
                              fontSize: 12,
                              color: C.t1,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          '${e.value.value}台',
                          style: TextStyle(
                            fontSize: 12,
                            color: C.brand2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          yuan(
                            topModels
                                    .firstWhere((tm) => tm.key == e.value.key)
                                    .value *
                                (devices
                                    .where(
                                      (d) =>
                                          d.model == e.value.key &&
                                          (d.status == 'in_stock' ||
                                              d.status == 'listed'),
                                    )
                                    .fold<int>(
                                      0,
                                      (s, d) => s + d.purchaseCost,
                                    )),
                          ),
                          style: TextStyle(fontSize: 10, color: C.t3),
                        ),
                      ],
                    ),
                  ),
                ),
          ]),
        const SizedBox(height: 12),
        // 周转排行
        if (turnoverByModel.isNotEmpty)
          _reportSection('⚡ 周转排行 (快→慢)', [
            ...turnoverByModel.asMap().entries.map((e) {
              final m = e.value;
              final days = m['avgDays'] as int;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      alignment: Alignment.center,
                      child: Text(
                        '${e.key + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          color: days <= 15 ? C.green : C.t3,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        m['model'] as String,
                        style: TextStyle(fontSize: 12, color: C.t1),
                      ),
                    ),
                    Text(
                      '$days天',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color:
                            days <= 15
                                ? C.green
                                : (days <= 30 ? C.orange : C.red),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ]),
        const SizedBox(height: 40),
      ],
    );
  }
}

// ====== 3. 质检报表 ======
class _QCReport extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final qcStats = _s.getQCStats();
    final defects = _s.getQCDefects();
    final byGrade = qcStats['byGrade'] as Map<String, int>;
    final total = qcStats['total'] as int;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _reportSection('🔍 质检总览', [
          _kpiGrid([
            _kpiItem('总质检', '$total', '通过${qcStats['passed']}', C.brand2),
            _kpiItem(
              '通过率',
              '${((qcStats['passRate'] as double) * 100).toStringAsFixed(0)}%',
              total > 0 ? 'A品${byGrade['A'] ?? 0}台' : '',
              C.green,
            ),
            _kpiItem(
              '需维修',
              '${(byGrade['C'] ?? 0) + (byGrade['D'] ?? 0)}',
              'D品${byGrade['D'] ?? 0}台',
              C.orange,
            ),
            _kpiItem(
              'A品率',
              total > 0
                  ? '${((byGrade['A'] ?? 0) / total * 100).toStringAsFixed(0)}%'
                  : '0%',
              '',
              C.blue,
            ),
          ]),
        ]),
        const SizedBox(height: 12),
        // 品级分布
        if (total > 0)
          _reportSection('📊 品级分布', [
            ...['A', 'B', 'C', 'D'].map((g) {
              final cnt = byGrade[g] ?? 0;
              final pct = cnt / total;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color:
                                g == 'A'
                                    ? C.green
                                    : g == 'B'
                                    ? C.blue
                                    : g == 'C'
                                    ? C.orange
                                    : C.red,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text(
                              g,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$cnt 台',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: C.t1,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${(pct * 100).toStringAsFixed(0)}%',
                          style: TextStyle(fontSize: 12, color: C.t2),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: pct,
                        backgroundColor: C.bg,
                        valueColor: AlwaysStoppedAnimation(
                          g == 'A'
                              ? C.green
                              : g == 'B'
                              ? C.blue
                              : g == 'C'
                              ? C.orange
                              : C.red,
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ]),
        const SizedBox(height: 12),
        // 缺陷分布
        if (defects.isNotEmpty)
          _reportSection('⚠️ 缺陷分布 TOP 6', [
            ...() {
              final sorted =
                  defects.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value));
              return sorted
                  .take(6)
                  .toList()
                  .asMap()
                  .entries
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 22,
                            alignment: Alignment.center,
                            child: Text(
                              '${e.key + 1}',
                              style: TextStyle(fontSize: 11, color: C.t3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              e.value.key,
                              style: TextStyle(fontSize: 12, color: C.t1),
                            ),
                          ),
                          Text(
                            '${e.value.value}次',
                            style: TextStyle(
                              fontSize: 12,
                              color: C.red,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
            }(),
          ]),
        const SizedBox(height: 40),
      ],
    );
  }
}

// ====== 4. 维修报表 ======
class _RepairReport extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final stats = _s.getRepairStats();
    final repairs = _s.getRepairOrders();
    final byType = stats['byType'] as Map<String, dynamic>;
    final byStatus = stats['byStatus'] as Map<String, int>;
    final typeCountMap = byType['count'] as Map<String, int>;
    final typeCostMap = byType['cost'] as Map<String, int>;
    final total = stats['total'] as int;
    final totalCost = stats['totalCost'] as int;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _reportSection('🔧 维修总览', [
          _kpiGrid([
            _kpiItem('维修工单', '$total', '总额${yuan(totalCost)}', C.orange),
            _kpiItem(
              '平均成本',
              yuan(stats['avgCost'] as int),
              total > 0 ? '${(total / repairs.length).round()}台' : '',
              C.brand2,
            ),
            _kpiItem(
              '完成',
              '${byStatus['完成'] ?? 0}',
              '进行中${byStatus['进行中'] ?? 0}',
              C.green,
            ),
            _kpiItem(
              '待修',
              '${byStatus['待修'] ?? 0}',
              '${total > 0 ? '完成率${((byStatus['完成'] ?? 0) / total * 100).toStringAsFixed(0)}%' : ''}',
              C.orange,
            ),
          ]),
        ]),
        const SizedBox(height: 12),
        // 维修类型分布
        if (typeCountMap.isNotEmpty)
          _reportSection('📊 维修类型分布', [
            ...typeCountMap.entries.map((e) {
              final cost = typeCostMap[e.key] ?? 0;
              final pct = total > 0 ? e.value / total : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          e.key,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: C.t1,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${e.value}次',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: C.brand2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          yuan(cost),
                          style: TextStyle(fontSize: 11, color: C.t3),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: pct,
                        backgroundColor: C.bg,
                        valueColor: const AlwaysStoppedAnimation(
                          Color(0xFFFF9500),
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ]),
        const SizedBox(height: 12),
        // 状态分布
        if (byStatus.isNotEmpty)
          _reportSection('📋 维修状态', [
            ...byStatus.entries.map((e) {
              final pct = total > 0 ? e.value / total : 0.0;
              final c =
                  e.key == '完成'
                      ? C.green
                      : e.key == '进行中'
                      ? C.brand2
                      : C.orange;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      e.key,
                      style: TextStyle(fontSize: 12, color: C.t1),
                    ),
                    const Spacer(),
                    Text(
                      '${e.value} (${(pct * 100).toStringAsFixed(0)}%)',
                      style: TextStyle(
                        fontSize: 12,
                        color: c,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ]),
        const SizedBox(height: 40),
      ],
    );
  }
}

// ====== 5. 销售报表 ======
class _SalesReport extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final channelStats = _s.getSalesChannelStats();
    final monthly = _s.getMonthlyTrend();
    final profitByModel = _s.getProfitByModel().take(10).toList();
    final devices = _s.getDevices();
    final sold = devices.where((d) => d.status == 'sold').length;
    final totalRevenue = devices
        .where((d) => d.status == 'sold')
        .fold<int>(0, (s, d) => s + d.sellPrice);
    final totalProfit = devices
        .where((d) => d.status == 'sold')
        .fold<int>(0, (s, d) => s + d.netProfit);
    final grossMargin =
        totalRevenue > 0 ? (totalProfit / totalRevenue * 100) : 0.0;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _reportSection('💰 销售总览', [
          _kpiGrid([
            _kpiItem(
              '累计售出',
              '$sold 台',
              '营收${yuan(totalRevenue)}',
              C.brand2,
            ),
            _kpiItem(
              '累计毛利',
              yuan(totalProfit),
              '毛利率${grossMargin.toStringAsFixed(1)}%',
              C.green,
            ),
            _kpiItem(
              '平均售价',
              sold > 0 ? yuan(totalRevenue ~/ sold) : '¥0',
              '均利${sold > 0 ? yuan(totalProfit ~/ sold) : "¥0"}',
              C.blue,
            ),
            _kpiItem('平均周转', '${_s.getAvgTurnoverDays()}天', '', C.orange),
          ]),
        ]),
        const SizedBox(height: 12),
        // 渠道分析
        if (channelStats.isNotEmpty)
          _reportSection('📊 渠道GMV分析', [
            ...channelStats.map((c) {
              final totalGmv = channelStats.fold<int>(
                0,
                (s, e) => s + (e['gmv'] as int),
              );
              final pct = totalGmv > 0 ? (c['gmv'] as int) / totalGmv : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          c['channel'] as String,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: C.t1,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          yuan(c['gmv'] as int),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: C.brand2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(pct * 100).toStringAsFixed(0)}%',
                          style: TextStyle(fontSize: 11, color: C.t3),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width - 130,
                            child: LinearProgressIndicator(
                              value: pct,
                              backgroundColor: C.bg,
                              valueColor: const AlwaysStoppedAnimation(
                                Color(0xFF34C759),
                              ),
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${c['count']}单',
                          style: TextStyle(fontSize: 10, color: C.t3),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ]),
        const SizedBox(height: 12),
        // 月度趋势
        _reportSection('📈 月度销售趋势', [
          ...monthly.map(
            (m) => _trendRow(
              m['month'] as String,
              m['gmv'] as int,
              m['profit'] as int,
              m['count'] as int,
            ),
          ),
        ]),
        const SizedBox(height: 12),
        // 利润排行
        if (profitByModel.isNotEmpty)
          _reportSection('🏆 型号利润排行', [
            ...profitByModel.asMap().entries.map((e) {
              final m = e.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      alignment: Alignment.center,
                      child: Text(
                        '${e.key + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          color: e.key < 3 ? C.brand2 : C.t3,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        m['model'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          color: C.t1,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '${m['count']}台',
                      style: TextStyle(fontSize: 10, color: C.t2),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      yuan(m['profit'] as int),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color:
                            (m['profit'] as int) >= 0 ? C.green : C.red,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ]),
        const SizedBox(height: 40),
      ],
    );
  }
}

// ====== 6. 采购分析报表 ======
class _PurchaseReport extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final pos = _s.getPurchaseOrders();
    final channelStats = _s.getPurchaseChannelStats();
    final suppliers = _s.getSupplierStats();
    final totalCost = pos.fold<int>(0, (s, p) => s + p.totalCost);
    final totalReturned = pos.fold<int>(0, (s, p) => s + p.returnedCount);
    final totalAfterSale = pos.fold<int>(
      0,
      (s, p) => s + (p.afterSaleAmount ?? 0),
    );

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _reportSection('📥 采购总览', [
          _kpiGrid([
            _kpiItem(
              '采购单',
              '${pos.length}',
              '总额${yuan(totalCost)}',
              C.brand2,
            ),
            _kpiItem(
              '退货',
              '$totalReturned 件',
              pos.isEmpty
                  ? ''
                  : '退货率${pos.fold<int>(0, (s, p) => s + p.deviceCount) > 0 ? (totalReturned / pos.fold<int>(0, (s, p) => s + p.deviceCount) * 100).toStringAsFixed(1) : 0}%',
              C.red,
            ),
            _kpiItem(
              '售后议价',
              yuan(totalAfterSale),
              pos.length > 0 ? '均${yuan(totalAfterSale ~/ (pos.length))}' : '',
              C.orange,
            ),
            _kpiItem(
              '平均单额',
              pos.isEmpty ? '¥0' : yuan(totalCost ~/ pos.length),
              '',
              C.blue,
            ),
          ]),
        ]),
        const SizedBox(height: 12),
        // 采购渠道分析
        if (channelStats.isNotEmpty)
          _reportSection('🛒 采购渠道分析', [
            ...channelStats.map((c) {
              final totalVal = channelStats.fold<int>(
                0,
                (s, e) => s + (e['totalCost'] as int),
              );
              final pct =
                  totalVal > 0 ? (c['totalCost'] as int) / totalVal : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          c['platform'] as String,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: C.t1,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          yuan(c['totalCost'] as int),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: C.brand2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: pct,
                        backgroundColor: C.bg,
                        valueColor: const AlwaysStoppedAnimation(
                          Color(0xFFAF52DE),
                        ),
                        minHeight: 6,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          Text(
                            '${c['count']}单',
                            style: TextStyle(fontSize: 10, color: C.t3),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '退货${c['returned']}件',
                            style: TextStyle(fontSize: 10, color: C.red),
                          ),
                          if ((c['afterSale'] as int) > 0) ...[
                            const SizedBox(width: 12),
                            Text(
                              '议价${yuan(c['afterSale'] as int)}',
                              style: TextStyle(
                                fontSize: 10,
                                color: C.orange,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ]),
        const SizedBox(height: 12),
        // 供应商利润分析
        if (suppliers.isNotEmpty)
          _reportSection('🏭 供应商利润分析', [
            ...suppliers.asMap().entries.map((e) {
              final m = e.value;
              final profitVal = m['profit'] as int;
              final revenue = m['revenue'] as int;
              final margin = revenue > 0 ? profitVal / revenue * 100 : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      alignment: Alignment.center,
                      child: Text(
                        '${e.key + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          color: e.key < 3 ? const Color(0xFFAF52DE) : C.t3,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m['channel'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              color: C.t1,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${m['count']}台 · 利润率${margin.toStringAsFixed(0)}%',
                            style: TextStyle(fontSize: 9, color: C.t3),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      yuan(profitVal),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: profitVal >= 0 ? C.green : C.red,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ]),
        const SizedBox(height: 40),
      ],
    );
  }
}

// ========== 报表通用组件 ==========
Widget _reportSection(String title, List<Widget> children) => Container(
  padding: const EdgeInsets.all(14),
  decoration: BoxDecoration(
    color: C.card,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: C.line),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: C.t1,
        ),
      ),
      const SizedBox(height: 12),
      ...children,
    ],
  ),
);

Widget _kpiGrid(List<Widget> items) => GridView.count(
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  crossAxisCount: 2,
  mainAxisSpacing: 8,
  crossAxisSpacing: 8,
  childAspectRatio: 2.2,
  children: items,
);

Widget _kpiItem(String label, String value, String sub, Color color) =>
    Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 9, color: C.t3)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          if (sub.isNotEmpty) ...[
            const SizedBox(height: 1),
            Text(sub, style: TextStyle(fontSize: 9, color: C.t3)),
          ],
        ],
      ),
    );

Widget _kpiRow(String label, String value, String sub) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Row(
    children: [
      Expanded(
        child: Text(label, style: TextStyle(fontSize: 13, color: C.t1)),
      ),
      Text(
        value,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: C.brand2,
        ),
      ),
      const SizedBox(width: 10),
      Text(sub, style: TextStyle(fontSize: 10, color: C.t3)),
    ],
  ),
);

Widget _trendRow(String month, int gmv, int profit, int count) {
  const maxVal = 500000; // 假设最大50万用于进度条
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 55,
              child: Text(
                month.length > 7 ? month.substring(5) : month,
                style: TextStyle(fontSize: 11, color: C.t2),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: maxVal > 0 ? (gmv / maxVal).clamp(0.0, 1.0) : 0.0,
                  backgroundColor: C.bg,
                  valueColor: AlwaysStoppedAnimation(C.brand2),
                  minHeight: 5,
                ),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 65,
              child: Text(
                yuan(gmv),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: C.t1,
                ),
              ),
            ),
            SizedBox(
              width: 50,
              child: Text(
                yuan(profit),
                style: TextStyle(
                  fontSize: 10,
                  color: profit >= 0 ? C.green : C.red,
                ),
              ),
            ),
            SizedBox(
              width: 25,
              child: Text(
                '$count单',
                style: TextStyle(fontSize: 9, color: C.t3),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
