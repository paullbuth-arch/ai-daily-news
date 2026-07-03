import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ipad_boss_app/models.dart';
import 'package:ipad_boss_app/services/xianyu_copy_service.dart';
import 'package:ipad_boss_app/storage.dart';

void main() {
  late Directory tmp;
  late Storage storage;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('boss_copy_');
    storage = Storage('${tmp.path}/data.json');
    await storage.load();
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('文案样本和规则可以保存并读取', () async {
    await storage.saveXianyuCopyRules('只写真实描述，避免夸大承诺');
    await storage.addXianyuCopyExample(
      XianyuCopyExample(
        id: 'copy-1',
        title: '成交样本',
        model: 'iPad Air 5',
        condition: '95新',
        text: '这台 iPad Air 5 成色干净，电池表现稳定，适合学习和轻办公。',
        tags: '成交快',
        resultNote: '2天售出',
        score: 5,
        createdAt: '2026-06-30T10:00:00',
      ),
    );

    final examples = storage.getXianyuCopyExamples();

    expect(storage.getXianyuCopyRules(), contains('真实描述'));
    expect(examples, hasLength(1));
    expect(examples.first.score, 5);
  });

  test('可以从已售设备导入文案样本并去重', () async {
    await storage.addDevice(
      Device(
        id: 'd1',
        serial: 'F1',
        model: 'iPad Pro 11',
        capacity: '128G',
        color: '银色',
        network: 'WiFi',
        condition: '99新',
        purchaseCost: 400000,
        purchaseDate: '2026-06-01',
        sellPrice: 488000,
        status: 'sold',
        description: '成色很新，屏幕显示细腻，ID 无锁，适合画画和办公。',
        createdAt: '2026-06-20T12:00:00',
      ),
    );

    expect(await storage.importSoldDescriptionsAsCopyExamples(), 1);
    expect(await storage.importSoldDescriptionsAsCopyExamples(), 0);
    expect(storage.getXianyuCopyExamples(), hasLength(1));
    expect(storage.getXianyuCopyExamples().first.tags, '已售导入');
  });

  test('生成参考上下文包含规则、样本和已售文案', () async {
    await storage.saveXianyuCopyRules('本店规则：不写全新，不承诺官方保修');
    await storage.addXianyuCopyExample(
      XianyuCopyExample(
        id: 'copy-1',
        title: '高转化样本',
        model: 'iPad Air 5',
        condition: '95新',
        text: '机器整体很清爽，电池健康稳定，ID 无锁，拿到即可登录使用。',
        tags: '成交快',
        resultNote: '询问少',
        score: 5,
        createdAt: '2026-06-30T10:00:00',
      ),
    );
    await storage.addDevice(
      Device(
        id: 'd1',
        serial: 'F1',
        model: 'iPad Air 5',
        capacity: '64G',
        color: '星光色',
        network: 'WiFi',
        condition: '95新',
        purchaseCost: 260000,
        purchaseDate: '2026-06-01',
        sellPrice: 318000,
        status: 'sold',
        description: '外观干净，系统流畅，适合记笔记、追剧和轻办公。',
        createdAt: '2026-06-25T12:00:00',
      ),
    );

    final context = XianyuCopyService.buildReferenceContext(
      storage,
      model: 'iPad Air 5',
      condition: '95新',
    );

    expect(XianyuCopyService.builtInMaterialCount, 100);
    expect(XianyuCopyService.builtInExampleCount, 100);
    expect(context, contains('本店规则'));
    expect(context, contains('内置 100 条素材提炼规则'));
    expect(context, contains('本次随机写法'));
    expect(context, contains('高转化样本'));
    expect(context, contains('已售设备历史文案'));
    expect(context, contains('不要照抄'));
  });

  test('入库基础素材模式只参考内置100条，不带历史文案', () async {
    await storage.addXianyuCopyExample(
      XianyuCopyExample(
        id: 'copy-history',
        title: '不应进入入库自动文案',
        model: 'iPad Air 5',
        condition: '95新',
        text: '这是旧的手工样本文案，入库自动生成不应复用。',
        tags: '历史样本',
        resultNote: '历史成交',
        score: 5,
        createdAt: '2026-06-30T10:00:00',
      ),
    );
    await storage.addDevice(
      Device(
        id: 'sold-copy',
        serial: 'F2',
        model: 'iPad Air 5',
        capacity: '64G',
        color: '星光色',
        network: 'WiFi',
        condition: '95新',
        purchaseCost: 260000,
        purchaseDate: '2026-06-01',
        sellPrice: 318000,
        status: 'sold',
        description: '这是上一台同型号的已售文案，入库时不应直接参考。',
        createdAt: '2026-06-25T12:00:00',
      ),
    );

    final context = XianyuCopyService.buildReferenceContext(
      storage,
      model: 'iPad Air 5',
      condition: '95新',
      includeCuratedExamples: false,
      includeSoldDescriptions: false,
      randomizeBuiltIns: false,
    );

    expect(context, contains('内置 100 条素材提炼规则'));
    expect(context, contains('内置安全改写样本'));
    expect(context, isNot(contains('高转化参考样本')));
    expect(context, isNot(contains('已售设备历史文案')));
    expect(context, isNot(contains('这是旧的手工样本文案')));
    expect(context, isNot(contains('这是上一台同型号的已售文案')));
  });
}
