// 数据模型层 —— 二手iPad生意管家
// 零外部依赖，纯Dart，可单元测试

/// 单台设备（库存中的iPad）
class Device {
  final String id;          // 内部ID（时间戳）
  String serial;            // 序列号
  String model;             // 型号 如 iPad Pro 11 2022
  String capacity;          // 容量 如 128G
  String color;             // 颜色
  String network;           // WiFi / WiFi+蜂窝
  String condition;         // 成色 99新/95新/9成新/8成新
  int batteryHealth;        // 电池健康度 %
  int cycleCount;           // 循环次数
  bool idLockClean;         // ID锁是否干净（无锁）
  String accessories;       // 配件
  int purchaseCost;         // 采购成本（分）
  String purchaseChannel;   // 采购渠道
  String purchaseDate;      // 收购日期
  int sellPrice;            // 售价（分），0表示未定价/未售
  String status;            // in_stock / listed / sold / returned
  String? sellChannel;      // 销售渠道
  String? sellDate;         // 售出日期
  int? repairCost;          // 翻新维修成本
  int? platformFee;         // 平台佣金
  int? logisticsCost;       // 物流成本
  int? afterSaleCost;       // 售后成本
  String? buyerContact;     // 买家联系方式
  String? imagePath;        // 实拍图本地路径（分号分隔多张）
  String? description;      // AI生成的商品描述（上架闲鱼用）
  String createdAt;         // 创建时间

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
    int cost = purchaseCost + (repairCost ?? 0) + (platformFee ?? 0) + (logisticsCost ?? 0) + (afterSaleCost ?? 0);
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
  bool get isStagnant => (status == 'in_stock' || status == 'listed') && stockDays > 15;

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

/// 订单
class Order {
  final String id;
  String deviceId;     // 关联设备ID
  String deviceName;   // 冗余设备名
  String buyer;        // 买家
  String channel;      // 渠道
  int amount;          // 成交金额（分）
  int profit;          // 毛利（分，=售价-采购-维修-佣金-物流）
  String status;       // shipped/done/aftersale/cancelled（cancelled=重新上架作废）
  int? afterSaleCost;  // 售后费用（分），影响净利
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
  int gmv;          // 今日GMV（分）
  int grossProfit;  // 今日毛利（分）
  int orderCount;   // 今日订单数
  int inStockCount; // 在售台数
  int stagnantCount;// 滞销台数
  int capitalOccupied; // 资金占用（分）
  int pendingCount;    // 待发货（订单pending）
  int shippedCount;    // 在途（订单shipped）
  int pendingQcCount;  // 待质检（in_stock且未定价）
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
  int totalGmv;          // 累计贡献GMV（分）
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
  String type;     // 换电池/换屏/换壳/其他
  int cost;        // 成本（分）
  String status;   // 待修/进行中/完成
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

/// 采购单
class PurchaseOrder {
  final String id;
  String supplier;                // 供应商/来源
  String sourcePlatform;          // 来源平台：手动/闲鱼/转转/爱回收/其他
  String? sourceOrderId;          // 源平台订单号
  List<String> deviceIds;        // 关联设备ID列表
  int totalCost;                  // 采购总金额（分）
  String status;                  // pending/partial/done/cancelled
  int returnedCount;             // 已退货数量
  int? afterSaleAmount;          // 售后议价金额（分）
  String? afterSaleNote;         // 售后备注
  String? note;                   // 备注
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
    supplier: j['supplier'] as String,
    sourcePlatform: j['sourcePlatform'] as String? ?? '手动',
    sourceOrderId: j['sourceOrderId'] as String?,
    deviceIds: (j['deviceIds'] as List?)?.cast<String>() ?? [],
    totalCost: (j['totalCost'] as num).toInt(),
    status: j['status'] as String? ?? 'pending',
    returnedCount: (j['returnedCount'] as num?)?.toInt() ?? 0,
    afterSaleAmount: (j['afterSaleAmount'] as num?)?.toInt(),
    afterSaleNote: j['afterSaleNote'] as String?,
    note: j['note'] as String?,
    createdAt: j['createdAt'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'supplier': supplier, 'sourcePlatform': sourcePlatform,
    'sourceOrderId': sourceOrderId, 'deviceIds': deviceIds,
    'totalCost': totalCost, 'status': status, 'returnedCount': returnedCount,
    'afterSaleAmount': afterSaleAmount, 'afterSaleNote': afterSaleNote,
    'note': note, 'createdAt': createdAt,
  };
}

/// 质检报告——详细检测项
class QCReport {
  final String id;
  String deviceId;
  String deviceName;
  String inspector;          // 质检员
  // 外观检测
  String screenCondition;    // 屏幕状况：完美/细微划痕/明显划痕/碎裂
  String frameCondition;     // 边框状况：完美/轻微磕碰/明显磕碰/变形
  String backCondition;      // 背板状况：完美/划痕/碎裂
  String cameraCondition;    // 摄像头：正常/有灰/划痕/破损
  bool hasFaceId;            // Face ID 是否正常
  bool hasTouchId;           // Touch ID 是否正常
  // 功能检测
  bool wifiOk;               // WiFi
  bool bluetoothOk;          // 蓝牙
  bool microphoneOk;         // 麦克风
  bool speakerOk;            // 扬声器
  bool buttonsOk;            // 按键
  bool chargingOk;           // 充电
  // 结论
  String grade;              // A/B/C/D 品级
  String conclusion;         // 通过/需维修/报废
  String? repairSuggestion;  // 维修建议
  int? estimatedRepairCost;  // 预估维修成本（分）
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
    wifiOk && bluetoothOk && microphoneOk && speakerOk && buttonsOk && chargingOk &&
    hasFaceId && hasTouchId;

  factory QCReport.fromJson(Map<String, dynamic> j) => QCReport(
    id: j['id'] as String,
    deviceId: j['deviceId'] as String,
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
    createdAt: j['createdAt'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'deviceId': deviceId, 'deviceName': deviceName,
    'inspector': inspector,
    'screenCondition': screenCondition, 'frameCondition': frameCondition,
    'backCondition': backCondition, 'cameraCondition': cameraCondition,
    'hasFaceId': hasFaceId, 'hasTouchId': hasTouchId,
    'wifiOk': wifiOk, 'bluetoothOk': bluetoothOk,
    'microphoneOk': microphoneOk, 'speakerOk': speakerOk,
    'buttonsOk': buttonsOk, 'chargingOk': chargingOk,
    'grade': grade, 'conclusion': conclusion,
    'repairSuggestion': repairSuggestion,
    'estimatedRepairCost': estimatedRepairCost,
    'note': note, 'createdAt': createdAt,
  };
}

/// 分货记录——设备分配/分发
class AllocationRecord {
  final String id;
  String deviceId;
  String deviceName;
  String assignee;         // 领用人/销售员
  String department;       // 部门/门店
  String purpose;          // 用途：门店展示/销售/维修备机/其他
  String status;           // assigned/returned
  String? returnedAt;      // 归还时间
  String? note;
  String createdAt;

  AllocationRecord({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.assignee,
    this.department = '',
    this.purpose = '销售',
    this.status = 'assigned',
    this.returnedAt,
    this.note,
    required this.createdAt,
  });

  factory AllocationRecord.fromJson(Map<String, dynamic> j) => AllocationRecord(
    id: j['id'] as String,
    deviceId: j['deviceId'] as String,
    deviceName: j['deviceName'] as String? ?? '',
    assignee: j['assignee'] as String,
    department: j['department'] as String? ?? '',
    purpose: j['purpose'] as String? ?? '销售',
    status: j['status'] as String? ?? 'assigned',
    returnedAt: j['returnedAt'] as String?,
    note: j['note'] as String?,
    createdAt: j['createdAt'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'deviceId': deviceId, 'deviceName': deviceName,
    'assignee': assignee, 'department': department,
    'purpose': purpose, 'status': status,
    'returnedAt': returnedAt, 'note': note, 'createdAt': createdAt,
  };
}

/// 租借记录
class RentalRecord {
  final String id;
  String deviceId;
  String deviceName;
  String borrower;         // 借用人
  String contact;          // 联系方式
  String purpose;          // 用途
  String status;           // borrowed/returned/overdue
  DateTime borrowedAt;
  DateTime? dueAt;         // 应还日期
  DateTime? returnedAt;
  int? deposit;            // 押金（分）
  String? note;
  String createdAt;

  RentalRecord({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.borrower,
    this.contact = '',
    this.purpose = '',
    this.status = 'borrowed',
    required this.borrowedAt,
    this.dueAt,
    this.returnedAt,
    this.deposit,
    this.note,
    required this.createdAt,
  });

  bool get isOverdue => status == 'borrowed' && dueAt != null && DateTime.now().isAfter(dueAt!);

  factory RentalRecord.fromJson(Map<String, dynamic> j) => RentalRecord(
    id: j['id'] as String,
    deviceId: j['deviceId'] as String,
    deviceName: j['deviceName'] as String? ?? '',
    borrower: j['borrower'] as String,
    contact: j['contact'] as String? ?? '',
    purpose: j['purpose'] as String? ?? '',
    status: j['status'] as String? ?? 'borrowed',
    borrowedAt: DateTime.parse(j['borrowedAt'] as String),
    dueAt: j['dueAt'] != null ? DateTime.parse(j['dueAt'] as String) : null,
    returnedAt: j['returnedAt'] != null ? DateTime.parse(j['returnedAt'] as String) : null,
    deposit: (j['deposit'] as num?)?.toInt(),
    note: j['note'] as String?,
    createdAt: j['createdAt'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'deviceId': deviceId, 'deviceName': deviceName,
    'borrower': borrower, 'contact': contact, 'purpose': purpose,
    'status': status, 'borrowedAt': borrowedAt.toIso8601String(),
    'dueAt': dueAt?.toIso8601String(), 'returnedAt': returnedAt?.toIso8601String(),
    'deposit': deposit, 'note': note, 'createdAt': createdAt,
  };
}

/// 分期付款计划
class InstallmentPlan {
  final String id;
  String deviceId;
  String deviceName;
  String buyer;
  String contact;
  int totalAmount;          // 总金额（分）
  int downPayment;          // 首付（分）
  int installmentCount;     // 分期期数
  int installmentAmount;    // 每期金额（分）
  String status;            // active/completed/defaulted
  List<InstallmentItem> items;
  String createdAt;

  InstallmentPlan({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.buyer,
    this.contact = '',
    required this.totalAmount,
    this.downPayment = 0,
    this.installmentCount = 3,
    this.installmentAmount = 0,
    this.status = 'active',
    this.items = const [],
    required this.createdAt,
  });

  int get paidAmount => items.where((i) => i.paid).fold(0, (s, i) => s + i.amount);
  int get remainingAmount => totalAmount - paidAmount;

  factory InstallmentPlan.fromJson(Map<String, dynamic> j) => InstallmentPlan(
    id: j['id'] as String,
    deviceId: j['deviceId'] as String,
    deviceName: j['deviceName'] as String? ?? '',
    buyer: j['buyer'] as String,
    contact: j['contact'] as String? ?? '',
    totalAmount: (j['totalAmount'] as num).toInt(),
    downPayment: (j['downPayment'] as num?)?.toInt() ?? 0,
    installmentCount: (j['installmentCount'] as num?)?.toInt() ?? 3,
    installmentAmount: (j['installmentAmount'] as num?)?.toInt() ?? 0,
    status: j['status'] as String? ?? 'active',
    items: (j['items'] as List?)?.map((e) => InstallmentItem.fromJson(e)).toList() ?? [],
    createdAt: j['createdAt'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'deviceId': deviceId, 'deviceName': deviceName,
    'buyer': buyer, 'contact': contact,
    'totalAmount': totalAmount, 'downPayment': downPayment,
    'installmentCount': installmentCount, 'installmentAmount': installmentAmount,
    'status': status,
    'items': items.map((i) => i.toJson()).toList(),
    'createdAt': createdAt,
  };
}

/// 分期付款条目
class InstallmentItem {
  final int index;         // 第几期（1-based）
  int amount;              // 本期待还金额（分）
  DateTime dueDate;        // 应还日期
  bool paid;               // 是否已还
  DateTime? paidAt;        // 实际还款日期

  InstallmentItem({
    required this.index,
    required this.amount,
    required this.dueDate,
    this.paid = false,
    this.paidAt,
  });

  bool get isOverdue => !paid && DateTime.now().isAfter(dueDate);

  factory InstallmentItem.fromJson(Map<String, dynamic> j) => InstallmentItem(
    index: (j['index'] as num).toInt(),
    amount: (j['amount'] as num).toInt(),
    dueDate: DateTime.parse(j['dueDate'] as String),
    paid: j['paid'] as bool? ?? false,
    paidAt: j['paidAt'] != null ? DateTime.parse(j['paidAt'] as String) : null,
  );

  Map<String, dynamic> toJson() => {
    'index': index, 'amount': amount, 'dueDate': dueDate.toIso8601String(),
    'paid': paid, 'paidAt': paidAt?.toIso8601String(),
  };
}

/// 预付定金记录
class DepositRecord {
  final String id;
  String deviceId;
  String deviceName;
  String customer;
  String contact;
  int depositAmount;        // 定金金额（分）
  int totalPrice;           // 总价（分）
  String status;            // active/completed/cancelled/refunded
  String? note;
  String createdAt;

  DepositRecord({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.customer,
    this.contact = '',
    required this.depositAmount,
    required this.totalPrice,
    this.status = 'active',
    this.note,
    required this.createdAt,
  });

  int get remainingAmount => totalPrice - depositAmount;

  factory DepositRecord.fromJson(Map<String, dynamic> j) => DepositRecord(
    id: j['id'] as String,
    deviceId: j['deviceId'] as String,
    deviceName: j['deviceName'] as String? ?? '',
    customer: j['customer'] as String,
    contact: j['contact'] as String? ?? '',
    depositAmount: (j['depositAmount'] as num).toInt(),
    totalPrice: (j['totalPrice'] as num).toInt(),
    status: j['status'] as String? ?? 'active',
    note: j['note'] as String?,
    createdAt: j['createdAt'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'deviceId': deviceId, 'deviceName': deviceName,
    'customer': customer, 'contact': contact,
    'depositAmount': depositAmount, 'totalPrice': totalPrice,
    'status': status, 'note': note, 'createdAt': createdAt,
  };
}

/// 库存预警配置
class InventoryAlertConfig {
  int lowStockThreshold;         // 低库存阈值
  int stagnantDaysThreshold;     // 滞销天数阈值
  bool enableLowStockAlert;      // 启用低库存预警
  bool enableStagnantAlert;      // 启用滞销预警
  Map<String, int> modelThresholds; // 按型号独立阈值 { "iPad Pro 11 2022": 5 }

  InventoryAlertConfig({
    this.lowStockThreshold = 5,
    this.stagnantDaysThreshold = 15,
    this.enableLowStockAlert = true,
    this.enableStagnantAlert = true,
    Map<String, int>? modelThresholds,
  }) : modelThresholds = modelThresholds ?? {};

  factory InventoryAlertConfig.fromJson(Map<String, dynamic> j) => InventoryAlertConfig(
    lowStockThreshold: (j['lowStockThreshold'] as num?)?.toInt() ?? 5,
    stagnantDaysThreshold: (j['stagnantDaysThreshold'] as num?)?.toInt() ?? 15,
    enableLowStockAlert: j['enableLowStockAlert'] as bool? ?? true,
    enableStagnantAlert: j['enableStagnantAlert'] as bool? ?? true,
    modelThresholds: j['modelThresholds'] != null
        ? Map<String, int>.from(j['modelThresholds'] as Map)
        : {},
  );

  Map<String, dynamic> toJson() => {
    'lowStockThreshold': lowStockThreshold,
    'stagnantDaysThreshold': stagnantDaysThreshold,
    'enableLowStockAlert': enableLowStockAlert,
    'enableStagnantAlert': enableStagnantAlert,
    'modelThresholds': modelThresholds,
  };
}

/// ====================================================================
/// 爱管机 ERP v2 扩展模型
/// ====================================================================

/// 仓库
class Warehouse {
  final String id;
  String name;
  String address;
  String contact;
  String phone;
  bool isActive;
  String createdAt;

  Warehouse({
    required this.id,
    required this.name,
    this.address = '',
    this.contact = '',
    this.phone = '',
    this.isActive = true,
    required this.createdAt,
  });

  factory Warehouse.fromJson(Map<String, dynamic> j) => Warehouse(
    id: j['id'] as String, name: j['name'] as String,
    address: j['address'] as String? ?? '', contact: j['contact'] as String? ?? '',
    phone: j['phone'] as String? ?? '', isActive: j['isActive'] as bool? ?? true,
    createdAt: j['createdAt'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'address': address, 'contact': contact,
    'phone': phone, 'isActive': isActive, 'createdAt': createdAt,
  };
}

/// 库存调拨单
class WarehouseTransfer {
  final String id;
  String fromWarehouseId;
  String fromWarehouseName;
  String toWarehouseId;
  String toWarehouseName;
  List<String> deviceIds;
  String status;        // pending/done/cancelled
  String? operator;
  String? note;
  String createdAt;

  WarehouseTransfer({
    required this.id,
    required this.fromWarehouseId,
    required this.fromWarehouseName,
    required this.toWarehouseId,
    required this.toWarehouseName,
    this.deviceIds = const [],
    this.status = 'pending',
    this.operator,
    this.note,
    required this.createdAt,
  });

  int get deviceCount => deviceIds.length;

  factory WarehouseTransfer.fromJson(Map<String, dynamic> j) => WarehouseTransfer(
    id: j['id'] as String,
    fromWarehouseId: j['fromWarehouseId'] as String,
    fromWarehouseName: j['fromWarehouseName'] as String? ?? '',
    toWarehouseId: j['toWarehouseId'] as String,
    toWarehouseName: j['toWarehouseName'] as String? ?? '',
    deviceIds: (j['deviceIds'] as List?)?.cast<String>() ?? [],
    status: j['status'] as String? ?? 'pending',
    operator: j['operator'] as String?,
    note: j['note'] as String?,
    createdAt: j['createdAt'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'fromWarehouseId': fromWarehouseId, 'fromWarehouseName': fromWarehouseName,
    'toWarehouseId': toWarehouseId, 'toWarehouseName': toWarehouseName,
    'deviceIds': deviceIds, 'status': status, 'operator': operator,
    'note': note, 'createdAt': createdAt,
  };
}

/// 盘点单
class InventoryCount {
  final String id;
  String warehouseId;
  String warehouseName;
  String? operator;
  List<InventoryCountItem> items;
  String status;         // draft/done
  String? note;
  String createdAt;

  InventoryCount({
    required this.id,
    required this.warehouseId,
    required this.warehouseName,
    this.operator,
    this.items = const [],
    this.status = 'draft',
    this.note,
    required this.createdAt,
  });

  int get totalCount => items.length;
  int get matchedCount => items.where((i) => i.matched).length;
  int get diffCount => totalCount - matchedCount;

  factory InventoryCount.fromJson(Map<String, dynamic> j) => InventoryCount(
    id: j['id'] as String,
    warehouseId: j['warehouseId'] as String,
    warehouseName: j['warehouseName'] as String? ?? '',
    operator: j['operator'] as String?,
    items: (j['items'] as List?)?.map((e) => InventoryCountItem.fromJson(e)).toList() ?? [],
    status: j['status'] as String? ?? 'draft',
    note: j['note'] as String?,
    createdAt: j['createdAt'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'warehouseId': warehouseId, 'warehouseName': warehouseName,
    'operator': operator, 'items': items.map((i) => i.toJson()).toList(),
    'status': status, 'note': note, 'createdAt': createdAt,
  };
}

/// 盘点条目
class InventoryCountItem {
  String deviceId;
  String deviceName;
  String serial;
  bool matched;     // 盘点是否匹配
  String? note;

  InventoryCountItem({
    required this.deviceId,
    required this.deviceName,
    required this.serial,
    this.matched = true,
    this.note,
  });

  factory InventoryCountItem.fromJson(Map<String, dynamic> j) => InventoryCountItem(
    deviceId: j['deviceId'] as String,
    deviceName: j['deviceName'] as String? ?? '',
    serial: j['serial'] as String? ?? '',
    matched: j['matched'] as bool? ?? true,
    note: j['note'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId, 'deviceName': deviceName, 'serial': serial,
    'matched': matched, 'note': note,
  };
}

/// 其他出入库单（非采购/销售）
class OtherInOut {
  final String id;
  String type;          // in/out
  String category;      // 赠品/配件/样品/报废/其他
  String? deviceId;
  String deviceName;
  int quantity;
  int? amount;          // 金额（分）
  String? operator;
  String? note;
  String createdAt;

  OtherInOut({
    required this.id,
    required this.type,
    required this.category,
    this.deviceId,
    this.deviceName = '',
    this.quantity = 1,
    this.amount,
    this.operator,
    this.note,
    required this.createdAt,
  });

  factory OtherInOut.fromJson(Map<String, dynamic> j) => OtherInOut(
    id: j['id'] as String, type: j['type'] as String,
    category: j['category'] as String, deviceId: j['deviceId'] as String?,
    deviceName: j['deviceName'] as String? ?? '',
    quantity: (j['quantity'] as num?)?.toInt() ?? 1,
    amount: (j['amount'] as num?)?.toInt(),
    operator: j['operator'] as String?,
    note: j['note'] as String?,
    createdAt: j['createdAt'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'type': type, 'category': category, 'deviceId': deviceId,
    'deviceName': deviceName, 'quantity': quantity, 'amount': amount,
    'operator': operator, 'note': note, 'createdAt': createdAt,
  };
}

/// 维修配件明细
class RepairPart {
  final String id;
  String repairOrderId;
  String partName;
  int quantity;
  int unitCost;         // 单价（分）
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
    id: j['id'] as String, repairOrderId: j['repairOrderId'] as String,
    partName: j['partName'] as String, quantity: (j['quantity'] as num?)?.toInt() ?? 1,
    unitCost: (j['unitCost'] as num?)?.toInt() ?? 0,
    supplier: j['supplier'] as String?, createdAt: j['createdAt'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'repairOrderId': repairOrderId, 'partName': partName,
    'quantity': quantity, 'unitCost': unitCost, 'supplier': supplier,
    'createdAt': createdAt,
  };
}
