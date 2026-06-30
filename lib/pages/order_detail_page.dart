import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../components/index.dart';
import '../utils/utils.dart';
import '../models.dart';
import '../main.dart';

class OrderDetailPage extends StatefulWidget {
  final Order order;
  const OrderDetailPage({Key? key, required this.order}) : super(key: key);
  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  late Order order;
  Device? device;

  @override
  void initState() {
    super.initState();
    order = widget.order;
    final ds =
        gStorage.getDevices().where((d) => d.id == order.deviceId).toList();
    device = ds.isNotEmpty ? ds.first : null;
  }

  /// 已发货 → 已完成
  Future<void> _markDone() async {
    order.status = 'done';
    await gStorage.updateOrder(order);
    setState(() {});
    toast(context, '✅ 已标记完成，净利${yuan(order.netProfit)}');
  }

  /// 已完成 → 重新上架（原订单作废，设备回 listed）
  Future<void> _relist() async {
    final ok = await confirmAction(
      context,
      title: '确认重新上架',
      message: '该订单利润${yuan(order.netProfit)}将从历史统计中扣除，设备回到上架待售状态。确定？',
      confirmText: '重新上架',
      confirmColor: C.orange,
    );
    if (!ok) return;
    order.status = 'cancelled';
    await gStorage.updateOrder(order);
    if (device != null) {
      device!.status = 'listed';
      device!.sellDate = null;
      device!.sellChannel = null;
      device!.platformFee = null;
      device!.logisticsCost = null;
      device!.afterSaleCost = null;
      device!.buyerContact = null;
      await gStorage.updateDevice(device!);
    }
    setState(() {});
    toast(context, '已重新上架，原订单利润已扣除');
  }

  /// 售后费用录入
  Future<void> _inputAfterSale() async {
    final ctrl = TextEditingController(
      text:
          order.afterSaleCost != null
              ? (order.afterSaleCost! / 100).toStringAsFixed(0)
              : '',
    );
    String? selectedReason = order.afterSaleReason;
    final reasons = ['质量问题', '买家反悔', '描述不符', '物流损坏', '其他'];
    final result = await showAppFormDialog<Map<String, dynamic>>(
      context: context,
      title: '售后录入',
      subtitle: '费用会从当前订单净利和利润统计中扣除',
      maxHeightFactor: 0.66,
      child: StatefulBuilder(
        builder:
            (sheetContext, setS) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '售后原因',
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
                      reasons
                          .map(
                            (r) => AppChoicePill(
                              label: r,
                              selected: selectedReason == r,
                              onTap: () => setS(() => selectedReason = r),
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 14),
                AppFormField(
                  controller: ctrl,
                  label: '售后费用(元)',
                  icon: Icons.receipt_long_outlined,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                ),
                const SizedBox(height: 18),
                AppSheetActions(
                  primaryLabel: '保存',
                  onPrimary: () {
                    final v = (double.tryParse(ctrl.text) ?? 0) * 100;
                    Navigator.pop(sheetContext, {
                      'cost': v.toInt(),
                      'reason': selectedReason,
                    });
                  },
                ),
              ],
            ),
      ),
    );
    ctrl.dispose();
    if (result == null) return;
    final cost = result['cost'] as int;
    if (cost < 0) {
      toast(context, '售后费用不能为负数');
      return;
    }
    final reason = result['reason'] as String?;
    order.afterSaleCost = cost > 0 ? cost : null;
    order.afterSaleReason = cost > 0 ? reason : null;
    if (cost > 0) {
      order.status = 'aftersale';
    } else if (order.status == 'aftersale') {
      order.status = 'done';
    }
    await gStorage.updateOrder(order);
    if (device != null) {
      device!.afterSaleCost = cost > 0 ? cost : null;
      await gStorage.updateDevice(device!);
    }
    setState(() {});
    toast(
      context,
      '售后已记录${cost > 0 ? "，净利调整为${yuan(order.netProfit)}" : ""}${reason != null ? "（$reason）" : ""}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final sc = _sc(order.status);
    final stText =
        {
          'shipped': '已发货',
          'done': '已完成',
          'aftersale': '售后',
          'cancelled': '已作废',
        }[order.status] ??
        order.status;
    return appScaffold(
      context,
      '订单详情',
      ListView(
        padding: const EdgeInsets.all(14),
        children: [
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(order.id, style: TextStyle(fontSize: 12, color: C.t2)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: sc.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        stText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: sc,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _row('设备', order.deviceName),
                _row('买家', order.buyer.isEmpty ? '未知' : order.buyer),
                _row('渠道', order.channel),
                _row('成交金额', yuan(order.amount)),
                _row('毛利', yuan(order.profit)),
                if (order.afterSaleCost != null &&
                    order.afterSaleCost! > 0) ...[
                  _row('售后费用', yuan(order.afterSaleCost!), vc: C.red),
                  if (order.afterSaleReason != null)
                    _row('售后原因', order.afterSaleReason!, vc: C.orange),
                ],
                _row('净利', yuan(order.netProfit), vc: C.green, bold: true),
                _row('下单时间', order.createdAt),
              ],
            ),
          ),
          if (device != null)
            CardBox(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '关联设备',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: C.t1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _row(
                    '型号',
                    '${device!.model} ${device!.capacity} ${device!.color}',
                  ),
                  _row('序列号', device!.serial),
                  _row(
                    '成色',
                    '${device!.condition} · 电池${device!.batteryHealth}%',
                  ),
                  _row(
                    '采购',
                    '${yuan(device!.purchaseCost)} · ${device!.purchaseChannel}',
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          // 按状态显示操作按钮
          if (order.status == 'shipped') primaryBtn('✅ 设为已完成', _markDone),
          if (order.status == 'shipped')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ghostBtn('转售后（录入售后费用）', _inputAfterSale),
            ),
          if (order.status == 'done') primaryBtn('重新上架', _relist),
          if (order.status == 'done')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ghostBtn('转售后（录入售后费用）', _inputAfterSale),
            ),
          if (order.status == 'aftersale')
            primaryBtn('✏️ 修改售后费用', _inputAfterSale),
          if (order.status == 'cancelled')
            CardBox(
              child: Center(
                child: Text(
                  '该订单已作废（重新上架），利润已从历史统计扣除',
                  style: TextStyle(fontSize: 12, color: C.t3),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(String k, String v, {Color? vc, bool bold = false}) => Padding(
    padding: EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(k, style: TextStyle(fontSize: 12, color: C.t2)),
        ),
        Expanded(
          child: Text(
            v,
            style: TextStyle(
              fontSize: 13,
              color: vc ?? C.t1,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
  Color _sc(String s) =>
      s == 'shipped'
          ? C.cyan
          : (s == 'done' ? C.green : (s == 'aftersale' ? C.red : C.t3));
}
