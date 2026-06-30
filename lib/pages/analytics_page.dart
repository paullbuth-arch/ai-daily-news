import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../components/index.dart';
import '../utils/utils.dart';
import '../storage.dart';
import '../main.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({Key? key}) : super(key: key);
  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  @override
  Widget build(BuildContext context) {
    final s = gStorage.computeStats();
    final ageDist = gStorage.getInventoryAgeDist();
    final avgProfit = gStorage.getAvgProfit();
    final avgTurnover = gStorage.getAvgTurnoverDays();
    final turnoverRate = gStorage.getCapitalTurnoverRate();
    final profitByModel = gStorage.getProfitByModel().take(8).toList();
    final turnoverByModel = gStorage.getTurnoverByModel().take(8).toList();
    final suppliers = gStorage.getSupplierStats().take(8).toList();
    // KPI 目标达成
    final profitTarget = 35000; // 350元=35000分
    final turnoverTarget = 15;
    return appScaffold(
      context,
      '经营分析',
      ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // KPI 区
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 9,
            crossAxisSpacing: 9,
            childAspectRatio: 1.6,
            children: [
              _kpi(
                '库存金额',
                yuan(s.capitalOccupied),
                '在售${s.inStockCount}台',
                C.orange,
              ),
              _kpi(
                '平均单台利润',
                yuan(avgProfit),
                avgProfit >= profitTarget ? '✓ 达标(目标350+)' : '目标350+',
                avgProfit >= profitTarget ? C.green : C.t3,
              ),
              _kpi(
                '平均周转天数',
                '$avgTurnover天',
                avgTurnover > 0 && avgTurnover <= turnoverTarget
                    ? '✓ 达标(目标≤15天)'
                    : '目标≤15天',
                avgTurnover > 0 && avgTurnover <= turnoverTarget
                    ? C.green
                    : C.t3,
              ),
              _kpi(
                '资金周转率',
                turnoverRate.toStringAsFixed(2),
                turnoverRate > 2 ? '✓ 达标(目标>2)' : '目标>2',
                turnoverRate > 2 ? C.green : C.t3,
              ),
            ],
          ),
          // 库存年龄分布
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '库存年龄分布',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: C.t1,
                  ),
                ),
                const SizedBox(height: 12),
                ...ageDist.entries.map((e) {
                  final total = ageDist.values.fold<int>(0, (a, b) => a + b);
                  final pct = total > 0 ? e.value * 100 / total : 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
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
                              '${e.value}台 · ${pct.toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 11,
                                color: C.t1,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: total > 0 ? e.value / total : 0,
                            backgroundColor: C.bg,
                            valueColor: AlwaysStoppedAnimation(
                              e.key.contains('30')
                                  ? C.red
                                  : (e.key.contains('16') ? C.orange : C.green),
                            ),
                            minHeight: 7,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          // 利润排行
          if (profitByModel.isNotEmpty)
            CardBox(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '型号利润排行',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: C.t1,
                        ),
                      ),
                      Spacer(),
                      Text(
                        'Top 8',
                        style: TextStyle(fontSize: 10, color: C.t3),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...profitByModel.asMap().entries.map((e) {
                    final m = e.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
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
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                ],
              ),
            ),
          // 周转分析
          if (turnoverByModel.isNotEmpty)
            CardBox(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '⚡ 型号周转分析',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: C.t1,
                        ),
                      ),
                      Spacer(),
                      Text('快→慢', style: TextStyle(fontSize: 10, color: C.t3)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...turnoverByModel.asMap().entries.map((e) {
                    final m = e.value;
                    final days = m['avgDays'] as int;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            alignment: Alignment.center,
                            child: Text(
                              '${e.key + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                color: e.key < 3 ? C.green : C.t3,
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
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${m['count']}台',
                            style: TextStyle(fontSize: 10, color: C.t2),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '$days天',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
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
                ],
              ),
            ),
          // 供应商排行
          if (suppliers.isNotEmpty)
            CardBox(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '供应商利润排行',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: C.t1,
                        ),
                      ),
                      Spacer(),
                      Text(
                        'Top 8',
                        style: TextStyle(fontSize: 10, color: C.t3),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...suppliers.asMap().entries.map((e) {
                    final m = e.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            alignment: Alignment.center,
                            child: Text(
                              '${e.key + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                color: e.key < 3 ? C.purple : C.t3,
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
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Row(
                                  children: [
                                    Text(
                                      '均利${yuan(m['avgProfit'] as int)}',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: C.t3,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if ((m['afterSaleRate'] as num? ?? 0) >
                                        0) ...[
                                      Text(
                                        '售后率${((m['afterSaleRate'] as num) * 100).toStringAsFixed(0)}%',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color:
                                              (m['afterSaleRate'] as num) >= 0.2
                                                  ? C.red
                                                  : C.orange,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
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
                ],
              ),
            ),
          const SizedBox(height: 20),
          Text(
            '数据基于已售设备与订单净利（扣除售后费用，作废订单不计）',
            textAlign: TextAlign.center,
            style: TextStyle(color: C.t3, fontSize: 10, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _kpi(String label, String value, String sub, Color color) => Container(
    padding: EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: C.card,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: C.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: C.t2)),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        SizedBox(height: 3),
        Text(sub, style: TextStyle(fontSize: 9, color: C.t3)),
      ],
    ),
  );
}
