import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../components/index.dart';
import '../utils/utils.dart';
import '../storage.dart';
import '../models.dart';
import '../main.dart';

class FinancePage extends StatefulWidget {
  const FinancePage({Key? key}) : super(key: key);
  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  @override
  Widget build(BuildContext context) {
    final soldDevices =
        gStorage.getDevices().where((d) => d.status == 'sold').toList();
    int totalProfit = 0;
    int totalRevenue = 0;
    int totalCost = 0;
    for (final d in soldDevices) {
      totalProfit += d.netProfit;
      totalRevenue += d.sellPrice;
      totalCost +=
          d.purchaseCost +
          (d.repairCost ?? 0) +
          (d.platformFee ?? 0) +
          (d.logisticsCost ?? 0);
    }
    final profitByModel = gStorage.getProfitByModel();
    final orders = gStorage.getOrders();
    return appScaffold(
      context,
      '财务中心 · 单台利润',
      ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [C.green, C.t3]),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '累计净利',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  yuan(totalProfit),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '累计营收',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                        Text(
                          yuan(totalRevenue),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 18),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '累计成本',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                        Text(
                          yuan(totalCost),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 18),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '已售台数',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                        Text(
                          '${soldDevices.length}台',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (profitByModel.isNotEmpty)
            CardBox(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '按型号利润分析',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: C.t1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...profitByModel.map(
                    (m) => Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m['model'] as String,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: C.t1,
                                  ),
                                ),
                                Text(
                                  '${m["count"]}台 · 营收${yuan(m["revenue"] as int)}',
                                  style: TextStyle(fontSize: 10, color: C.t2),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            yuan(m['profit'] as int),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color:
                                  (m['profit'] as int) >= 0 ? C.green : C.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '单台利润明细',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: C.t1,
                  ),
                ),
                const SizedBox(height: 10),
                if (soldDevices.isEmpty)
                  Text('暂无已售设备', style: TextStyle(fontSize: 12, color: C.t2))
                else
                  ...soldDevices.map(
                    (d) => Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: C.bgDeep,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: C.border),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.tablet_mac_rounded,
                              color: C.t2,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${d.model} ${d.capacity}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: C.t1,
                                    ),
                                  ),
                                  Text(
                                    '售价${yuan(d.sellPrice)} · 成本${yuan(d.purchaseCost + (d.repairCost ?? 0) + (d.platformFee ?? 0) + (d.logisticsCost ?? 0))}',
                                    style: TextStyle(fontSize: 10, color: C.t2),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              yuan(d.netProfit),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: d.netProfit >= 0 ? C.green : C.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '收支流水',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: C.t1,
                  ),
                ),
                const SizedBox(height: 10),
                if (orders.isEmpty)
                  Text('暂无流水', style: TextStyle(fontSize: 12, color: C.t2))
                else
                  ...orders
                      .take(20)
                      .map(
                        (o) => Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${o.deviceName} · ${o.channel}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: C.t1,
                                      ),
                                    ),
                                    Text(
                                      o.createdAt,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: C.t2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '+${yuan(o.profit)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: C.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
