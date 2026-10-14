import '../models.dart';

/// 一台机器的维修成本对不上。
class RepairCostLoss {
  final Device device;

  /// 这台机器全部维修工单的成本合计（分）。
  final int repairOrdersTotal;

  const RepairCostLoss({required this.device, required this.repairOrdersTotal});

  /// 设备上记录的维修成本（分）。
  int get recorded => device.repairCost ?? 0;

  /// 少记的金额（分）。恒为正 —— 只收「工单合计 > 设备记录」的方向。
  int get lost => repairOrdersTotal - recorded;
}

class DataHealthReport {
  final List<RepairCostLoss> repairCostLosses;

  const DataHealthReport({required this.repairCostLosses});

  static const empty = DataHealthReport(repairCostLosses: []);

  bool get isClean => repairCostLosses.isEmpty;

  /// 合计少记的金额（分）。
  int get lostTotal =>
      repairCostLosses.fold(0, (sum, loss) => sum + loss.lost);
}

/// 数据体检 —— 只读扫描，不修改任何数据。
///
/// 目前只查一项已知的旧 bug：售出页曾经把表单里**空白**的「维修成本」写回
/// 设备，于是"修过又卖过"的机器丢掉了已记录的维修成本，毛利随之虚高。
/// 真实成本还留在维修工单里，所以能反查出来。见 sell_page 的 _prefillRepairCost。
///
/// 只报「工单合计 > 设备记录」这一个方向：反过来（设备记录 > 工单合计）
/// 通常是用户在售出表单里手填了一笔没建工单的维修费 —— 那是正常输入，
/// 不是数据损坏，报出来只会制造噪音。
DataHealthReport scanDataHealth({
  required List<Device> devices,
  required List<RepairOrder> repairOrders,
}) {
  final totalsByDevice = <String, int>{};
  for (final order in repairOrders) {
    totalsByDevice[order.deviceId] =
        (totalsByDevice[order.deviceId] ?? 0) + order.cost;
  }

  final losses = <RepairCostLoss>[];
  for (final device in devices) {
    final total = totalsByDevice[device.id] ?? 0;
    if (total > (device.repairCost ?? 0)) {
      losses.add(
        RepairCostLoss(device: device, repairOrdersTotal: total),
      );
    }
  }

  // 少记最多的排前面 —— 先看影响最大的。
  losses.sort((a, b) => b.lost.compareTo(a.lost));
  return DataHealthReport(repairCostLosses: losses);
}
