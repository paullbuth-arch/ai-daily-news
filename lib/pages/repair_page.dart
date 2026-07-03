import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../components/index.dart';
import '../utils/utils.dart';
import '../models.dart';
import '../main.dart';

String _fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class RepairPage extends StatefulWidget {
  const RepairPage({Key? key}) : super(key: key);
  @override
  State<RepairPage> createState() => _RepairPageState();
}

class _RepairPageState extends State<RepairPage> {
  void _refresh() => setState(() {});

  Future<void> _addRepair() async {
    final devices =
        gStorage
            .getDevices()
            .where((d) => d.status == 'in_stock' || d.status == 'listed')
            .toList();
    if (devices.isEmpty) {
      toast(context, '暂无可维修设备');
      return;
    }
    Device? sel;
    String type = '换电池';
    final costCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final ok = await showAppFormDialog<bool>(
      context: context,
      title: '新增维修工单',
      subtitle: '记录翻新成本，自动回写到设备利润',
      maxHeightFactor: 0.84,
      child: StatefulBuilder(
        builder:
            (sheetContext, setS) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '选择设备',
                  style: TextStyle(
                    color: C.t2,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                ...devices.map(
                  (d) => AppSelectionTile(
                    title: '${d.model} ${d.capacity}',
                    subtitle:
                        '${d.condition} · ${d.color} · 采购${yuan(d.purchaseCost)}',
                    icon: Icons.tablet_mac_rounded,
                    selected: sel?.id == d.id,
                    onTap: () => setS(() => sel = d),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '维修类型',
                  style: TextStyle(
                    color: C.t2,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      ['换电池', '换屏', '换壳', '其他']
                          .map(
                            (t) => AppChoicePill(
                              label: t,
                              selected: type == t,
                              onTap: () => setS(() => type = t),
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 12),
                AppFormField(
                  controller: costCtrl,
                  label: '维修成本(元)',
                  icon: Icons.payments_outlined,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                AppFormField(
                  controller: noteCtrl,
                  label: '备注',
                  icon: Icons.notes_rounded,
                  maxLines: 2,
                ),
                const SizedBox(height: 18),
                AppSheetActions(
                  primaryLabel: '提交',
                  onPrimary: () {
                    if (sel == null) {
                      toast(context, '请选择设备');
                      return;
                    }
                    Navigator.pop(sheetContext, true);
                  },
                ),
              ],
            ),
      ),
    );
    if (ok == true && sel != null) {
      final now = DateTime.now();
      final cost = (double.tryParse(costCtrl.text) ?? 0) * 100;
      await gStorage.addRepairOrder(
        RepairOrder(
          id: 'r${now.millisecondsSinceEpoch}',
          deviceId: sel!.id,
          deviceName: '${sel!.model} ${sel!.capacity}',
          type: type,
          cost: cost.toInt(),
          status: '完成',
          note: noteCtrl.text,
          createdAt: _fmt(now),
        ),
      );
      sel!.repairCost = (sel!.repairCost ?? 0) + cost.toInt();
      await gStorage.updateDevice(sel!);
      _refresh();
      toast(context, '维修工单已创建');
    }
    costCtrl.dispose();
    noteCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repairs = gStorage.getRepairOrders();
    return appScaffold(
      context,
      '翻新维修 · 配件库存',
      ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: primaryBtn('新增维修工单', _addRepair),
          ),
          if (repairs.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 40),
              child: Column(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: C.bgCardMuted,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: C.border),
                    ),
                    child: Icon(
                      Icons.build_circle_outlined,
                      color: C.t3,
                      size: 26,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text('暂无维修工单', style: TextStyle(color: C.t2, fontSize: 13)),
                ],
              ),
            )
          else
            ...repairs.map(
              (r) => CardBox(
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: C.t3.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(_typeIcon(r.type), color: C.t3, size: 20),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${r.deviceName} · ${r.type}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: C.t1,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '成本${yuan(r.cost)} · ${r.status} · ${r.createdAt}',
                            style: TextStyle(fontSize: 10, color: C.t2),
                          ),
                          if (r.note.isNotEmpty)
                            Text(
                              '备注：${r.note}',
                              style: TextStyle(fontSize: 10, color: C.t3),
                            ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        final ok = await confirmAction(
                          context,
                          title: '删除维修工单',
                          message: '确定删除「${r.deviceName} · ${r.type}」这条维修记录吗？',
                          confirmText: '删除',
                        );
                        if (!ok) return;
                        await gStorage.deleteRepairOrder(r.id);
                        _refresh();
                        toast(context, '已删除');
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          color: C.red,
                          size: 18,
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

  IconData _typeIcon(String t) =>
      t == '换电池'
          ? Icons.battery_charging_full_outlined
          : (t == '换屏'
              ? Icons.screenshot_monitor_outlined
              : (t == '换壳'
                  ? Icons.inventory_2_outlined
                  : Icons.build_outlined));
}
