// 业务逻辑单元测试
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipad_boss_app/models.dart';
import 'package:ipad_boss_app/storage.dart';
import 'package:ipad_boss_app/serial_decoder.dart';

void main() {
  group('Device 利润计算', () {
    test('未售设备净利为0', () {
      final d = Device(
        id: '1', serial: 'F9XNL3C0JCD6', model: 'iPad Air 5', capacity: '64G',
        color: '星光色', network: 'WiFi', condition: '95新', purchaseCost: 235000,
        purchaseDate: '2026-06-21', createdAt: '2026-06-21', status: 'in_stock',
      );
      expect(d.netProfit, 0);
    });

    test('已售设备净利正确计算（含各项成本）', () {
      final d = Device(
        id: '2', serial: 'F2XNL3C0JCD6', model: 'iPad Pro 11', capacity: '128G',
        color: '银色', network: 'WiFi', condition: '99新', purchaseCost: 470000,
        purchaseDate: '2026-06-01', createdAt: '2026-06-01',
        status: 'sold', sellPrice: 568000, repairCost: 8000, platformFee: 2000,
        logisticsCost: 3000, afterSaleCost: 0,
      );
      // 净利 = 5680 - (4700+80+20+30+0) = 850元 = 85000分
      expect(d.netProfit, 85000);
    });

    test('净利为负时正确返回负值', () {
      final d = Device(
        id: '3', serial: 'F3XNL3C0JCD6', model: 'iPad 9', capacity: '64G',
        color: '深空灰', network: 'WiFi', condition: '8成新', purchaseCost: 200000,
        purchaseDate: '2026-06-01', createdAt: '2026-06-01',
        status: 'sold', sellPrice: 180000, repairCost: 10000,
      );
      // 净利 = 1800 - (2000+100) = -300元
      expect(d.netProfit, -30000);
    });
  });

  group('Device 库存状态', () {
    test('在库超过30天判定为滞销', () {
      final old = DateTime.now().subtract(const Duration(days: 40));
      final d = Device(
        id: '1', serial: 'F1', model: 'iPad Air 5', capacity: '64G',
        color: '银色', network: 'WiFi', condition: '95新', purchaseCost: 235000,
        purchaseDate: '${old.year}-${old.month.toString().padLeft(2, '0')}-${old.day.toString().padLeft(2, '0')}',
        createdAt: '', status: 'in_stock',
      );
      expect(d.isStagnant, true);
    });

    test('在库20天判定为滞销（15天阈值）', () {
      final recent = DateTime.now().subtract(const Duration(days: 20));
      final d = Device(
        id: '2', serial: 'F2', model: 'iPad Air 5', capacity: '64G',
        color: '银色', network: 'WiFi', condition: '95新', purchaseCost: 235000,
        purchaseDate: '${recent.year}-${recent.month.toString().padLeft(2, '0')}-${recent.day.toString().padLeft(2, '0')}',
        createdAt: '', status: 'listed',
      );
      expect(d.isStagnant, true);
    });

    test('已售设备不判定为滞销', () {
      final old = DateTime.now().subtract(const Duration(days: 50));
      final d = Device(
        id: '3', serial: 'F3', model: 'iPad Air 5', capacity: '64G',
        color: '银色', network: 'WiFi', condition: '95新', purchaseCost: 235000,
        purchaseDate: '${old.year}-${old.month.toString().padLeft(2, '0')}-${old.day.toString().padLeft(2, '0')}',
        createdAt: '', status: 'sold', sellPrice: 290000,
      );
      expect(d.isStagnant, false);
    });
  });

  group('Device JSON序列化', () {
    test('toJson/fromJson 往返一致', () {
      final d = Device(
        id: '1', serial: 'F9XNL3C0JCD6', model: 'iPad Pro 11 2022', capacity: '128G',
        color: '银色', network: 'WiFi+蜂窝', condition: '99新', batteryHealth: 95,
        cycleCount: 50, idLockClean: true, accessories: '原装盒+充电器',
        purchaseCost: 470000, purchaseChannel: '华强北', purchaseDate: '2026-06-01',
        sellPrice: 568000, status: 'sold', sellChannel: '闲鱼', sellDate: '2026-06-15',
        repairCost: 8000, platformFee: 2000, logisticsCost: 3000,
        createdAt: '2026-06-01',
      );
      final j = d.toJson();
      final d2 = Device.fromJson(j);
      expect(d2.id, d.id);
      expect(d2.serial, d.serial);
      expect(d2.model, d.model);
      expect(d2.purchaseCost, d.purchaseCost);
      expect(d2.sellPrice, d.sellPrice);
      expect(d2.netProfit, d.netProfit);
    });
  });

  group('序列号解码', () {
    test('短序列号返回无效', () {
      final r = SerialDecoder.decode('ABC');
      expect(r.valid, false);
    });

    test('合法序列号能解码出型号产地', () {
      final r = SerialDecoder.decode('F9XNL3C0JCD6');
      expect(r.valid, true);
      expect(r.origin, contains('中国'));
      expect(r.productionDate, isNotEmpty);
    });

    test('F开头识别为郑州产地', () {
      final r = SerialDecoder.decode('F9XNL3C0JCD6');
      expect(r.origin, contains('郑州'));
    });
  });

  group('ID锁安全检测', () {
    test('全部无锁判定为安全', () {
      final r = IdLockChecker.check(
        iCloudLocked: false, activationLocked: false, mdmSupervised: false, configLock: false,
      );
      expect(r['clean'], true);
      expect(r['risk'], '安全');
    });

    test('iCloud锁判定为高风险', () {
      final r = IdLockChecker.check(
        iCloudLocked: true, activationLocked: false, mdmSupervised: false, configLock: false,
      );
      expect(r['clean'], false);
      expect(r['risk'], '高风险');
      expect((r['issues'] as List).length, 1);
    });

    test('MDM监管机判定为高风险', () {
      final r = IdLockChecker.check(
        iCloudLocked: false, activationLocked: false, mdmSupervised: true, configLock: false,
      );
      expect(r['clean'], false);
      expect((r['issues'] as List).any((e) => e.toString().contains('MDM')), true);
    });
  });

  group('Device imagePath字段', () {
    test('imagePath正确序列化', () {
      final d = Device(
        id: '1', serial: 'F1', model: 'iPad Air 5', capacity: '64G',
        color: '银色', network: 'WiFi', condition: '95新', purchaseCost: 235000,
        purchaseDate: '2026-06-21', createdAt: '2026-06-21',
        imagePath: '/data/user/0/app/files/img1.jpg',
      );
      final j = d.toJson();
      expect(j['imagePath'], '/data/user/0/app/files/img1.jpg');
      final d2 = Device.fromJson(j);
      expect(d2.imagePath, d.imagePath);
    });

    test('无imagePath时fromJson返回null', () {
      final j = {'id': '1', 'serial': 'F1', 'model': 'iPad', 'capacity': '64G', 'color': '银', 'network': 'WiFi', 'condition': '95新', 'purchaseCost': 100000, 'purchaseDate': '2026-06-21', 'createdAt': '2026-06-21'};
      final d = Device.fromJson(j);
      expect(d.imagePath, isNull);
    });
  });

  group('Agent模型', () {
    test('Agent toJson/fromJson 往返一致', () {
      final a = Agent(id: 'a1', name: '小陈', phone: '138', commissionRate: 0.08, totalGmv: 168000, createdAt: '2026-06-21');
      final j = a.toJson();
      final a2 = Agent.fromJson(j);
      expect(a2.id, a.id);
      expect(a2.name, a.name);
      expect(a2.phone, a.phone);
      expect(a2.commissionRate, a.commissionRate);
      expect(a2.totalGmv, a.totalGmv);
    });

    test('Agent默认佣金比例0.1', () {
      final a = Agent(id: 'a1', name: 'test', createdAt: '2026-06-21');
      expect(a.commissionRate, 0.1);
      expect(a.totalGmv, 0);
    });
  });

  group('RepairOrder模型', () {
    test('RepairOrder toJson/fromJson 往返一致', () {
      final r = RepairOrder(id: 'r1', deviceId: 'd1', deviceName: 'iPad Air 5', type: '换电池', cost: 8000, status: '完成', note: '原装电池', createdAt: '2026-06-21');
      final j = r.toJson();
      final r2 = RepairOrder.fromJson(j);
      expect(r2.id, r.id);
      expect(r2.deviceId, r.deviceId);
      expect(r2.type, r.type);
      expect(r2.cost, r.cost);
      expect(r2.status, r.status);
      expect(r2.note, r.note);
    });

    test('RepairOrder默认状态待修', () {
      final r = RepairOrder(id: 'r1', deviceId: 'd1', deviceName: 'iPad', type: '换屏', cost: 5000, createdAt: '2026-06-21');
      expect(r.status, '待修');
      expect(r.note, '');
    });
  });

  group('Stats扩展字段', () {
    test('Stats默认值正确', () {
      final s = Stats();
      expect(s.pendingCount, 0);
      expect(s.shippedCount, 0);
      expect(s.pendingQcCount, 0);
      expect(s.channelGmv, isEmpty);
    });
  });

  group('DailyStat', () {
    test('DailyStat默认值为0', () {
      final d = DailyStat(date: '2026-06-21');
      expect(d.gmv, 0);
      expect(d.profit, 0);
    });
  });

  group('自动定价 calcAutoPrice', () {
    test('小于1000元加168', () {
      expect(calcAutoPrice(99900), (999 + 168) * 100);
    });
    test('1000-2000元加238', () {
      expect(calcAutoPrice(100000), (1000 + 238) * 100);
      expect(calcAutoPrice(199900), (1999 + 238) * 100);
    });
    test('2000-3000元加298', () {
      expect(calcAutoPrice(200000), (2000 + 298) * 100);
    });
    test('4000-5000元加498', () {
      expect(calcAutoPrice(450000), (4500 + 498) * 100);
    });
    test('7000-9000元加798', () {
      expect(calcAutoPrice(800000), (8000 + 798) * 100);
    });
    test('大于9000元加12%', () {
      expect(calcAutoPrice(1000000), (10000 * 1.12 * 100).round());
    });
    test('边界值8999属于7000-9000档加798', () {
      expect(calcAutoPrice(899900), (8999 + 798) * 100);
    });
    test('9000元走12%加价', () {
      expect(calcAutoPrice(900000), (9000 * 1.12 * 100).round());
    });
  });

  group('滞销判定15天', () {
    test('在库14天不滞销', () {
      final d = DateTime.now().subtract(const Duration(days: 14));
      final dev = Device(id: '1', serial: 'F1', model: 'iPad Air 5', capacity: '64G', color: '银', network: 'WiFi', condition: '95新', purchaseCost: 100000, purchaseDate: '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}', createdAt: '', status: 'listed');
      expect(dev.isStagnant, false);
    });
    test('在库17天判定滞销', () {
      final d = DateTime.now().subtract(const Duration(days: 17));
      final dev = Device(id: '1', serial: 'F1', model: 'iPad Air 5', capacity: '64G', color: '银', network: 'WiFi', condition: '95新', purchaseCost: 100000, purchaseDate: '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}', createdAt: '', status: 'listed');
      expect(dev.isStagnant, true);
    });
  });

  group('Order netProfit 售后扣除', () {
    test('无售后费用时净利等于毛利', () {
      final o = Order(id: 'o1', deviceId: 'd1', deviceName: 'iPad', buyer: 'x', channel: '闲鱼', amount: 100000, profit: 20000, status: 'done', createdAt: '2026-06-22');
      expect(o.netProfit, 20000);
    });
    test('有售后费用时净利=毛利-售后', () {
      final o = Order(id: 'o1', deviceId: 'd1', deviceName: 'iPad', buyer: 'x', channel: '闲鱼', amount: 100000, profit: 20000, status: 'aftersale', afterSaleCost: 5000, createdAt: '2026-06-22');
      expect(o.netProfit, 15000);
    });
    test('Order toJson/fromJson 往返含afterSaleCost', () {
      final o = Order(id: 'o1', deviceId: 'd1', deviceName: 'iPad', buyer: 'x', channel: '闲鱼', amount: 100000, profit: 20000, status: 'aftersale', afterSaleCost: 5000, createdAt: '2026-06-22');
      final j = o.toJson();
      expect(j['afterSaleCost'], 5000);
      final o2 = Order.fromJson(j);
      expect(o2.afterSaleCost, 5000);
      expect(o2.netProfit, 15000);
    });
    test('旧数据无afterSaleCost字段时默认为null', () {
      final j = {'id':'o1','deviceId':'d1','deviceName':'iPad','buyer':'x','channel':'闲鱼','amount':100000,'profit':20000,'status':'done','createdAt':'2026-06-22'};
      final o = Order.fromJson(j);
      expect(o.afterSaleCost, isNull);
      expect(o.netProfit, 20000);
    });
  });

  group('Storage.getModelAnalysis 采购决策', () {
    late Directory tmp;
    setUp(() async => tmp = await Directory.systemTemp.createTemp('boss_ana_'));
    tearDown(() async => tmp.delete(recursive: true));

    test('无历史型号返回 hasHistory=false 且各项为0', () async {
      final st = Storage('${tmp.path}/a.json');
      await st.load();
      final a = st.getModelAnalysis('iPad 不存在型号');
      expect(a['hasHistory'], false);
      expect(a['salesCount'], 0);
      expect(a['stagnantRate'], 0.0);
      expect((a['suppliers'] as List).isEmpty, true);
    });

    test('有已售+在售型号正确算均利润/周转/压货率/供应商', () async {
      final st = Storage('${tmp.path}/b.json');
      await st.load();
      // 2台已售 + 1台在售(滞销)
      await st.addDevice(Device(
        id: 's1', serial: 'F1', model: 'iPad Air 5', capacity: '64G',
        color: '银', network: 'WiFi', condition: '95新', purchaseCost: 200000,
        purchaseChannel: '回收商A', purchaseDate: '2026-06-01', createdAt: '2026-06-01',
        status: 'sold', sellPrice: 280000, sellDate: '2026-06-11',
      )); // 周转10天 利润80000
      await st.addDevice(Device(
        id: 's2', serial: 'F2', model: 'iPad Air 5', capacity: '64G',
        color: '银', network: 'WiFi', condition: '95新', purchaseCost: 220000,
        purchaseChannel: '回收商B', purchaseDate: '2026-06-01', createdAt: '2026-06-01',
        status: 'sold', sellPrice: 300000, sellDate: '2026-06-16',
      )); // 周转15天 利润80000
      final old = DateTime.now().subtract(const Duration(days: 20));
      final oldStr = '${old.year}-${old.month.toString().padLeft(2, '0')}-${old.day.toString().padLeft(2, '0')}';
      await st.addDevice(Device(
        id: 'i1', serial: 'F3', model: 'iPad Air 5', capacity: '64G',
        color: '银', network: 'WiFi', condition: '95新', purchaseCost: 210000,
        purchaseChannel: '回收商A', purchaseDate: oldStr, createdAt: '',
        status: 'listed',
      )); // 滞销
      final a = st.getModelAnalysis('iPad Air 5');
      expect(a['hasHistory'], true);
      expect(a['salesCount'], 2);
      expect(a['inStockCount'], 1);
      expect(a['stagnantCount'], 1);
      expect(a['avgProfit'], 80000); // (80000+80000)/2
      expect(a['avgTurnoverDays'], 12); // (10+15)/2
      // 压货率 = 滞销1 / (售2+在售1) = 0.333
      expect((a['stagnantRate'] as double).toStringAsFixed(2), '0.33');
      expect((a['suppliers'] as List).length, 2);
    });
  });

  group('Storage 经营统计口径', () {
    late Directory tmp;
    setUp(() async => tmp = await Directory.systemTemp.createTemp('boss_stats_'));
    tearDown(() async => tmp.delete(recursive: true));

    test('客户汇总排除已作废订单', () async {
      final st = Storage('${tmp.path}/customers.json');
      await st.load();
      await st.addOrder(Order(id: 'o1', deviceId: 'd1', deviceName: 'iPad', buyer: '张三', channel: '闲鱼', amount: 100000, profit: 10000, status: 'done', createdAt: '2026-06-01'));
      await st.addOrder(Order(id: 'o2', deviceId: 'd2', deviceName: 'iPad', buyer: '张三', channel: '闲鱼', amount: 50000, profit: 5000, status: 'cancelled', createdAt: '2026-06-02'));
      final customers = st.getCustomers();
      expect(customers.length, 1);
      expect(customers.first['count'], 1);
      expect(customers.first['totalAmount'], 100000);
    });

    test('资金周转率使用当前在售库存总资金作分母', () async {
      final st = Storage('${tmp.path}/turnover.json');
      await st.load();
      final now = DateTime.now();
      final day = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
      await st.addDevice(Device(id: 'd1', serial: 'F1', model: 'iPad Air 5', capacity: '64G', color: '银色', network: 'WiFi', condition: '95新', purchaseCost: 100000, purchaseDate: day, createdAt: day, status: 'listed'));
      await st.addDevice(Device(id: 'd2', serial: 'F2', model: 'iPad Air 5', capacity: '64G', color: '银色', network: 'WiFi', condition: '95新', purchaseCost: 300000, purchaseDate: day, createdAt: day, status: 'in_stock'));
      await st.addOrder(Order(id: 'o1', deviceId: 's1', deviceName: 'iPad', buyer: '李四', channel: '闲鱼', amount: 200000, profit: 20000, status: 'done', createdAt: day));
      expect(st.getCapitalTurnoverRate(), 0.5);
    });
  });
}
