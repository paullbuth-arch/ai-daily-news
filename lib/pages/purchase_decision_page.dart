import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../components/index.dart';
import '../utils/utils.dart';
import '../main.dart';
import '../ai_service.dart';
import 'market_price_page.dart';
import 'restock_suggestion_page.dart';

class PurchaseDecisionPage extends StatefulWidget {
  final String? initialModel;
  final int? initialCostFen;

  const PurchaseDecisionPage({Key? key, this.initialModel, this.initialCostFen})
    : super(key: key);

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
  bool _suppressInputNotify = false;
  Map<String, dynamic>? _refPrices;

  static const int _targetProfit = 35000;
  static const int _afterSaleReserve = 6000;
  static const int _defaultLogistics = 1500;

  @override
  void initState() {
    super.initState();
    _costCtrl.addListener(_onInputChanged);
    _qtyCtrl.addListener(_onInputChanged);
    _applyInitialInput();
  }

  @override
  void dispose() {
    _costCtrl.removeListener(_onInputChanged);
    _qtyCtrl.removeListener(_onInputChanged);
    _costCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    if (_suppressInputNotify || !mounted) return;
    setState(() => _aiResult = null);
  }

  void _applyInitialInput() {
    final model = widget.initialModel?.trim();
    if (model == null || model.isEmpty) return;

    final ref = _computeRefPrices(model);
    final market = gStorage.getMarketPrice(model);
    final history = gStorage.getMarketPriceHistory(model, days: 30);
    final analysis = gStorage.getModelAnalysis(model);
    final initialCost = widget.initialCostFen ?? _initialCost(ref, market);

    _suppressInputNotify = true;
    if (initialCost > 0) {
      _costCtrl.text = (initialCost / 100).toStringAsFixed(0);
    }
    _suppressInputNotify = false;

    _selectedModel = model;
    _analysis = analysis;
    _refPrices = ref;
    _marketPrice = market;
    _marketHistory = history;
  }

  List<String> get _modelOptions {
    final dbModels = gStorage.getDevices().map((d) => d.model).toSet().toList();
    final marketModels = gStorage.getAllLatestMarketPrices().keys.toList();
    final preset = iPadModels.map((m) => m['name']!).toList();
    final all = <String>[...preset];
    for (final m in [...dbModels, ...marketModels]) {
      if (!all.contains(m)) all.add(m);
    }
    return all;
  }

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
            : sameModel.fold<int>(0, (sum, d) => sum + d.purchaseCost) ~/
                sameModel.length;
    final avgSell =
        sold.isEmpty
            ? 0
            : sold.fold<int>(0, (sum, d) => sum + d.sellPrice) ~/ sold.length;
    final bestPurchase =
        sameModel.isEmpty
            ? 0
            : sameModel
                .map((d) => d.purchaseCost)
                .reduce((a, b) => a < b ? a : b);
    final avgProfit =
        sold.isEmpty
            ? 0
            : sold.fold<int>(0, (sum, d) => sum + d.netProfit) ~/ sold.length;

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

    int turnoverTotal = 0;
    int turnoverCount = 0;
    for (final d in sold) {
      final sd = d.sellDate;
      if (sd == null) continue;
      try {
        turnoverTotal +=
            DateTime.parse(
              sd,
            ).difference(DateTime.parse(d.purchaseDate)).inDays;
        turnoverCount++;
      } catch (_) {}
    }

    final repairAvg =
        sold.isEmpty
            ? 0
            : sold.fold<int>(0, (sum, d) => sum + (d.repairCost ?? 0)) ~/
                sold.length;
    final feeAvg =
        sold.isEmpty
            ? 0
            : sold.fold<int>(0, (sum, d) => sum + (d.platformFee ?? 0)) ~/
                sold.length;
    final logisticsAvg =
        sold.isEmpty
            ? 0
            : sold.fold<int>(0, (sum, d) => sum + (d.logisticsCost ?? 0)) ~/
                sold.length;
    final stagnant = inStock.where((d) => d.isStagnant).length;
    final oldestStockDays =
        inStock.isEmpty
            ? 0
            : inStock.map((d) => d.stockDays).reduce((a, b) => a > b ? a : b);

    return {
      'avgPurchaseCost': avgPurchase,
      'avgSellPrice': avgSell,
      'bestPurchaseCost': bestPurchase,
      'sales30d': sales30d,
      'inStockCount': inStock.length,
      'stagnantCount': stagnant,
      'oldestStockDays': oldestStockDays,
      'avgProfit': avgProfit,
      'avgTurnoverDays': turnoverCount > 0 ? turnoverTotal ~/ turnoverCount : 0,
      'repairAvg': repairAvg,
      'feeAvg': feeAvg,
      'logisticsAvg': logisticsAvg,
      'dataCount': sameModel.length,
    };
  }

  void _onModelChanged(String? v) {
    final ref = v == null ? null : _computeRefPrices(v);
    final market = v == null ? null : gStorage.getMarketPrice(v);
    final history =
        v == null ? null : gStorage.getMarketPriceHistory(v, days: 30);
    final analysis = v == null ? null : gStorage.getModelAnalysis(v);

    _suppressInputNotify = true;
    if (v == null) {
      _costCtrl.clear();
    } else {
      final suggest = _initialCost(ref, market);
      if (suggest > 0) {
        _costCtrl.text = (suggest / 100).toStringAsFixed(0);
      } else {
        _costCtrl.clear();
      }
    }
    _suppressInputNotify = false;

    setState(() {
      _selectedModel = v;
      _analysis = analysis;
      _refPrices = ref;
      _marketPrice = market;
      _marketHistory = history;
      _aiResult = null;
    });
  }

  int _initialCost(Map<String, dynamic>? ref, Map<String, dynamic>? market) {
    final avgPurchase = (ref?['avgPurchaseCost'] as int?) ?? 0;
    if (avgPurchase > 0) return avgPurchase;
    final marketPrice = (market?['price'] as int?) ?? 0;
    if (marketPrice > 0) return marketPrice;
    return 0;
  }

  int get _costFen {
    final cost = double.tryParse(_costCtrl.text.trim()) ?? 0;
    return (cost * 100).round();
  }

  int get _qty {
    final q = int.tryParse(_qtyCtrl.text.trim()) ?? 1;
    return q <= 0 ? 1 : q.clamp(1, 999).toInt();
  }

  _PurchasePlan? _buildPlan(Map<String, dynamic>? ref) {
    if (ref == null || _selectedModel == null || _costFen <= 0) return null;

    final avgSell = ref['avgSellPrice'] as int;
    final repairAvg = ref['repairAvg'] as int;
    final historicalFee = ref['feeAvg'] as int;
    final logisticsAvg = ref['logisticsAvg'] as int;
    final estimatedFee =
        avgSell > 0
            ? _maxInt(historicalFee, (avgSell * 0.016).round())
            : historicalFee;
    final logistics = logisticsAvg > 0 ? logisticsAvg : _defaultLogistics;
    final fixedCosts = repairAvg + estimatedFee + logistics + _afterSaleReserve;
    final marketCost = (_marketPrice?['price'] as int?) ?? 0;
    final maxPurchase =
        avgSell > 0
            ? _maxInt(0, avgSell - fixedCosts - _targetProfit)
            : marketCost > 0
            ? _maxInt(0, marketCost - 5000)
            : 0;
    final quickSell = avgSell > 0 ? (avgSell * 0.94).round() : 0;
    final netProfit = avgSell > 0 ? avgSell - _costFen - fixedCosts : 0;
    final quickProfit =
        quickSell > 0 ? quickSell - _costFen - fixedCosts : netProfit;
    final breakEven = _costFen + fixedCosts;
    final sales30 = ref['sales30d'] as int;
    final inStock = ref['inStockCount'] as int;
    final stagnant = ref['stagnantCount'] as int;
    final avgTurnover = ref['avgTurnoverDays'] as int;
    final trendScore = _trendScore();
    final profitScore = _profitScore(avgSell, netProfit);
    final salesScore =
        sales30 >= 8
            ? 92
            : sales30 >= 5
            ? 78
            : sales30 >= 3
            ? 64
            : sales30 >= 1
            ? 45
            : 24;
    final stockScore =
        inStock == 0
            ? 90
            : sales30 > 0 && inStock <= sales30
            ? 78
            : sales30 > 0 && inStock <= sales30 * 2
            ? 58
            : inStock <= 2
            ? 62
            : 34;
    final dataScore = (ref['dataCount'] as int) >= 3 ? 72 : 45;
    var score =
        (profitScore * 0.36 +
                salesScore * 0.22 +
                stockScore * 0.22 +
                trendScore * 0.12 +
                dataScore * 0.08)
            .round();
    if (maxPurchase > 0 && _costFen > maxPurchase) {
      final overRate = (_costFen - maxPurchase) / maxPurchase;
      score -= (overRate * 70).clamp(8, 28).round();
    }
    score = score.clamp(0, 100).toInt();

    final risks = _riskItems(
      avgSell: avgSell,
      maxPurchase: maxPurchase,
      netProfit: netProfit,
      quickProfit: quickProfit,
      sales30: sales30,
      inStock: inStock,
      stagnant: stagnant,
      avgTurnover: avgTurnover,
    );

    late String decision;
    late String summary;
    late Color color;
    if (avgSell == 0 && marketCost == 0) {
      decision = '先别重仓';
      summary = '没有售价和行情锚点，只适合小批试单。';
      color = C.orange;
    } else if (maxPurchase > 0 && _costFen > maxPurchase) {
      decision = '压价再收';
      summary = '当前报价高于建议上限 ${yuan(_costFen - maxPurchase)}。';
      color = C.orange;
    } else if (score >= 75 && netProfit >= _targetProfit) {
      decision = '建议收';
      summary = '利润、周转和库存压力都在可控区间。';
      color = C.mint;
    } else if (score >= 55 && netProfit > 15000) {
      decision = '谨慎收';
      summary = '有利润，但需要控制数量或压一点价格。';
      color = C.orange;
    } else {
      decision = '不建议';
      summary = '当前利润或动销不足，容易变成压货。';
      color = C.red;
    }

    return _PurchasePlan(
      decision: decision,
      summary: summary,
      color: color,
      score: score,
      costFen: _costFen,
      quantity: _qty,
      avgSell: avgSell,
      quickSell: quickSell,
      netProfit: netProfit,
      quickProfit: quickProfit,
      maxPurchase: maxPurchase,
      fixedCosts: fixedCosts,
      breakEven: breakEven,
      batchCapital: _costFen * _qty,
      risks: risks,
    );
  }

  int _trendScore() {
    final history = _marketHistory;
    if (history == null || history.length < 2) return 52;
    final first = history.first['price'] as int;
    final last = history.last['price'] as int;
    if (first <= 0) return 52;
    final pct = (last - first) / first;
    if (pct > 0.03) return 76;
    if (pct > 0.0) return 64;
    if (pct > -0.03) return 52;
    return 30;
  }

  int _profitScore(int avgSell, int netProfit) {
    if (avgSell <= 0) return 35;
    final margin = netProfit / avgSell;
    if (netProfit >= 50000 && margin >= 0.12) return 96;
    if (netProfit >= _targetProfit) return 82;
    if (netProfit >= 22000) return 62;
    if (netProfit > 0) return 42;
    return 12;
  }

  List<_RiskItem> _riskItems({
    required int avgSell,
    required int maxPurchase,
    required int netProfit,
    required int quickProfit,
    required int sales30,
    required int inStock,
    required int stagnant,
    required int avgTurnover,
  }) {
    final list = <_RiskItem>[];
    if (maxPurchase > 0 && _costFen > maxPurchase) {
      list.add(
        _RiskItem(
          color: C.red,
          title: '报价超上限',
          text:
              '建议最高 ${yuan(maxPurchase)}，当前高出 ${yuan(_costFen - maxPurchase)}。',
        ),
      );
    }
    if (avgSell <= 0) {
      list.add(
        const _RiskItem(
          color: C.orange,
          title: '缺少售价历史',
          text: '没有同型号成交价，建议先看今日批发价和同行售价。',
        ),
      );
    }
    if (sales30 == 0) {
      list.add(
        const _RiskItem(
          color: C.orange,
          title: '近30天无成交',
          text: '动销不足时不要按常规利润模型重仓。',
        ),
      );
    }
    if (sales30 > 0 && inStock > sales30 * 2) {
      list.add(
        _RiskItem(
          color: C.red,
          title: '库存偏重',
          text: '当前在售 $inStock 台，已经超过近30天销量的2倍。',
        ),
      );
    }
    if (stagnant > 0) {
      list.add(
        _RiskItem(
          color: C.orange,
          title: '已有滞销',
          text: '同型号还有 $stagnant 台滞销，先处理旧库存再加仓。',
        ),
      );
    }
    if (avgTurnover >= 35) {
      list.add(
        _RiskItem(
          color: C.orange,
          title: '周转偏慢',
          text: '历史平均周转 $avgTurnover 天，现金会被占用更久。',
        ),
      );
    }
    if (quickProfit < 0) {
      list.add(
        _RiskItem(
          color: C.red,
          title: '快速出货会亏',
          text: '按快速出货价测算净利 ${yuan(quickProfit)}。',
        ),
      );
    }
    if (list.isEmpty) {
      list.add(
        const _RiskItem(
          color: C.mint,
          title: '没有明显硬伤',
          text: '重点盯住成色、电池和是否有隐藏维修成本。',
        ),
      );
    }
    return list.take(4).toList();
  }

  int _maxInt(int a, int b) => a > b ? a : b;

  @override
  Widget build(BuildContext context) {
    final plan = _buildPlan(_refPrices);
    return appScaffold(
      context,
      '收货报价器',
      ListView(
        padding: const EdgeInsets.all(14),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          _buildInputCard(plan),
          if (_selectedModel == null)
            _buildEmptyCard(
              icon: Icons.inventory_2_outlined,
              title: '先选一个型号',
              text: '选择型号后会自动带入历史均价、今日行情和库存压力。',
            )
          else if (plan == null)
            _buildEmptyCard(
              icon: Icons.payments_outlined,
              title: '输入收货成本',
              text: '填入对方报价后，系统会马上给出建议上限和不收原因。',
            )
          else ...[
            _buildDecisionCard(plan),
            _buildScenarioCard(plan),
            _buildRiskCard(plan),
            _buildFactsCard(plan),
            _buildSupplierCard(),
            _buildAiCard(plan),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildInputCard(_PurchasePlan? plan) {
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      radius: 20,
      color: const Color(0xEA0B0F16),
      borderColor: Colors.white.withValues(alpha: 0.11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '按报价实时判断',
            style: TextStyle(
              color: C.t1,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '结论来自历史成交、库存、周转和今日批发价。',
            style: TextStyle(color: C.t3, fontSize: 11.5, height: 1.45),
          ),
          const SizedBox(height: 14),
          _buildModelDropdown(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MoneyField(
                  controller: _costCtrl,
                  label: '对方报价(元/台)',
                  icon: Icons.sell_outlined,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 84,
                child: _MoneyField(
                  controller: _qtyCtrl,
                  label: '数量',
                  icon: Icons.tag_rounded,
                ),
              ),
            ],
          ),
          if (plan != null && plan.maxPurchase > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: plan.color.withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: plan.color.withValues(alpha: 0.20)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '建议最高收货价 ${yuan(plan.maxPurchase)}',
                      style: TextStyle(
                        color: plan.color,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  smallBtn(
                    '填入',
                    () => _setCost(plan.maxPurchase),
                    color: plan.color,
                    icon: Icons.keyboard_return_rounded,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _InlineButton(
                  label: '批量补货建议',
                  icon: Icons.playlist_add_check_rounded,
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RestockSuggestionPage(),
                        ),
                      ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InlineButton(
                  label: '录入今日行情',
                  icon: Icons.price_change_outlined,
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MarketPricePage(),
                        ),
                      ).then((_) {
                        if (_selectedModel != null)
                          _onModelChanged(_selectedModel);
                      }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModelDropdown() => AppDropdownField<String>(
    value: _selectedModel,
    hint: '选择型号',
    options: _modelOptions,
    labelBuilder: (value) => value,
    onChanged: _onModelChanged,
  );

  Widget _buildDecisionCard(_PurchasePlan plan) {
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      radius: 20,
      color: plan.color.withValues(alpha: 0.10),
      borderColor: plan.color.withValues(alpha: 0.32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: plan.color.withValues(alpha: 0.17),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _decisionIcon(plan.decision),
                  color: plan.color,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.decision,
                      style: TextStyle(
                        color: plan.color,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plan.summary,
                      style: const TextStyle(
                        color: C.t2,
                        fontSize: 12.5,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${plan.score}分',
                  style: TextStyle(
                    color: plan.color,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _DecisionMetric(
                  label: '预计单台净利',
                  value: plan.avgSell > 0 ? yuan(plan.netProfit) : '暂无',
                  color: plan.netProfit >= _targetProfit ? C.mint : C.orange,
                ),
              ),
              _VerticalRule(),
              Expanded(
                child: _DecisionMetric(
                  label: '本批占用',
                  value: yuan(plan.batchCapital),
                  color: C.cyan,
                ),
              ),
              _VerticalRule(),
              Expanded(
                child: _DecisionMetric(
                  label: '保本售价',
                  value: yuan(plan.breakEven),
                  color: C.purple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _decisionIcon(String decision) {
    if (decision.contains('建议')) return Icons.check_circle_outline_rounded;
    if (decision.contains('不建议')) return Icons.block_rounded;
    return Icons.tune_rounded;
  }

  Widget _buildScenarioCard(_PurchasePlan plan) {
    return GlassPanel(
      padding: const EdgeInsets.all(14),
      radius: 18,
      color: const Color(0xDE0B0F16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '三档报价',
            style: TextStyle(
              color: C.t1,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          _ScenarioLine(
            title: '按当前报价',
            subtitle: '${yuan(plan.costFen)} × ${plan.quantity}台',
            value: plan.avgSell > 0 ? '净利 ${yuan(plan.netProfit)}' : '缺售价',
            color: plan.netProfit >= _targetProfit ? C.mint : C.orange,
          ),
          if (plan.maxPurchase > 0)
            _ScenarioLine(
              title: '压到建议上限',
              subtitle: '最高 ${yuan(plan.maxPurchase)}',
              value: '目标净利 ${yuan(_targetProfit)}',
              color: C.cyan,
              onTap: () => _setCost(plan.maxPurchase),
            ),
          if (plan.quickSell > 0)
            _ScenarioLine(
              title: '快速出货价',
              subtitle: '按历史均价94%出',
              value: '${yuan(plan.quickSell)} / 净利${yuan(plan.quickProfit)}',
              color: plan.quickProfit >= 0 ? C.purple : C.red,
            ),
        ],
      ),
    );
  }

  Widget _buildRiskCard(_PurchasePlan plan) {
    return GlassPanel(
      padding: const EdgeInsets.all(14),
      radius: 18,
      color: const Color(0xDE0B0F16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '不收原因 / 风险',
            style: TextStyle(
              color: C.t1,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          ...plan.risks.map(
            (risk) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: risk.color.withValues(alpha: 0.13),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.priority_high_rounded,
                      color: risk.color,
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          risk.title,
                          style: TextStyle(
                            color: risk.color,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          risk.text,
                          style: const TextStyle(
                            color: C.t2,
                            fontSize: 11.5,
                            height: 1.4,
                          ),
                        ),
                      ],
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

  Widget _buildFactsCard(_PurchasePlan plan) {
    final ref = _refPrices!;
    final market = (_marketPrice?['price'] as int?) ?? 0;
    return GlassPanel(
      padding: const EdgeInsets.all(14),
      radius: 18,
      color: const Color(0xDE0B0F16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '模型事实',
            style: TextStyle(
              color: C.t1,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _FactTile(
                '历史售价',
                _amountText(ref['avgSellPrice'] as int),
                C.cyan,
              ),
              _FactTile('历史均利', _amountText(ref['avgProfit'] as int), C.mint),
              _FactTile('近30天销量', '${ref['sales30d']}台', C.purple),
              _FactTile('当前在售', '${ref['inStockCount']}台', C.orange),
              _FactTile(
                '滞销',
                '${ref['stagnantCount']}台',
                (ref['stagnantCount'] as int) > 0 ? C.red : C.t3,
              ),
              _FactTile('均周转', '${ref['avgTurnoverDays']}天', C.blue),
              _FactTile(
                '今日批发',
                market > 0 ? yuan(market) : '未录入',
                market > 0 ? C.cyan : C.t3,
              ),
              _FactTile(
                '历史最佳拿货',
                _amountText(ref['bestPurchaseCost'] as int),
                C.t2,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _amountText(int amount) => amount > 0 ? yuan(amount) : '暂无';

  Widget _buildSupplierCard() {
    final analysis = _analysis;
    if (analysis == null) return const SizedBox.shrink();
    final suppliers = analysis['suppliers'] as List;
    if (suppliers.isEmpty) return const SizedBox.shrink();
    return GlassPanel(
      padding: const EdgeInsets.all(14),
      radius: 18,
      color: const Color(0xDE0B0F16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '历史采购渠道',
            style: TextStyle(
              color: C.t1,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          ...suppliers
              .take(4)
              .map(
                (s) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          s['channel'] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: C.t1,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        '${s['count']}台',
                        style: const TextStyle(color: C.t3, fontSize: 11),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '均利 ${yuan((s['profit'] as int) ~/ (s['count'] as int))}',
                        style: const TextStyle(
                          color: C.mint,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
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

  Widget _buildAiCard(_PurchasePlan plan) {
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
                      'AI复核',
                      style: TextStyle(
                        color: C.t1,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '用于补充判断，不替代本地报价线',
                      style: TextStyle(color: C.t3, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const LinearProgressIndicator(minHeight: 3, color: C.purple)
          else if (_aiResult != null)
            Text(
              _aiResult!,
              style: const TextStyle(
                color: C.t2,
                fontSize: 12.5,
                height: 1.65,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            Text(
              '本地结论是「${plan.decision}」。如果你要和供应商谈价，可以让AI把压价理由整理成一句话。',
              style: const TextStyle(color: C.t2, fontSize: 12, height: 1.5),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _loading ? null : _askAi,
              icon: const Icon(Icons.psychology_alt_outlined, size: 18),
              label: Text(_aiResult == null ? '让AI复核本次报价' : '重新复核'),
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

  Widget _buildEmptyCard({
    required IconData icon,
    required String title,
    required String text,
  }) {
    return GlassPanel(
      padding: const EdgeInsets.all(20),
      radius: 20,
      color: const Color(0xD80B0F16),
      child: Column(
        children: [
          Icon(icon, color: C.t3, size: 34),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: C.t1,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: C.t2, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }

  void _setCost(int costFen) {
    _costCtrl.text = (costFen / 100).toStringAsFixed(0);
  }

  void _askAi() async {
    if (_selectedModel == null || _refPrices == null) {
      toast(context, '请先选择型号');
      return;
    }
    if (_costFen <= 0) {
      toast(context, '请输入采购成本');
      return;
    }
    final analysis = _analysis ?? gStorage.getModelAnalysis(_selectedModel!);
    setState(() => _loading = true);
    final r = await AiService.purchaseDecision(
      model: _selectedModel!,
      purchaseCost: _costFen,
      quantity: _qty,
      analysis: analysis,
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

class _PurchasePlan {
  final String decision;
  final String summary;
  final Color color;
  final int score;
  final int costFen;
  final int quantity;
  final int avgSell;
  final int quickSell;
  final int netProfit;
  final int quickProfit;
  final int maxPurchase;
  final int fixedCosts;
  final int breakEven;
  final int batchCapital;
  final List<_RiskItem> risks;

  const _PurchasePlan({
    required this.decision,
    required this.summary,
    required this.color,
    required this.score,
    required this.costFen,
    required this.quantity,
    required this.avgSell,
    required this.quickSell,
    required this.netProfit,
    required this.quickProfit,
    required this.maxPurchase,
    required this.fixedCosts,
    required this.breakEven,
    required this.batchCapital,
    required this.risks,
  });
}

class _RiskItem {
  final Color color;
  final String title;
  final String text;

  const _RiskItem({
    required this.color,
    required this.title,
    required this.text,
  });
}

class _MoneyField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;

  const _MoneyField({
    required this.controller,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => AppFormField(
    controller: controller,
    keyboardType: TextInputType.number,
    label: label,
    icon: icon,
  );
}

class _InlineButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _InlineButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 42,
    child: OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 17),
      label: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: C.t1,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        backgroundColor: Colors.white.withValues(alpha: 0.05),
        shape: const StadiumBorder(),
      ),
    ),
  );
}

class _DecisionMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DecisionMetric({
    required this.label,
    required this.value,
    required this.color,
  });

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
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),
  );
}

class _VerticalRule extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 38,
    color: Colors.white.withValues(alpha: 0.08),
  );
}

class _ScenarioLine extends StatelessWidget {
  final String title;
  final String subtitle;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _ScenarioLine({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.stacked_line_chart_rounded,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: C.t1,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: C.t3, fontSize: 10.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: row,
      ),
    );
  }
}

class _FactTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _FactTile(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Container(
    width: 132,
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.045),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
    ),
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
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),
  );
}
