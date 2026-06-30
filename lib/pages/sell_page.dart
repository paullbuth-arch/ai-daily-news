import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../components/index.dart';
import '../utils/utils.dart';
import '../models.dart';
import '../main.dart';

// ====== 售出页 ======
class SellPage extends StatefulWidget {
  const SellPage({Key? key}) : super(key: key);
  @override
  State<SellPage> createState() => _SellPageState();
}

class _SellPageState extends State<SellPage> {
  Device? selected;
  final _priceCtrl = TextEditingController();
  final _buyerCtrl = TextEditingController();
  final _repairCtrl = TextEditingController();
  final _feeCtrl = TextEditingController();
  final _logisticsCtrl = TextEditingController(text: '15');
  String channel = '闲鱼';
  int? computedProfit;

  List<Device> get sellable =>
      gStorage
          .getDevices()
          .where((d) => d.status == 'in_stock' || d.status == 'listed')
          .toList();

  void _computeProfit() {
    final price = (double.tryParse(_priceCtrl.text) ?? 0) * 100;
    final repair = (double.tryParse(_repairCtrl.text) ?? 0) * 100;
    final fee = (double.tryParse(_feeCtrl.text) ?? 0) * 100;
    final logi = (double.tryParse(_logisticsCtrl.text) ?? 0) * 100;
    if (selected != null) {
      setState(() {
        computedProfit =
            price.toInt() -
            selected!.purchaseCost -
            repair.toInt() -
            fee.toInt() -
            logi.toInt();
      });
    }
  }

  Future<void> _confirm() async {
    if (selected == null) {
      toast(context, '请选择设备');
      return;
    }
    final priceValue = double.tryParse(_priceCtrl.text);
    if (priceValue == null || priceValue <= 0) {
      toast(context, '请输入售价');
      return;
    }
    final repairValue = double.tryParse(_repairCtrl.text) ?? 0;
    final feeValue = double.tryParse(_feeCtrl.text) ?? 0;
    final logisticsValue = double.tryParse(_logisticsCtrl.text) ?? 0;
    if (repairValue < 0 || feeValue < 0 || logisticsValue < 0) {
      toast(context, '成本费用不能为负数');
      return;
    }
    final now = DateTime.now();
    final price = (priceValue * 100).round();
    final repair = (repairValue * 100).round();
    final fee = (feeValue * 100).round();
    final logi = (logisticsValue * 100).round();
    final profit = price - selected!.purchaseCost - repair - fee - logi;
    if (profit < 0) {
      final ok = await confirmAction(
        context,
        title: '确认亏损出售',
        message: '这单预计亏损 ${yuan(profit.abs())}。确认继续记录出售吗？',
        confirmText: '继续出售',
        confirmColor: C.red,
      );
      if (!ok) return;
    }
    final d = selected!;
    d.status = 'sold';
    d.sellPrice = price;
    d.sellChannel = channel;
    d.sellDate = fmtDate(now);
    d.repairCost = repair;
    d.platformFee = fee;
    d.logisticsCost = logi;
    d.buyerContact = _buyerCtrl.text.trim();
    await gStorage.updateDevice(d);
    await gStorage.addOrder(
      Order(
        id: 'o${now.millisecondsSinceEpoch}',
        deviceId: d.id,
        deviceName: '${d.model} ${d.capacity}',
        buyer: _buyerCtrl.text.trim().isEmpty ? '未知' : _buyerCtrl.text.trim(),
        channel: channel,
        amount: price,
        profit: profit,
        status: 'shipped',
        createdAt:
            fmtDate(now) +
            ' ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      ),
    );
    toast(context, '✅ 已售出，毛利${yuan(profit)}');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => appScaffold(
    context,
    '售出设备',
    ListView(
      padding: const EdgeInsets.all(16),
      children: [
        CardBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('选择设备', style: TextStyle(fontSize: 12, color: C.t2)),
              const SizedBox(height: 8),
              ...sellable.map(
                (d) => GestureDetector(
                  onTap:
                      () => setState(() {
                        selected = d;
                        _computeProfit();
                      }),
                  child: Container(
                    margin: EdgeInsets.only(bottom: 8),
                    padding: EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color:
                          selected?.id == d.id
                              ? C.cyan.withOpacity(0.15)
                              : C.bgDeep,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected?.id == d.id ? C.cyan : C.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.tablet_mac_rounded, color: C.t2, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${d.model} ${d.capacity} ${d.color}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: C.t1,
                                ),
                              ),
                              Text(
                                '采购${yuan(d.purchaseCost)} · 库${d.stockDays}天',
                                style: TextStyle(fontSize: 10, color: C.t2),
                              ),
                            ],
                          ),
                        ),
                        if (selected?.id == d.id)
                          Text(
                            '✓',
                            style: TextStyle(color: C.t3, fontSize: 16),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (selected != null)
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _priceCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _computeProfit(),
                  style: TextStyle(color: C.t1, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: '售价(元)',
                    labelStyle: TextStyle(color: C.t2),
                    filled: true,
                    fillColor: C.bgDeep,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: C.border),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _repairCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _computeProfit(),
                        style: TextStyle(color: C.t1, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: '维修成本',
                          labelStyle: TextStyle(color: C.t2),
                          filled: true,
                          fillColor: C.bgDeep,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: C.border),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _feeCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _computeProfit(),
                        style: TextStyle(color: C.t1, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: '平台佣金',
                          labelStyle: TextStyle(color: C.t2),
                          filled: true,
                          fillColor: C.bgDeep,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: C.border),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _logisticsCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _computeProfit(),
                        style: TextStyle(color: C.t1, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: '物流',
                          labelStyle: TextStyle(color: C.t2),
                          filled: true,
                          fillColor: C.bgDeep,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: C.border),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _buyerCtrl,
                  style: TextStyle(color: C.t1, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: '买家',
                    labelStyle: TextStyle(color: C.t2),
                    filled: true,
                    fillColor: C.bgDeep,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: C.border),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text('渠道：', style: TextStyle(fontSize: 12, color: C.t2)),
                    const SizedBox(width: 8),
                    ...['闲鱼', '抖音', '转转', '私域', '同行'].map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(c, style: const TextStyle(fontSize: 11)),
                          selected: channel == c,
                          selectedColor: C.cyan,
                          onSelected: (_) => setState(() => channel = c),
                        ),
                      ),
                    ),
                  ],
                ),
                if (computedProfit != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (computedProfit! >= 0 ? C.green : C.red)
                            .withOpacity(0.12),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Row(
                        children: [
                          Text(
                            computedProfit! >= 0 ? '💰' : '📉',
                            style: const TextStyle(fontSize: 20),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '预计毛利：${yuan(computedProfit!)}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: computedProfit! >= 0 ? C.green : C.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                primaryBtn('✅ 确认售出', _confirm),
              ],
            ),
          ),
      ],
    ),
  );
}
