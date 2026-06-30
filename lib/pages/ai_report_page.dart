import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../components/index.dart';
import '../utils/utils.dart';
import '../storage.dart';
import '../ai_service.dart';
import '../main.dart';

class AiReportPage extends StatefulWidget {
  const AiReportPage({Key? key}) : super(key: key);
  @override
  State<AiReportPage> createState() => _AiReportPageState();
}

class _AiReportPageState extends State<AiReportPage> {
  String? report;
  bool loading = false;
  List<String> highlights = [];
  List<String> concerns = [];
  List<String> suggestions = [];
  List<String> localAnomalies = [];

  Future<void> _gen() async {
    setState(() => loading = true);
    final s = gStorage.computeStats();
    final stg =
        gStorage
            .getDevices()
            .where((d) => d.isStagnant)
            .map((d) => '${d.model} ${d.capacity}')
            .toList();

    // 本地异常检测
    localAnomalies = _detectAnomalies(s);

    final r = await AiService.dailyReport(
      gmv: s.gmv,
      grossProfit: s.grossProfit,
      orderCount: s.orderCount,
      inStock: s.inStockCount,
      stagnant: s.stagnantCount,
      capital: s.capitalOccupied,
      stagnantModels: stg,
    );
    _parseReport(r);
    setState(() {
      report = r;
      loading = false;
    });
  }

  /// 本地异常检测
  List<String> _detectAnomalies(dynamic s) {
    final anomalies = <String>[];
    final devices = gStorage.getDevices();

    // 1. 滞销率 > 30%
    if (s.stagnantCount > 0 && s.inStockCount > 0) {
      final rate = s.stagnantCount / s.inStockCount;
      if (rate > 0.3) {
        anomalies.add('滞销率 ${(rate * 100).toStringAsFixed(0)}%，超过 30% 警戒线');
      }
    }

    // 2. 今日GMV比周均值低50%以上
    final sold =
        devices.where((d) => d.status == 'sold' && d.sellDate != null).toList();
    final today = DateTime.now();
    final weekAgo = today.subtract(const Duration(days: 7));
    final weekSales =
        sold.where((d) {
          try {
            return DateTime.parse(d.sellDate!).isAfter(weekAgo);
          } catch (_) {
            return false;
          }
        }).toList();
    if (weekSales.length >= 3 && s.gmv > 0) {
      final weekAvgGmv =
          weekSales.fold(0, (int sum, d) => sum + d.sellPrice) ~/
          weekSales.length;
      if (s.gmv < weekAvgGmv * 0.5) {
        anomalies.add('今日 GMV 低于近 7 日均值 50% 以上');
      }
    }

    // 3. 单台利润低于历史均值50%
    final soldHasProfit = sold.where((d) => d.netProfit > 0).toList();
    if (soldHasProfit.length >= 3) {
      final avgProfit =
          soldHasProfit.fold(0, (int sum, d) => sum + d.netProfit) ~/
          soldHasProfit.length;
      final todaySold =
          sold.where((d) {
            try {
              return DateTime.parse(d.sellDate!).day == today.day;
            } catch (_) {
              return false;
            }
          }).toList();
      for (final d in todaySold) {
        if (d.netProfit < avgProfit * 0.5) {
          anomalies.add(
            '${d.model} ${d.capacity} 利润 ${(d.netProfit / 100).toStringAsFixed(0)}元，低于历史均值 50%',
          );
          break;
        }
      }
    }

    // 4. 某机型连续7天无动销（有库存但没卖出）
    for (final model in devices.map((d) => d.model).toSet()) {
      final inStock =
          devices
              .where(
                (d) =>
                    d.model == model &&
                    (d.status == 'in_stock' || d.status == 'listed'),
              )
              .toList();
      if (inStock.isNotEmpty) {
        final lastSold =
            sold.where((d) => d.model == model).toList()
              ..sort((a, b) => (b.sellDate ?? '').compareTo(a.sellDate ?? ''));
        if (lastSold.isNotEmpty) {
          try {
            final lastDate = DateTime.parse(lastSold.first.sellDate!);
            if (today.difference(lastDate).inDays >= 7) {
              anomalies.add('$model 已有 7 天以上无动销，库存 ${inStock.length} 台');
            }
          } catch (_) {}
        } else {
          anomalies.add('$model 从未售出，库存 ${inStock.length} 台');
        }
      }
    }

    return anomalies;
  }

  /// 解析结构化输出
  void _parseReport(String text) {
    highlights = [];
    concerns = [];
    suggestions = [];
    String currentSection = '';
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.contains('【亮点】') || trimmed.contains('[亮点]')) {
        currentSection = 'highlights';
      } else if (trimmed.contains('【待关注】') || trimmed.contains('[待关注]')) {
        currentSection = 'concerns';
      } else if (trimmed.contains('【明日建议】') || trimmed.contains('[明日建议]')) {
        currentSection = 'suggestions';
      } else if (trimmed.startsWith('•') ||
          trimmed.startsWith('-') ||
          trimmed.startsWith('*')) {
        final item = trimmed.substring(1).trim();
        if (item.isNotEmpty) {
          if (currentSection == 'highlights')
            highlights.add(item);
          else if (currentSection == 'concerns')
            concerns.add(item);
          else if (currentSection == 'suggestions')
            suggestions.add(item);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = gStorage.computeStats();
    return appScaffold(
      context,
      'AI经营日报',
      ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // 今日数据头
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Color(0xFF4338CA)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      '今日数据',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE0E7FF),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '更新于 ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, "0")}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFFA5B4FC),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _d('GMV', yuan(s.gmv)),
                    _d('毛利', yuan(s.grossProfit)),
                    _d('在售', '${s.inStockCount}台'),
                    _d('滞销', '${s.stagnantCount}台'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // AI生成按钮
          if (report == null && !loading)
            CardBox(
              child: Column(
                children: [
                  Text(
                    '点击下方按钮，AI将基于你的真实经营数据生成今日日报与建议',
                    style: TextStyle(fontSize: 12.5, color: C.t3, height: 1.8),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  primaryBtn('生成AI日报', _gen),
                ],
              ),
            ),
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: C.brand2),
              ),
            ),
          // 结构化卡片
          if (report != null && !loading) ...[
            // 亮点
            if (highlights.isNotEmpty)
              _sectionCard('✅ 今日亮点', highlights, C.green),
            const SizedBox(height: 10),
            // 待关注
            if (concerns.isNotEmpty) _sectionCard('⚠️ 待关注', concerns, C.orange),
            const SizedBox(height: 10),
            // 建议
            if (suggestions.isNotEmpty)
              _sectionCard('🎯 明日建议', suggestions, C.brand2),
            const SizedBox(height: 10),
            // 本地异常检测
            if (localAnomalies.isNotEmpty)
              _sectionCard('🚨 异常预警', localAnomalies, C.red),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _gen,
                style: OutlinedButton.styleFrom(
                  foregroundColor: C.brand2,
                  side: BorderSide(color: C.brand2),
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                child: const Text('重新生成', style: TextStyle(fontSize: 13)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionCard(String title, List<String> items, Color accent) {
    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: C.t1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: C.t1,
                        height: 1.5,
                      ),
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

  Widget _d(String l, String v) => Expanded(
    child: Column(
      children: [
        Text(
          v,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Color(0xFFFBBF24),
          ),
        ),
        const SizedBox(height: 2),
        Text(l, style: const TextStyle(fontSize: 10, color: Color(0xFFA5B4FC))),
      ],
    ),
  );
}
