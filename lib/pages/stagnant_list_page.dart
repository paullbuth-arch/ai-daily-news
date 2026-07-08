import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../components/index.dart';
import '../utils/utils.dart';
import '../models.dart';
import '../main.dart';
import '../services/automation_service.dart';
import 'sell_page.dart';

// ====== 滞销预警列表页 ======
class StagnantListPage extends StatefulWidget {
  const StagnantListPage({Key? key}) : super(key: key);
  @override
  State<StagnantListPage> createState() => _StagnantListPageState();
}

class _StagnantListPageState extends State<StagnantListPage> {
  void _refresh() => setState(() {});

  /// 降价
  Future<void> _cutPrice(Device d) async {
    final ctrl = TextEditingController(
      text: d.sellPrice > 0 ? (d.sellPrice / 100).toStringAsFixed(0) : '',
    );
    final price = await showAppFormDialog<int>(
      context: context,
      title: '滞销降价',
      subtitle: '${d.model} ${d.capacity} · 已在库${d.stockDays}天',
      maxHeightFactor: 0.52,
      child: Builder(
        builder:
            (sheetContext) => Column(
              children: [
                AppFormField(
                  controller: ctrl,
                  label: '新售价(元)',
                  icon: Icons.trending_down_rounded,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                ),
                const SizedBox(height: 18),
                AppSheetActions(
                  primaryLabel: '确定',
                  primaryColor: C.orange,
                  onPrimary: () {
                    final v = (double.tryParse(ctrl.text) ?? 0) * 100;
                    Navigator.pop(sheetContext, v.toInt());
                  },
                ),
              ],
            ),
      ),
    );
    ctrl.dispose();
    if (price != null && price > 0) {
      d.sellPrice = price;
      await gStorage.updateDevice(d);
      setState(() {});
      toast(context, '已降价为${yuan(price)}');
    }
  }

  Future<void> _applySuggestedPrice(Device d, int price) async {
    final ok = await confirmAction(
      context,
      title: '套用建议价格',
      message:
          '${d.model} ${d.capacity}\n'
          '${d.sellPrice > 0 ? '当前售价 ${yuan(d.sellPrice)}\n' : ''}'
          '建议调整为 ${yuan(price)}。',
      confirmText: '确认调整',
      confirmColor: C.orange,
    );
    if (!ok) return;
    d.sellPrice = price;
    if (d.status == 'in_stock') d.status = 'listed';
    await gStorage.updateDevice(d);
    if (!mounted) return;
    setState(() {});
    toast(context, '已更新为${yuan(price)}');
  }

  @override
  Widget build(BuildContext context) {
    final list = gStorage.getDevices().where((d) => d.isStagnant).toList();
    return appScaffold(
      context,
      '滞销预警（超15天）',
      ListView(
        padding: const EdgeInsets.all(14),
        children: [
          if (list.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 60),
              child: Column(
                children: [
                  const Text('✅', style: TextStyle(fontSize: 48)),
                  SizedBox(height: 12),
                  Text(
                    '暂无滞销设备，库存健康',
                    style: TextStyle(color: C.t2, fontSize: 13),
                  ),
                ],
              ),
            )
          else
            ...list.map((d) {
              final hasImg = d.imagePath != null && d.imagePath!.isNotEmpty;
              final firstImg = hasImg ? d.imagePath!.split(';').first : null;
              final suggested = AutomationService.recommendedStalePrice(
                d,
                gStorage,
              );
              return Container(
                margin: EdgeInsets.only(bottom: 10),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: C.bgCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: C.red.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: C.bgCardMuted,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child:
                              firstImg != null
                                  ? ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.file(
                                      File(firstImg),
                                      fit: BoxFit.cover,
                                      width: 56,
                                      height: 56,
                                    ),
                                  )
                                  : Center(
                                    child: Icon(
                                      Icons.tablet_mac_rounded,
                                      color: C.t2,
                                      size: 22,
                                    ),
                                  ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${d.model} ${d.capacity}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: C.t1,
                                ),
                              ),
                              Text(
                                '${d.color} · ${d.condition} · 电池${d.batteryHealth}%',
                                style: TextStyle(fontSize: 10, color: C.t2),
                              ),
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    yuan(d.sellPrice),
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: C.t3,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    '采购${yuan(d.purchaseCost)}',
                                    style: TextStyle(fontSize: 10, color: C.t2),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: C.red.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '库${d.stockDays}天',
                            style: TextStyle(
                              color: C.red,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (suggested > 0) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: C.orange.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: C.orange.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              color: C.orange,
                              size: 17,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '建议调到 ${yuan(suggested)}',
                                style: TextStyle(
                                  color: C.t2,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            smallBtn(
                              '套用',
                              () => _applySuggestedPrice(d, suggested),
                              color: C.orange,
                              icon: Icons.trending_down_rounded,
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed:
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SellPage(),
                                  ),
                                ).then((_) => _refresh()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: C.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              '售出',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _cutPrice(d),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: C.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              '降价',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              d.status = 'listed';
                              gStorage.updateDevice(d).then((_) {
                                _refresh();
                                toast(context, '已标记上架');
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: C.cyan,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              '上架',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
