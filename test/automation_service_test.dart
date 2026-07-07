import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ipad_boss_app/models.dart';
import 'package:ipad_boss_app/services/automation_service.dart';
import 'package:ipad_boss_app/storage.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('boss_auto_');
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  Future<Storage> storage(String name) async {
    final st = Storage('${tmp.path}/$name.json');
    await st.load();
    return st;
  }

  Device device({
    required String id,
    String model = 'iPad Air 5',
    String status = 'listed',
    int purchaseCost = 220000,
    int sellPrice = 298000,
    String? purchaseDate,
    String? description = '成色不错，功能正常。',
    String? imagePath = '/tmp/ipad.jpg',
    String serial = 'FTEST001',
  }) {
    final today = DateTime.now();
    return Device(
      id: id,
      serial: serial,
      model: model,
      capacity: '64G',
      color: '星光色',
      network: 'WiFi',
      condition: '95新',
      batteryHealth: 92,
      cycleCount: 120,
      purchaseCost: purchaseCost,
      purchaseDate: purchaseDate ?? _date(today),
      sellPrice: sellPrice,
      status: status,
      description: description,
      imagePath: imagePath,
      createdAt: _date(today),
    );
  }

  test('滞销库存生成可执行调价任务', () async {
    final st = await storage('stale');
    final old = DateTime.now().subtract(const Duration(days: 35));
    await st.addDevice(
      device(id: 'd1', purchaseDate: _date(old), sellPrice: 300000),
    );

    final plan = AutomationService.buildPlan(st);
    final task = plan.tasks.firstWhere(
      (t) => t.kind == AutomationTaskKind.staleStock,
    );

    expect(task.impact, AutomationImpact.critical);
    expect(task.actionKind, AutomationActionKind.applyPriceCut);
    expect(task.suggestedPriceFen, lessThan(300000));
  });

  test('上架资料缺口生成文案或处理任务', () async {
    final st = await storage('pipeline');
    await st.addDevice(
      device(id: 'd1', sellPrice: 0, description: '', imagePath: ''),
    );

    final plan = AutomationService.buildPlan(st);
    final task = plan.tasks.firstWhere(
      (t) => t.kind == AutomationTaskKind.listingPipeline,
    );

    expect(task.impact, AutomationImpact.critical);
    expect(task.metric, '3项');
    expect(task.actionKind, AutomationActionKind.generateCopy);
  });

  test('今日行情未更新时生成行情任务', () async {
    final st = await storage('market');
    await st.addDevice(device(id: 'd1'));

    final plan = AutomationService.buildPlan(st);

    expect(
      plan.tasks.any((t) => t.kind == AutomationTaskKind.marketPrice),
      true,
    );
  });

  test('待发货订单生成订单风险任务且忽略作废订单', () async {
    final st = await storage('orders');
    await st.addOrder(
      Order(
        id: 'o1',
        deviceId: 'd1',
        deviceName: 'iPad Air 5 64G',
        buyer: '张三',
        channel: '闲鱼',
        amount: 298000,
        profit: 50000,
        status: 'pending',
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
    await st.addOrder(
      Order(
        id: 'o2',
        deviceId: 'd2',
        deviceName: 'iPad Pro',
        buyer: '李四',
        channel: '闲鱼',
        amount: 500000,
        profit: 80000,
        status: 'cancelled',
        createdAt: DateTime.now().toIso8601String(),
      ),
    );

    final plan = AutomationService.buildPlan(st);
    final task = plan.tasks.firstWhere(
      (t) => t.kind == AutomationTaskKind.orderRisk,
    );

    expect(task.orderId, 'o1');
    expect(task.metric, '1单');
  });

  test('标记完成后今日待办会隐藏并可恢复', () async {
    final st = await storage('completed');
    await st.addDevice(device(id: 'd1'));
    final now = DateTime.now();
    final first = AutomationService.buildPlan(st, now: now).tasks.first;

    await AutomationService.markCompleted(st, first.id, now: now);
    final hidden = AutomationService.buildPlan(st, now: now);

    expect(hidden.completedCount, 1);
    expect(hidden.openTasks.any((t) => t.id == first.id), false);

    await AutomationService.clearCompletedToday(st, now: now);
    final restored = AutomationService.buildPlan(st, now: now);

    expect(restored.completedCount, 0);
    expect(restored.openTasks.any((t) => t.id == first.id), true);
  });
}

String _date(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
