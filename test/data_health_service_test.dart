import 'package:flutter_test/flutter_test.dart';
import 'package:ipad_boss_app/models.dart';
import 'package:ipad_boss_app/services/data_health_service.dart';

/// 数据体检的扫描口径。
void main() {
  Device device({
    required String id,
    int? repairCost,
    String status = 'sold',
    String model = 'iPad Pro 11 2021',
  }) => Device(
    id: id,
    serial: 'F$id',
    model: model,
    capacity: '64G',
    color: '星光色',
    network: 'WiFi',
    condition: '95新',
    purchaseCost: 200000,
    purchaseDate: '2026-06-01',
    sellPrice: 298000,
    status: status,
    repairCost: repairCost,
    sellDate: status == 'sold' ? '2026-06-20' : null,
    createdAt: '2026-06-01',
  );

  RepairOrder repair({required String deviceId, required int cost}) =>
      RepairOrder(
        id: 'r$deviceId',
        deviceId: deviceId,
        deviceName: 'iPad Pro 11 2021 64G',
        type: '换电池',
        cost: cost,
        status: '完成',
        createdAt: '2026-06-10',
      );

  DataHealthReport scan(List<Device> devices, List<RepairOrder> repairs) =>
      scanDataHealth(devices: devices, repairOrders: repairs);

  test('工单合计大于设备记录时报为少记', () {
    final report = scan(
      [device(id: 'd1', repairCost: 0)], // 被旧 bug 清零
      [repair(deviceId: 'd1', cost: 30000)],
    );

    expect(report.isClean, isFalse);
    expect(report.repairCostLosses, hasLength(1));
    expect(report.repairCostLosses.single.lost, 30000);
    expect(report.lostTotal, 30000);
  });

  test('多张工单会累加后比对', () {
    final report = scan(
      [device(id: 'd1', repairCost: 10000)],
      [
        repair(deviceId: 'd1', cost: 30000),
        repair(deviceId: 'd1', cost: 20000),
      ],
    );

    expect(report.repairCostLosses.single.repairOrdersTotal, 50000);
    expect(report.repairCostLosses.single.recorded, 10000);
    expect(report.repairCostLosses.single.lost, 40000);
  });

  test('设备记录大于工单合计不报 —— 那是手填的、没建工单的维修费', () {
    final report = scan(
      [device(id: 'd1', repairCost: 50000)],
      [repair(deviceId: 'd1', cost: 30000)],
    );

    expect(report.isClean, isTrue);
    expect(report.lostTotal, 0);
  });

  test('对得上的机器不报', () {
    final report = scan(
      [device(id: 'd1', repairCost: 30000)],
      [repair(deviceId: 'd1', cost: 30000)],
    );

    expect(report.isClean, isTrue);
  });

  test('没有维修工单的机器不报，哪怕它没有维修成本', () {
    final report = scan([device(id: 'd1')], const []);

    expect(report.isClean, isTrue);
  });

  test('工单挂在别的机器上不会串台', () {
    final report = scan(
      [device(id: 'd1', repairCost: 30000), device(id: 'd2')],
      [repair(deviceId: 'd1', cost: 30000)],
    );

    expect(report.isClean, isTrue);
  });

  test('按少记金额从大到小排序', () {
    final report = scan(
      [
        device(id: 'd1', repairCost: 0, model: '小额的'),
        device(id: 'd2', repairCost: 0, model: '大额的'),
      ],
      [
        repair(deviceId: 'd1', cost: 10000),
        repair(deviceId: 'd2', cost: 90000),
      ],
    );

    expect(
      report.repairCostLosses.map((l) => l.device.model).toList(),
      ['大额的', '小额的'],
    );
    expect(report.lostTotal, 100000);
  });

  test('未售出的机器同样纳入扫描', () {
    // 被 bug 清零后又重新上架的机器，status 已经回到 listed。
    final report = scan(
      [device(id: 'd1', repairCost: 0, status: 'listed')],
      [repair(deviceId: 'd1', cost: 30000)],
    );

    expect(report.repairCostLosses, hasLength(1));
  });
}
