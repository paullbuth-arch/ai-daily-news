import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipad_boss_app/main.dart';
import 'package:ipad_boss_app/models.dart';
import 'package:ipad_boss_app/pages/sell_page.dart';
import 'package:ipad_boss_app/storage.dart';
import 'package:ipad_boss_app/theme/colors.dart';

/// 售出流程的回归测试。
///
/// 守的是一个真实发生过的数据损坏：维修页用 `+=` **累加**
/// device.repairCost，而售出页拿表单的值 `=` **覆盖**同一个字段，表单初值
/// 又是空的 —— 于是卖出后已记录的维修成本被清零，毛利同时虚高。
/// 见 sell_page.dart 的 _prefillRepairCost。
///
/// 断言停在界面上而不是走完 `_confirm`：`_confirm` 里串了两段真实写盘，
/// 而 `testWidgets` 的 FakeAsync 时区只能可靠地推进第一段，硬驱动会假失败。
/// 好在不变量不需要走到底 —— `_confirm` 就是拿表单的值写回 device.repairCost，
/// 所以「表单被正确预填」+「毛利把维修算进去了」足以守住它。
///
/// 另一个坑：FakeAsync 里直接 await 真实文件 I/O 会**永远挂住**，凡是要读写
/// Storage 的地方都必须包进 `tester.runAsync`。
void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('sell_page_');
  });

  tearDown(() async {
    // Storage 可能还攥着文件句柄，删不掉不算测试失败。
    try {
      if (tmp.existsSync()) await tmp.delete(recursive: true);
    } on FileSystemException {
      // 临时目录，交给系统清理
    }
  });

  Device device({
    String id = 'd1',
    String model = 'iPad Pro 11 2021',
    int purchaseCost = 200000,
    int? repairCost,
    String status = 'listed',
  }) => Device(
    id: id,
    serial: 'FTEST001',
    model: model,
    capacity: '64G',
    color: '星光色',
    network: 'WiFi',
    condition: '95新',
    purchaseCost: purchaseCost,
    purchaseDate: '2026-07-01',
    sellPrice: 298000,
    status: status,
    repairCost: repairCost,
    createdAt: '2026-07-01',
  );

  /// 页面较高，给它一块够大的画布，避免目标控件落在视口外。
  void useLargeSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> bootStorage(WidgetTester tester, Device d) =>
      tester.runAsync(() async {
        C.useLightTheme(true);
        gStorage = Storage('${tmp.path}/data.json');
        await gStorage.load();
        await gStorage.addDevice(d);
      });

  Finder fieldFinder(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(TextField));

  TextField fieldWithLabel(WidgetTester tester, String label) =>
      tester.widget<TextField>(fieldFinder(label));

  /// 展开型号系列分组，再选中具体设备。
  Future<void> pickDevice(WidgetTester tester, Device d) async {
    await tester.tap(find.text('iPad Pro 11 2021'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('${d.model} ${d.capacity} ${d.color}'));
    await tester.pumpAndSettle();
  }

  testWidgets('已记录的维修成本会被预填，并计入毛利', (tester) async {
    useLargeSurface(tester);
    final d = device(repairCost: 30000); // 维修页累加出来的 ¥300
    await bootStorage(tester, d);

    await tester.pumpWidget(const MaterialApp(home: SellPage()));
    await tester.pumpAndSettle();
    await pickDevice(tester, d);

    expect(
      fieldWithLabel(tester, '维修成本').controller!.text,
      '300',
      reason: '选中设备后应把已记录的维修成本预填进表单',
    );

    await tester.enterText(fieldFinder('售价(元)'), '3000');
    await tester.pumpAndSettle();

    // 3000 售价 − 2000 采购 − 300 维修 − 48 闲鱼手续费(1.6%) − 15 物流 = 637 元。
    // 维修成本一旦丢失，这里会变成 ¥937。
    expect(
      find.text('预计毛利：¥637'),
      findsOneWidget,
      reason: '毛利必须扣掉维修成本',
    );
  });

  testWidgets('设备没有维修记录时表单保持为空', (tester) async {
    useLargeSurface(tester);
    final d = device();
    await bootStorage(tester, d);

    await tester.pumpWidget(const MaterialApp(home: SellPage()));
    await tester.pumpAndSettle();
    await pickDevice(tester, d);

    expect(fieldWithLabel(tester, '维修成本').controller!.text, '');
  });
}
