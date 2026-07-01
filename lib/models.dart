// 数据模型层 —— 二手iPad生意管家
// 零外部依赖，纯Dart，可单元测试

/// 单台设备（库存中的iPad）
class Device {
  final String id; // 内部ID（时间戳）
  String serial; // 序列号
  String model; // 型号 如 iPad Pro 11 2022
  String capacity; // 容量 如 128G
  String color; // 颜色
  String network; // WiFi / WiFi+蜂窝
  String condition; // 成色 99新/95新/9成新/8成新
  int batteryHealth; // 电池健康度 %
  int cycleCount; // 循环次数
  bool idLockClean; // ID锁是否干净（无锁）
  String accessories; // 配件
  int purchaseCost; // 采购成本（分）
  String purchaseChannel; // 采购渠道
  String purchaseDate; // 收购日期
  int sellPrice; // 售价（分），0表示未定价/未售
  String status; // in_stock / listed / sold / returned
  String? sellChannel; // 销售渠道
  String? sellDate; // 售出日期
  int? repairCost; // 翻新维修成本
  int? platformFee; // 平台手续费
  int? logisticsCost; // 物流成本
  int? afterSaleCost; // 售后成本
  String? buyerContact; // 买家联系方式
  String? imagePath; // 实拍图本地路径（分号分隔多张）
  String? description; // AI生成的商品描述（上架闲鱼用）
  String createdAt; // 创建时间

  Device({
    required this.id,
    required this.serial,
    required this.model,
    required this.capacity,
    required this.color,
    required this.network,
    required this.condition,
    this.batteryHealth = 100,
    this.cycleCount = 0,
    this.idLockClean = true,
    this.accessories = '裸机',
    required this.purchaseCost,
    this.purchaseChannel = '',
    required this.purchaseDate,
    this.sellPrice = 0,
    this.status = 'in_stock',
    this.sellChannel,
    this.sellDate,
    this.repairCost,
    this.platformFee,
    this.logisticsCost,
    this.afterSaleCost,
    this.buyerContact,
    this.imagePath,
    this.description,
    required this.createdAt,
  });

  /// 单台净利（分）。未售返回0
  int get netProfit {
    if (status != 'sold' || sellPrice == 0) return 0;
    int cost =
        purchaseCost +
        (repairCost ?? 0) +
        (platformFee ?? 0) +
        (logisticsCost ?? 0) +
        (afterSaleCost ?? 0);
    return sellPrice - cost;
  }

  /// 在库天数（基于purchaseDate）
  int get stockDays {
    try {
      final d = DateTime.parse(purchaseDate);
      return DateTime.now().difference(d).inDays;
    } catch (_) {
      return 0;
    }
  }

  /// 是否滞销（在库且超15天）
  bool get isStagnant =>
      (status == 'in_stock' || status == 'listed') && stockDays > 15;

  factory Device.fromJson(Map<String, dynamic> j) => Device(
    id: j['id'] as String,
    serial: j['serial'] as String,
    model: j['model'] as String,
    capacity: j['capacity'] as String,
    color: j['color'] as String,
    network: j['network'] as String,
    condition: j['condition'] as String,
    batteryHealth: (j['batteryHealth'] as num?)?.toInt() ?? 100,
    cycleCount: (j['cycleCount'] as num?)?.toInt() ?? 0,
    idLockClean: j['idLockClean'] as bool? ?? true,
    accessories: j['accessories'] as String? ?? '裸机',
    purchaseCost: (j['purchaseCost'] as num).toInt(),
    purchaseChannel: j['purchaseChannel'] as String? ?? '',
    purchaseDate: j['purchaseDate'] as String,
    sellPrice: (j['sellPrice'] as num?)?.toInt() ?? 0,
    status: j['status'] as String? ?? 'in_stock',
    sellChannel: j['sellChannel'] as String?,
    sellDate: j['sellDate'] as String?,
    repairCost: (j['repairCost'] as num?)?.toInt(),
    platformFee: (j['platformFee'] as num?)?.toInt(),
    logisticsCost: (j['logisticsCost'] as num?)?.toInt(),
    afterSaleCost: (j['afterSaleCost'] as num?)?.toInt(),
    buyerContact: j['buyerContact'] as String?,
    imagePath: j['imagePath'] as String?,
    description: j['description'] as String?,
    createdAt: j['createdAt'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'serial': serial,
    'model': model,
    'capacity': capacity,
    'color': color,
    'network': network,
    'condition': condition,
    'batteryHealth': batteryHealth,
    'cycleCount': cycleCount,
    'idLockClean': idLockClean,
    'accessories': accessories,
    'purchaseCost': purchaseCost,
    'purchaseChannel': purchaseChannel,
    'purchaseDate': purchaseDate,
    'sellPrice': sellPrice,
    'status': status,
    'sellChannel': sellChannel,
    'sellDate': sellDate,
    'repairCost': repairCost,
    'platformFee': platformFee,
    'logisticsCost': logisticsCost,
    'afterSaleCost': afterSaleCost,
    'buyerContact': buyerContact,
    'imagePath': imagePath,
    'description': description,
    'createdAt': createdAt,
  };
}

/// 闲鱼文案经验样本。
class XianyuCopyExample {
  final String id;
  String title;
  String model;
  String condition;
  String text;
  String tags;
  String resultNote;
  int score;
  String createdAt;

  XianyuCopyExample({
    required this.id,
    required this.title,
    this.model = '',
    this.condition = '',
    required this.text,
    this.tags = '',
    this.resultNote = '',
    this.score = 4,
    required this.createdAt,
  });

  factory XianyuCopyExample.fromJson(Map<String, dynamic> j) =>
      XianyuCopyExample(
        id: j['id'] as String,
        title: j['title'] as String? ?? '未命名样本',
        model: j['model'] as String? ?? '',
        condition: j['condition'] as String? ?? '',
        text: j['text'] as String? ?? '',
        tags: j['tags'] as String? ?? '',
        resultNote: j['resultNote'] as String? ?? '',
        score: (j['score'] as num?)?.toInt() ?? 4,
        createdAt: j['createdAt'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'model': model,
    'condition': condition,
    'text': text,
    'tags': tags,
    'resultNote': resultNote,
    'score': score,
    'createdAt': createdAt,
  };
}

/// 订单
class Order {
  final String id;
  String deviceId; // 关联设备ID
  String deviceName; // 冗余设备名
  String buyer; // 买家
  String channel; // 渠道
  int amount; // 成交金额（分）
  int profit; // 毛利（分，=售价-采购-维修-佣金-物流）
  String status; // shipped/done/aftersale/cancelled（cancelled=重新上架作废）
  int? afterSaleCost; // 售后费用（分），影响净利
  String? afterSaleReason; // 售后原因：质量问题/买家反悔/描述不符/物流损坏/其他
  String createdAt;

  Order({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.buyer,
    required this.channel,
    required this.amount,
    required this.profit,
    required this.status,
    this.afterSaleCost,
    this.afterSaleReason,
    required this.createdAt,
  });

  /// 净利 = 毛利 - 售后费用
  int get netProfit => profit - (afterSaleCost ?? 0);

  factory Order.fromJson(Map<String, dynamic> j) => Order(
    id: j['id'] as String,
    deviceId: j['deviceId'] as String,
    deviceName: j['deviceName'] as String,
    buyer: j['buyer'] as String? ?? '',
    channel: j['channel'] as String? ?? '',
    amount: (j['amount'] as num).toInt(),
    profit: (j['profit'] as num).toInt(),
    status: j['status'] as String? ?? 'shipped',
    afterSaleCost: (j['afterSaleCost'] as num?)?.toInt(),
    afterSaleReason: j['afterSaleReason'] as String?,
    createdAt: j['createdAt'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'deviceId': deviceId,
    'deviceName': deviceName,
    'buyer': buyer,
    'channel': channel,
    'amount': amount,
    'profit': profit,
    'status': status,
    'afterSaleCost': afterSaleCost,
    'afterSaleReason': afterSaleReason,
    'createdAt': createdAt,
  };
}

/// 经营统计快照
class Stats {
  int gmv; // 今日GMV（分）
  int grossProfit; // 今日毛利（分）
  int orderCount; // 今日订单数
  int inStockCount; // 在售台数
  int stagnantCount; // 滞销台数
  int capitalOccupied; // 资金占用（分）
  int pendingCount; // 待发货（订单pending）
  int shippedCount; // 在途（订单shipped）
  int pendingQcCount; // 待质检（in_stock且未定价）
  Map<String, int> channelGmv; // 各渠道GMV（分）

  Stats({
    this.gmv = 0,
    this.grossProfit = 0,
    this.orderCount = 0,
    this.inStockCount = 0,
    this.stagnantCount = 0,
    this.capitalOccupied = 0,
    this.pendingCount = 0,
    this.shippedCount = 0,
    this.pendingQcCount = 0,
    Map<String, int>? channelGmv,
  }) : channelGmv = channelGmv ?? {};
}

/// 每日统计（用于趋势图）
class DailyStat {
  final String date; // yyyy-MM-dd
  final int gmv;
  final int profit;
  DailyStat({required this.date, this.gmv = 0, this.profit = 0});
}

/// 代理（分销）
class Agent {
  final String id;
  String name;
  String phone;
  double commissionRate; // 佣金比例 0.1 = 10%
  int totalGmv; // 累计贡献GMV（分）
  String createdAt;

  Agent({
    required this.id,
    required this.name,
    this.phone = '',
    this.commissionRate = 0.1,
    this.totalGmv = 0,
    required this.createdAt,
  });

  factory Agent.fromJson(Map<String, dynamic> j) => Agent(
    id: j['id'] as String,
    name: j['name'] as String,
    phone: j['phone'] as String? ?? '',
    commissionRate: (j['commissionRate'] as num?)?.toDouble() ?? 0.1,
    totalGmv: (j['totalGmv'] as num?)?.toInt() ?? 0,
    createdAt: j['createdAt'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'commissionRate': commissionRate,
    'totalGmv': totalGmv,
    'createdAt': createdAt,
  };
}

/// 维修工单
class RepairOrder {
  final String id;
  String deviceId;
  String deviceName;
  String type; // 换电池/换屏/换壳/其他
  int cost; // 成本（分）
  String status; // 待修/进行中/完成
  String note;
  String createdAt;

  RepairOrder({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.type,
    required this.cost,
    this.status = '待修',
    this.note = '',
    required this.createdAt,
  });

  factory RepairOrder.fromJson(Map<String, dynamic> j) => RepairOrder(
    id: j['id'] as String,
    deviceId: j['deviceId'] as String,
    deviceName: j['deviceName'] as String,
    type: j['type'] as String,
    cost: (j['cost'] as num).toInt(),
    status: j['status'] as String? ?? '待修',
    note: j['note'] as String? ?? '',
    createdAt: j['createdAt'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'deviceId': deviceId,
    'deviceName': deviceName,
    'type': type,
    'cost': cost,
    'status': status,
    'note': note,
    'createdAt': createdAt,
  };
}

/// 自动定价：根据采购成本（分）按分档加价规则计算售价（分）
/// <1000→+168, 1000-2000→+238, 2000-3000→+298, 3000-4000→+398,
/// 4000-5000→+498, 5000-7000→+598, 7000-9000→+798, >9000→+12%
int calcAutoPrice(int purchaseCostFen) {
  final y = purchaseCostFen / 100.0; // 转元
  const thresholds = [1000.0, 2000.0, 3000.0, 4000.0, 5000.0, 7000.0, 9000.0];
  const additions = [168, 238, 298, 398, 498, 598, 798];
  for (int i = 0; i < thresholds.length; i++) {
    if (y < thresholds[i]) {
      return ((y + additions[i]) * 100).round();
    }
  }
  // >9000 加 12%
  return (y * 1.12 * 100).round();
}

/// ====================================================================
/// 爱管机 ERP 扩展模型
/// ====================================================================

/// 采购单（统计报表使用）
class PurchaseOrder {
  final String id;
  String supplier;
  String sourcePlatform;
  String? sourceOrderId;
  List<String> deviceIds;
  int totalCost;
  String status;
  int returnedCount;
  int? afterSaleAmount;
  String? afterSaleNote;
  String? note;
  String createdAt;

  PurchaseOrder({
    required this.id,
    required this.supplier,
    this.sourcePlatform = '手动',
    this.sourceOrderId,
    this.deviceIds = const [],
    this.totalCost = 0,
    this.status = 'pending',
    this.returnedCount = 0,
    this.afterSaleAmount,
    this.afterSaleNote,
    this.note,
    required this.createdAt,
  });

  int get deviceCount => deviceIds.length;
  int get effectiveCount => deviceIds.length - returnedCount;

  factory PurchaseOrder.fromJson(Map<String, dynamic> j) => PurchaseOrder(
    id: j['id'] as String,
    supplier: j['supplier'] as String? ?? '',
    sourcePlatform: j['sourcePlatform'] as String? ?? '手动',
    sourceOrderId: j['sourceOrderId'] as String?,
    deviceIds: (j['deviceIds'] as List?)?.cast<String>() ?? [],
    totalCost: (j['totalCost'] as num?)?.toInt() ?? 0,
    status: j['status'] as String? ?? 'pending',
    returnedCount: (j['returnedCount'] as num?)?.toInt() ?? 0,
    afterSaleAmount: (j['afterSaleAmount'] as num?)?.toInt(),
    afterSaleNote: j['afterSaleNote'] as String?,
    note: j['note'] as String?,
    createdAt: j['createdAt'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'supplier': supplier,
    'sourcePlatform': sourcePlatform,
    'sourceOrderId': sourceOrderId,
    'deviceIds': deviceIds,
    'totalCost': totalCost,
    'status': status,
    'returnedCount': returnedCount,
    'afterSaleAmount': afterSaleAmount,
    'afterSaleNote': afterSaleNote,
    'note': note,
    'createdAt': createdAt,
  };
}

/// 质检报告（统计报表使用）
class QCReport {
  final String id;
  String deviceId;
  String deviceName;
  String inspector;
  String screenCondition;
  String frameCondition;
  String backCondition;
  String cameraCondition;
  bool hasFaceId;
  bool hasTouchId;
  bool wifiOk;
  bool bluetoothOk;
  bool microphoneOk;
  bool speakerOk;
  bool buttonsOk;
  bool chargingOk;
  String grade;
  String conclusion;
  String? repairSuggestion;
  int? estimatedRepairCost;
  String? note;
  String createdAt;

  static const screenOptions = ['完美', '细微划痕', '明显划痕', '碎裂'];
  static const frameOptions = ['完美', '轻微磕碰', '明显磕碰', '变形'];
  static const backOptions = ['完美', '划痕', '碎裂'];
  static const cameraOptions = ['正常', '有灰', '划痕', '破损'];
  static const grades = ['A', 'B', 'C', 'D'];

  QCReport({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    this.inspector = '',
    this.screenCondition = '完美',
    this.frameCondition = '完美',
    this.backCondition = '完美',
    this.cameraCondition = '正常',
    this.hasFaceId = true,
    this.hasTouchId = true,
    this.wifiOk = true,
    this.bluetoothOk = true,
    this.microphoneOk = true,
    this.speakerOk = true,
    this.buttonsOk = true,
    this.chargingOk = true,
    this.grade = 'A',
    this.conclusion = '通过',
    this.repairSuggestion,
    this.estimatedRepairCost,
    this.note,
    required this.createdAt,
  });

  bool get allPassed =>
      wifiOk &&
      bluetoothOk &&
      microphoneOk &&
      speakerOk &&
      buttonsOk &&
      chargingOk &&
      hasFaceId &&
      hasTouchId;

  factory QCReport.fromJson(Map<String, dynamic> j) => QCReport(
    id: j['id'] as String,
    deviceId: j['deviceId'] as String? ?? '',
    deviceName: j['deviceName'] as String? ?? '',
    inspector: j['inspector'] as String? ?? '',
    screenCondition: j['screenCondition'] as String? ?? '完美',
    frameCondition: j['frameCondition'] as String? ?? '完美',
    backCondition: j['backCondition'] as String? ?? '完美',
    cameraCondition: j['cameraCondition'] as String? ?? '正常',
    hasFaceId: j['hasFaceId'] as bool? ?? true,
    hasTouchId: j['hasTouchId'] as bool? ?? true,
    wifiOk: j['wifiOk'] as bool? ?? true,
    bluetoothOk: j['bluetoothOk'] as bool? ?? true,
    microphoneOk: j['microphoneOk'] as bool? ?? true,
    speakerOk: j['speakerOk'] as bool? ?? true,
    buttonsOk: j['buttonsOk'] as bool? ?? true,
    chargingOk: j['chargingOk'] as bool? ?? true,
    grade: j['grade'] as String? ?? 'A',
    conclusion: j['conclusion'] as String? ?? '通过',
    repairSuggestion: j['repairSuggestion'] as String?,
    estimatedRepairCost: (j['estimatedRepairCost'] as num?)?.toInt(),
    note: j['note'] as String?,
    createdAt: j['createdAt'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'deviceId': deviceId,
    'deviceName': deviceName,
    'inspector': inspector,
    'screenCondition': screenCondition,
    'frameCondition': frameCondition,
    'backCondition': backCondition,
    'cameraCondition': cameraCondition,
    'hasFaceId': hasFaceId,
    'hasTouchId': hasTouchId,
    'wifiOk': wifiOk,
    'bluetoothOk': bluetoothOk,
    'microphoneOk': microphoneOk,
    'speakerOk': speakerOk,
    'buttonsOk': buttonsOk,
    'chargingOk': chargingOk,
    'grade': grade,
    'conclusion': conclusion,
    'repairSuggestion': repairSuggestion,
    'estimatedRepairCost': estimatedRepairCost,
    'note': note,
    'createdAt': createdAt,
  };
}

/// 爱管机 ERP v2 扩展模型
class RepairPart {
  final String id;
  String repairOrderId;
  String partName;
  int quantity;
  int unitCost; // 单价（分）
  String? supplier;
  String createdAt;

  RepairPart({
    required this.id,
    required this.repairOrderId,
    required this.partName,
    this.quantity = 1,
    this.unitCost = 0,
    this.supplier,
    required this.createdAt,
  });

  int get totalCost => quantity * unitCost;

  factory RepairPart.fromJson(Map<String, dynamic> j) => RepairPart(
    id: j['id'] as String,
    repairOrderId: j['repairOrderId'] as String,
    partName: j['partName'] as String,
    quantity: (j['quantity'] as num?)?.toInt() ?? 1,
    unitCost: (j['unitCost'] as num?)?.toInt() ?? 0,
    supplier: j['supplier'] as String?,
    createdAt: j['createdAt'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'repairOrderId': repairOrderId,
    'partName': partName,
    'quantity': quantity,
    'unitCost': unitCost,
    'supplier': supplier,
    'createdAt': createdAt,
  };
}
