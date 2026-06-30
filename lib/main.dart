// 机掌柜 · 二手iPad经营工作台
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
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'theme/colors.dart';
import 'storage.dart';
import 'models.dart';
import 'ai_service.dart';
import 'auth_service.dart';
import 'login_page.dart';
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
  await AuthService.init(gStorage);
  final aiMap = gStorage.getSettings()['aiConfig'] as Map<String, dynamic>?;
  AiService.setConfig(AiConfig.fromMap(aiMap));
  if (gStorage.getDevices().isEmpty) {
    await seedDemoData();
  }
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
      final saved = gStorage.getSettings()['themeMode'] as String?;
      switch (saved) {
        case 'light':
          gThemeMode = ThemeMode.light;
          break;
        case 'system':
          gThemeMode = ThemeMode.system;
          break;
        default:
          gThemeMode = ThemeMode.dark;
      }
      setState(() {});
    } else if (!gStorageReady) {
      Future.delayed(const Duration(milliseconds: 200), _loadTheme);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '机掌柜',
      debugShowCheckedModeBanner: false,
      themeMode: gThemeMode,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      home: AuthService.isLoggedIn ? const MainShell() : const LoginPage(),
    );
  }

  ThemeData _buildLightTheme() => ThemeData(
    scaffoldBackgroundColor: const Color(0xFFF0F2F5),
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF4F46E5),
      secondary: Color(0xFF3B82F6),
      surface: Colors.white,
      onPrimary: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: true,
      iconTheme: IconThemeData(color: Color(0xFF111827)),
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: Color(0xFF111827),
        letterSpacing: 0.3,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
      ),
    ),
    dividerColor: const Color(0xFFEEF0F3),
    cardTheme: CardTheme(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE5E7EB), width: 0.8),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );

  ThemeData _buildDarkTheme() => ThemeData(
    scaffoldBackgroundColor: const Color(0xFF050507),
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF00F0FF),
      secondary: Color(0xFFB829FF),
      surface: Color(0xFF0c0e14),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0a0c14),
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: Color(0xFFE0E2E8),
        letterSpacing: 0.3,
      ),
    ),
  );
}

// ═══════════════════════════════════════════════
// iPad 型号常量
// ═══════════════════════════════════════════════

const List<Map<String, String>> iPadModels = [
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
  {'name': 'iPad Air 11 2024 (M3)', 'chip': 'M3'},
  {'name': 'iPad Air 13 2024 (M3)', 'chip': 'M3'},
  {'name': 'iPad Air 5 (M1)', 'chip': 'M1'},
  {'name': 'iPad Air 4 (A14)', 'chip': 'A14'},
  {'name': 'iPad Air 3 (A12)', 'chip': 'A12'},
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
  '深空灰', '银色', '星光色', '粉色', '紫色', '蓝色', '玫瑰金', '金色', '绿色', '黄色',
];
const List<String> iPadNetworks = ['WiFi', 'WiFi+蜂窝'];
const List<String> iPadConditions = ['全新', '99新', '95新', '9成新', '8成新', '7成新'];
const List<String> PurchaseChannels = [
  '华强北同行', '回收商A', '回收商B', '同行调货', '闲鱼回收', '线下收购', '海外代购',
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

  await gStorage.addDevice(Device(
    id: 'demo1', serial: 'F9XNL3C0JCD6', model: 'iPad Pro 12.9 2021',
    capacity: '256G', color: '深空灰', network: 'WiFi+蜂窝', condition: '95新',
    batteryHealth: 92, cycleCount: 118, idLockClean: true,
    purchaseCost: 395000, purchaseChannel: '华强北同行', purchaseDate: _fmt(d1),
    sellPrice: 458000, status: 'listed', createdAt: _fmt(d1),
  ));
  await gStorage.addDevice(Device(
    id: 'demo2', serial: 'F2XKL2P0JWD8', model: 'iPad Air 5',
    capacity: '64G', color: '星光色', network: 'WiFi', condition: '9成新',
    batteryHealth: 89, cycleCount: 156, idLockClean: true,
    purchaseCost: 235000, purchaseChannel: '回收商A', purchaseDate: _fmt(d2),
    sellPrice: 298000, status: 'listed', createdAt: _fmt(d2),
  ));
  await gStorage.addDevice(Device(
    id: 'demo3', serial: 'F3WLM3Q0KRE2', model: 'iPad Pro 11 2022',
    capacity: '128G', color: '银色', network: 'WiFi', condition: '99新',
    batteryHealth: 98, cycleCount: 32, idLockClean: true,
    purchaseCost: 470000, purchaseChannel: '同行调货', purchaseDate: _fmt(d3),
    sellPrice: 568000, status: 'sold', sellChannel: '闲鱼', sellDate: _fmt(now),
    repairCost: 8000, platformFee: 2000, logisticsCost: 3000,
    buyerContact: '微信·李', createdAt: _fmt(d3),
  ));
  await gStorage.addDevice(Device(
    id: 'demo4', serial: 'F4VNM4R0LSF3', model: 'iPad 10',
    capacity: '64G', color: '银色', network: 'WiFi', condition: '8成新',
    batteryHealth: 85, cycleCount: 210, idLockClean: true,
    purchaseCost: 190000, purchaseChannel: '回收商B', purchaseDate: _fmt(d4),
    sellPrice: 228000, status: 'listed', createdAt: _fmt(d4),
  ));
  await gStorage.addDevice(Device(
    id: 'demo5', serial: 'F5VNM5R0LSF4', model: 'iPad mini 6',
    capacity: '256G', color: '粉色', network: 'WiFi', condition: '95新',
    batteryHealth: 96, cycleCount: 45, idLockClean: true,
    purchaseCost: 300000, purchaseChannel: '回收商A', purchaseDate: _fmt(d5),
    sellPrice: 368000, status: 'in_stock', createdAt: _fmt(d5),
  ));
  await gStorage.addOrder(Order(
    id: 'o1', deviceId: 'demo3', deviceName: 'iPad Pro 11 2022 128G',
    buyer: '微信·李', channel: '闲鱼', amount: 568000, profit: 85000,
    status: 'shipped', createdAt: _fmt(now) + ' 14:32',
  ));
  await gStorage.addOrder(Order(
    id: 'o2', deviceId: 'demo3', deviceName: 'iPad 9 64G',
    buyer: '抖音·王', channel: '抖音', amount: 168000, profit: 28000,
    status: 'pending', createdAt: _fmt(now) + ' 10:15',
  ));
  await gStorage.addAgent(Agent(
    id: 'a1', name: '小陈', phone: '138****8888',
    commissionRate: 0.08, totalGmv: 168000, createdAt: _fmt(d2),
  ));
  await gStorage.addRepairOrder(RepairOrder(
    id: 'r1', deviceId: 'demo3', deviceName: 'iPad Pro 11 2022',
    type: '换电池', cost: 8000, status: '完成', note: '原装电池',
    createdAt: _fmt(d3),
  ));
}
