import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../components/index.dart';
import '../utils/utils.dart';
import '../storage.dart';
import '../models.dart';
import '../main.dart';
import '../ai_service.dart';
import 'restock_suggestion_page.dart';

class PurchaseDecisionPage extends StatefulWidget {
  const PurchaseDecisionPage({Key? key}) : super(key: key);
  @override
  State<PurchaseDecisionPage> createState() => _PurchaseDecisionPageState();
}

class _PurchaseDecisionPageState extends State<PurchaseDecisionPage> {
  String? _selectedModel;
  final _costCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  Map<String, dynamic>? _analysis;
  Map<String, dynamic>? _marketPrice;
  List<Map<String, dynamic>>? _marketHistory;
  String? _aiResult;
  bool _loading = false;
  Map<String, dynamic>? _refPrices; // 参考价

  @override
  void dispose() {
    _costCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  List<String> get _modelOptions {
    final dbModels = gStorage.getDevices().map((d) => d.model).toSet().toList();
    final preset = iPadModels.map((m) => m['name']!).toList();
    final all = <String>[...preset];
    for (final m in dbModels) {
      if (!all.contains(m)) all.add(m);
    }
    return all;
  }

  /// 计算该型号的参考价格
  Map<String, dynamic> _computeRefPrices(String model) {
    final devices = gStorage.getDevices();
    final sameModel = devices.where((d) => d.model == model).toList();
    final sold = sameModel.where((d) => d.status == 'sold').toList();
    final inStock =
        sameModel
            .where((d) => d.status == 'in_stock' || d.status == 'listed')
            .toList();

    final avgPurchase =
        sameModel.isEmpty
            ? 0
            : sameModel.map((d) => d.purchaseCost).reduce((a, b) => a + b) ~/
                sameModel.length;
    final avgSell =
        sold.isEmpty
            ? 0
            : sold.map((d) => d.sellPrice).reduce((a, b) => a + b) ~/
                sold.length;
    final bestPurchase =
        sameModel.isEmpty
            ? 0
            : sameModel
                .map((d) => d.purchaseCost)
                .reduce((a, b) => a < b ? a : b);
    final totalProfit =
        sold.isEmpty ? 0 : sold.map((d) => d.netProfit).reduce((a, b) => a + b);
    final avgProfit = sold.isEmpty ? 0 : totalProfit ~/ sold.length;

    // 近30天销量
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final sales30d =
        sold.where((d) {
          final sd = d.sellDate;
          if (sd == null) return false;
          try {
            return DateTime.parse(sd).isAfter(thirtyDaysAgo);
          } catch (_) {
            return false;
          }
        }).length;

    // 维修/佣金/物流均价
    final repairAvg =
        sold.isEmpty
            ? 0
            : sold.map((d) => d.repairCost ?? 0).reduce((a, b) => a + b) ~/
                sold.length;
    final feeAvg =
        sold.isEmpty
            ? 0
            : sold.map((d) => d.platformFee ?? 0).reduce((a, b) => a + b) ~/
                sold.length;
    final logisticsAvg =
        sold.isEmpty
            ? 0
            : sold.map((d) => d.logisticsCost ?? 0).reduce((a, b) => a + b) ~/
                sold.length;

    return {
      'avgPurchaseCost': avgPurchase,
      'avgSellPrice': avgSell,
      'bestPurchaseCost': bestPurchase,
      'sales30d': sales30d,
      'inStockCount': inStock.length,
      'avgProfit': avgProfit,
      'repairAvg': repairAvg,
      'feeAvg': feeAvg,
      'logisticsAvg': logisticsAvg,
    };
  }

  /// 选型号时自动加载参考价 + 今日行情
  void _onModelChanged(String? v) {
    setState(() {
      _selectedModel = v;
      _analysis = null;
      _aiResult = null;
      _refPrices = null;
      _marketPrice = null;
      _marketHistory = null;
      if (v != null) {
        _refPrices = _computeRefPrices(v);
        _marketPrice = gStorage.getMarketPrice(v);
        _marketHistory = gStorage.getMarketPriceHistory(v, days: 30);
        // 自动填入历史采购均价作为建议采购成本
        final rp = _refPrices!;
        final suggestCost = (rp['avgPurchaseCost'] as int);
        if (suggestCost > 0) {
          _costCtrl.text = (suggestCost / 100).toStringAsFixed(0);
        }
      } else {
        _costCtrl.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return appScaffold(
      context,
      '采购决策 · 该不该收',
      ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // ===== 输入卡 =====
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('型号', style: TextStyle(fontSize: 13, color: C.t2)),
                const SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: C.bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: C.line),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedModel,
                    isExpanded: true,
                    underline: const SizedBox(),
                    dropdownColor: C.card,
                    hint: Text(
                      '选择型号',
                      style: TextStyle(color: C.t3, fontSize: 14),
                    ),
                    style: TextStyle(color: C.t1, fontSize: 14),
                    items:
                        _modelOptions
                            .map(
                              (m) => DropdownMenuItem(
                                value: m,
                                child: Text(
                                  m,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            )
                            .toList(),
                    onChanged: _onModelChanged,
                  ),
                ),
                const SizedBox(height: 12),
                // 参考价卡片（选型号后显示）
                if (_refPrices != null) ...[
                  _buildRefPriceCard(_refPrices!),
                  const SizedBox(height: 12),
                  // 风险评分（实时）
                  _buildRiskScoreCard(_refPrices!),
                  const SizedBox(height: 12),
                ],
                // 采购成本 + 数量并排
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _costCtrl,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: C.t1, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: '采购成本(元/台)',
                          labelStyle: TextStyle(color: C.t2, fontSize: 12),
                          filled: true,
                          fillColor: C.bg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: C.line),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 70,
                      child: TextField(
                        controller: _qtyCtrl,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: C.t1, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: '数量',
                          labelStyle: TextStyle(color: C.t2, fontSize: 12),
                          filled: true,
                          fillColor: C.bg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: C.line),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // 利润拆解（有参考价时显示）
                if (_refPrices != null) ...[
                  const SizedBox(height: 12),
                  _buildProfitBreakdown(_refPrices!),
                ],
                const SizedBox(height: 10),
                ghostBtn(
                  '批量补货建议',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RestockSuggestionPage(),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                primaryBtn('开始分析', _analyze),
              ],
            ),
          ),
          // 分析结果
          if (_analysis != null) ...[
            const SizedBox(height: 14),
            _buildKpiCard(),
            const SizedBox(height: 12),
            _buildSupplierCard(),
            const SizedBox(height: 12),
            _buildAiCard(),
          ],
        ],
      ),
    );
  }

  /// 参考价卡片
  Widget _buildRefPriceCard(Map<String, dynamic> rp) {
    final avgPur = (rp['avgPurchaseCost'] as int) ~/ 100;
    final avgSell = (rp['avgSellPrice'] as int) ~/ 100;
    final bestPur = (rp['bestPurchaseCost'] as int) ~/ 100;
    final sales30 = rp['sales30d'] as int;
    final inStock = rp['inStockCount'] as int;
    final avgProfit = (rp['avgProfit'] as int) ~/ 100;
    final wholesalePrice =
        _marketPrice != null ? ((_marketPrice!['price'] as int) ~/ 100) : null;

    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '参考数据',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: C.t1,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: C.brand.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '基于 ${sales30 + inStock} 条历史',
                  style: TextStyle(fontSize: 9, color: C.brand),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _refRow('📉 历史采购均价', '¥$avgPur', avgPur > 0 ? null : '暂无数据'),
          _refRow('📈 历史售价均价', '¥$avgSell', avgSell > 0 ? null : '暂无数据'),
          if (wholesalePrice != null)
            _refRow(
              '🏪 今日批发价',
              '¥$wholesalePrice',
              _marketPrice!['date'] as String?,
            ),
          Divider(color: C.line, height: 8),
          _refRow(
            '🏆 历史最佳采购价',
            '¥$bestPur',
            bestPur > 0 && bestPur < avgPur
                ? '比均价低 ¥${avgPur - bestPur}'
                : null,
          ),
          _refRow('💰 历史均利', '¥$avgProfit', avgProfit > 0 ? null : '暂无'),
          _refRow('📦 近30天销量', '$sales30 台', null),
          _refRow('🏪 当前在售', '$inStock 台', null),
        ],
      ),
    );
  }

  Widget _refRow(String label, String value, String? hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(fontSize: 11, color: C.t2)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: C.t1,
            ),
          ),
          if (hint != null)
            Expanded(
              child: Text(
                ' · $hint',
                style: TextStyle(fontSize: 9, color: C.t3),
                textAlign: TextAlign.right,
              ),
            ),
        ],
      ),
    );
  }

  /// 利润拆解卡片
  Widget _buildProfitBreakdown(Map<String, dynamic> rp) {
    final costStr = _costCtrl.text.trim();
    final cost = double.tryParse(costStr) ?? 0;
    final costFen = (cost * 100).round();
    final avgSell = (rp['avgSellPrice'] as int);
    final repairAvg = rp['repairAvg'] as int;
    final feeAvg = rp['feeAvg'] as int;
    final logisticsAvg = rp['logisticsAvg'] as int;
    final afterSaleAvg = 6000; // 售后预留 ¥60（固定的合理预留）

    if (costFen <= 0 || avgSell <= 0) return const SizedBox();

    final totalCost =
        costFen + repairAvg + feeAvg + logisticsAvg + afterSaleAvg;
    final netProfit = avgSell - totalCost;
    final margin = avgSell > 0 ? (netProfit / avgSell * 100) : 0.0;
    final avgTurnover = rp['avgTurnoverDays'] as int? ?? 28;

    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '预估单台利润',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: C.t1,
                ),
              ),
              const Spacer(),
              Text(
                '净利 ¥${(netProfit / 100).toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: netProfit > 0 ? C.green : C.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '毛利率 ${margin.toStringAsFixed(1)}% · 预计周转 ${avgTurnover}天',
            style: TextStyle(fontSize: 10, color: C.t3),
          ),
          Divider(color: C.line, height: 16),
          _profitRow('预计售价', avgSell, null, bold: true),
          _profitRow('拿货成本', costFen, C.red),
          _profitRow('维修成本预估', repairAvg, C.orange),
          _profitRow('平台佣金预估', feeAvg, C.orange),
          _profitRow('物流+包装', logisticsAvg, C.orange),
          _profitRow('售后预留', afterSaleAvg, C.orange),
          Divider(color: C.line, height: 8),
          _profitRow(
            '预估净利',
            netProfit,
            netProfit > 0 ? C.green : C.red,
            bold: true,
          ),
        ],
      ),
    );
  }

  Widget _profitRow(
    String label,
    int amountFen,
    Color? amountColor, {
    bool bold = false,
  }) {
    final isNegative = amountFen < 0;
    final display =
        isNegative
            ? '-¥${((-amountFen) / 100).toStringAsFixed(0)}'
            : '¥${(amountFen / 100).toStringAsFixed(0)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: C.t2)),
          const Spacer(),
          Text(
            display,
            style: TextStyle(
              fontSize: bold ? 14 : 12,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: amountColor ?? C.t1,
            ),
          ),
        ],
      ),
    );
  }

  /// 风险评分
  Widget _buildRiskScoreCard(Map<String, dynamic> rp) {
    final cost = double.tryParse(_costCtrl.text) ?? 0;
    final costFen = (cost * 100).round();
    final avgSell = rp['avgSellPrice'] as int;
    final sales30 = rp['sales30d'] as int;
    final inStock = rp['inStockCount'] as int;

    // 利润空间评分：成本 vs 售价
    int profitScore = 0;
    if (avgSell > 0 && costFen > 0) {
      final margin = (avgSell - costFen) / avgSell;
      if (margin > 0.15)
        profitScore = 90;
      else if (margin > 0.10)
        profitScore = 70;
      else if (margin > 0.05)
        profitScore = 50;
      else if (margin > 0)
        profitScore = 30;
      else
        profitScore = 10;
    }

    // 周转速度评分：销量越高分越高
    int turnoverScore =
        sales30 >= 8
            ? 90
            : sales30 >= 5
            ? 70
            : sales30 >= 3
            ? 50
            : sales30 >= 1
            ? 30
            : 10;

    // 库存压力评分：在售越少越好
    int stockScore =
        inStock <= 2
            ? 90
            : inStock <= 5
            ? 70
            : inStock <= 10
            ? 50
            : 30;

    // 价格趋势评分：批发价趋势
    int trendScore = 50; // 默认中等
    if (_marketHistory != null && _marketHistory!.length >= 2) {
      final first = (_marketHistory!.first['price'] as int);
      final last = (_marketHistory!.last['price'] as int);
      final change = last - first;
      final pct = first > 0 ? change / first : 0.0;
      if (pct > 0.03)
        trendScore = 80;
      else if (pct > 0)
        trendScore = 65;
      else if (pct > -0.03)
        trendScore = 50;
      else
        trendScore = 30;
    }

    // 综合评分
    final totalScore =
        (profitScore * 0.30 +
                turnoverScore * 0.25 +
                stockScore * 0.25 +
                trendScore * 0.20)
            .round();

    String conclusion;
    Color conclusionColor;
    if (totalScore >= 75) {
      conclusion = '建议收';
      conclusionColor = C.green;
    } else if (totalScore >= 55) {
      conclusion = '谨慎收';
      conclusionColor = C.orange;
    } else {
      conclusion = '不建议';
      conclusionColor = C.red;
    }

    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '综合评分',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: C.t1,
                ),
              ),
              const Spacer(),
              Text(
                '$totalScore 分 · $conclusion',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: conclusionColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _scoreBar('利润空间', profitScore, 0.30, Colors.blue),
          const SizedBox(height: 6),
          _scoreBar('周转速度', turnoverScore, 0.25, Colors.teal),
          const SizedBox(height: 6),
          _scoreBar('库存压力', stockScore, 0.25, Colors.indigo),
          const SizedBox(height: 6),
          _scoreBar('价格趋势', trendScore, 0.20, Colors.cyan),
        ],
      ),
    );
  }

  Widget _scoreBar(String label, int score, double weight, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: C.t2)),
            const Spacer(),
            Text(
              '$score 分',
              style: TextStyle(
                fontSize: 11,
                color: C.t1,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: 4),
            Text(
              '(${(weight * 100).toStringAsFixed(0)}%)',
              style: TextStyle(fontSize: 9, color: C.t3),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: score / 100,
            backgroundColor: C.line,
            valueColor: AlwaysStoppedAnimation<Color>(color.withOpacity(0.8)),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  /// KPI 卡片 —— 无框大数字风格
  Widget _buildKpiCard() {
    final a = _analysis!;
    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '历史指标',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: C.t1,
            ),
          ),
          const SizedBox(height: 14),
          // 第一行：4 大核心指标（大数字）
          Row(
            children: [
              Expanded(child: _bigKpi('${a['salesCount']}', '销量(台)', C.brand2)),
              Expanded(
                child: _bigKpi(
                  ((a['avgProfit'] as int) / 100).toStringAsFixed(0),
                  '均利润(元)',
                  C.green,
                ),
              ),
              Expanded(
                child: _bigKpi('${a['avgTurnoverDays']}', '均周转(天)', C.orange),
              ),
              Expanded(
                child: _bigKpi(
                  '${((a['stagnantRate'] as double) * 100).toStringAsFixed(0)}',
                  '压货率(%)',
                  C.pink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 第二行：辅助指标（小标签）
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('在售 ${a['inStockCount']}', C.t2),
              _chip(
                '滞销 ${a['stagnantCount']}',
                a['stagnantCount'] as int > 0 ? C.pink : C.t2,
              ),
              _chip(
                '均价 ${((a['avgSellPrice'] as int) / 100).toStringAsFixed(0)}',
                C.t2,
              ),
              _chip(
                '均成本 ${((a['avgPurchaseCost'] as int) / 100).toStringAsFixed(0)}',
                C.t2,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 大数字 KPI（无框，纯色块）
  Widget _bigKpi(String value, String label, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Text(
        value,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: color,
          height: 1.2,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        label,
        style: TextStyle(fontSize: 10, color: C.t3),
        textAlign: TextAlign.center,
      ),
    ],
  );

  /// 小标签 chip（无框）
  Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
    ),
  );

  Widget _buildSupplierCard() {
    final a = _analysis!;
    final suppliers = a['suppliers'] as List;
    if (suppliers.isEmpty && a['hasHistory'] == false) {
      return CardBox(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '⚠️ 无历史数据',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: C.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '该型号无销售历史，建议参考 AI 判断。',
              style: TextStyle(fontSize: 12, color: C.t2),
            ),
          ],
        ),
      );
    }
    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '供应商表现',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: C.t1,
            ),
          ),
          const SizedBox(height: 10),
          ...suppliers.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: C.brand.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      s['channel'] as String,
                      style: const TextStyle(
                        fontSize: 12,
                        color: C.brand,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${s['count']}台',
                    style: TextStyle(fontSize: 12, color: C.t2),
                  ),
                  const Spacer(),
                  Text(
                    '均利${((s['profit'] as int) / 100).toStringAsFixed(0)}元',
                    style: const TextStyle(
                      fontSize: 13,
                      color: C.green,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [C.purple, C.brand2]),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI 综合判断',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '综合 历史数据 + 采购成本',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: CircularProgressIndicator(color: Colors.white))
          else if (_aiResult != null)
            Text(
              _aiResult!,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white,
                height: 1.8,
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _askAi,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '获取 AI 采购建议',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _analyze() {
    if (_selectedModel == null) {
      toast(context, '请选择型号');
      return;
    }
    final cost = double.tryParse(_costCtrl.text) ?? 0;
    if (cost <= 0) {
      toast(context, '请输入采购成本');
      return;
    }
    setState(() {
      _analysis = gStorage.getModelAnalysis(_selectedModel!);
      _marketPrice = gStorage.getMarketPrice(_selectedModel!);
      _marketHistory = gStorage.getMarketPriceHistory(
        _selectedModel!,
        days: 30,
      );
      _aiResult = null;
    });
  }

  void _askAi() async {
    final costFen = ((double.tryParse(_costCtrl.text) ?? 0) * 100).round();
    final qty = int.tryParse(_qtyCtrl.text) ?? 1;
    setState(() => _loading = true);
    final r = await AiService.purchaseDecision(
      model: _selectedModel!,
      purchaseCost: costFen,
      quantity: qty,
      analysis: _analysis!,
      marketPrice: _marketPrice,
      marketHistory: _marketHistory,
    );
    if (!mounted) return;
    setState(() {
      _aiResult = r;
      _loading = false;
    });
  }
}
