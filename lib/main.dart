// 货脉 · 二手iPad经营工作台
// 商务科技设计系统 · 模块化架构
//
// 目录结构:
//   lib/
//     main.dart           ← 入口 + 全局状态 + 常量
//     theme/colors.dart   ← 设计系统（颜色/间距/圆角/阴影）
//     components/         ← 共享UI组件
//     utils/utils.dart    ← 工具函数
//     pages/              ← 各页面（每个页面独立文件）
//     models.dart         ← 数据模型
//     storage.dart        ← 本地持久化
//     *_service.dart      ← 各服务层

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'theme/colors.dart';
import 'storage.dart';
import 'models.dart';
import 'ai_service.dart';
import 'auth_service.dart';
import 'cloud_sync_service.dart';
import 'pages/shell.dart';

// ═══════════════════════════════════════════════
// 全局状态
// ═══════════════════════════════════════════════

late Storage gStorage;
bool gStorageReady = false;
late String gDocDir;

/// 主题变更回调（供 SettingsPage 调用）
VoidCallback? gOnThemeChange;

// ═══════════════════════════════════════════════
// 入口
// ═══════════════════════════════════════════════

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = await getApplicationDocumentsDirectory();
  gDocDir = dir.path;
  gStorage = Storage('$gDocDir/ipad_boss_data.json');
  await gStorage.load();
  await gStorage.prepareForUserDataStartup();
  await AuthService.init(gStorage);
  CloudSyncService.startBackgroundSync(storage: gStorage, docDir: gDocDir);
  final aiMap = gStorage.getSettings()['aiConfig'] as Map<String, dynamic>?;
  AiService.setConfig(AiConfig.fromMap(aiMap));
  AiService.setPromptRules(gStorage.getAiPromptRules());
  gStorageReady = true;
  runApp(const IpadBossApp());
}

// ═══════════════════════════════════════════════
// App Widget
// ═══════════════════════════════════════════════

class IpadBossApp extends StatefulWidget {
  const IpadBossApp({Key? key}) : super(key: key);
  @override
  State<IpadBossApp> createState() => _IpadBossAppState();
}

class _IpadBossAppState extends State<IpadBossApp> {
  bool _themeLoaded = false;

  @override
  void initState() {
    super.initState();
    gOnThemeChange = () => setState(() {});
    _loadTheme();
  }

  @override
  void dispose() {
    gOnThemeChange = null;
    super.dispose();
  }

  void _loadTheme() {
    if (gStorageReady && !_themeLoaded) {
      _themeLoaded = true;
      final settings = gStorage.getSettings();
      final saved = settings['themeMode'] as String?;
      if (saved == 'light') {
        gThemeMode = ThemeMode.light;
      } else {
        gThemeMode = ThemeMode.dark;
        if (saved != 'dark') {
          settings['themeMode'] = 'dark';
          gStorage.saveSettings(settings);
        }
      }
      setState(() {});
    } else if (!gStorageReady) {
      Future.delayed(const Duration(milliseconds: 200), _loadTheme);
    }
  }

  @override
  Widget build(BuildContext context) {
    C.useLightTheme(gThemeMode == ThemeMode.light);
    return MaterialApp(
      title: '货脉',
      debugShowCheckedModeBanner: false,
      themeMode: gThemeMode,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      home: const MainShell(),
    );
  }

  ThemeData _buildLightTheme() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: C.bgDeep,
      fontFamily: null,
      colorScheme: ColorScheme.light(
        primary: C.primary,
        secondary: C.blue,
        tertiary: C.green,
        surface: C.bgCard,
        onPrimary: const Color(0xFF111B0F),
        onSurface: C.t1,
        outline: C.border,
      ),
    );
    final radius = BorderRadius.circular(C.radiusMd);
    return base.copyWith(
      visualDensity: VisualDensity.standard,
      splashColor: C.primary.withValues(alpha: 0.10),
      highlightColor: C.t1.withValues(alpha: 0.04),
      dividerColor: C.divider,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: C.t1,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: C.t1,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: C.bgCard,
        hintStyle: TextStyle(color: C.t3, fontSize: 13),
        labelStyle: TextStyle(color: C.t2, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: C.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: C.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(C.radiusMd)),
          borderSide: BorderSide(color: C.primary, width: 1.4),
        ),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        color: C.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(C.radiusLg),
          side: BorderSide(color: C.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: C.primary,
          foregroundColor: const Color(0xFF111B0F),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(C.radiusMd),
          ),
          textStyle: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: C.primary,
          foregroundColor: const Color(0xFF111B0F),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(C.radiusMd),
          ),
          textStyle: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: C.t1,
          side: BorderSide(color: C.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(C.radiusMd),
          ),
        ),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: C.bgDeep,
      fontFamily: null,
      colorScheme: ColorScheme.dark(
        primary: C.primary,
        secondary: C.blue,
        tertiary: C.green,
        surface: C.bgCard,
        onPrimary: Colors.black,
        onSurface: C.t1,
      ),
    );
    final radius = BorderRadius.circular(C.radiusMd);
    return base.copyWith(
      visualDensity: VisualDensity.standard,
      splashColor: C.cyan.withValues(alpha: 0.08),
      highlightColor: C.t1.withValues(alpha: 0.04),
      dividerColor: C.divider,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: C.t1,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: C.t1,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: C.bgSurface,
        hintStyle: TextStyle(color: C.t3, fontSize: 13),
        labelStyle: TextStyle(color: C.t2, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: C.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: C.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(C.radiusMd)),
          borderSide: BorderSide(color: C.primary, width: 1.4),
        ),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        color: C.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(C.radiusLg),
          side: BorderSide(color: C.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: C.primary,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(C.radiusMd),
          ),
          textStyle: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: C.primary,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(C.radiusMd),
          ),
          textStyle: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: C.t1,
          side: BorderSide(color: C.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(C.radiusMd),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// iPad 型号常量
// ═══════════════════════════════════════════════

const List<Map<String, String>> iPadModels = [
  {'name': 'iPad Pro 13 2025 (M5)', 'chip': 'M5'},
  {'name': 'iPad Pro 11 2025 (M5)', 'chip': 'M5'},
  {'name': 'iPad Pro 13 2024 (M4)', 'chip': 'M4'},
  {'name': 'iPad Pro 11 2024 (M4)', 'chip': 'M4'},
  {'name': 'iPad Pro 12.9 2022 (M2)', 'chip': 'M2'},
  {'name': 'iPad Pro 11 2022 (M2)', 'chip': 'M2'},
  {'name': 'iPad Pro 12.9 2021 (M1)', 'chip': 'M1'},
  {'name': 'iPad Pro 11 2021 (M1)', 'chip': 'M1'},
  {'name': 'iPad Pro 12.9 2020 (A12Z)', 'chip': 'A12Z'},
  {'name': 'iPad Pro 11 2020 (A12Z)', 'chip': 'A12Z'},
  {'name': 'iPad Pro 12.9 2018 (A12X)', 'chip': 'A12X'},
  {'name': 'iPad Pro 11 2018 (A12X)', 'chip': 'A12X'},
  {'name': 'iPad Air 13 2026 (M4)', 'chip': 'M4'},
  {'name': 'iPad Air 11 2026 (M4)', 'chip': 'M4'},
  {'name': 'iPad Air 13 2025 (M3)', 'chip': 'M3'},
  {'name': 'iPad Air 11 2025 (M3)', 'chip': 'M3'},
  {'name': 'iPad Air 13 2024 (M2)', 'chip': 'M2'},
  {'name': 'iPad Air 11 2024 (M2)', 'chip': 'M2'},
  {'name': 'iPad Air 5 (M1)', 'chip': 'M1'},
  {'name': 'iPad Air 4 (A14)', 'chip': 'A14'},
  {'name': 'iPad Air 3 (A12)', 'chip': 'A12'},
  {'name': 'iPad A16 (A16)', 'chip': 'A16'},
  {'name': 'iPad 10 (A14)', 'chip': 'A14'},
  {'name': 'iPad 9 (A13)', 'chip': 'A13'},
  {'name': 'iPad 8 (A12)', 'chip': 'A12'},
  {'name': 'iPad 7 (A10)', 'chip': 'A10'},
  {'name': 'iPad mini 7 (A17 Pro)', 'chip': 'A17 Pro'},
  {'name': 'iPad mini 6 (A15)', 'chip': 'A15'},
  {'name': 'iPad mini 5 (A12)', 'chip': 'A12'},
];

const List<String> iPadCapacities = ['64G', '128G', '256G', '512G', '1TB'];
const List<String> iPadColors = [
  '深空灰',
  '银色',
  '星光色',
  '粉色',
  '紫色',
  '蓝色',
  '玫瑰金',
  '金色',
  '绿色',
  '黄色',
];
const List<String> iPadNetworks = ['WiFi', 'WiFi+蜂窝'];
const List<String> iPadConditions = ['全新', '99新', '95新', '9成新', '8成新', '7成新'];
const List<String> PurchaseChannels = [
  '华强北同行',
  '回收商A',
  '回收商B',
  '同行调货',
  '闲鱼回收',
  '线下收购',
  '海外代购',
];

// ═══════════════════════════════════════════════
// 演示数据
// ═══════════════════════════════════════════════

String _fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Future<void> seedDemoData() async {
  final now = DateTime.now();
  final d1 = now.subtract(const Duration(days: 42));
  final d2 = now.subtract(const Duration(days: 12));
  final d3 = now.subtract(const Duration(days: 5));
  final d4 = now.subtract(const Duration(days: 36));
  final d5 = now.subtract(const Duration(days: 1));

  await gStorage.addDevice(
    Device(
      id: 'demo1',
      serial: 'F9XNL3C0JCD6',
      model: 'iPad Pro 12.9 2021',
      capacity: '256G',
      color: '深空灰',
      network: 'WiFi+蜂窝',
      condition: '95新',
      batteryHealth: 92,
      cycleCount: 118,
      idLockClean: true,
      purchaseCost: 395000,
      purchaseChannel: '华强北同行',
      purchaseDate: _fmt(d1),
      sellPrice: 458000,
      status: 'listed',
      createdAt: _fmt(d1),
    ),
  );
  await gStorage.addDevice(
    Device(
      id: 'demo2',
      serial: 'F2XKL2P0JWD8',
      model: 'iPad Air 5',
      capacity: '64G',
      color: '星光色',
      network: 'WiFi',
      condition: '9成新',
      batteryHealth: 89,
      cycleCount: 156,
      idLockClean: true,
      purchaseCost: 235000,
      purchaseChannel: '回收商A',
      purchaseDate: _fmt(d2),
      sellPrice: 298000,
      status: 'listed',
      createdAt: _fmt(d2),
    ),
  );
  await gStorage.addDevice(
    Device(
      id: 'demo3',
      serial: 'F3WLM3Q0KRE2',
      model: 'iPad Pro 11 2022',
      capacity: '128G',
      color: '银色',
      network: 'WiFi',
      condition: '99新',
      batteryHealth: 98,
      cycleCount: 32,
      idLockClean: true,
      purchaseCost: 470000,
      purchaseChannel: '同行调货',
      purchaseDate: _fmt(d3),
      sellPrice: 568000,
      status: 'sold',
      sellChannel: '闲鱼',
      sellDate: _fmt(now),
      repairCost: 8000,
      platformFee: 2000,
      logisticsCost: 3000,
      buyerContact: '微信·李',
      createdAt: _fmt(d3),
    ),
  );
  await gStorage.addDevice(
    Device(
      id: 'demo4',
      serial: 'F4VNM4R0LSF3',
      model: 'iPad 10',
      capacity: '64G',
      color: '银色',
      network: 'WiFi',
      condition: '8成新',
      batteryHealth: 85,
      cycleCount: 210,
      idLockClean: true,
      purchaseCost: 190000,
      purchaseChannel: '回收商B',
      purchaseDate: _fmt(d4),
      sellPrice: 228000,
      status: 'listed',
      createdAt: _fmt(d4),
    ),
  );
  await gStorage.addDevice(
    Device(
      id: 'demo5',
      serial: 'F5VNM5R0LSF4',
      model: 'iPad mini 6',
      capacity: '256G',
      color: '粉色',
      network: 'WiFi',
      condition: '95新',
      batteryHealth: 96,
      cycleCount: 45,
      idLockClean: true,
      purchaseCost: 300000,
      purchaseChannel: '回收商A',
      purchaseDate: _fmt(d5),
      sellPrice: 368000,
      status: 'in_stock',
      createdAt: _fmt(d5),
    ),
  );
  await gStorage.addOrder(
    Order(
      id: 'o1',
      deviceId: 'demo3',
      deviceName: 'iPad Pro 11 2022 128G',
      buyer: '微信·李',
      channel: '闲鱼',
      amount: 568000,
      profit: 85000,
      status: 'shipped',
      createdAt: _fmt(now) + ' 14:32',
    ),
  );
  await gStorage.addOrder(
    Order(
      id: 'o2',
      deviceId: 'demo3',
      deviceName: 'iPad 9 64G',
      buyer: '抖音·王',
      channel: '抖音',
      amount: 168000,
      profit: 28000,
      status: 'pending',
      createdAt: _fmt(now) + ' 10:15',
    ),
  );
  await gStorage.addAgent(
    Agent(
      id: 'a1',
      name: '小陈',
      phone: '138****8888',
      commissionRate: 0.08,
      totalGmv: 168000,
      createdAt: _fmt(d2),
    ),
  );
  await gStorage.addRepairOrder(
    RepairOrder(
      id: 'r1',
      deviceId: 'demo3',
      deviceName: 'iPad Pro 11 2022',
      type: '换电池',
      cost: 8000,
      status: '完成',
      note: '原装电池',
      createdAt: _fmt(d3),
    ),
  );
}
