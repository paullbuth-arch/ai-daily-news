import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../components/index.dart';
import '../storage.dart';
import '../main.dart';

class RestockSuggestionPage extends StatefulWidget {
  const RestockSuggestionPage({Key? key}) : super(key: key);
  @override
  State<RestockSuggestionPage> createState() => _RestockSuggestionPageState();
}

class _RestockSuggestionPageState extends State<RestockSuggestionPage> {
  /// 计算每个型号的补货建议
  List<Map<String, dynamic>> _computeSuggestions() {
    final devices = gStorage.getDevices();
    final sold =
        devices.where((d) => d.status == 'sold' && d.sellDate != null).toList();
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    // 按型号分组
    final modelData = <String, Map<String, dynamic>>{};
    for (final d in devices) {
      final model = d.model;
      if (!modelData.containsKey(model)) {
        modelData[model] = {
          'model': model,
          'inStock': 0,
          'sales30d': 0,
          'avgSellPrice': 0,
          'salesList': <int>[],
        };
      }
      if (d.status == 'in_stock' || d.status == 'listed') {
        modelData[model]!['inStock'] =
            (modelData[model]!['inStock'] as int) + 1;
      }
    }
    for (final d in sold) {
      final model = d.model;
      if (!modelData.containsKey(model)) continue;
      try {
        if (DateTime.parse(d.sellDate!).isAfter(thirtyDaysAgo)) {
          modelData[model]!['sales30d'] =
              (modelData[model]!['sales30d'] as int) + 1;
        }
      } catch (_) {}
      (modelData[model]!['salesList'] as List<int>).add(d.sellPrice);
    }

    // 计算建议
    final suggestions = <Map<String, dynamic>>[];
    for (final entry in modelData.entries) {
      final data = entry.value;
      final inStock = data['inStock'] as int;
      final sales30 = data['sales30d'] as int;

      // 月销 / 4 ≈ 周销
      // 建议库存 = 月销 * 1.5（覆盖6周）
      final suggestedStock = (sales30 * 1.5).round();
      final toPurchase = suggestedStock - inStock;

      // 建议采购上限 = 历史售价均价 * 0.85（留15%利润空间）
      final salesList = data['salesList'] as List<int>;
      final avgPrice =
          salesList.isEmpty
              ? 0
              : salesList.fold(0, (int a, int b) => a + b) ~/ salesList.length;
      final maxPurchase = avgPrice > 0 ? (avgPrice * 0.85).round() : 0;

      if (sales30 > 0 || inStock > 0) {
        suggestions.add({
          'model': data['model'],
          'inStock': inStock,
          'sales30d': sales30,
          'suggestedStock': suggestedStock,
          'toPurchase': toPurchase > 0 ? toPurchase : 0,
          'maxPurchasePrice': maxPurchase,
          'avgSellPrice': avgPrice,
        });
      }
    }

    // 按补货紧迫度排序：库存/月销比越低越紧迫
    suggestions.sort((a, b) {
      final ratioA =
          (a['sales30d'] as int) > 0
              ? (a['inStock'] as int) / (a['sales30d'] as int)
              : 999;
      final ratioB =
          (b['sales30d'] as int) > 0
              ? (b['inStock'] as int) / (b['sales30d'] as int)
              : 999;
      return ratioA.compareTo(ratioB);
    });

    return suggestions;
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _computeSuggestions();
    return appScaffold(
      context,
      '批量补货建议',
      ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Text(
            '基于近 30 天销量 + 当前库存自动计算',
            style: TextStyle(fontSize: 11, color: C.t3),
          ),
          const SizedBox(height: 12),
          if (suggestions.isEmpty)
            CardBox(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    '暂无数据，先录入一些设备和订单吧',
                    style: TextStyle(fontSize: 12, color: C.t3),
                  ),
                ),
              ),
            )
          else
            ...suggestions.map((s) => _buildSuggestionCard(s)),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard(Map<String, dynamic> s) {
    final model = s['model'] as String;
    final inStock = s['inStock'] as int;
    final sales30 = s['sales30d'] as int;
    final toPurchase = s['toPurchase'] as int;
    final maxPrice = s['maxPurchasePrice'] as int;
    final avgPrice = s['avgSellPrice'] as int;

    String action;
    Color actionColor;
    if (toPurchase > 0) {
      action = '建议补 $toPurchase 台';
      actionColor = C.green;
    } else if (inStock > sales30 * 2) {
      action = '库存充足，暂不补货';
      actionColor = C.t3;
    } else {
      action = '观察即可';
      actionColor = C.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: CardBox(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    model,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: C.t1,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: actionColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    action,
                    style: TextStyle(
                      fontSize: 11,
                      color: actionColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _row('库存', '$inStock 台'),
            _row('近30天销量', '$sales30 台'),
            _row('建议库存', '${s['suggestedStock']} 台（覆盖 6 周）'),
            if (avgPrice > 0)
              _row('历史售价均价', '¥${(avgPrice / 100).toStringAsFixed(0)}'),
            if (maxPrice > 0)
              _row('建议采购上限', '¥${(maxPrice / 100).toStringAsFixed(0)}'),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: TextStyle(fontSize: 11, color: C.t2)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              color: C.t1,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
