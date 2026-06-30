import 'dart:math' as math;
import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'models.dart';
import 'storage.dart';
import 'ai_service.dart';
import 'backup_service.dart';
import 'webdav_service.dart';
import 'serial_decoder.dart';
import 'update_service.dart';
import 'auth_service.dart';
import 'login_page.dart';
import 'api_service.dart';
import 'erp_pages.dart';

late Storage gStorage;
bool gStorageReady = false;
late String gDocDir;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = await getApplicationDocumentsDirectory();
  gDocDir = dir.path;
  gStorage = Storage('$gDocDir/ipad_boss_data.json');
  await gStorage.load();
  // 初始化认证服务
  await AuthService.init(gStorage);
  // 从 settings 注入 AI 配置
  final aiMap = gStorage.getSettings()['aiConfig'] as Map<String, dynamic>?;
  AiService.setConfig(AiConfig.fromMap(aiMap));
  if (gStorage.getDevices().isEmpty) {
    await _seedDemoData();
  }
  gStorageReady = true;
  runApp(const IpadBossApp());
}

String _fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Future<void> _seedDemoData() async {
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

/// 全局主题状态：用于跨页面切换主题
ThemeMode gThemeMode = ThemeMode.light;
bool gThemeLoaded = false;

class IpadBossApp extends StatefulWidget {
  const IpadBossApp({Key? key}) : super(key: key);
  @override
  State<IpadBossApp> createState() => _IpadBossAppState();
}

class _IpadBossAppState extends State<IpadBossApp> {
  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  void _loadTheme() {
    if (gStorageReady && !gThemeLoaded) {
      gThemeLoaded = true;
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

  void changeTheme(ThemeMode mode) {
    setState(() => gThemeMode = mode);
    gStorage.getSettings()['themeMode'] =
        mode == ThemeMode.light
            ? 'light'
            : mode == ThemeMode.system
            ? 'system'
            : 'dark';
    gStorage.saveSettings(gStorage.getSettings());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '机掌柜',
      debugShowCheckedModeBanner: false,
      themeMode: gThemeMode,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF4F6F8),
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF0F766E),
          secondary: Color(0xFF2563EB),
          surface: Colors.white,
          onPrimary: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Color(0xFF1A1A2E)),
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A2E),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFFFFFFFF),
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
            borderSide: BorderSide(color: Color(0xFFE1E5EA)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
            borderSide: BorderSide(color: Color(0xFFE1E5EA)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
            borderSide: BorderSide(color: Color(0xFF0F766E), width: 1.4),
          ),
        ),
        dividerColor: Color(0xFFE1E5EA),
      ),
      darkTheme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF101214),
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF2DD4BF),
          secondary: Color(0xFF60A5FA),
          surface: Color(0xFF181B1F),
        ),
      ),
      home: AuthService.isLoggedIn ? const MainShell() : const LoginPage(),
    );
  }
}

/// 颜色常量（经营工具风格：中性色为主，少量状态色）
class C {
  // 背景 & 卡片
  static Color get bg =>
      gThemeMode == ThemeMode.light
          ? const Color(0xFFF8FAFC)
          : const Color(0xFF0F1419);
  static Color get card =>
      gThemeMode == ThemeMode.light
          ? const Color(0xFFFFFFFF)
          : const Color(0xFF171D23);
  static Color get cardMuted =>
      gThemeMode == ThemeMode.light
          ? const Color(0xFFF1F5F9)
          : const Color(0xFF202832);
  static Color get line =>
      gThemeMode == ThemeMode.light
          ? const Color(0xFFE2E8F0)
          : const Color(0xFF2B3440);
  static Color get t1 =>
      gThemeMode == ThemeMode.light
          ? const Color(0xFF0F172A)
          : const Color(0xFFE5EAF0);
  static Color get t2 =>
      gThemeMode == ThemeMode.light
          ? const Color(0xFF475569)
          : const Color(0xFF9AA6B2);
  static Color get t3 =>
      gThemeMode == ThemeMode.light
          ? const Color(0xFF7C8A9A)
          : const Color(0xFF6F7C8A);
  static Color get nav =>
      gThemeMode == ThemeMode.light
          ? const Color(0xFFFFFFFF)
          : const Color(0xFF121820);
  static Color get selected =>
      gThemeMode == ThemeMode.light
          ? const Color(0xFFE6F4F1)
          : const Color(0xFF12302C);
  static const brand = Color(0xFF047857);
  static const brand2 = Color(0xFF334155);
  static const brandLight = Color(0xFFDDF4EA);
  static const green = Color(0xFF059669);
  static const red = Color(0xFFDC2626);
  static const orange = Color(0xFFD97706);
  static const pink = Color(0xFFDB2777);
  static const purple = Color(0xFF7C3AED);
  static const blue = Color(0xFF2563EB);
}

String yuan(int fen) => '¥${(fen / 100).round()}';

void toast(BuildContext ctx, String m) {
  ScaffoldMessenger.of(ctx).hideCurrentSnackBar();
  ScaffoldMessenger.of(ctx).showSnackBar(
    SnackBar(
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_rounded, color: C.brand2, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              m,
              style: TextStyle(
                fontSize: 13,
                color: C.t1,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(40, 0, 40, 200),
      duration: const Duration(milliseconds: 2000),
      backgroundColor: C.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: C.brand2, width: 1.2),
      ),
      elevation: 8,
    ),
  );
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmText = '确定',
  Color confirmColor = C.red,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder:
        (ctx) => AlertDialog(
          backgroundColor: C.card,
          title: Text(title, style: TextStyle(color: C.t1, fontSize: 16)),
          content: Text(message, style: TextStyle(color: C.t2, fontSize: 13)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('取消', style: TextStyle(color: C.t2)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(confirmText, style: TextStyle(color: confirmColor)),
            ),
          ],
        ),
  );
  return ok == true;
}

const Set<String> _localOnlySettingKeys = {
  'auth_token',
  'auth_email',
  'webdavConfig',
};

dynamic _cloneJsonValue(dynamic value) {
  if (value is Map) {
    return value.map(
      (key, child) => MapEntry(key.toString(), _cloneJsonValue(child)),
    );
  }
  if (value is List) {
    return value.map(_cloneJsonValue).toList();
  }
  return value;
}

Map<String, dynamic> snapshotLocalOnlySettings(Storage storage) {
  final settings = storage.getSettings();
  final local = <String, dynamic>{};
  for (final key in _localOnlySettingKeys) {
    if (settings.containsKey(key)) {
      local[key] = _cloneJsonValue(settings[key]);
    }
  }
  return local;
}

Future<void> restoreLocalOnlySettings(
  Storage storage,
  Map<String, dynamic> localSettings,
) async {
  final settings = Map<String, dynamic>.from(storage.getSettings());
  for (final key in _localOnlySettingKeys) {
    if (localSettings.containsKey(key)) {
      settings[key] = _cloneJsonValue(localSettings[key]);
    } else {
      settings.remove(key);
    }
  }
  await storage.saveSettings(settings);
}

Map<String, dynamic> storagePayloadForSync(Storage storage) {
  final data = Map<String, dynamic>.from(storage.toFullMap());
  final settings = Map<String, dynamic>.from((data['settings'] as Map?) ?? {});
  for (final key in _localOnlySettingKeys) {
    settings.remove(key);
  }
  data['settings'] = settings;
  return data;
}

Widget primaryBtn(String label, VoidCallback onTap) => SizedBox(
  width: double.infinity,
  child: ElevatedButton(
    onPressed: onTap,
    style: ElevatedButton.styleFrom(
      backgroundColor: C.brand,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 0,
    ),
    child: Text(
      label,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    ),
  ),
);

Widget ghostBtn(String label, VoidCallback onTap) => SizedBox(
  width: double.infinity,
  child: OutlinedButton(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      foregroundColor: C.t1,
      side: BorderSide(color: C.line),
      padding: EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    child: Text(
      label,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    ),
  ),
);

class CardBox extends StatelessWidget {
  final Widget child;
  const CardBox({Key? key, required this.child}) : super(key: key);
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: C.card,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: C.line),
    ),
    child: child,
  );
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;
  final VoidCallback? onTap;
  const SectionTitle(this.title, {Key? key, this.trailing, this.onTap})
    : super(key: key);
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: C.t1,
        ),
      ),
      const Spacer(),
      if (trailing != null)
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Text(
              trailing!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: C.brand,
              ),
            ),
          ),
        ),
    ],
  );
}

class StatusChip extends StatelessWidget {
  final String text;
  final Color color;
  const StatusChip(this.text, this.color, {Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700),
    ),
  );
}

class PageScaffold extends StatelessWidget {
  final Widget child;
  final Widget? title;
  final Widget? subtitle;
  final Widget? action;
  const PageScaffold({
    Key? key,
    required this.child,
    this.title,
    this.subtitle,
    this.action,
  }) : super(key: key);
  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      children: [
        if (title != null || action != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title != null) title!,
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: subtitle!,
                        ),
                    ],
                  ),
                ),
                if (action != null) action!,
              ],
            ),
          ),
        child,
      ],
    ),
  );
}

Widget appScaffold(BuildContext context, String title, Widget body) => Scaffold(
  backgroundColor: C.bg,
  appBar: AppBar(
    backgroundColor: C.bg,
    elevation: 0,
    leading: IconButton(
      icon: Icon(Icons.chevron_left, color: C.t1),
      onPressed: () => Navigator.pop(context),
    ),
    title: Text(
      title,
      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: C.t1),
    ),
    centerTitle: true,
  ),
  body: SafeArea(child: body),
);

// ====== iPad型号列表（可手动选择） ======
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

// ====== 主框架（底部导航） ======
class MainShell extends StatefulWidget {
  const MainShell({Key? key}) : super(key: key);
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  final _homeKey = GlobalKey<_HomePageState>();
  final _stockKey = GlobalKey<_StockPageState>();
  final _orderKey = GlobalKey<_OrderPageState>();

  void _onTap(int i) {
    if (i == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ScanPage()),
      ).then((_) {
        _homeKey.currentState?._refresh();
        _stockKey.currentState?._refresh();
        _orderKey.currentState?._refresh();
      });
      return;
    }
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 820;
    final pages = <Widget>[
      HomePage(key: _homeKey),
      StockPage(key: _stockKey),
      const SizedBox(),
      OrderPage(key: _orderKey),
      const MePage(),
    ];
    if (isWide) {
      return Scaffold(
        backgroundColor: C.bg,
        body: Row(
          children: [
            _SideNav(index: _index, onTap: _onTap),
            Expanded(child: IndexedStack(index: _index, children: pages)),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: C.bg,
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: _NavBar(index: _index, onTap: _onTap),
    );
  }
}

class _NavDef {
  final IconData icon;
  final String name;
  const _NavDef(this.icon, this.name);
}

const List<_NavDef> _mainNav = [
  _NavDef(Icons.dashboard_outlined, '看板'),
  _NavDef(Icons.inventory_2_outlined, '库存'),
  _NavDef(Icons.qr_code_scanner_rounded, '收货'),
  _NavDef(Icons.receipt_long_outlined, '订单'),
  _NavDef(Icons.apps_outlined, '更多'),
];

class _SideNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _SideNav({required this.index, required this.onTap});
  @override
  Widget build(BuildContext context) => SafeArea(
    right: false,
    child: Container(
      width: 232,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      decoration: BoxDecoration(
        color: C.nav,
        border: Border(right: BorderSide(color: C.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 18),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: C.selected,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.tablet_mac_rounded,
                    color: C.brand,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '机掌柜',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: C.t1,
                      ),
                    ),
                    Text('经营工作台', style: TextStyle(fontSize: 11, color: C.t3)),
                  ],
                ),
              ],
            ),
          ),
          _item(0),
          _item(1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => onTap(2),
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                label: const Text('扫码收货'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: C.brand,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
            ),
          ),
          _item(3),
          _item(4),
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: C.cardMuted,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: C.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '今日提醒',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: C.t1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '先处理待质检与待发货设备',
                  style: TextStyle(fontSize: 11, color: C.t2, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _item(int navIndex) {
    final item = _mainNav[navIndex];
    final on = index == navIndex;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () => onTap(navIndex),
        borderRadius: BorderRadius.circular(9),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: on ? C.selected : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            children: [
              Icon(item.icon, size: 20, color: on ? C.brand : C.t2),
              const SizedBox(width: 11),
              Text(
                item.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                  color: on ? C.t1 : C.t2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _NavBar({required this.index, required this.onTap});
  @override
  Widget build(BuildContext context) => Container(
    height: 62 + MediaQuery.of(context).padding.bottom,
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
    decoration: BoxDecoration(
      color: C.nav,
      border: Border(top: BorderSide(color: C.line)),
    ),
    child: Row(children: [_ni(0), _ni(1), _scanItem(), _ni(3), _ni(4)]),
  );
  Widget _scanItem() {
    final item = _mainNav[2];
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 28,
              decoration: BoxDecoration(
                color: C.brand,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(item.icon, color: Colors.white, size: 18),
            ),
            const SizedBox(height: 3),
            Text(
              item.name,
              style: const TextStyle(
                fontSize: 10,
                color: C.brand,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ni(int idx) {
    final on = index == idx;
    final item = _mainNav[idx];
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(idx),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 38,
              height: 28,
              decoration: BoxDecoration(
                color: on ? C.selected : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(item.icon, size: 19, color: on ? C.brand : C.t3),
            ),
            const SizedBox(height: 3),
            Text(
              item.name,
              style: TextStyle(
                fontSize: 10,
                color: on ? C.brand : C.t3,
                fontWeight: on ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ====== 图表 ======
class LineChartPainter extends CustomPainter {
  final List<double> data;
  final List<String> labels;
  final int labelStep; // 标签显示步长，1=每个都显示，2=每2个显示1个
  LineChartPainter({
    required this.data,
    required this.labels,
    this.labelStep = 1,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final padL = 34.0, padB = 18.0, padT = 6.0;
    final chartW = w - padL - 6, chartH = h - padB - padT;
    double maxV = data.fold(0.0, (a, b) => a > b ? a : b);
    if (maxV == 0) maxV = 1;
    final gridPaint =
        Paint()
          ..color = C.line
          ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = padT + chartH * i / 4;
      canvas.drawLine(Offset(padL, y), Offset(padL + chartW, y), gridPaint);
    }
    final tp = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.right,
    );
    for (int i = 0; i <= 2; i++) {
      final v = (maxV * (1 - i / 2)).toInt();
      // Y轴显示元（分转元），不再用 k
      tp.text = TextSpan(
        text: '¥${(v / 100).toStringAsFixed(0)}',
        style: TextStyle(color: C.t3, fontSize: 9),
      );
      tp.layout();
      tp.paint(canvas, Offset(0, padT + chartH * i / 2 - tp.height / 2));
    }
    for (int i = 0; i < labels.length; i++) {
      if (i % labelStep != 0 && i != labels.length - 1)
        continue; // 隔点显示，最后一个始终显示
      final x = padL + chartW * i / (labels.length - 1);
      tp.text = TextSpan(
        text: labels[i],
        style: TextStyle(color: C.t3, fontSize: 9),
      );
      tp.layout();
      tp.paint(canvas, Offset(x - tp.width / 2, h - padB + 2));
    }
    final pts = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final x = padL + chartW * i / (data.length - 1);
      final y = padT + chartH * (1 - data[i] / maxV);
      pts.add(Offset(x, y));
    }
    final fillPath = Path()..moveTo(pts.first.dx, padT + chartH);
    for (final p in pts) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(pts.last.dx, padT + chartH);
    fillPath.close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          colors: [C.brand2.withOpacity(0.25), C.brand2.withOpacity(0.02)],
        ).createShader(Rect.fromLTWH(padL, padT, chartW, chartH)),
    );
    final linePath = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts) {
      linePath.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = C.brand2
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    for (final p in pts) {
      canvas.drawCircle(p, 2.5, Paint()..color = C.brand2);
    }
  }

  @override
  bool shouldRepaint(covariant LineChartPainter old) => old.data != data;
}

class _Seg {
  final double v;
  final Color c;
  const _Seg(this.v, this.c);
}

class DonutPainter extends CustomPainter {
  final List<_Seg> segs;
  final String centerText;
  DonutPainter({required this.segs, required this.centerText});
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 4;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final total = segs.fold<double>(0.0, (a, s) => a + s.v);
    if (total == 0) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = C.line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14,
      );
    } else {
      double start = -math.pi / 2;
      for (final seg in segs) {
        final sweep = (seg.v / total) * 2 * math.pi;
        canvas.drawArc(
          rect,
          start,
          sweep,
          false,
          Paint()
            ..color = seg.c
            ..style = PaintingStyle.stroke
            ..strokeWidth = 14
            ..strokeCap = StrokeCap.round,
        );
        start += sweep + 0.04;
      }
    }
    final tp = TextPainter(
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )
      ..text = TextSpan(
        text: centerText,
        style: TextStyle(color: C.t2, fontSize: 10),
      );
    tp.layout();
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant DonutPainter old) => false;
}

// ====== 首页 ======
class _ChartData {
  final List<double> profit;
  final List<String> labels;
  final String title;
  final int total;
  _ChartData(this.profit, this.labels, this.title, this.total);
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Stats? stats;
  List<Device> stagnant = [];
  List<DailyStat> daily = [];
  Map<String, int> channelGmv = {};
  int yesterdayProfit = 0;
  int yesterdayOrders = 0;
  // 图表周期：0=近7天，1=当月，2=近12个月
  int chartMode = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    final s = gStorage.computeStats();
    final stg = gStorage.getDevices().where((d) => d.isStagnant).toList();
    final dl = gStorage.getDailyStats(days: 7);
    final cg = gStorage.getChannelGmv();
    final yp = gStorage.getYesterdayProfit();
    final yo = gStorage.getYesterdayOrderCount();
    setState(() {
      stats = s;
      stagnant = stg;
      daily = dl;
      channelGmv = cg;
      yesterdayProfit = yp;
      yesterdayOrders = yo;
    });
  }

  /// 根据当前 chartMode 返回图表数据 + 标签 + 标题
  _ChartData _chartData() {
    if (chartMode == 0) {
      final profit = daily.map((d) => d.profit.toDouble()).toList();
      final labels = daily.map((d) => d.date.substring(5)).toList();
      return _ChartData(
        profit,
        labels,
        '近7天毛利趋势',
        daily.fold(0, (a, d) => a + d.profit),
      );
    }
    if (chartMode == 1) {
      // 当月每日
      final now = DateTime.now();
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      final orders = gStorage.getOrders();
      final ms = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final profit = <double>[];
      final labels = <String>[];
      for (int i = 1; i <= daysInMonth; i++) {
        final ds = '$ms-${i.toString().padLeft(2, '0')}';
        int p = 0;
        for (final o in orders) {
          if (o.createdAt.startsWith(ds)) p += o.profit;
        }
        profit.add(p.toDouble());
        labels.add(i.toString());
      }
      final total = profit.fold<double>(0.0, (a, b) => a + b).toInt();
      return _ChartData(profit, labels, '当月每日毛利', total);
    }
    // 近12个月
    final monthly = gStorage.getMonthlyStats(months: 12);
    final profit = monthly.map((d) => d.profit.toDouble()).toList();
    final labels = monthly.map((d) => d.date.substring(5)).toList();
    final total = monthly.fold<int>(0, (a, d) => a + d.profit);
    return _ChartData(profit, labels, '近12月毛利趋势', total);
  }

  @override
  Widget build(BuildContext context) {
    final s = stats ?? Stats();
    final chart = _chartData();
    final segColors = [C.brand, C.brand2, C.purple, C.orange, C.pink, C.green];
    final segList = <_Seg>[];
    int ci = 0;
    channelGmv.forEach((k, v) {
      if (v > 0) {
        segList.add(_Seg(v.toDouble(), segColors[ci % segColors.length]));
        ci++;
      }
    });
    // 趋势对比：今日 vs 昨日
    final yesterdayGmv = gStorage.getYesterdayGmv();
    final profitDiff = s.grossProfit - yesterdayProfit;
    final orderDiff = s.orderCount - yesterdayOrders;
    final gmvDiffPct =
        yesterdayGmv > 0 ? ((s.gmv - yesterdayGmv) / yesterdayGmv * 100) : null;
    return PageScaffold(
      title: Text(
        '经营看板',
        style: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w900,
          color: C.t1,
        ),
      ),
      subtitle: Text(
        gStorageReady
            ? '机掌柜 · 在售${s.inStockCount}台 · 今日${s.orderCount}单'
            : '加载中...',
        style: TextStyle(fontSize: 12, color: C.t2),
      ),
      action: IconButton(
        tooltip: '刷新',
        icon: Icon(Icons.refresh_rounded, color: C.t2),
        onPressed: _refresh,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: C.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: C.line),
            ),
            child: LayoutBuilder(
              builder: (context, box) {
                final tight = box.maxWidth < 520;
                final metricWidth = tight ? 148.0 : 230.0;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: C.selected,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.payments_outlined,
                                  color: C.brand,
                                  size: 19,
                                ),
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '今日 GMV',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: C.t2,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      _fmt(DateTime.now()),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: C.t3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          FittedBox(
                            alignment: Alignment.centerLeft,
                            fit: BoxFit.scaleDown,
                            child: Text(
                              yuan(s.gmv),
                              style: TextStyle(
                                color: C.t1,
                                fontSize: tight ? 28 : 34,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (gmvDiffPct != null) ...[
                            const SizedBox(height: 6),
                            StatusChip(
                              '${gmvDiffPct >= 0 ? '增长' : '下降'} ${gmvDiffPct.abs().toStringAsFixed(1)}%',
                              gmvDiffPct >= 0 ? C.green : C.red,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 1,
                      height: tight ? 102 : 112,
                      color: C.line,
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: metricWidth,
                      child: Column(
                        children: [
                          _sideMetric(
                            '今日毛利',
                            yuan(s.grossProfit),
                            profitDiff >= 0
                                ? '+${yuan(profitDiff.abs())}'
                                : '-${yuan(profitDiff.abs())}',
                            profitDiff >= 0 ? C.green : C.red,
                          ),
                          _sideMetric(
                            '毛利率',
                            s.gmv > 0
                                ? '${(s.grossProfit / s.gmv * 100).toStringAsFixed(1)}%'
                                : '0%',
                            '经营效率',
                            C.blue,
                          ),
                          _sideMetric(
                            '今日订单',
                            '${s.orderCount}',
                            orderDiff >= 0
                                ? '+${orderDiff.abs()}'
                                : '-${orderDiff.abs()}',
                            orderDiff >= 0 ? C.green : C.red,
                            last: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: LayoutBuilder(
              builder: (context, box) {
                final compact = [
                  _count(
                    '${s.inStockCount}',
                    '在售设备',
                    C.brand,
                    Icons.inventory_2_outlined,
                  ),
                  _count(
                    '${s.pendingQcCount}',
                    '待质检',
                    C.orange,
                    Icons.fact_check_outlined,
                  ),
                  _count(
                    '${s.shippedCount}',
                    '在途',
                    C.blue,
                    Icons.local_shipping_outlined,
                  ),
                  _count(
                    '${s.pendingCount}',
                    '待发货',
                    C.green,
                    Icons.outbox_outlined,
                  ),
                ];
                if (box.maxWidth < 520) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (int i = 0; i < compact.length; i++) ...[
                          SizedBox(width: 132, child: compact[i]),
                          if (i != compact.length - 1) const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  );
                }
                return Row(
                  children: [
                    for (int i = 0; i < compact.length; i++) ...[
                      Expanded(child: compact[i]),
                      if (i != compact.length - 1) const SizedBox(width: 8),
                    ],
                  ],
                );
              },
            ),
          ),
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle(chart.title, trailing: '累计${yuan(chart.total)}'),
                const SizedBox(height: 8),
                // 周期切换：近7天 / 当月 / 近12月
                Row(
                  children: [
                    _chartTab('近7天', 0),
                    const SizedBox(width: 6),
                    _chartTab('当月', 1),
                    const SizedBox(width: 6),
                    _chartTab('近12月', 2),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 150,
                  child: CustomPaint(
                    painter: LineChartPainter(
                      data: chart.profit,
                      labels: chart.labels,
                      labelStep: chartMode == 1 ? 2 : 1,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Row(
              children: [
                Expanded(
                  child: _miniSummary(
                    Icons.account_balance_wallet_outlined,
                    '资金占用',
                    yuan(s.capitalOccupied),
                    '在售${s.inStockCount}台',
                    C.orange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const StagnantListPage(),
                          ),
                        ).then((_) => _refresh()),
                    child: _miniSummary(
                      Icons.warning_amber_rounded,
                      '滞销预警',
                      '${s.stagnantCount}台',
                      s.stagnantCount > 0 ? '点击处理 · 建议清仓' : '库存健康',
                      s.stagnantCount > 0 ? C.red : C.green,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (channelGmv.isNotEmpty)
            CardBox(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle('渠道占比'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      SizedBox(
                        width: 110,
                        height: 130,
                        child: CustomPaint(
                          painter: DonutPainter(
                            segs: segList,
                            centerText: '渠道',
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          children:
                              channelGmv.entries.toList().asMap().entries.map((
                                e,
                              ) {
                                final color =
                                    segColors[e.key % segColors.length];
                                final total = channelGmv.values.fold<int>(
                                  0,
                                  (a, b) => a + b,
                                );
                                final pct =
                                    total > 0
                                        ? (e.value.value * 100 / total)
                                            .toStringAsFixed(0)
                                        : '0';
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 7),
                                      Text(
                                        e.value.key,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: C.t1,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        '$pct%',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: C.t1,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          _AiReportCard(
            onGen:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AiReportPage()),
                ),
          ),
          if (stagnant.isNotEmpty)
            GestureDetector(
              onTap:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StagnantListPage()),
                  ).then((_) => _refresh()),
              child: CardBox(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionTitle(
                      '滞销预警',
                      trailing: '全部',
                      onTap:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const StagnantListPage(),
                            ),
                          ).then((_) => _refresh()),
                    ),
                    const SizedBox(height: 10),
                    ...stagnant
                        .take(5)
                        .map(
                          (d) => Padding(
                            padding: const EdgeInsets.only(bottom: 9),
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: C.cardMuted,
                                    borderRadius: BorderRadius.circular(9),
                                    border: Border.all(color: C.line),
                                  ),
                                  child: Icon(
                                    Icons.tablet_mac_rounded,
                                    color: C.t2,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${d.model} ${d.capacity}',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: C.t1,
                                        ),
                                      ),
                                      Text(
                                        '在库${d.stockDays}天 · 当前${yuan(d.sellPrice)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: C.t2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const StatusChip('滞销', C.red),
                              ],
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ),
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('快捷操作'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _quick(
                        Icons.qr_code_scanner_rounded,
                        '扫码收货',
                        C.brand,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ScanPage()),
                        ).then((_) => _refresh()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _quick(
                        Icons.query_stats_rounded,
                        '批发价',
                        C.purple,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MarketPricePage(),
                          ),
                        ).then((_) => _refresh()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _quick(
                        Icons.point_of_sale_outlined,
                        '售出',
                        C.green,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SellPage()),
                        ).then((_) => _refresh()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chartTab(String label, int mode) {
    final on = chartMode == mode;
    return GestureDetector(
      onTap: () => setState(() => chartMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: on ? C.selected : C.cardMuted,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: on ? C.brand.withOpacity(0.28) : C.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: on ? C.brand : C.t2,
            fontWeight: on ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _sideMetric(
    String label,
    String value,
    String sub,
    Color color, {
    bool last = false,
  }) => Container(
    padding: EdgeInsets.only(bottom: last ? 0 : 8),
    margin: EdgeInsets.only(bottom: last ? 0 : 8),
    decoration: BoxDecoration(
      border: last ? null : Border(bottom: BorderSide(color: C.line)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  color: C.t2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: FittedBox(
            alignment: Alignment.centerRight,
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: C.t1,
              ),
            ),
          ),
        ),
      ],
    ),
  );
  Widget _count(String n, String l, Color c, IconData icon) => Container(
    height: 54,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: C.card,
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: C.line),
    ),
    child: Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: c.withOpacity(0.11),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 17, color: c),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: Text(
                  n,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: C.t1,
                  ),
                ),
              ),
              Text(
                l,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  color: C.t2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _miniSummary(
    IconData icon,
    String label,
    String value,
    String sub,
    Color color,
  ) => Container(
    height: 60,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: C.card,
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: C.line),
    ),
    child: Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withOpacity(0.11),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 17),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  color: C.t2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ),
              Text(
                sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 9.5, color: C.t3),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _quick(
    IconData icon,
    String label,
    Color c,
    VoidCallback onTap, {
    VoidCallback? onLongPress,
    String? longHint,
  }) => GestureDetector(
    onTap: onTap,
    onLongPress:
        onLongPress != null
            ? () {
              onLongPress();
              if (longHint != null) toast(context, longHint);
            }
            : null,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: C.cardMuted,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: C.line),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: c.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: c, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: C.t1,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _AiReportCard extends StatefulWidget {
  final VoidCallback onGen;
  const _AiReportCard({required this.onGen});
  @override
  State<_AiReportCard> createState() => _AiReportCardState();
}

class _AiReportCardState extends State<_AiReportCard> {
  String? report;
  bool loading = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: widget.onGen,
    child: Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: C.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: C.blue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: C.blue,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI 经营日报',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: C.t1,
                      ),
                    ),
                    Text(
                      '基于当前库存、订单与毛利生成',
                      style: TextStyle(fontSize: 11, color: C.t3),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: C.t3),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            report ?? '生成今日经营简报，快速查看风险、补货和清仓建议。',
            style: TextStyle(fontSize: 12, color: C.t2, height: 1.6),
          ),
          if (loading)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: C.brand,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

// ====== 库存页（横向卡片布局） ======
class StockPage extends StatefulWidget {
  const StockPage({Key? key}) : super(key: key);
  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  int chipIndex = 0;
  final chips = ['全部', 'iPad Pro', 'iPad Air', '数字系列', 'iPad mini'];
  String searchKw = '';

  @override
  void initState() {
    super.initState();
  }

  void _refresh() => setState(() {});

  List<Device> get filtered {
    var list =
        gStorage
            .getDevices()
            .where((d) => d.status == 'in_stock' || d.status == 'listed')
            .toList();
    if (chipIndex > 0) {
      final kw = chips[chipIndex];
      list =
          list
              .where(
                (d) =>
                    d.model.contains(kw.replaceAll('iPad ', '')) ||
                    d.model.contains(kw),
              )
              .toList();
    }
    if (searchKw.isNotEmpty) {
      list =
          list
              .where(
                (d) =>
                    d.model.toLowerCase().contains(searchKw.toLowerCase()) ||
                    d.serial.toLowerCase().contains(searchKw.toLowerCase()) ||
                    d.capacity.toLowerCase().contains(searchKw.toLowerCase()),
              )
              .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final devices = filtered;
    final allInStock =
        gStorage
            .getDevices()
            .where((d) => d.status == 'in_stock' || d.status == 'listed')
            .toList();
    return PageScaffold(
      title: Text(
        '库存管理',
        style: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w900,
          color: C.t1,
        ),
      ),
      subtitle: Text(
        '在售${allInStock.length}台 · 成本占用${yuan(allInStock.fold(0, (s, d) => s + d.purchaseCost))}',
        style: TextStyle(fontSize: 12, color: C.t2),
      ),
      action: IconButton(
        tooltip: '扫码收货',
        icon: Icon(Icons.qr_code_scanner_rounded, color: C.brand),
        onPressed:
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ScanPage()),
            ).then((_) => _refresh()),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Row(
              children: [
                Expanded(
                  child: _stockMetric(
                    '在售',
                    '${allInStock.where((d) => d.status == 'listed').length}',
                    C.brand,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _stockMetric(
                    '未定价',
                    '${allInStock.where((d) => d.sellPrice <= 0).length}',
                    C.orange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _stockMetric(
                    '滞销',
                    '${allInStock.where((d) => d.isStagnant).length}',
                    C.red,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: C.card,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: C.line),
              ),
              child: TextField(
                onChanged: (v) => setState(() => searchKw = v),
                style: TextStyle(color: C.t1, fontSize: 13),
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded, color: C.t3, size: 18),
                  prefixIconConstraints: const BoxConstraints(minWidth: 28),
                  border: InputBorder.none,
                  hintText: '搜索型号、序列号、容量',
                  hintStyle: TextStyle(color: C.t3, fontSize: 13),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: chips.length,
              separatorBuilder: (_, __) => const SizedBox(width: 7),
              itemBuilder: (_, i) {
                final on = chipIndex == i;
                return GestureDetector(
                  onTap: () => setState(() => chipIndex = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: on ? C.selected : C.card,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: on ? C.brand.withOpacity(0.28) : C.line,
                      ),
                    ),
                    child: Text(
                      chips[i],
                      style: TextStyle(
                        fontSize: 12,
                        color: on ? C.brand : C.t2,
                        fontWeight: on ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          if (devices.isEmpty)
            _emptyStock()
          else
            LayoutBuilder(
              builder: (context, box) {
                final columns =
                    box.maxWidth >= 900 ? 4 : (box.maxWidth >= 620 ? 3 : 2);
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  crossAxisCount: columns,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: columns >= 3 ? 0.86 : 0.8,
                  children: devices.map(_deviceCard).toList(),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _stockMetric(String label, String value, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: C.card,
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: C.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            color: C.t2,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  Widget _emptyStock() => Padding(
    padding: const EdgeInsets.only(top: 58),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: C.cardMuted,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: C.line),
            ),
            child: Icon(Icons.inventory_2_outlined, color: C.t3, size: 26),
          ),
          const SizedBox(height: 12),
          Text(
            '暂无库存',
            style: TextStyle(
              color: C.t1,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text('扫码收货后会出现在这里', style: TextStyle(color: C.t2, fontSize: 12)),
        ],
      ),
    ),
  );

  Widget _deviceCard(Device d) {
    final hasImg = d.imagePath != null && d.imagePath!.isNotEmpty;
    final firstImg = hasImg ? d.imagePath!.split(';').first : null;
    final goodCond =
        d.condition.contains('99') ||
        d.condition.contains('95') ||
        d.condition.contains('全新');
    return GestureDetector(
      onTap:
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DetailPage(device: d)),
          ).then((_) => _refresh()),
      child: Container(
        decoration: BoxDecoration(
          color: C.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: C.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(9),
                    ),
                    child: Container(
                      width: double.infinity,
                      color: C.cardMuted,
                      child:
                          firstImg != null
                              ? Image.file(
                                File(firstImg),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              )
                              : Center(
                                child: Icon(
                                  Icons.tablet_mac_rounded,
                                  color: C.t3,
                                  size: 34,
                                ),
                              ),
                    ),
                  ),
                  Positioned(
                    top: 7,
                    left: 7,
                    child: StatusChip(
                      d.isStagnant ? '滞销' : '在售',
                      d.isStagnant ? C.red : C.green,
                    ),
                  ),
                  if (!d.idLockClean)
                    Positioned(
                      top: 7,
                      right: 7,
                      child: StatusChip('ID锁', C.red),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.model,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: C.t1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${d.capacity} · ${d.color} · ${d.network}',
                    style: TextStyle(fontSize: 10.5, color: C.t2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Text(
                        d.sellPrice > 0 ? yuan(d.sellPrice) : '未定价',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: d.sellPrice > 0 ? C.brand : C.orange,
                        ),
                      ),
                      const Spacer(),
                      StatusChip(d.condition, goodCond ? C.green : C.orange),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '库龄${d.stockDays}天 · 电池${d.batteryHealth}% · 成本${yuan(d.purchaseCost)}',
                    style: TextStyle(fontSize: 9.5, color: C.t3),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ====== 扫码收货页（全新改造：AI识别+多图+型号选择+渠道预设） ======
class ScanPage extends StatefulWidget {
  const ScanPage({Key? key}) : super(key: key);
  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  // 基本信息
  final _serialCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  String selectedModel = '';
  String selectedCapacity = '';
  String selectedColor = '';
  String selectedNetwork = 'WiFi';
  String selectedCondition = '95新';
  String selectedChannel = '华强北同行';
  bool isCustomChannel = false;
  final _customChannelCtrl = TextEditingController();

  // ID锁检测
  bool iCloudLock = false, actLock = false, mdm = false, configLock = false;
  Map<String, dynamic>? idCheck;

  // 多图上传（最多12张）
  List<String> imagePaths = [];

  // "关于本机"截图AI识别
  String? aboutThisDeviceImagePath;
  bool aiRecognizing = false;
  Map<String, String>? aiRecognizedInfo;

  // 保存
  bool saving = false;

  // 步骤指引：当前步骤 0=基本信息 1=实拍图 2=确认入库
  int currentStep = 0;

  void _checkIdLock() {
    final c = IdLockChecker.check(
      iCloudLocked: iCloudLock,
      activationLocked: actLock,
      mdmSupervised: mdm,
      configLock: configLock,
    );
    setState(() {
      idCheck = c;
    });
  }

  /// 拍"关于本机"截图，AI识别序列号
  Future<void> _pickAboutThisDevice() async {
    try {
      final picker = ImagePicker();
      final x = await picker.pickImage(source: ImageSource.camera);
      if (x != null) {
        final now = DateTime.now();
        final dest = '$gDocDir/about_${now.millisecondsSinceEpoch}.jpg';
        await File(x.path).copy(dest);
        setState(() {
          aboutThisDeviceImagePath = dest;
          aiRecognizing = true;
        });

        // 读取图片转为base64
        final bytes = await File(dest).readAsBytes();
        final base64 = base64Encode(bytes);

        // 调用AI识别
        final info = await AiService.recognizeAboutThisDevice(base64);
        setState(() {
          aiRecognizing = false;
          aiRecognizedInfo = info;
          // 自动填入识别结果
          if (info['serial'] != '未知' && info['serial']!.isNotEmpty) {
            _serialCtrl.text = info['serial']!;
          }
          if (info['model'] != '未知' && info['model']!.isNotEmpty) {
            selectedModel = info['model']!;
          }
          if (info['capacity'] != '未知' && info['capacity']!.isNotEmpty) {
            selectedCapacity = info['capacity']!;
          }
          if (info['color'] != '未知' && info['color']!.isNotEmpty) {
            selectedColor = info['color']!;
          }
          if (info['network'] != '未知' && info['network']!.isNotEmpty) {
            selectedNetwork = info['network']!;
          }
          if (info['batteryHealth'] != '未知' &&
              info['batteryHealth']!.isNotEmpty) {
            // batteryHealth 保留但不直接用字段，后面存入Device
          }
        });
        toast(context, '✅ AI已识别设备信息');
      }
    } catch (e) {
      setState(() {
        aiRecognizing = false;
      });
      toast(context, 'AI识别失败：$e');
    }
  }

  /// 添加实拍图（原图，不压缩）
  Future<void> _addImage(bool fromCamera) async {
    if (imagePaths.length >= 12) {
      toast(context, '最多上传12张图片');
      return;
    }
    try {
      final picker = ImagePicker();
      final x = await picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      );
      if (x != null) {
        final now = DateTime.now();
        final dest =
            '$gDocDir/dev_${now.millisecondsSinceEpoch}_${imagePaths.length}.jpg';
        // 原图拷贝，不做压缩
        await File(x.path).copy(dest);
        setState(() {
          imagePaths.add(dest);
        });
        toast(context, '已添加第${imagePaths.length}张图片');
      }
    } catch (e) {
      toast(context, '选图失败：$e');
    }
  }

  /// 多选图片（从相册批量选择）
  Future<void> _addMultipleImages() async {
    final remaining = 12 - imagePaths.length;
    if (remaining <= 0) {
      toast(context, '最多上传12张图片');
      return;
    }
    try {
      final picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage();
      if (images.isNotEmpty) {
        int added = 0;
        for (final x in images) {
          if (imagePaths.length >= 12) break;
          final now = DateTime.now();
          final dest =
              '$gDocDir/dev_${now.millisecondsSinceEpoch}_${imagePaths.length + added}.jpg';
          await File(x.path).copy(dest);
          imagePaths.add(dest);
          added++;
        }
        setState(() {});
        toast(context, '已添加${added}张图片，共${imagePaths.length}张');
      }
    } catch (e) {
      toast(context, '批量选图失败：$e');
    }
  }

  /// 删除某张图
  void _removeImage(int index) {
    setState(() {
      imagePaths.removeAt(index);
    });
  }

  Future<void> _save() async {
    // 校验
    if (selectedModel.isEmpty) {
      toast(context, '请选择iPad型号');
      return;
    }
    if (selectedCapacity.isEmpty) {
      toast(context, '请选择容量');
      return;
    }
    if (_costCtrl.text.isEmpty || (double.tryParse(_costCtrl.text) ?? 0) <= 0) {
      toast(context, '请输入采购成本');
      return;
    }

    setState(() => saving = true);
    final now = DateTime.now();
    final cost = (double.tryParse(_costCtrl.text) ?? 0) * 100;
    final channel = isCustomChannel ? _customChannelCtrl.text : selectedChannel;
    final serial = _serialCtrl.text.trim().toUpperCase();

    // 如果有"关于本机"识别的电池信息
    int batteryHealth = 100;
    int cycleCount = 0;
    if (aiRecognizedInfo != null) {
      if (aiRecognizedInfo!['batteryHealth'] != '未知') {
        batteryHealth =
            int.tryParse(
              aiRecognizedInfo!['batteryHealth']!.replaceAll('%', ''),
            ) ??
            100;
      }
      if (aiRecognizedInfo!['cycleCount'] != '未知') {
        cycleCount = int.tryParse(aiRecognizedInfo!['cycleCount']!) ?? 0;
      }
    }

    // 序列号解码（如果有）
    final idClean = idCheck != null ? idCheck!['clean'] as bool : true;

    // 商品描述：优先复用同型号历史描述，无历史或用户选重新生成时调 AI
    String? description;
    // 查找同型号的历史描述
    final historyList =
        gStorage
            .getDevices()
            .where(
              (d) =>
                  d.model == selectedModel &&
                  d.description != null &&
                  d.description!.isNotEmpty,
            )
            .map((d) => d.description)
            .toList();
    final historyDesc = historyList.isNotEmpty ? historyList.last : null;
    // 有历史描述时弹窗让用户选
    if (historyDesc != null && mounted) {
      final choice = await showDialog<String>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              backgroundColor: C.card,
              title: Text('商品描述', style: TextStyle(color: C.t1, fontSize: 16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '同型号有历史描述可用',
                    style: TextStyle(color: C.t2, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: C.bg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: C.line),
                    ),
                    child: Text(
                      historyDesc,
                      style: TextStyle(fontSize: 11, color: C.t2, height: 1.6),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'ai'),
                  child: const Text(
                    '重新AI生成',
                    style: TextStyle(color: C.purple),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'reuse'),
                  child: const Text('复用历史', style: TextStyle(color: C.brand2)),
                ),
              ],
            ),
      );
      if (choice == 'reuse') {
        description = historyDesc;
      }
    }
    // 需要AI生成时
    if (description == null) {
      try {
        description = await AiService.generateDescription(
          model: selectedModel,
          capacity: selectedCapacity,
          color: selectedColor.isEmpty ? '未知' : selectedColor,
          network: selectedNetwork,
          condition: selectedCondition,
          batteryHealth: batteryHealth,
          cycleCount: cycleCount,
          idLockClean: idClean,
          accessories: '裸机',
        );
        if (description.startsWith('AI调用') || description.startsWith('AI返回')) {
          description = null;
        }
      } catch (_) {
        description = null;
      }
    }

    final d = Device(
      id: 'd${now.millisecondsSinceEpoch}',
      serial: serial.isEmpty ? '未填写' : serial,
      model: selectedModel,
      capacity: selectedCapacity,
      color: selectedColor.isEmpty ? '未知' : selectedColor,
      network: selectedNetwork,
      condition: selectedCondition,
      batteryHealth: batteryHealth,
      cycleCount: cycleCount,
      idLockClean: idClean,
      accessories: '裸机',
      purchaseCost: cost.toInt(),
      purchaseChannel: channel,
      purchaseDate: _fmt(now),
      sellPrice: calcAutoPrice(cost.toInt()),
      status: 'listed',
      imagePath: imagePaths.isNotEmpty ? imagePaths.join(';') : null,
      description: description,
      createdAt: now.toIso8601String(),
    );
    await gStorage.addDevice(d);
    setState(() => saving = false);
    toast(
      context,
      description != null
          ? '✅ 已入库并自动定价${yuan(d.sellPrice)}：${d.model}（AI描述已生成）'
          : '✅ 已入库并自动定价${yuan(d.sellPrice)}：${d.model}',
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => appScaffold(
    context,
    '扫码收货',
    Stepper(
      type: StepperType.vertical,
      currentStep: currentStep,
      onStepContinue: () {
        if (currentStep < 2) setState(() => currentStep++);
      },
      onStepCancel: () {
        if (currentStep > 0) setState(() => currentStep--);
      },
      controlsBuilder:
          (context, details) => Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                if (currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: details.onStepCancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: C.t2,
                        side: BorderSide(color: C.line),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                      child: Text('上一步', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                if (currentStep > 0) const SizedBox(width: 10),
                if (currentStep < 2)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: details.onStepContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: C.brand2,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                      child: const Text('下一步', style: TextStyle(fontSize: 13)),
                    ),
                  ),
              ],
            ),
          ),
      steps: [
        // 步骤1：基本信息
        Step(
          title: Text(
            '基本信息',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: C.t1,
            ),
          ),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // "关于本机"拍照识别
              CardBox(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '关于本机 · AI识别',
                      style: TextStyle(fontSize: 12, color: C.t2),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '拍一张"设置→关于本机"页面截图，AI自动识别序列号和型号',
                      style: TextStyle(fontSize: 10, color: C.t3),
                    ),
                    const SizedBox(height: 8),
                    if (aboutThisDeviceImagePath != null)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: Image.file(
                              File(aboutThisDeviceImagePath!),
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: GestureDetector(
                              onTap:
                                  () => setState(() {
                                    aboutThisDeviceImagePath = null;
                                    aiRecognizedInfo = null;
                                  }),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                          if (aiRecognizing)
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: C.brand2,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'AI识别中...',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _pickAboutThisDevice,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: C.purple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            '拍关于本机让AI识别',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    if (aiRecognizedInfo != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: C.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(color: C.green.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'AI识别结果',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: C.green,
                                ),
                              ),
                              const SizedBox(height: 6),
                              ...aiRecognizedInfo!.entries
                                  .where(
                                    (e) => e.key != '_raw' && e.value != '未知',
                                  )
                                  .map(
                                    (e) => Padding(
                                      padding: EdgeInsets.only(bottom: 3),
                                      child: Text(
                                        '${e.key}: ${e.value}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: C.t2,
                                        ),
                                      ),
                                    ),
                                  ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),

              // 序列号手动输入/修正
              CardBox(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '序列号（可手动修正）',
                      style: TextStyle(fontSize: 12, color: C.t2),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _serialCtrl,
                      style: TextStyle(color: C.t1, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: '输入或AI识别后自动填入',
                        hintStyle: TextStyle(color: C.t3),
                        filled: true,
                        fillColor: C.bg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: C.line),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: C.brand2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),

              // iPad型号选择
              CardBox(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('型号', style: TextStyle(fontSize: 12, color: C.t2)),
                    const SizedBox(height: 6),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: C.bg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: C.line),
                      ),
                      child: DropdownButton<String>(
                        value: selectedModel.isEmpty ? null : selectedModel,
                        hint: Text(
                          '选择iPad型号',
                          style: TextStyle(color: C.t3, fontSize: 13),
                        ),
                        isExpanded: true,
                        underline: const SizedBox(),
                        dropdownColor: C.card,
                        style: TextStyle(color: C.t1, fontSize: 13),
                        items:
                            iPadModels
                                .map(
                                  (m) => DropdownMenuItem(
                                    value: m['name'],
                                    child: Text(
                                      m['name']!,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged:
                            (v) => setState(() => selectedModel = v ?? ''),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),

              // 容量+颜色+网络 一行
              CardBox(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '容量',
                                style: TextStyle(fontSize: 11, color: C.t2),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: C.bg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: C.line),
                                ),
                                child: DropdownButton<String>(
                                  value:
                                      selectedCapacity.isEmpty
                                          ? null
                                          : selectedCapacity,
                                  hint: Text(
                                    '容量',
                                    style: TextStyle(color: C.t3, fontSize: 12),
                                  ),
                                  isExpanded: true,
                                  underline: const SizedBox(),
                                  dropdownColor: C.card,
                                  style: TextStyle(color: C.t1, fontSize: 12),
                                  items:
                                      iPadCapacities
                                          .map(
                                            (c) => DropdownMenuItem(
                                              value: c,
                                              child: Text(
                                                c,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                  onChanged:
                                      (v) => setState(
                                        () => selectedCapacity = v ?? '',
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '颜色',
                                style: TextStyle(fontSize: 11, color: C.t2),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: C.bg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: C.line),
                                ),
                                child: DropdownButton<String>(
                                  value:
                                      selectedColor.isEmpty
                                          ? null
                                          : selectedColor,
                                  hint: Text(
                                    '颜色',
                                    style: TextStyle(color: C.t3, fontSize: 12),
                                  ),
                                  isExpanded: true,
                                  underline: const SizedBox(),
                                  dropdownColor: C.card,
                                  style: TextStyle(color: C.t1, fontSize: 12),
                                  items:
                                      iPadColors
                                          .map(
                                            (c) => DropdownMenuItem(
                                              value: c,
                                              child: Text(
                                                c,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                  onChanged:
                                      (v) => setState(
                                        () => selectedColor = v ?? '',
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '网络',
                                style: TextStyle(fontSize: 11, color: C.t2),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: C.bg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: C.line),
                                ),
                                child: DropdownButton<String>(
                                  value: selectedNetwork,
                                  isExpanded: true,
                                  underline: const SizedBox(),
                                  dropdownColor: C.card,
                                  style: TextStyle(color: C.t1, fontSize: 12),
                                  items:
                                      iPadNetworks
                                          .map(
                                            (n) => DropdownMenuItem(
                                              value: n,
                                              child: Text(
                                                n,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                  onChanged:
                                      (v) => setState(
                                        () => selectedNetwork = v ?? '',
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),

              // 成色选择
              CardBox(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('成色', style: TextStyle(fontSize: 12, color: C.t2)),
                    const SizedBox(height: 6),
                    Wrap(
                      children:
                          iPadConditions
                              .map(
                                (c) => Padding(
                                  padding: const EdgeInsets.only(
                                    right: 6,
                                    bottom: 4,
                                  ),
                                  child: ChoiceChip(
                                    label: Text(
                                      c,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    selected: selectedCondition == c,
                                    selectedColor: C.brand,
                                    onSelected:
                                        (_) => setState(
                                          () => selectedCondition = c,
                                        ),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),

              // 采购成本 + 渠道
              CardBox(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _costCtrl,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: C.t1, fontSize: 14),
                            decoration: InputDecoration(
                              labelText: '采购成本(元)',
                              labelStyle: TextStyle(color: C.t2),
                              filled: true,
                              fillColor: C.bg,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: C.line),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text('采购渠道', style: TextStyle(fontSize: 12, color: C.t2)),
                    const SizedBox(height: 6),
                    Wrap(
                      children:
                          PurchaseChannels.map(
                            (c) => Padding(
                              padding: const EdgeInsets.only(
                                right: 6,
                                bottom: 4,
                              ),
                              child: ChoiceChip(
                                label: Text(
                                  c,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                selected:
                                    !isCustomChannel && selectedChannel == c,
                                selectedColor: C.brand,
                                onSelected:
                                    (_) => setState(() {
                                      selectedChannel = c;
                                      isCustomChannel = false;
                                    }),
                              ),
                            ),
                          ).toList(),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 6, bottom: 4),
                      child: ChoiceChip(
                        label: const Text(
                          '自定义',
                          style: TextStyle(fontSize: 11),
                        ),
                        selected: isCustomChannel,
                        selectedColor: C.brand,
                        onSelected:
                            (_) => setState(() {
                              isCustomChannel = true;
                            }),
                      ),
                    ),
                    if (isCustomChannel)
                      TextField(
                        controller: _customChannelCtrl,
                        style: TextStyle(color: C.t1, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: '输入渠道名称',
                          labelStyle: TextStyle(color: C.t2),
                          filled: true,
                          fillColor: C.bg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: C.line),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),

              // ID锁安全检测
              CardBox(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ID锁安全检测',
                      style: TextStyle(fontSize: 12, color: C.t2),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      children: [
                        _lockCheck(
                          'iCloud锁',
                          iCloudLock,
                          (v) => setState(() => iCloudLock = v),
                        ),
                        _lockCheck(
                          '激活锁',
                          actLock,
                          (v) => setState(() => actLock = v),
                        ),
                        _lockCheck(
                          'MDM监管',
                          mdm,
                          (v) => setState(() => mdm = v),
                        ),
                        _lockCheck(
                          '配置锁',
                          configLock,
                          (v) => setState(() => configLock = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    primaryBtn('检测ID锁', _checkIdLock),
                    if (idCheck != null && !(idCheck!['clean'] as bool))
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: C.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: C.red.withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            const Text('⚠️', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${idCheck!["risk"]}：${(idCheck!["issues"] as List).join("、")}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFFCA5A5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (idCheck != null && idCheck!['clean'] as bool)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: C.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: C.green.withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            const Text('✓', style: TextStyle(color: C.green)),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'ID锁检测通过：无iCloud锁、无激活锁、非监管机',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6EE7B7),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          isActive: true,
        ),

        // 步骤2：实拍图
        Step(
          title: Text(
            '实拍图（最多12张）',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: C.t1,
            ),
          ),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CardBox(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '设备实拍',
                          style: TextStyle(fontSize: 12, color: C.t2),
                        ),
                        const Spacer(),
                        Text(
                          '${imagePaths.length}/12张',
                          style: TextStyle(fontSize: 11, color: C.t3),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // 已选图片横向展示
                    if (imagePaths.isNotEmpty)
                      SizedBox(
                        height: 100,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: imagePaths.length + 1,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            if (i == imagePaths.length) {
                              // 添加按钮
                              return GestureDetector(
                                onTap: () => _addImage(false),
                                child: Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    color: C.bg,
                                    borderRadius: BorderRadius.circular(11),
                                    border: Border.all(color: C.line),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.add_photo_alternate,
                                      color: C.t3,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              );
                            }
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(11),
                                  child: Image.file(
                                    File(imagePaths[i]),
                                    width: 90,
                                    height: 90,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () => _removeImage(i),
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 4,
                                  left: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '#${i + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      )
                    else
                      Container(
                        height: 90,
                        decoration: BoxDecoration(
                          color: C.bg,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: C.line),
                        ),
                        child: Center(
                          child: Text(
                            '未上传实拍图',
                            style: TextStyle(color: C.t3, fontSize: 12),
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _addMultipleImages(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: C.card,
                              foregroundColor: C.t1,
                              padding: EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              '相册多选',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _addImage(false),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: C.card,
                              foregroundColor: C.t1,
                              padding: EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              '相册单选',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _addImage(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: C.brand2,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              '拍照',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          isActive: true,
        ),

        // 步骤3：确认入库
        Step(
          title: Text(
            '确认入库',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: C.t1,
            ),
          ),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CardBox(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '入库信息确认',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: C.t1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (selectedModel.isNotEmpty) _kv('型号', selectedModel),
                    if (selectedCapacity.isNotEmpty)
                      _kv(
                        '容量/颜色/网络',
                        '$selectedCapacity $selectedColor $selectedNetwork',
                      ),
                    if (_serialCtrl.text.isNotEmpty)
                      _kv('序列号', _serialCtrl.text),
                    _kv('成色', selectedCondition),
                    _kv('采购成本', '${_costCtrl.text}元'),
                    _kv(
                      '采购渠道',
                      isCustomChannel
                          ? _customChannelCtrl.text
                          : selectedChannel,
                    ),
                    if (idCheck != null)
                      _kv(
                        'ID锁',
                        idCheck!['clean'] as bool
                            ? '✓ 安全'
                            : '✗ ${idCheck!["risk"]}',
                      ),
                    _kv('实拍图', '${imagePaths.length}张'),
                    const SizedBox(height: 14),
                    saving
                        ? const Center(
                          child: CircularProgressIndicator(color: C.brand2),
                        )
                        : primaryBtn('确认入库', _save),
                  ],
                ),
              ),
            ],
          ),
          isActive: true,
        ),
      ],
    ),
  );

  Widget _lockCheck(String label, bool val, ValueChanged<bool> onChanged) =>
      Padding(
        padding: EdgeInsets.only(right: 8, bottom: 6),
        child: FilterChip(
          label: Text(
            label,
            style: TextStyle(fontSize: 11, color: val ? Colors.white : C.t2),
          ),
          selected: val,
          selectedColor: C.red,
          onSelected: onChanged,
        ),
      );
  Widget _kv(String k, String v) => Padding(
    padding: EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(k, style: TextStyle(fontSize: 12, color: C.t2)),
        ),
        Expanded(
          child: Text(
            v,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: C.t1,
            ),
          ),
        ),
      ],
    ),
  );
}

// ====== 订单页（含tab筛选） ======
class OrderPage extends StatefulWidget {
  const OrderPage({Key? key}) : super(key: key);
  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  int tab = 0;
  final tabs = ['全部', '已发货', '已完成', '售后'];
  final statusMap = ['all', 'shipped', 'done', 'aftersale'];

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    var orders = gStorage.getOrders();
    if (statusMap[tab] != 'all') {
      orders = orders.where((o) => o.status == statusMap[tab]).toList();
    }
    return PageScaffold(
      title: Text(
        '订单管理',
        style: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w900,
          color: C.t1,
        ),
      ),
      subtitle: Text(
        '累计${gStorage.getOrders().length}单 · 当前筛选${orders.length}单',
        style: TextStyle(fontSize: 12, color: C.t2),
      ),
      action: IconButton(
        tooltip: '售出设备',
        icon: Icon(Icons.point_of_sale_outlined, color: C.brand),
        onPressed:
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SellPage()),
            ).then((_) => _refresh()),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: C.card,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: C.line),
            ),
            child: Row(
              children: List.generate(tabs.length, (i) {
                final on = tab == i;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => tab = i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: on ? C.selected : Colors.transparent,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        tabs[i],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                          color: on ? C.brand : C.t2,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SellPage()),
                    ).then((_) => _refresh()),
                icon: const Icon(Icons.add_shopping_cart_outlined, size: 18),
                label: const Text('售出设备并生成订单'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: C.brand,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
            ),
          ),
          if (orders.isEmpty) _emptyOrders() else ...orders.map(_orderCard),
        ],
      ),
    );
  }

  Widget _emptyOrders() => Padding(
    padding: const EdgeInsets.only(top: 46),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: C.cardMuted,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: C.line),
            ),
            child: Icon(Icons.receipt_long_outlined, color: C.t3, size: 26),
          ),
          const SizedBox(height: 12),
          Text(
            '暂无订单',
            style: TextStyle(
              color: C.t1,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text('售出设备后会自动生成订单', style: TextStyle(color: C.t2, fontSize: 12)),
        ],
      ),
    ),
  );

  Widget _orderCard(Order o) {
    final sc = _sc(o.status);
    final stText =
        {
          'shipped': '已发货',
          'done': '已完成',
          'aftersale': '售后',
          'cancelled': '已作废',
        }[o.status] ??
        o.status;
    final profitColor = o.netProfit >= 0 ? C.green : C.red;
    return GestureDetector(
      onTap:
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => OrderDetailPage(order: o)),
          ).then((_) => _refresh()),
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: C.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: C.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  o.id,
                  style: TextStyle(
                    fontSize: 11,
                    color: C.t3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                StatusChip(stText, sc),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: C.cardMuted,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: C.line),
                  ),
                  child: Icon(Icons.tablet_mac_rounded, color: C.t2, size: 21),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        o.deviceName,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: C.t1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${o.buyer.isEmpty ? "未知买家" : o.buyer} · ${o.channel} · ${o.createdAt}',
                        style: TextStyle(fontSize: 10.5, color: C.t2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      yuan(o.amount),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: C.t1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '净利${yuan(o.netProfit)}',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: profitColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _sc(String s) =>
      s == 'shipped'
          ? C.brand
          : (s == 'done' ? C.green : (s == 'aftersale' ? C.red : C.t3));
}

// ====== 订单详情页 ======
class OrderDetailPage extends StatefulWidget {
  final Order order;
  const OrderDetailPage({Key? key, required this.order}) : super(key: key);
  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  late Order order;
  Device? device;

  @override
  void initState() {
    super.initState();
    order = widget.order;
    final ds =
        gStorage.getDevices().where((d) => d.id == order.deviceId).toList();
    device = ds.isNotEmpty ? ds.first : null;
  }

  /// 已发货 → 已完成
  Future<void> _markDone() async {
    order.status = 'done';
    await gStorage.updateOrder(order);
    setState(() {});
    toast(context, '✅ 已标记完成，净利${yuan(order.netProfit)}');
  }

  /// 已完成 → 重新上架（原订单作废，设备回 listed）
  Future<void> _relist() async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: C.card,
            title: Text('确认重新上架', style: TextStyle(color: C.t1, fontSize: 16)),
            content: Text(
              '该订单利润${yuan(order.netProfit)}将从历史统计中扣除，设备回到上架待售状态。确定？',
              style: TextStyle(color: C.t2, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('取消', style: TextStyle(color: C.t2)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('重新上架', style: TextStyle(color: C.orange)),
              ),
            ],
          ),
    );
    if (ok != true) return;
    order.status = 'cancelled';
    await gStorage.updateOrder(order);
    if (device != null) {
      device!.status = 'listed';
      device!.sellDate = null;
      device!.sellChannel = null;
      device!.platformFee = null;
      device!.logisticsCost = null;
      device!.afterSaleCost = null;
      device!.buyerContact = null;
      await gStorage.updateDevice(device!);
    }
    setState(() {});
    toast(context, '已重新上架，原订单利润已扣除');
  }

  /// 售后费用录入
  Future<void> _inputAfterSale() async {
    final ctrl = TextEditingController(
      text:
          order.afterSaleCost != null
              ? (order.afterSaleCost! / 100).toStringAsFixed(0)
              : '',
    );
    String? selectedReason = order.afterSaleReason;
    final reasons = ['质量问题', '买家反悔', '描述不符', '物流损坏', '其他'];
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setS) => AlertDialog(
                  backgroundColor: C.card,
                  title: Text(
                    '售后录入',
                    style: TextStyle(color: C.t1, fontSize: 16),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '录入后将从当月/年度总利润中扣除',
                        style: TextStyle(color: C.t2, fontSize: 11),
                      ),
                      const SizedBox(height: 12),
                      Text('售后原因', style: TextStyle(color: C.t2, fontSize: 12)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children:
                            reasons
                                .map(
                                  (r) => ChoiceChip(
                                    label: Text(
                                      r,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    selected: selectedReason == r,
                                    selectedColor: C.brand,
                                    onSelected:
                                        (_) => setS(() => selectedReason = r),
                                  ),
                                )
                                .toList(),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: ctrl,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        style: TextStyle(color: C.t1),
                        decoration: InputDecoration(
                          labelText: '售后费用(元)',
                          labelStyle: TextStyle(color: C.t2),
                          filled: true,
                          fillColor: C.bg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: C.line),
                          ),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('取消', style: TextStyle(color: C.t2)),
                    ),
                    TextButton(
                      onPressed: () {
                        final v = (double.tryParse(ctrl.text) ?? 0) * 100;
                        Navigator.pop(ctx, {
                          'cost': v.toInt(),
                          'reason': selectedReason,
                        });
                      },
                      child: Text('保存', style: TextStyle(color: C.brand2)),
                    ),
                  ],
                ),
          ),
    );
    if (result == null) return;
    final cost = result['cost'] as int;
    if (cost < 0) {
      toast(context, '售后费用不能为负数');
      return;
    }
    final reason = result['reason'] as String?;
    order.afterSaleCost = cost > 0 ? cost : null;
    order.afterSaleReason = cost > 0 ? reason : null;
    if (cost > 0) {
      order.status = 'aftersale';
    } else if (order.status == 'aftersale') {
      order.status = 'done';
    }
    await gStorage.updateOrder(order);
    if (device != null) {
      device!.afterSaleCost = cost > 0 ? cost : null;
      await gStorage.updateDevice(device!);
    }
    setState(() {});
    toast(
      context,
      '售后已记录${cost > 0 ? "，净利调整为${yuan(order.netProfit)}" : ""}${reason != null ? "（$reason）" : ""}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final sc = _sc(order.status);
    final stText =
        {
          'shipped': '已发货',
          'done': '已完成',
          'aftersale': '售后',
          'cancelled': '已作废',
        }[order.status] ??
        order.status;
    return appScaffold(
      context,
      '订单详情',
      ListView(
        padding: const EdgeInsets.all(14),
        children: [
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(order.id, style: TextStyle(fontSize: 12, color: C.t2)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: sc.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        stText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: sc,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _row('设备', order.deviceName),
                _row('买家', order.buyer.isEmpty ? '未知' : order.buyer),
                _row('渠道', order.channel),
                _row('成交金额', yuan(order.amount)),
                _row('毛利', yuan(order.profit)),
                if (order.afterSaleCost != null &&
                    order.afterSaleCost! > 0) ...[
                  _row('售后费用', yuan(order.afterSaleCost!), vc: C.red),
                  if (order.afterSaleReason != null)
                    _row('售后原因', order.afterSaleReason!, vc: C.orange),
                ],
                _row('净利', yuan(order.netProfit), vc: C.green, bold: true),
                _row('下单时间', order.createdAt),
              ],
            ),
          ),
          if (device != null)
            CardBox(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '关联设备',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: C.t1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _row(
                    '型号',
                    '${device!.model} ${device!.capacity} ${device!.color}',
                  ),
                  _row('序列号', device!.serial),
                  _row(
                    '成色',
                    '${device!.condition} · 电池${device!.batteryHealth}%',
                  ),
                  _row(
                    '采购',
                    '${yuan(device!.purchaseCost)} · ${device!.purchaseChannel}',
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          // 按状态显示操作按钮
          if (order.status == 'shipped') primaryBtn('✅ 设为已完成', _markDone),
          if (order.status == 'shipped')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ghostBtn('转售后（录入售后费用）', _inputAfterSale),
            ),
          if (order.status == 'done') primaryBtn('重新上架', _relist),
          if (order.status == 'done')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ghostBtn('转售后（录入售后费用）', _inputAfterSale),
            ),
          if (order.status == 'aftersale')
            primaryBtn('✏️ 修改售后费用', _inputAfterSale),
          if (order.status == 'cancelled')
            CardBox(
              child: Center(
                child: Text(
                  '该订单已作废（重新上架），利润已从历史统计扣除',
                  style: TextStyle(fontSize: 12, color: C.t3),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(String k, String v, {Color? vc, bool bold = false}) => Padding(
    padding: EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(k, style: TextStyle(fontSize: 12, color: C.t2)),
        ),
        Expanded(
          child: Text(
            v,
            style: TextStyle(
              fontSize: 13,
              color: vc ?? C.t1,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
  Color _sc(String s) =>
      s == 'shipped'
          ? C.brand
          : (s == 'done' ? C.green : (s == 'aftersale' ? C.red : C.t3));
}

// ====== 滞销预警列表页 ======
class StagnantListPage extends StatefulWidget {
  const StagnantListPage({Key? key}) : super(key: key);
  @override
  State<StagnantListPage> createState() => _StagnantListPageState();
}

class _StagnantListPageState extends State<StagnantListPage> {
  void _refresh() => setState(() {});

  /// 降价
  Future<void> _cutPrice(Device d) async {
    final ctrl = TextEditingController(
      text: d.sellPrice > 0 ? (d.sellPrice / 100).toStringAsFixed(0) : '',
    );
    final price = await showDialog<int>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: C.card,
            title: Text('降价', style: TextStyle(color: C.t1, fontSize: 16)),
            content: TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: TextStyle(color: C.t1),
              decoration: InputDecoration(
                labelText: '新售价(元)',
                labelStyle: TextStyle(color: C.t2),
                filled: true,
                fillColor: C.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: C.line),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('取消', style: TextStyle(color: C.t2)),
              ),
              TextButton(
                onPressed: () {
                  final v = (double.tryParse(ctrl.text) ?? 0) * 100;
                  Navigator.pop(ctx, v.toInt());
                },
                child: Text('确定', style: TextStyle(color: C.brand2)),
              ),
            ],
          ),
    );
    if (price != null && price > 0) {
      d.sellPrice = price;
      await gStorage.updateDevice(d);
      setState(() {});
      toast(context, '已降价为${yuan(price)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = gStorage.getDevices().where((d) => d.isStagnant).toList();
    return appScaffold(
      context,
      '滞销预警（超15天）',
      ListView(
        padding: const EdgeInsets.all(14),
        children: [
          if (list.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 60),
              child: Column(
                children: [
                  const Text('✅', style: TextStyle(fontSize: 48)),
                  SizedBox(height: 12),
                  Text(
                    '暂无滞销设备，库存健康',
                    style: TextStyle(color: C.t2, fontSize: 13),
                  ),
                ],
              ),
            )
          else
            ...list.map((d) {
              final hasImg = d.imagePath != null && d.imagePath!.isNotEmpty;
              final firstImg = hasImg ? d.imagePath!.split(';').first : null;
              return Container(
                margin: EdgeInsets.only(bottom: 10),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: C.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: C.red.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A3550),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child:
                              firstImg != null
                                  ? ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.file(
                                      File(firstImg),
                                      fit: BoxFit.cover,
                                      width: 56,
                                      height: 56,
                                    ),
                                  )
                                  : const Center(
                                    child: Icon(
                                      Icons.tablet_mac_rounded,
                                      color: Colors.white70,
                                      size: 22,
                                    ),
                                  ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${d.model} ${d.capacity}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: C.t1,
                                ),
                              ),
                              Text(
                                '${d.color} · ${d.condition} · 电池${d.batteryHealth}%',
                                style: TextStyle(fontSize: 10, color: C.t2),
                              ),
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    yuan(d.sellPrice),
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: C.brand2,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    '采购${yuan(d.purchaseCost)}',
                                    style: TextStyle(fontSize: 10, color: C.t2),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: C.red.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '库${d.stockDays}天',
                            style: const TextStyle(
                              color: C.red,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed:
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SellPage(),
                                  ),
                                ).then((_) => _refresh()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: C.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              '售出',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _cutPrice(d),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: C.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              '降价',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              d.status = 'listed';
                              gStorage.updateDevice(d).then((_) {
                                _refresh();
                                toast(context, '已标记上架');
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: C.brand,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              '上架',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ====== 售出页 ======
class SellPage extends StatefulWidget {
  const SellPage({Key? key}) : super(key: key);
  @override
  State<SellPage> createState() => _SellPageState();
}

class _SellPageState extends State<SellPage> {
  Device? selected;
  final _priceCtrl = TextEditingController();
  final _buyerCtrl = TextEditingController();
  final _repairCtrl = TextEditingController();
  final _feeCtrl = TextEditingController();
  final _logisticsCtrl = TextEditingController(text: '15');
  String channel = '闲鱼';
  int? computedProfit;

  List<Device> get sellable =>
      gStorage
          .getDevices()
          .where((d) => d.status == 'in_stock' || d.status == 'listed')
          .toList();

  void _computeProfit() {
    final price = (double.tryParse(_priceCtrl.text) ?? 0) * 100;
    final repair = (double.tryParse(_repairCtrl.text) ?? 0) * 100;
    final fee = (double.tryParse(_feeCtrl.text) ?? 0) * 100;
    final logi = (double.tryParse(_logisticsCtrl.text) ?? 0) * 100;
    if (selected != null) {
      setState(() {
        computedProfit =
            price.toInt() -
            selected!.purchaseCost -
            repair.toInt() -
            fee.toInt() -
            logi.toInt();
      });
    }
  }

  Future<void> _confirm() async {
    if (selected == null) {
      toast(context, '请选择设备');
      return;
    }
    final priceValue = double.tryParse(_priceCtrl.text);
    if (priceValue == null || priceValue <= 0) {
      toast(context, '请输入售价');
      return;
    }
    final repairValue = double.tryParse(_repairCtrl.text) ?? 0;
    final feeValue = double.tryParse(_feeCtrl.text) ?? 0;
    final logisticsValue = double.tryParse(_logisticsCtrl.text) ?? 0;
    if (repairValue < 0 || feeValue < 0 || logisticsValue < 0) {
      toast(context, '成本费用不能为负数');
      return;
    }
    final now = DateTime.now();
    final price = (priceValue * 100).round();
    final repair = (repairValue * 100).round();
    final fee = (feeValue * 100).round();
    final logi = (logisticsValue * 100).round();
    final profit = price - selected!.purchaseCost - repair - fee - logi;
    if (profit < 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              backgroundColor: C.card,
              title: Text(
                '确认亏损出售',
                style: TextStyle(color: C.t1, fontSize: 16),
              ),
              content: Text(
                '这单预计亏损 ${yuan(profit.abs())}。确认继续记录出售吗？',
                style: TextStyle(color: C.t2, fontSize: 13),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('取消', style: TextStyle(color: C.t2)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text('继续出售', style: TextStyle(color: C.red)),
                ),
              ],
            ),
      );
      if (ok != true) return;
    }
    final d = selected!;
    d.status = 'sold';
    d.sellPrice = price;
    d.sellChannel = channel;
    d.sellDate = _fmt(now);
    d.repairCost = repair;
    d.platformFee = fee;
    d.logisticsCost = logi;
    d.buyerContact = _buyerCtrl.text.trim();
    await gStorage.updateDevice(d);
    await gStorage.addOrder(
      Order(
        id: 'o${now.millisecondsSinceEpoch}',
        deviceId: d.id,
        deviceName: '${d.model} ${d.capacity}',
        buyer: _buyerCtrl.text.trim().isEmpty ? '未知' : _buyerCtrl.text.trim(),
        channel: channel,
        amount: price,
        profit: profit,
        status: 'shipped',
        createdAt:
            _fmt(now) +
            ' ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      ),
    );
    toast(context, '✅ 已售出，毛利${yuan(profit)}');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => appScaffold(
    context,
    '售出设备',
    ListView(
      padding: const EdgeInsets.all(16),
      children: [
        CardBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('选择设备', style: TextStyle(fontSize: 12, color: C.t2)),
              const SizedBox(height: 8),
              ...sellable.map(
                (d) => GestureDetector(
                  onTap:
                      () => setState(() {
                        selected = d;
                        _computeProfit();
                      }),
                  child: Container(
                    margin: EdgeInsets.only(bottom: 8),
                    padding: EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color:
                          selected?.id == d.id
                              ? C.brand.withOpacity(0.15)
                              : C.bg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected?.id == d.id ? C.brand : C.line,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.tablet_mac_rounded, color: C.t2, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${d.model} ${d.capacity} ${d.color}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: C.t1,
                                ),
                              ),
                              Text(
                                '采购${yuan(d.purchaseCost)} · 库${d.stockDays}天',
                                style: TextStyle(fontSize: 10, color: C.t2),
                              ),
                            ],
                          ),
                        ),
                        if (selected?.id == d.id)
                          Text(
                            '✓',
                            style: TextStyle(color: C.brand2, fontSize: 16),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (selected != null)
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _priceCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _computeProfit(),
                  style: TextStyle(color: C.t1, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: '售价(元)',
                    labelStyle: TextStyle(color: C.t2),
                    filled: true,
                    fillColor: C.bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: C.line),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _repairCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _computeProfit(),
                        style: TextStyle(color: C.t1, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: '维修成本',
                          labelStyle: TextStyle(color: C.t2),
                          filled: true,
                          fillColor: C.bg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: C.line),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _feeCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _computeProfit(),
                        style: TextStyle(color: C.t1, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: '平台佣金',
                          labelStyle: TextStyle(color: C.t2),
                          filled: true,
                          fillColor: C.bg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: C.line),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _logisticsCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _computeProfit(),
                        style: TextStyle(color: C.t1, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: '物流',
                          labelStyle: TextStyle(color: C.t2),
                          filled: true,
                          fillColor: C.bg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: C.line),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _buyerCtrl,
                  style: TextStyle(color: C.t1, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: '买家',
                    labelStyle: TextStyle(color: C.t2),
                    filled: true,
                    fillColor: C.bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: C.line),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text('渠道：', style: TextStyle(fontSize: 12, color: C.t2)),
                    const SizedBox(width: 8),
                    ...['闲鱼', '抖音', '转转', '私域', '同行'].map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(c, style: const TextStyle(fontSize: 11)),
                          selected: channel == c,
                          selectedColor: C.brand,
                          onSelected: (_) => setState(() => channel = c),
                        ),
                      ),
                    ),
                  ],
                ),
                if (computedProfit != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (computedProfit! >= 0 ? C.green : C.red)
                            .withOpacity(0.12),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Row(
                        children: [
                          Text(
                            computedProfit! >= 0 ? '💰' : '📉',
                            style: const TextStyle(fontSize: 20),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '预计毛利：${yuan(computedProfit!)}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: computedProfit! >= 0 ? C.green : C.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                primaryBtn('✅ 确认售出', _confirm),
              ],
            ),
          ),
      ],
    ),
  );
}

// ====== 设备详情页 ======
class DetailPage extends StatefulWidget {
  final Device device;
  const DetailPage({Key? key, required this.device}) : super(key: key);
  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  String? aiPrice;
  bool loading = false;
  bool downloading = false;
  late Device device;
  final GlobalKey _coverKey = GlobalKey();
  static const _galleryChannel = MethodChannel('ipad_boss_app/gallery');

  @override
  void initState() {
    super.initState();
    device = widget.device;
  }

  Future<void> _askAi() async {
    setState(() => loading = true);
    final r = await AiService.priceAdvice(
      model: device.model,
      capacity: device.capacity,
      color: device.color,
      network: device.network,
      condition: device.condition,
      batteryHealth: device.batteryHealth,
      purchaseCost: device.purchaseCost,
      stockDays: device.stockDays,
    );
    setState(() {
      aiPrice = r;
      loading = false;
    });
  }

  void _adjustPrice() async {
    final ctrl = TextEditingController(
      text:
          device.sellPrice > 0
              ? (device.sellPrice / 100).toStringAsFixed(0)
              : '',
    );
    final result = await showDialog<int>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: C.card,
            title: Text('售价微调', style: TextStyle(color: C.t1, fontSize: 16)),
            content: TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: TextStyle(color: C.t1),
              decoration: InputDecoration(
                labelText: '新售价(元)',
                labelStyle: TextStyle(color: C.t2),
                filled: true,
                fillColor: C.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: C.line),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('取消', style: TextStyle(color: C.t2)),
              ),
              TextButton(
                onPressed: () {
                  final v = (double.tryParse(ctrl.text) ?? 0) * 100;
                  Navigator.pop(ctx, v.toInt());
                },
                child: Text('确定', style: TextStyle(color: C.brand2)),
              ),
            ],
          ),
    );
    if (result == null) return;
    if (result <= 0) {
      toast(context, '售价需大于0');
      return;
    }
    device.sellPrice = result;
    if (device.status == 'in_stock') device.status = 'listed';
    await gStorage.updateDevice(device);
    setState(() {});
    toast(context, '售价已调整为${yuan(result)}');
  }

  void _genReport() {
    final report = '''【机掌柜验机报告】

设备：${device.model} ${device.capacity} ${device.color}
序列号：${device.serial}
网络制式：${device.network}

—— 成色鉴定 ——
成色等级：${device.condition}
电池健康度：${device.batteryHealth}%
充电循环次数：${device.cycleCount}次

—— 安全检测 ——
iCloud激活锁：${device.idLockClean ? "无锁 ✓" : "有锁 ✗"}
ID锁状态：${device.idLockClean ? "正常 ✓" : "异常 ✗"}
配件：${device.accessories}

—— 质检结论 ——
${device.idLockClean ? "✅ 该设备各项检测正常，可正常交易" : "⚠️ 该设备存在ID锁风险，建议谨慎"}

检测时间：${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}
报告由「机掌柜」自动生成''';
    Clipboard.setData(ClipboardData(text: report));
    toast(context, '验机报告已复制到剪贴板，可粘贴发给买家');
  }

  /// 一键下载：描述存剪贴板 + 图片存相册 + 最前面插自制封面图
  /// [openXianyu] 为 true 时下载成功后拉起闲鱼 app
  Future<void> _downloadAll({bool openXianyu = false}) async {
    if (downloading) return;
    setState(() => downloading = true);
    try {
      // 1. 截取自制封面图（RepaintBoundary 渲染的设备信息卡）
      String? coverPath;
      final ctx = _coverKey.currentContext;
      if (ctx != null) {
        final boundary = ctx.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2.5);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          final coverFile = File(
            '$gDocDir/cover_${device.id}_${DateTime.now().millisecondsSinceEpoch}.png',
          );
          await coverFile.writeAsBytes(byteData.buffer.asUint8List());
          coverPath = coverFile.path;
        }
      }

      // 2. 组装图片列表：封面图在最前 + 设备实拍图
      final images = <String>[];
      if (coverPath != null) images.add(coverPath);
      if (device.imagePath != null && device.imagePath!.isNotEmpty) {
        images.addAll(
          device.imagePath!
              .split(';')
              .where((s) => s.isNotEmpty && File(s).existsSync()),
        );
      }

      // 3. 商品描述复制到剪贴板
      final desc = (device.description ?? '').trim();
      if (desc.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: desc));
      }

      // 4. 调用原生通道把图片保存到手机相册
      if (images.isEmpty) {
        toast(context, desc.isNotEmpty ? '✅ 描述已复制到剪贴板（暂无图片）' : '暂无可下载的图片与描述');
        return;
      }
      final result = await _galleryChannel.invokeMethod('saveImagesToGallery', {
        'paths': images,
        'albumName': '机掌柜',
      });
      final saved = (result is Map) ? (result['saved'] as int? ?? 0) : 0;
      final msg = StringBuffer('✅ 已保存${saved}张图到相册');
      if (desc.isNotEmpty) msg.write('，描述已复制到剪贴板');
      toast(context, msg.toString());

      // 5. 按需拉起闲鱼
      if (openXianyu) {
        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;
        await _openXianyu();
      }
    } catch (e) {
      toast(context, '下载失败：$e');
    } finally {
      if (mounted) setState(() => downloading = false);
    }
  }

  /// 拉起闲鱼 app（已安装则直接打开，未安装提示去应用商店）
  Future<void> _openXianyu() async {
    try {
      final result = await _galleryChannel.invokeMethod('openXianyu');
      if (result is Map && result['success'] == true) {
        toast(context, '已打开闲鱼，去发布商品吧');
      } else {
        // 闲鱼未安装，提示用户
        toast(context, '未检测到闲鱼，请先安装闲鱼 app');
      }
    } catch (e) {
      toast(context, '拉起闲鱼失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImg = device.imagePath != null && device.imagePath!.isNotEmpty;
    final images = hasImg ? device.imagePath!.split(';') : <String>[];
    final hasDesc =
        device.description != null && device.description!.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              children: [
                Stack(
                  children: [
                    Container(
                      height: 230,
                      color: C.cardMuted,
                      child:
                          images.isNotEmpty
                              ? Image.file(
                                File(images.first),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 230,
                              )
                              : Center(
                                child: Icon(
                                  Icons.tablet_mac_rounded,
                                  color: C.t3,
                                  size: 64,
                                ),
                              ),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.32),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.chevron_left_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 12,
                      left: 14,
                      child: StatusChip(
                        device.idLockClean ? 'ID无锁' : 'ID异常',
                        device.idLockClean ? C.green : C.red,
                      ),
                    ),
                    if (device.isStagnant)
                      const Positioned(
                        bottom: 12,
                        right: 14,
                        child: StatusChip('滞销', C.red),
                      ),
                  ],
                ),
                // 多图横向展示
                if (images.length > 1)
                  SizedBox(
                    height: 80,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: images.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder:
                          (_, i) => ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(images[i]),
                              width: 70,
                              height: 70,
                              fit: BoxFit.cover,
                            ),
                          ),
                    ),
                  ),
                CardBox(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${device.model} ${device.capacity} ${device.color}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: C.t1,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            device.sellPrice > 0
                                ? yuan(device.sellPrice)
                                : '未定价',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: device.sellPrice > 0 ? C.brand : C.orange,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '采购${yuan(device.purchaseCost)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: C.t2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          if (device.status == 'sold')
                            StatusChip(
                              '毛利${yuan(device.netProfit)}',
                              device.netProfit >= 0 ? C.green : C.red,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${device.purchaseChannel} · 库龄${device.stockDays}天 · ${device.serial.isEmpty ? "暂无序列号" : device.serial}',
                        style: TextStyle(fontSize: 11.5, color: C.t2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 9,
                    crossAxisSpacing: 9,
                    childAspectRatio: 3.2,
                    children: [
                      _a('型号', device.model),
                      _a('容量/颜色', '${device.capacity} ${device.color}'),
                      _a('网络', device.network),
                      _a('成色', device.condition),
                      _a('电池健康', '${device.batteryHealth}%'),
                      _a('循环次数', '${device.cycleCount}次'),
                      _a(
                        'ID锁检测',
                        device.idLockClean ? '✓ 无锁' : '✗ 有锁',
                        vc: device.idLockClean ? C.green : C.red,
                      ),
                      _a(
                        '在库天数',
                        '${device.stockDays}天${device.isStagnant ? "(滞销)" : ""}',
                      ),
                    ],
                  ),
                ),
                // 商品描述（AI生成，三行高度可滑动，不占太多篇幅）
                CardBox(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle('商品描述', trailing: 'AI生成'),
                      const SizedBox(height: 8),
                      Container(
                        height: 66, // 约三行高度
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: C.bg,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: C.line),
                        ),
                        child:
                            hasDesc
                                ? SingleChildScrollView(
                                  child: SelectableText(
                                    device.description!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: C.t2,
                                      height: 1.5,
                                    ),
                                  ),
                                )
                                : Center(
                                  child: Text(
                                    '暂无AI描述（入库时未生成）',
                                    style: TextStyle(fontSize: 12, color: C.t3),
                                  ),
                                ),
                      ),
                    ],
                  ),
                ),
                CardBox(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionTitle(
                        'AI定价建议',
                        trailing: AiService.effectiveConfig.model,
                      ),
                      const SizedBox(height: 8),
                      if (aiPrice != null)
                        Text(
                          aiPrice!,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: C.t2,
                            height: 1.8,
                          ),
                        )
                      else
                        Text(
                          '点击下方按钮，调用AI根据型号/成色/电池/采购成本/库存天数给出定价建议',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: C.t3,
                            height: 1.8,
                          ),
                        ),
                      const SizedBox(height: 12),
                      if (loading)
                        const Center(
                          child: CircularProgressIndicator(color: C.brand2),
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _askAi,
                            icon: const Icon(
                              Icons.auto_awesome_rounded,
                              size: 18,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: C.purple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(11),
                              ),
                              elevation: 0,
                            ),
                            label: const Text(
                              '调用 AI 定价',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // 一键下载：两个并排按钮（纯下载 / 下载并去闲鱼）
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed:
                              downloading
                                  ? null
                                  : () => _downloadAll(openXianyu: false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: C.card,
                            foregroundColor: C.t1,
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
                            ),
                            elevation: 0,
                            side: BorderSide(color: C.line),
                          ),
                          child: const Text(
                            '仅下载',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed:
                              downloading
                                  ? null
                                  : () => _downloadAll(openXianyu: true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: C.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
                            ),
                            elevation: 0,
                          ),
                          child:
                              downloading
                                  ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                  : const Text(
                                    '下载并去闲鱼',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (device.status == 'in_stock' || device.status == 'listed')
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                    child: primaryBtn(
                      '售出此设备',
                      () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const SellPage()),
                      ),
                    ),
                  ),
                if (device.status == 'in_stock' || device.status == 'listed')
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                    child: ghostBtn('售价微调', _adjustPrice),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  child: ghostBtn('生成验机报告', _genReport),
                ),
                CardBox(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle('全链路追溯'),
                      const SizedBox(height: 12),
                      _tl(
                        '收购入库',
                        '${device.purchaseDate} · 采购${yuan(device.purchaseCost)} · ${device.purchaseChannel}',
                        true,
                      ),
                      _tl(
                        '质检完成',
                        '${device.condition} · 电池${device.batteryHealth}% · ID锁${device.idLockClean ? "无锁 ✓" : "有锁 ✗"}',
                        true,
                      ),
                      if (device.status == 'listed')
                        _tl(
                          '上架待售',
                          '标价${device.sellPrice > 0 ? yuan(device.sellPrice) : "未定"} · 在库${device.stockDays}天${device.isStagnant ? " · 滞销" : ""}',
                          false,
                          last: true,
                        ),
                      if (device.status == 'sold' &&
                          device.repairCost != null &&
                          device.repairCost! > 0)
                        _tl(
                          '翻新维修',
                          '${device.sellDate ?? ""} · 成本${yuan(device.repairCost!)}',
                          false,
                        ),
                      if (device.status == 'sold')
                        _tl(
                          '已售出',
                          '${device.sellDate ?? ""} · ${device.sellChannel ?? ""} · 售价${yuan(device.sellPrice)} · 毛利${yuan(device.netProfit)}',
                          true,
                          last: true,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            // 屏幕外的自制封面图（用于一键下载时截图，置顶相册防止闲鱼错乱）
            Positioned(
              left: -10000,
              top: 0,
              child: RepaintBoundary(key: _coverKey, child: _buildCoverImage()),
            ),
          ],
        ),
      ),
    );
  }

  /// 自制封面图：包含设备核心信息，下载时截图置顶相册
  Widget _buildCoverImage() {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 360,
        height: 480,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E293B), Color(0xFF0B0F1A)],
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: C.selected,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.tablet_mac_rounded,
                    color: C.brand,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  '机掌柜',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: C.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    device.idLockClean ? 'ID无锁' : 'ID有锁',
                    style: TextStyle(
                      color: device.idLockClean ? C.green : C.red,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              device.model,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              '${device.capacity} · ${device.color} · ${device.network}',
              style: const TextStyle(
                color: C.brand2,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            _coverRow('成色', device.condition),
            _coverRow('电池健康', '${device.batteryHealth}%'),
            _coverRow('充电循环', '${device.cycleCount}次'),
            _coverRow('序列号', device.serial),
            const Spacer(),
            Container(
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: C.line),
              ),
              child: Row(
                children: [
                  Text('售价', style: TextStyle(color: C.t2, fontSize: 13)),
                  const Spacer(),
                  Text(
                    device.sellPrice > 0 ? yuan(device.sellPrice) : '未定价',
                    style: const TextStyle(
                      color: C.brand2,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: Text(
                '${device.purchaseDate} · 实拍图见后续',
                style: TextStyle(color: C.t3, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coverRow(String k, String v) => Padding(
    padding: EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(k, style: TextStyle(color: C.t2, fontSize: 13)),
        ),
        Expanded(
          child: Text(
            v,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
  Widget _a(String l, String v, {Color? vc}) => Container(
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: C.cardMuted,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: C.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          l,
          style: TextStyle(
            fontSize: 10,
            color: C.t2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          v,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: vc ?? C.t1,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
  Widget _tl(String tt, String td, bool active, {bool last = false}) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Column(
        children: [
          Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: active ? C.brand : C.t3,
              shape: BoxShape.circle,
              border: Border.all(color: C.bg, width: 2),
            ),
          ),
          if (!last) Container(width: 2, height: 36, color: C.line),
        ],
      ),
      SizedBox(width: 11),
      Expanded(
        child: Padding(
          padding: EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tt,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: C.t1,
                ),
              ),
              SizedBox(height: 2),
              Text(td, style: TextStyle(fontSize: 11, color: C.t2)),
            ],
          ),
        ),
      ),
    ],
  );
}

// ====== AI日报页 ======
class AiReportPage extends StatefulWidget {
  const AiReportPage({Key? key}) : super(key: key);
  @override
  State<AiReportPage> createState() => _AiReportPageState();
}

class _AiReportPageState extends State<AiReportPage> {
  String? report;
  bool loading = false;
  List<String> highlights = [];
  List<String> concerns = [];
  List<String> suggestions = [];
  List<String> localAnomalies = [];

  Future<void> _gen() async {
    setState(() => loading = true);
    final s = gStorage.computeStats();
    final stg =
        gStorage
            .getDevices()
            .where((d) => d.isStagnant)
            .map((d) => '${d.model} ${d.capacity}')
            .toList();

    // 本地异常检测
    localAnomalies = _detectAnomalies(s);

    final r = await AiService.dailyReport(
      gmv: s.gmv,
      grossProfit: s.grossProfit,
      orderCount: s.orderCount,
      inStock: s.inStockCount,
      stagnant: s.stagnantCount,
      capital: s.capitalOccupied,
      stagnantModels: stg,
    );
    _parseReport(r);
    setState(() {
      report = r;
      loading = false;
    });
  }

  /// 本地异常检测
  List<String> _detectAnomalies(dynamic s) {
    final anomalies = <String>[];
    final devices = gStorage.getDevices();

    // 1. 滞销率 > 30%
    if (s.stagnantCount > 0 && s.inStockCount > 0) {
      final rate = s.stagnantCount / s.inStockCount;
      if (rate > 0.3) {
        anomalies.add('滞销率 ${(rate * 100).toStringAsFixed(0)}%，超过 30% 警戒线');
      }
    }

    // 2. 今日GMV比周均值低50%以上
    final sold =
        devices.where((d) => d.status == 'sold' && d.sellDate != null).toList();
    final today = DateTime.now();
    final weekAgo = today.subtract(const Duration(days: 7));
    final weekSales =
        sold.where((d) {
          try {
            return DateTime.parse(d.sellDate!).isAfter(weekAgo);
          } catch (_) {
            return false;
          }
        }).toList();
    if (weekSales.length >= 3 && s.gmv > 0) {
      final weekAvgGmv =
          weekSales.fold(0, (int sum, d) => sum + d.sellPrice) ~/
          weekSales.length;
      if (s.gmv < weekAvgGmv * 0.5) {
        anomalies.add('今日 GMV 低于近 7 日均值 50% 以上');
      }
    }

    // 3. 单台利润低于历史均值50%
    final soldHasProfit = sold.where((d) => d.netProfit > 0).toList();
    if (soldHasProfit.length >= 3) {
      final avgProfit =
          soldHasProfit.fold(0, (int sum, d) => sum + d.netProfit) ~/
          soldHasProfit.length;
      final todaySold =
          sold.where((d) {
            try {
              return DateTime.parse(d.sellDate!).day == today.day;
            } catch (_) {
              return false;
            }
          }).toList();
      for (final d in todaySold) {
        if (d.netProfit < avgProfit * 0.5) {
          anomalies.add(
            '${d.model} ${d.capacity} 利润 ${(d.netProfit / 100).toStringAsFixed(0)}元，低于历史均值 50%',
          );
          break;
        }
      }
    }

    // 4. 某机型连续7天无动销（有库存但没卖出）
    for (final model in devices.map((d) => d.model).toSet()) {
      final inStock =
          devices
              .where(
                (d) =>
                    d.model == model &&
                    (d.status == 'in_stock' || d.status == 'listed'),
              )
              .toList();
      if (inStock.isNotEmpty) {
        final lastSold =
            sold.where((d) => d.model == model).toList()
              ..sort((a, b) => (b.sellDate ?? '').compareTo(a.sellDate ?? ''));
        if (lastSold.isNotEmpty) {
          try {
            final lastDate = DateTime.parse(lastSold.first.sellDate!);
            if (today.difference(lastDate).inDays >= 7) {
              anomalies.add('$model 已有 7 天以上无动销，库存 ${inStock.length} 台');
            }
          } catch (_) {}
        } else {
          anomalies.add('$model 从未售出，库存 ${inStock.length} 台');
        }
      }
    }

    return anomalies;
  }

  /// 解析结构化输出
  void _parseReport(String text) {
    highlights = [];
    concerns = [];
    suggestions = [];
    String currentSection = '';
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.contains('【亮点】') || trimmed.contains('[亮点]')) {
        currentSection = 'highlights';
      } else if (trimmed.contains('【待关注】') || trimmed.contains('[待关注]')) {
        currentSection = 'concerns';
      } else if (trimmed.contains('【明日建议】') || trimmed.contains('[明日建议]')) {
        currentSection = 'suggestions';
      } else if (trimmed.startsWith('•') ||
          trimmed.startsWith('-') ||
          trimmed.startsWith('*')) {
        final item = trimmed.substring(1).trim();
        if (item.isNotEmpty) {
          if (currentSection == 'highlights')
            highlights.add(item);
          else if (currentSection == 'concerns')
            concerns.add(item);
          else if (currentSection == 'suggestions')
            suggestions.add(item);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = gStorage.computeStats();
    return appScaffold(
      context,
      'AI经营日报',
      ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // 今日数据头
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Color(0xFF4338CA)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      '今日数据',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE0E7FF),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '更新于 ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, "0")}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFFA5B4FC),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _d('GMV', yuan(s.gmv)),
                    _d('毛利', yuan(s.grossProfit)),
                    _d('在售', '${s.inStockCount}台'),
                    _d('滞销', '${s.stagnantCount}台'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // AI生成按钮
          if (report == null && !loading)
            CardBox(
              child: Column(
                children: [
                  Text(
                    '点击下方按钮，AI将基于你的真实经营数据生成今日日报与建议',
                    style: TextStyle(fontSize: 12.5, color: C.t3, height: 1.8),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  primaryBtn('生成AI日报', _gen),
                ],
              ),
            ),
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: C.brand2),
              ),
            ),
          // 结构化卡片
          if (report != null && !loading) ...[
            // 亮点
            if (highlights.isNotEmpty)
              _sectionCard('✅ 今日亮点', highlights, C.green),
            const SizedBox(height: 10),
            // 待关注
            if (concerns.isNotEmpty) _sectionCard('⚠️ 待关注', concerns, C.orange),
            const SizedBox(height: 10),
            // 建议
            if (suggestions.isNotEmpty)
              _sectionCard('🎯 明日建议', suggestions, C.brand2),
            const SizedBox(height: 10),
            // 本地异常检测
            if (localAnomalies.isNotEmpty)
              _sectionCard('🚨 异常预警', localAnomalies, C.red),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _gen,
                style: OutlinedButton.styleFrom(
                  foregroundColor: C.brand2,
                  side: BorderSide(color: C.brand2),
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                child: const Text('重新生成', style: TextStyle(fontSize: 13)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionCard(String title, List<String> items, Color accent) {
    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: C.t1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: C.t1,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _d(String l, String v) => Expanded(
    child: Column(
      children: [
        Text(
          v,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Color(0xFFFBBF24),
          ),
        ),
        const SizedBox(height: 2),
        Text(l, style: const TextStyle(fontSize: 10, color: Color(0xFFA5B4FC))),
      ],
    ),
  );
}

// ====== 代理管理页 ======
class AgentManagerPage extends StatefulWidget {
  const AgentManagerPage({Key? key}) : super(key: key);
  @override
  State<AgentManagerPage> createState() => _AgentManagerPageState();
}

class _AgentManagerPageState extends State<AgentManagerPage> {
  void _refresh() => setState(() {});

  Future<void> _addAgent() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final rateCtrl = TextEditingController(text: '10');
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: C.card,
            title: Text('新增代理', style: TextStyle(color: C.t1, fontSize: 16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: TextStyle(color: C.t1),
                  decoration: InputDecoration(
                    labelText: '代理名称',
                    labelStyle: TextStyle(color: C.t2),
                    filled: true,
                    fillColor: C.bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: C.line),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  style: TextStyle(color: C.t1),
                  decoration: InputDecoration(
                    labelText: '联系方式',
                    labelStyle: TextStyle(color: C.t2),
                    filled: true,
                    fillColor: C.bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: C.line),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: rateCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: C.t1),
                  decoration: InputDecoration(
                    labelText: '佣金比例(%)',
                    labelStyle: TextStyle(color: C.t2),
                    filled: true,
                    fillColor: C.bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: C.line),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('取消', style: TextStyle(color: C.t2)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('添加', style: TextStyle(color: C.brand2)),
              ),
            ],
          ),
    );
    if (ok == true && nameCtrl.text.isNotEmpty) {
      final now = DateTime.now();
      await gStorage.addAgent(
        Agent(
          id: 'a${now.millisecondsSinceEpoch}',
          name: nameCtrl.text,
          phone: phoneCtrl.text,
          commissionRate: (double.tryParse(rateCtrl.text) ?? 10) / 100,
          totalGmv: 0,
          createdAt: _fmt(now),
        ),
      );
      _refresh();
      toast(context, '已添加代理');
    }
  }

  @override
  Widget build(BuildContext context) {
    final agents = gStorage.getAgents();
    return appScaffold(
      context,
      '私域分销 · 代理管理',
      ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: primaryBtn('新增代理', _addAgent),
          ),
          if (agents.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 40),
              child: Column(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: C.cardMuted,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: C.line),
                    ),
                    child: Icon(Icons.groups_2_outlined, color: C.t3, size: 26),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '暂无代理，点击上方添加',
                    style: TextStyle(color: C.t2, fontSize: 13),
                  ),
                ],
              ),
            )
          else
            ...agents.map(
              (a) => CardBox(
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: C.pink.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(
                        Icons.person_outline_rounded,
                        color: C.pink,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: C.t1,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${a.phone} · 佣金${(a.commissionRate * 100).toStringAsFixed(0)}%',
                            style: TextStyle(fontSize: 11, color: C.t2),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '累计GMV ${yuan(a.totalGmv)} · 加入${a.createdAt}',
                            style: TextStyle(fontSize: 10, color: C.t3),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        final ok = await confirmAction(
                          context,
                          title: '删除代理',
                          message: '确定删除代理「${a.name}」吗？此操作不会删除历史订单。',
                          confirmText: '删除',
                        );
                        if (!ok) return;
                        await gStorage.deleteAgent(a.id);
                        _refresh();
                        toast(context, '已删除');
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          color: C.red,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ====== 财务中心页 ======
class FinancePage extends StatefulWidget {
  const FinancePage({Key? key}) : super(key: key);
  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  @override
  Widget build(BuildContext context) {
    final soldDevices =
        gStorage.getDevices().where((d) => d.status == 'sold').toList();
    int totalProfit = 0;
    int totalRevenue = 0;
    int totalCost = 0;
    for (final d in soldDevices) {
      totalProfit += d.netProfit;
      totalRevenue += d.sellPrice;
      totalCost +=
          d.purchaseCost +
          (d.repairCost ?? 0) +
          (d.platformFee ?? 0) +
          (d.logisticsCost ?? 0);
    }
    final profitByModel = gStorage.getProfitByModel();
    final orders = gStorage.getOrders();
    return appScaffold(
      context,
      '财务中心 · 单台利润',
      ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [C.green, C.brand2]),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '累计净利',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  yuan(totalProfit),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '累计营收',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                        Text(
                          yuan(totalRevenue),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 18),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '累计成本',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                        Text(
                          yuan(totalCost),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 18),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '已售台数',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                        Text(
                          '${soldDevices.length}台',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (profitByModel.isNotEmpty)
            CardBox(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '按型号利润分析',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: C.t1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...profitByModel.map(
                    (m) => Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m['model'] as String,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: C.t1,
                                  ),
                                ),
                                Text(
                                  '${m["count"]}台 · 营收${yuan(m["revenue"] as int)}',
                                  style: TextStyle(fontSize: 10, color: C.t2),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            yuan(m['profit'] as int),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color:
                                  (m['profit'] as int) >= 0 ? C.green : C.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '单台利润明细',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: C.t1,
                  ),
                ),
                const SizedBox(height: 10),
                if (soldDevices.isEmpty)
                  Text('暂无已售设备', style: TextStyle(fontSize: 12, color: C.t2))
                else
                  ...soldDevices.map(
                    (d) => Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: C.bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: C.line),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.tablet_mac_rounded,
                              color: C.t2,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${d.model} ${d.capacity}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: C.t1,
                                    ),
                                  ),
                                  Text(
                                    '售价${yuan(d.sellPrice)} · 成本${yuan(d.purchaseCost + (d.repairCost ?? 0) + (d.platformFee ?? 0) + (d.logisticsCost ?? 0))}',
                                    style: TextStyle(fontSize: 10, color: C.t2),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              yuan(d.netProfit),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: d.netProfit >= 0 ? C.green : C.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '收支流水',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: C.t1,
                  ),
                ),
                const SizedBox(height: 10),
                if (orders.isEmpty)
                  Text('暂无流水', style: TextStyle(fontSize: 12, color: C.t2))
                else
                  ...orders
                      .take(20)
                      .map(
                        (o) => Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${o.deviceName} · ${o.channel}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: C.t1,
                                      ),
                                    ),
                                    Text(
                                      o.createdAt,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: C.t2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '+${yuan(o.profit)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: C.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ====== 客户管理页 ======
class CustomerPage extends StatefulWidget {
  const CustomerPage({Key? key}) : super(key: key);
  @override
  State<CustomerPage> createState() => _CustomerPageState();
}

class _CustomerPageState extends State<CustomerPage> {
  @override
  Widget build(BuildContext context) {
    final customers = gStorage.getCustomers();
    return appScaffold(
      context,
      '客户管理 · 复购召回',
      ListView(
        padding: const EdgeInsets.all(14),
        children: [
          if (customers.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 40),
              child: Column(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: C.cardMuted,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: C.line),
                    ),
                    child: Icon(Icons.contacts_outlined, color: C.t3, size: 26),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '暂无客户，售出设备后自动生成',
                    style: TextStyle(color: C.t2, fontSize: 13),
                  ),
                ],
              ),
            )
          else
            ...customers.map(
              (c) => CardBox(
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: C.orange.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(
                        Icons.person_outline_rounded,
                        color: C.orange,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c['name'] as String,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: C.t1,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '购买${c["count"]}次 · 累计${yuan(c["totalAmount"] as int)}',
                            style: TextStyle(fontSize: 11, color: C.t2),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '最后购买：${c["lastDate"]} · 渠道：${(c["channels"] as Set).join("/")}',
                            style: TextStyle(fontSize: 10, color: C.t3),
                          ),
                        ],
                      ),
                    ),
                    if ((c['count'] as int) >= 2)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: C.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text(
                          '复购',
                          style: TextStyle(
                            fontSize: 9,
                            color: C.green,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.all(14),
            child: Text(
              '客户数据从订单自动聚合，售出设备越多客户库越完善。复购客户建议主动回访，推荐以旧换新。',
              style: TextStyle(fontSize: 11, color: C.t3, height: 1.7),
            ),
          ),
        ],
      ),
    );
  }
}

// ====== 翻新维修页 ======
class RepairPage extends StatefulWidget {
  const RepairPage({Key? key}) : super(key: key);
  @override
  State<RepairPage> createState() => _RepairPageState();
}

class _RepairPageState extends State<RepairPage> {
  void _refresh() => setState(() {});

  Future<void> _addRepair() async {
    final devices =
        gStorage
            .getDevices()
            .where((d) => d.status == 'in_stock' || d.status == 'listed')
            .toList();
    if (devices.isEmpty) {
      toast(context, '暂无可维修设备');
      return;
    }
    Device? sel;
    String type = '换电池';
    final costCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx2, setS) => AlertDialog(
                  backgroundColor: C.card,
                  title: Text(
                    '新增维修工单',
                    style: TextStyle(color: C.t1, fontSize: 16),
                  ),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '选择设备',
                          style: TextStyle(fontSize: 11, color: C.t2),
                        ),
                        const SizedBox(height: 6),
                        ...devices.map(
                          (d) => GestureDetector(
                            onTap: () => setS(() => sel = d),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color:
                                    sel?.id == d.id
                                        ? C.brand.withOpacity(0.15)
                                        : C.bg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: sel?.id == d.id ? C.brand : C.line,
                                ),
                              ),
                              child: Text(
                                '${d.model} ${d.capacity}',
                                style: TextStyle(fontSize: 12, color: C.t1),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          children:
                              ['换电池', '换屏', '换壳', '其他']
                                  .map(
                                    (t) => Padding(
                                      padding: const EdgeInsets.only(
                                        right: 6,
                                        bottom: 4,
                                      ),
                                      child: ChoiceChip(
                                        label: Text(
                                          t,
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                        selected: type == t,
                                        selectedColor: C.brand,
                                        onSelected: (_) => setS(() => type = t),
                                      ),
                                    ),
                                  )
                                  .toList(),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: costCtrl,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: C.t1),
                          decoration: InputDecoration(
                            labelText: '维修成本(元)',
                            labelStyle: TextStyle(color: C.t2),
                            filled: true,
                            fillColor: C.bg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: C.line),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: noteCtrl,
                          style: TextStyle(color: C.t1),
                          decoration: InputDecoration(
                            labelText: '备注',
                            labelStyle: TextStyle(color: C.t2),
                            filled: true,
                            fillColor: C.bg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: C.line),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx2, false),
                      child: Text('取消', style: TextStyle(color: C.t2)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx2, true),
                      child: const Text(
                        '提交',
                        style: TextStyle(color: C.brand2),
                      ),
                    ),
                  ],
                ),
          ),
    );
    if (ok == true && sel != null) {
      final now = DateTime.now();
      final cost = (double.tryParse(costCtrl.text) ?? 0) * 100;
      await gStorage.addRepairOrder(
        RepairOrder(
          id: 'r${now.millisecondsSinceEpoch}',
          deviceId: sel!.id,
          deviceName: '${sel!.model} ${sel!.capacity}',
          type: type,
          cost: cost.toInt(),
          status: '完成',
          note: noteCtrl.text,
          createdAt: _fmt(now),
        ),
      );
      sel!.repairCost = (sel!.repairCost ?? 0) + cost.toInt();
      await gStorage.updateDevice(sel!);
      _refresh();
      toast(context, '维修工单已创建');
    }
  }

  @override
  Widget build(BuildContext context) {
    final repairs = gStorage.getRepairOrders();
    return appScaffold(
      context,
      '翻新维修 · 配件库存',
      ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: primaryBtn('新增维修工单', _addRepair),
          ),
          if (repairs.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 40),
              child: Column(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: C.cardMuted,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: C.line),
                    ),
                    child: Icon(
                      Icons.build_circle_outlined,
                      color: C.t3,
                      size: 26,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text('暂无维修工单', style: TextStyle(color: C.t2, fontSize: 13)),
                ],
              ),
            )
          else
            ...repairs.map(
              (r) => CardBox(
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: C.brand2.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(_typeIcon(r.type), color: C.brand2, size: 20),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${r.deviceName} · ${r.type}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: C.t1,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '成本${yuan(r.cost)} · ${r.status} · ${r.createdAt}',
                            style: TextStyle(fontSize: 10, color: C.t2),
                          ),
                          if (r.note.isNotEmpty)
                            Text(
                              '备注：${r.note}',
                              style: TextStyle(fontSize: 10, color: C.t3),
                            ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        final ok = await confirmAction(
                          context,
                          title: '删除维修工单',
                          message: '确定删除「${r.deviceName} · ${r.type}」这条维修记录吗？',
                          confirmText: '删除',
                        );
                        if (!ok) return;
                        await gStorage.deleteRepairOrder(r.id);
                        _refresh();
                        toast(context, '已删除');
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          color: C.red,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _typeIcon(String t) =>
      t == '换电池'
          ? Icons.battery_charging_full_outlined
          : (t == '换屏'
              ? Icons.screenshot_monitor_outlined
              : (t == '换壳'
                  ? Icons.inventory_2_outlined
                  : Icons.build_outlined));
}

// ====== 经营分析页 ======
class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({Key? key}) : super(key: key);
  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  @override
  Widget build(BuildContext context) {
    final s = gStorage.computeStats();
    final ageDist = gStorage.getInventoryAgeDist();
    final avgProfit = gStorage.getAvgProfit();
    final avgTurnover = gStorage.getAvgTurnoverDays();
    final turnoverRate = gStorage.getCapitalTurnoverRate();
    final profitByModel = gStorage.getProfitByModel().take(8).toList();
    final turnoverByModel = gStorage.getTurnoverByModel().take(8).toList();
    final suppliers = gStorage.getSupplierStats().take(8).toList();
    // KPI 目标达成
    final profitTarget = 35000; // 350元=35000分
    final turnoverTarget = 15;
    return appScaffold(
      context,
      '经营分析',
      ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // KPI 区
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 9,
            crossAxisSpacing: 9,
            childAspectRatio: 1.6,
            children: [
              _kpi(
                '库存金额',
                yuan(s.capitalOccupied),
                '在售${s.inStockCount}台',
                C.orange,
              ),
              _kpi(
                '平均单台利润',
                yuan(avgProfit),
                avgProfit >= profitTarget ? '✓ 达标(目标350+)' : '目标350+',
                avgProfit >= profitTarget ? C.green : C.t3,
              ),
              _kpi(
                '平均周转天数',
                '$avgTurnover天',
                avgTurnover > 0 && avgTurnover <= turnoverTarget
                    ? '✓ 达标(目标≤15天)'
                    : '目标≤15天',
                avgTurnover > 0 && avgTurnover <= turnoverTarget
                    ? C.green
                    : C.t3,
              ),
              _kpi(
                '资金周转率',
                turnoverRate.toStringAsFixed(2),
                turnoverRate > 2 ? '✓ 达标(目标>2)' : '目标>2',
                turnoverRate > 2 ? C.green : C.t3,
              ),
            ],
          ),
          // 库存年龄分布
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '库存年龄分布',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: C.t1,
                  ),
                ),
                const SizedBox(height: 12),
                ...ageDist.entries.map((e) {
                  final total = ageDist.values.fold<int>(0, (a, b) => a + b);
                  final pct = total > 0 ? e.value * 100 / total : 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              e.key,
                              style: TextStyle(fontSize: 12, color: C.t2),
                            ),
                            Text(
                              '${e.value}台 · ${pct.toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 11,
                                color: C.t1,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: total > 0 ? e.value / total : 0,
                            backgroundColor: C.bg,
                            valueColor: AlwaysStoppedAnimation(
                              e.key.contains('30')
                                  ? C.red
                                  : (e.key.contains('16') ? C.orange : C.green),
                            ),
                            minHeight: 7,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          // 利润排行
          if (profitByModel.isNotEmpty)
            CardBox(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '型号利润排行',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: C.t1,
                        ),
                      ),
                      Spacer(),
                      Text(
                        'Top 8',
                        style: TextStyle(fontSize: 10, color: C.t3),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...profitByModel.asMap().entries.map((e) {
                    final m = e.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            alignment: Alignment.center,
                            child: Text(
                              '${e.key + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                color: e.key < 3 ? C.brand2 : C.t3,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              m['model'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                color: C.t1,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${m['count']}台',
                            style: TextStyle(fontSize: 10, color: C.t2),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            yuan(m['profit'] as int),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color:
                                  (m['profit'] as int) >= 0 ? C.green : C.red,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          // 周转分析
          if (turnoverByModel.isNotEmpty)
            CardBox(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '⚡ 型号周转分析',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: C.t1,
                        ),
                      ),
                      Spacer(),
                      Text('快→慢', style: TextStyle(fontSize: 10, color: C.t3)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...turnoverByModel.asMap().entries.map((e) {
                    final m = e.value;
                    final days = m['avgDays'] as int;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            alignment: Alignment.center,
                            child: Text(
                              '${e.key + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                color: e.key < 3 ? C.green : C.t3,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              m['model'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                color: C.t1,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${m['count']}台',
                            style: TextStyle(fontSize: 10, color: C.t2),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '$days天',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color:
                                  days <= 15
                                      ? C.green
                                      : (days <= 30 ? C.orange : C.red),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          // 供应商排行
          if (suppliers.isNotEmpty)
            CardBox(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '供应商利润排行',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: C.t1,
                        ),
                      ),
                      Spacer(),
                      Text(
                        'Top 8',
                        style: TextStyle(fontSize: 10, color: C.t3),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...suppliers.asMap().entries.map((e) {
                    final m = e.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            alignment: Alignment.center,
                            child: Text(
                              '${e.key + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                color: e.key < 3 ? C.purple : C.t3,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m['channel'] as String,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: C.t1,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Row(
                                  children: [
                                    Text(
                                      '均利${yuan(m['avgProfit'] as int)}',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: C.t3,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if ((m['afterSaleRate'] as num? ?? 0) >
                                        0) ...[
                                      Text(
                                        '售后率${((m['afterSaleRate'] as num) * 100).toStringAsFixed(0)}%',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color:
                                              (m['afterSaleRate'] as num) >= 0.2
                                                  ? C.red
                                                  : C.orange,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${m['count']}台',
                            style: TextStyle(fontSize: 10, color: C.t2),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            yuan(m['profit'] as int),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color:
                                  (m['profit'] as int) >= 0 ? C.green : C.red,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          const SizedBox(height: 20),
          Text(
            '数据基于已售设备与订单净利（扣除售后费用，作废订单不计）',
            textAlign: TextAlign.center,
            style: TextStyle(color: C.t3, fontSize: 10, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _kpi(String label, String value, String sub, Color color) => Container(
    padding: EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: C.card,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: C.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: C.t2)),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        SizedBox(height: 3),
        Text(sub, style: TextStyle(fontSize: 9, color: C.t3)),
      ],
    ),
  );
}

// ====== AI配置页（v2.0：选择提供商 + 可选模型名） ======
class AiConfigPage extends StatefulWidget {
  const AiConfigPage({Key? key}) : super(key: key);
  @override
  State<AiConfigPage> createState() => _AiConfigPageState();
}

class _AiConfigPageState extends State<AiConfigPage> {
  int _providerIndex = 0;
  late TextEditingController _apiKeyCtrl;
  late TextEditingController _modelCtrl;
  bool _obscureKey = true;
  bool _testing = false;
  bool _saving = false;
  bool _fetchingModels = false;
  List<ModelInfo>? _fetchedModels;
  String? _fetchError;

  List<ModelProvider> get _providers => kModelProviders;
  ModelProvider get _selectedProvider => _providers[_providerIndex];

  ModelInfo? get _bestModel =>
      (_fetchedModels != null && _fetchedModels!.isNotEmpty)
          ? _fetchedModels!.first
          : null;

  String get _effectiveModelName =>
      _modelCtrl.text.trim().isNotEmpty
          ? _modelCtrl.text.trim()
          : (_bestModel?.label ?? '（等待 API 获取）');

  @override
  void initState() {
    super.initState();
    final c = AiService.effectiveConfig;
    _apiKeyCtrl = TextEditingController(text: c.apiKey);
    _modelCtrl = TextEditingController(text: c.model);
    if (c.providerName.isNotEmpty) {
      for (int i = 0; i < _providers.length; i++) {
        if (_providers[i].name == c.providerName) {
          _providerIndex = i;
          break;
        }
      }
    }
    if (_apiKeyCtrl.text.isNotEmpty) {
      _doFetchModels();
    }
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  Future<void> _doFetchModels() async {
    final apiKey = _apiKeyCtrl.text.trim();
    if (apiKey.isEmpty) return;
    setState(() {
      _fetchingModels = true;
      _fetchError = null;
    });
    final models = await fetchModels(_selectedProvider.modelsUrl, apiKey);
    if (!mounted) return;
    setState(() {
      _fetchedModels = models;
      _fetchingModels = false;
      if (models == null) _fetchError = '无法获取模型列表，请检查 API Key 是否正确';
    });
  }

  void _onProviderChanged(int? v) {
    if (v == null) return;
    setState(() {
      _providerIndex = v;
      _fetchedModels = null;
      _fetchError = null;
    });
    if (_apiKeyCtrl.text.trim().isNotEmpty) {
      _doFetchModels();
    }
  }

  AiConfig _buildConfig() {
    final modelName = _modelCtrl.text.trim();
    final finalModel =
        modelName.isNotEmpty ? modelName : (_bestModel?.label ?? '');
    return AiConfig(
      providerName: _selectedProvider.name,
      baseUrl: _selectedProvider.baseUrl,
      apiKey: _apiKeyCtrl.text.trim(),
      model: finalModel,
    );
  }

  @override
  Widget build(BuildContext context) {
    return appScaffold(
      context,
      'AI 配置',
      ListView(
        padding: const EdgeInsets.all(14),
        children: [
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('模型提供商', style: TextStyle(fontSize: 13, color: C.t2)),
                const SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: C.bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: C.line),
                  ),
                  child: DropdownButton<int>(
                    value: _providerIndex,
                    isExpanded: true,
                    underline: const SizedBox(),
                    dropdownColor: C.card,
                    style: TextStyle(color: C.t1, fontSize: 14),
                    items: List.generate(
                      _providers.length,
                      (i) => DropdownMenuItem(
                        value: i,
                        child: Text(
                          _providers[i].name,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                    onChanged: _onProviderChanged,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'API Token（密钥）',
                  style: TextStyle(fontSize: 13, color: C.t2),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _apiKeyCtrl,
                  obscureText: _obscureKey,
                  style: TextStyle(color: C.t1, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '输入你的 API 密钥',
                    hintStyle: TextStyle(color: C.t3, fontSize: 12),
                    filled: true,
                    fillColor: C.bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: C.line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: C.brand2),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureKey ? Icons.visibility_off : Icons.visibility,
                        color: C.t3,
                        size: 18,
                      ),
                      onPressed:
                          () => setState(() => _obscureKey = !_obscureKey),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '填完密钥后自动拉取该厂商可用模型',
                      style: TextStyle(fontSize: 10, color: C.t3),
                    ),
                    const Spacer(),
                    if (_apiKeyCtrl.text.trim().isNotEmpty && !_fetchingModels)
                      GestureDetector(
                        onTap: _doFetchModels,
                        child: Text(
                          '刷新模型列表',
                          style: TextStyle(fontSize: 10, color: C.brand2),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_fetchingModels)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: CardBox(
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: C.brand2,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '正在从 ${_selectedProvider.name} 拉取最新模型...',
                      style: TextStyle(fontSize: 12, color: C.t2),
                    ),
                  ],
                ),
              ),
            ),
          if (_fetchError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: CardBox(
                child: Row(
                  children: [
                    Text('⚠️', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _fetchError!,
                        style: TextStyle(fontSize: 12, color: C.red),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '模型名称（可选）',
                      style: TextStyle(fontSize: 13, color: C.t2),
                    ),
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: C.brand2.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '留空=自动选最佳',
                        style: TextStyle(fontSize: 9, color: C.brand2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _bestModel != null
                      ? '留空则自动使用最强模型：${_bestModel!.label}（评分 ${_bestModel!.score}）'
                      : '请先填写 API Key 并等待模型列表加载',
                  style: TextStyle(fontSize: 10, color: C.t3),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _modelCtrl,
                  style: TextStyle(color: C.t1, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '留空自动选择',
                    hintStyle: TextStyle(color: C.t3, fontSize: 12),
                    filled: true,
                    fillColor: C.bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: C.line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: C.brand2),
                    ),
                  ),
                ),
                if (_fetchedModels != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'API 拉取结果（按性能评分降序）：',
                    style: TextStyle(fontSize: 9, color: C.t3),
                  ),
                  const SizedBox(height: 4),
                  ..._fetchedModels!
                      .take(10)
                      .map(
                        (m) => Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color:
                                      m.score == _bestModel?.score
                                          ? C.green
                                          : C.t3,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                m.label,
                                style: TextStyle(
                                  fontSize: 10,
                                  color:
                                      m.score == _bestModel?.score
                                          ? C.green
                                          : C.t2,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '评分 ${m.score}',
                                style: TextStyle(fontSize: 9, color: C.t3),
                              ),
                            ],
                          ),
                        ),
                      ),
                  if (_fetchedModels!.length > 10)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '...还有 ${_fetchedModels!.length - 10} 个模型',
                        style: TextStyle(fontSize: 9, color: C.t3),
                      ),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          CardBox(
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _bestModel != null ? C.green : C.t3,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_selectedProvider.name} · ${_effectiveModelName}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: C.t1,
                        ),
                      ),
                      Text(
                        'API 动态获取 · 端点：${_selectedProvider.baseUrl}',
                        style: TextStyle(fontSize: 9, color: C.t3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_testing)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(color: C.brand2),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _testConnection,
                style: OutlinedButton.styleFrom(
                  foregroundColor: C.brand2,
                  side: const BorderSide(color: C.brand2),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                child: const Text(
                  '测试连接',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          const SizedBox(height: 10),
          if (_saving)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(color: C.brand2),
              ),
            )
          else
            primaryBtn('保存配置', _save),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ghostBtn('↩️ 恢复默认', _resetDefault),
          ),
          const SizedBox(height: 16),
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '说明',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: C.t1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '\u2022 \u9009\u62e9\u63d0\u4f9b\u5546 \u2192 \u586b\u5199 API Key \u2192 \u81ea\u52a8\u62c9\u53d6\u53ef\u7528\u6a21\u578b\n\u2022 \u6a21\u578b\u540d\u7559\u7a7a = \u81ea\u52a8\u4f7f\u7528\u8bc4\u5206\u6700\u9ad8\u7684\u6700\u5f3a\u6a21\u578b\uff08\u4fdd\u5b58\u65f6\u81ea\u52a8\u586b\u5165\uff09\n\u2022 \u65e0\u9884\u8bbe\u786c\u7f16\u7801\uff0c\u5168\u90e8\u4ece\u5382\u5546 API \u52a8\u6001\u83b7\u53d6',
                  style: TextStyle(fontSize: 11, color: C.t2, height: 1.8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _testConnection() async {
    final cfg = _buildConfig();
    if (cfg.model.isEmpty) {
      toast(context, '请先等待模型列表加载完成');
      return;
    }
    AiService.setConfig(cfg);
    setState(() => _testing = true);
    final err = await AiService.testConnection();
    if (!mounted) return;
    setState(() => _testing = false);
    toast(context, err == null ? '✅ 连接成功（模型：${cfg.model}）' : '❌ $err');
  }

  void _save() async {
    final cfg = _buildConfig();
    if (cfg.model.isEmpty) {
      toast(context, '无法保存：模型列表未加载完成');
      return;
    }
    if (cfg.apiKey.isEmpty) {
      toast(context, '请填写 API 密钥');
      return;
    }
    setState(() => _saving = true);
    final settings = gStorage.getSettings();
    settings['aiConfig'] = cfg.toMap();
    await gStorage.saveSettings(settings);
    AiService.setConfig(cfg);
    if (!mounted) return;
    setState(() => _saving = false);
    toast(context, '✅ 已保存：${cfg.providerName} · ${cfg.model}');
    Navigator.pop(context);
  }

  void _resetDefault() {
    final c = AiConfig.defaultConfig();
    setState(() {
      _providerIndex = 0;
      _apiKeyCtrl.text = c.apiKey;
      _modelCtrl.text = c.model;
      _fetchedModels = null;
      _fetchError = null;
    });
    _doFetchModels();
  }
}

// ====== 备份恢复页（v1.4） ======
class BackupPage extends StatefulWidget {
  const BackupPage({Key? key}) : super(key: key);
  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  bool _busy = false;
  bool _hasBak = false;

  @override
  void initState() {
    super.initState();
    _checkBak();
  }

  void _checkBak() async {
    final bak = File('$gDocDir/ipad_boss_data.json.bak');
    final exists = await bak.exists();
    if (mounted) setState(() => _hasBak = exists);
  }

  @override
  Widget build(BuildContext context) {
    final devices = gStorage.getDevices();
    final orders = gStorage.getOrders();
    final lastBak = BackupService.lastBackupTime(gStorage);
    return appScaffold(
      context,
      '备份与恢复',
      ListView(
        padding: const EdgeInsets.all(14),
        children: [
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '数据概览',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: C.t1,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _stat('${devices.length}', '设备', C.brand2)),
                    const SizedBox(width: 8),
                    Expanded(child: _stat('${orders.length}', '订单', C.green)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _stat(
                        lastBak != null
                            ? '${DateTime.now().difference(lastBak).inDays}天前'
                            : '从未',
                        '上次备份',
                        C.orange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_busy)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: C.brand2),
              ),
            )
          else ...[
            primaryBtn('导出备份（分享）', _export),
            const SizedBox(height: 10),
            ghostBtn('导入恢复（从 zip）', _import),
            if (_hasBak) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _restoreBak,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: C.orange,
                    side: const BorderSide(color: C.orange),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  child: const Text(
                    '恢复导入前的自动备份',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
          ],
          const SizedBox(height: 16),
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '说明',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: C.t1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '• 导出：打包数据+图片为 zip，通过微信/网盘分享\n• 导入：选择 zip 文件恢复数据，会自动备份当前数据\n• 建议每周备份一次，换机前务必导出\n• 图片和数据一起打包，换手机不丢',
                  style: TextStyle(fontSize: 11, color: C.t2, height: 1.8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String n, String l, Color c) => Container(
    padding: EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(
      color: C.bg,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: C.line),
    ),
    child: Column(
      children: [
        Text(
          n,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c),
        ),
        SizedBox(height: 2),
        Text(l, style: TextStyle(fontSize: 10, color: C.t2)),
      ],
    ),
  );

  void _export() async {
    setState(() => _busy = true);
    try {
      final outDir = (await getTemporaryDirectory()).path;
      final zipPath = await BackupService.export(
        docDir: gDocDir,
        storage: gStorage,
        outDir: outDir,
      );
      await BackupService.markBackupDone(gStorage);
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      final origin =
          box == null
              ? const Rect.fromLTWH(0, 0, 1, 1)
              : box.localToGlobal(Offset.zero) & box.size;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(zipPath)],
          text: '机掌柜数据备份',
          sharePositionOrigin: origin,
        ),
      );
      setState(() {});
    } catch (e) {
      if (mounted) toast(context, '导出失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _import() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (result == null || result.files.single.path == null) return;
    final zipPath = result.files.single.path!;
    // 二次确认
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: C.card,
            title: Text('确认导入', style: TextStyle(color: C.t1, fontSize: 16)),
            content: Text(
              '导入将覆盖当前所有数据。系统会自动备份当前数据为 .bak 文件，可随时恢复。\n\n确定要导入吗？',
              style: TextStyle(color: C.t2, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('取消', style: TextStyle(color: C.t2)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('确定导入', style: TextStyle(color: C.brand2)),
              ),
            ],
          ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final outDir = (await getTemporaryDirectory()).path;
      await BackupService.backupCurrent(docDir: gDocDir, outDir: outDir);
      final summary = await BackupService.import(
        zipPath: zipPath,
        docDir: gDocDir,
        storage: gStorage,
      );
      // 导入后重新同步 AI 配置
      AiService.setConfig(
        AiConfig.fromMap(
          gStorage.getSettings()['aiConfig'] as Map<String, dynamic>?,
        ),
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _hasBak = true;
      });
      toast(
        context,
        '导入成功：${summary['deviceCount']}台设备 / ${summary['orderCount']}单 / ${summary['imageCount']}张图',
      );
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        toast(context, '导入失败：$e');
      }
    }
  }

  void _restoreBak() async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: C.card,
            title: Text('恢复备份', style: TextStyle(color: C.t1, fontSize: 16)),
            content: Text(
              '将把数据恢复到导入前的状态。当前数据会被覆盖。',
              style: TextStyle(color: C.t2, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('取消', style: TextStyle(color: C.t2)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('恢复', style: TextStyle(color: C.orange)),
              ),
            ],
          ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final success = await BackupService.restoreBak(
        docDir: gDocDir,
        storage: gStorage,
      );
      AiService.setConfig(
        AiConfig.fromMap(
          gStorage.getSettings()['aiConfig'] as Map<String, dynamic>?,
        ),
      );
      if (!mounted) return;
      setState(() => _busy = false);
      toast(context, success ? '已恢复到导入前状态' : '没有找到备份文件');
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        toast(context, '恢复失败：$e');
      }
    }
  }
}

// ====== 采购决策页（v1.4） ======
class PurchaseDecisionPage extends StatefulWidget {
  const PurchaseDecisionPage({Key? key}) : super(key: key);
  @override
  State<PurchaseDecisionPage> createState() => _PurchaseDecisionPageState();
}

class _PurchaseDecisionPageState extends State<PurchaseDecisionPage> {
  String? _selectedModel;
  final _costCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  Map<String, dynamic>? _analysis;
  Map<String, dynamic>? _marketPrice;
  List<Map<String, dynamic>>? _marketHistory;
  String? _aiResult;
  bool _loading = false;
  Map<String, dynamic>? _refPrices; // 参考价

  @override
  void dispose() {
    _costCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  List<String> get _modelOptions {
    final dbModels = gStorage.getDevices().map((d) => d.model).toSet().toList();
    final preset = iPadModels.map((m) => m['name']!).toList();
    final all = <String>[...preset];
    for (final m in dbModels) {
      if (!all.contains(m)) all.add(m);
    }
    return all;
  }

  /// 计算该型号的参考价格
  Map<String, dynamic> _computeRefPrices(String model) {
    final devices = gStorage.getDevices();
    final sameModel = devices.where((d) => d.model == model).toList();
    final sold = sameModel.where((d) => d.status == 'sold').toList();
    final inStock =
        sameModel
            .where((d) => d.status == 'in_stock' || d.status == 'listed')
            .toList();

    final avgPurchase =
        sameModel.isEmpty
            ? 0
            : sameModel.map((d) => d.purchaseCost).reduce((a, b) => a + b) ~/
                sameModel.length;
    final avgSell =
        sold.isEmpty
            ? 0
            : sold.map((d) => d.sellPrice).reduce((a, b) => a + b) ~/
                sold.length;
    final bestPurchase =
        sameModel.isEmpty
            ? 0
            : sameModel
                .map((d) => d.purchaseCost)
                .reduce((a, b) => a < b ? a : b);
    final totalProfit =
        sold.isEmpty ? 0 : sold.map((d) => d.netProfit).reduce((a, b) => a + b);
    final avgProfit = sold.isEmpty ? 0 : totalProfit ~/ sold.length;

    // 近30天销量
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final sales30d =
        sold.where((d) {
          final sd = d.sellDate;
          if (sd == null) return false;
          try {
            return DateTime.parse(sd).isAfter(thirtyDaysAgo);
          } catch (_) {
            return false;
          }
        }).length;

    // 维修/佣金/物流均价
    final repairAvg =
        sold.isEmpty
            ? 0
            : sold.map((d) => d.repairCost ?? 0).reduce((a, b) => a + b) ~/
                sold.length;
    final feeAvg =
        sold.isEmpty
            ? 0
            : sold.map((d) => d.platformFee ?? 0).reduce((a, b) => a + b) ~/
                sold.length;
    final logisticsAvg =
        sold.isEmpty
            ? 0
            : sold.map((d) => d.logisticsCost ?? 0).reduce((a, b) => a + b) ~/
                sold.length;

    return {
      'avgPurchaseCost': avgPurchase,
      'avgSellPrice': avgSell,
      'bestPurchaseCost': bestPurchase,
      'sales30d': sales30d,
      'inStockCount': inStock.length,
      'avgProfit': avgProfit,
      'repairAvg': repairAvg,
      'feeAvg': feeAvg,
      'logisticsAvg': logisticsAvg,
    };
  }

  /// 选型号时自动加载参考价 + 今日行情
  void _onModelChanged(String? v) {
    setState(() {
      _selectedModel = v;
      _analysis = null;
      _aiResult = null;
      _refPrices = null;
      _marketPrice = null;
      _marketHistory = null;
      if (v != null) {
        _refPrices = _computeRefPrices(v);
        _marketPrice = gStorage.getMarketPrice(v);
        _marketHistory = gStorage.getMarketPriceHistory(v, days: 30);
        // 自动填入历史采购均价作为建议采购成本
        final rp = _refPrices!;
        final suggestCost = (rp['avgPurchaseCost'] as int);
        if (suggestCost > 0) {
          _costCtrl.text = (suggestCost / 100).toStringAsFixed(0);
        }
      } else {
        _costCtrl.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return appScaffold(
      context,
      '采购决策 · 该不该收',
      ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // ===== 输入卡 =====
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('型号', style: TextStyle(fontSize: 13, color: C.t2)),
                const SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: C.bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: C.line),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedModel,
                    isExpanded: true,
                    underline: const SizedBox(),
                    dropdownColor: C.card,
                    hint: Text(
                      '选择型号',
                      style: TextStyle(color: C.t3, fontSize: 14),
                    ),
                    style: TextStyle(color: C.t1, fontSize: 14),
                    items:
                        _modelOptions
                            .map(
                              (m) => DropdownMenuItem(
                                value: m,
                                child: Text(
                                  m,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            )
                            .toList(),
                    onChanged: _onModelChanged,
                  ),
                ),
                const SizedBox(height: 12),
                // 参考价卡片（选型号后显示）
                if (_refPrices != null) ...[
                  _buildRefPriceCard(_refPrices!),
                  const SizedBox(height: 12),
                  // 风险评分（实时）
                  _buildRiskScoreCard(_refPrices!),
                  const SizedBox(height: 12),
                ],
                // 采购成本 + 数量并排
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _costCtrl,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: C.t1, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: '采购成本(元/台)',
                          labelStyle: TextStyle(color: C.t2, fontSize: 12),
                          filled: true,
                          fillColor: C.bg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: C.line),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 70,
                      child: TextField(
                        controller: _qtyCtrl,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: C.t1, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: '数量',
                          labelStyle: TextStyle(color: C.t2, fontSize: 12),
                          filled: true,
                          fillColor: C.bg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: C.line),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // 利润拆解（有参考价时显示）
                if (_refPrices != null) ...[
                  const SizedBox(height: 12),
                  _buildProfitBreakdown(_refPrices!),
                ],
                const SizedBox(height: 10),
                ghostBtn(
                  '批量补货建议',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RestockSuggestionPage(),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                primaryBtn('开始分析', _analyze),
              ],
            ),
          ),
          // 分析结果
          if (_analysis != null) ...[
            const SizedBox(height: 14),
            _buildKpiCard(),
            const SizedBox(height: 12),
            _buildSupplierCard(),
            const SizedBox(height: 12),
            _buildAiCard(),
          ],
        ],
      ),
    );
  }

  /// 参考价卡片
  Widget _buildRefPriceCard(Map<String, dynamic> rp) {
    final avgPur = (rp['avgPurchaseCost'] as int) ~/ 100;
    final avgSell = (rp['avgSellPrice'] as int) ~/ 100;
    final bestPur = (rp['bestPurchaseCost'] as int) ~/ 100;
    final sales30 = rp['sales30d'] as int;
    final inStock = rp['inStockCount'] as int;
    final avgProfit = (rp['avgProfit'] as int) ~/ 100;
    final wholesalePrice =
        _marketPrice != null ? ((_marketPrice!['price'] as int) ~/ 100) : null;

    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '参考数据',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: C.t1,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: C.brand.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '基于 ${sales30 + inStock} 条历史',
                  style: TextStyle(fontSize: 9, color: C.brand),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _refRow('📉 历史采购均价', '¥$avgPur', avgPur > 0 ? null : '暂无数据'),
          _refRow('📈 历史售价均价', '¥$avgSell', avgSell > 0 ? null : '暂无数据'),
          if (wholesalePrice != null)
            _refRow(
              '🏪 今日批发价',
              '¥$wholesalePrice',
              _marketPrice!['date'] as String?,
            ),
          Divider(color: C.line, height: 8),
          _refRow(
            '🏆 历史最佳采购价',
            '¥$bestPur',
            bestPur > 0 && bestPur < avgPur
                ? '比均价低 ¥${avgPur - bestPur}'
                : null,
          ),
          _refRow('💰 历史均利', '¥$avgProfit', avgProfit > 0 ? null : '暂无'),
          _refRow('📦 近30天销量', '$sales30 台', null),
          _refRow('🏪 当前在售', '$inStock 台', null),
        ],
      ),
    );
  }

  Widget _refRow(String label, String value, String? hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(fontSize: 11, color: C.t2)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: C.t1,
            ),
          ),
          if (hint != null)
            Expanded(
              child: Text(
                ' · $hint',
                style: TextStyle(fontSize: 9, color: C.t3),
                textAlign: TextAlign.right,
              ),
            ),
        ],
      ),
    );
  }

  /// 利润拆解卡片
  Widget _buildProfitBreakdown(Map<String, dynamic> rp) {
    final costStr = _costCtrl.text.trim();
    final cost = double.tryParse(costStr) ?? 0;
    final costFen = (cost * 100).round();
    final avgSell = (rp['avgSellPrice'] as int);
    final repairAvg = rp['repairAvg'] as int;
    final feeAvg = rp['feeAvg'] as int;
    final logisticsAvg = rp['logisticsAvg'] as int;
    final afterSaleAvg = 6000; // 售后预留 ¥60（固定的合理预留）

    if (costFen <= 0 || avgSell <= 0) return const SizedBox();

    final totalCost =
        costFen + repairAvg + feeAvg + logisticsAvg + afterSaleAvg;
    final netProfit = avgSell - totalCost;
    final margin = avgSell > 0 ? (netProfit / avgSell * 100) : 0.0;
    final avgTurnover = rp['avgTurnoverDays'] as int? ?? 28;

    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '预估单台利润',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: C.t1,
                ),
              ),
              const Spacer(),
              Text(
                '净利 ¥${(netProfit / 100).toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: netProfit > 0 ? C.green : C.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '毛利率 ${margin.toStringAsFixed(1)}% · 预计周转 ${avgTurnover}天',
            style: TextStyle(fontSize: 10, color: C.t3),
          ),
          Divider(color: C.line, height: 16),
          _profitRow('预计售价', avgSell, null, bold: true),
          _profitRow('拿货成本', costFen, C.red),
          _profitRow('维修成本预估', repairAvg, C.orange),
          _profitRow('平台佣金预估', feeAvg, C.orange),
          _profitRow('物流+包装', logisticsAvg, C.orange),
          _profitRow('售后预留', afterSaleAvg, C.orange),
          Divider(color: C.line, height: 8),
          _profitRow(
            '预估净利',
            netProfit,
            netProfit > 0 ? C.green : C.red,
            bold: true,
          ),
        ],
      ),
    );
  }

  Widget _profitRow(
    String label,
    int amountFen,
    Color? amountColor, {
    bool bold = false,
  }) {
    final isNegative = amountFen < 0;
    final display =
        isNegative
            ? '-¥${((-amountFen) / 100).toStringAsFixed(0)}'
            : '¥${(amountFen / 100).toStringAsFixed(0)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: C.t2)),
          const Spacer(),
          Text(
            display,
            style: TextStyle(
              fontSize: bold ? 14 : 12,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: amountColor ?? C.t1,
            ),
          ),
        ],
      ),
    );
  }

  /// 风险评分
  Widget _buildRiskScoreCard(Map<String, dynamic> rp) {
    final cost = double.tryParse(_costCtrl.text) ?? 0;
    final costFen = (cost * 100).round();
    final avgSell = rp['avgSellPrice'] as int;
    final sales30 = rp['sales30d'] as int;
    final inStock = rp['inStockCount'] as int;

    // 利润空间评分：成本 vs 售价
    int profitScore = 0;
    if (avgSell > 0 && costFen > 0) {
      final margin = (avgSell - costFen) / avgSell;
      if (margin > 0.15)
        profitScore = 90;
      else if (margin > 0.10)
        profitScore = 70;
      else if (margin > 0.05)
        profitScore = 50;
      else if (margin > 0)
        profitScore = 30;
      else
        profitScore = 10;
    }

    // 周转速度评分：销量越高分越高
    int turnoverScore =
        sales30 >= 8
            ? 90
            : sales30 >= 5
            ? 70
            : sales30 >= 3
            ? 50
            : sales30 >= 1
            ? 30
            : 10;

    // 库存压力评分：在售越少越好
    int stockScore =
        inStock <= 2
            ? 90
            : inStock <= 5
            ? 70
            : inStock <= 10
            ? 50
            : 30;

    // 价格趋势评分：批发价趋势
    int trendScore = 50; // 默认中等
    if (_marketHistory != null && _marketHistory!.length >= 2) {
      final first = (_marketHistory!.first['price'] as int);
      final last = (_marketHistory!.last['price'] as int);
      final change = last - first;
      final pct = first > 0 ? change / first : 0.0;
      if (pct > 0.03)
        trendScore = 80;
      else if (pct > 0)
        trendScore = 65;
      else if (pct > -0.03)
        trendScore = 50;
      else
        trendScore = 30;
    }

    // 综合评分
    final totalScore =
        (profitScore * 0.30 +
                turnoverScore * 0.25 +
                stockScore * 0.25 +
                trendScore * 0.20)
            .round();

    String conclusion;
    Color conclusionColor;
    if (totalScore >= 75) {
      conclusion = '建议收';
      conclusionColor = C.green;
    } else if (totalScore >= 55) {
      conclusion = '谨慎收';
      conclusionColor = C.orange;
    } else {
      conclusion = '不建议';
      conclusionColor = C.red;
    }

    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '综合评分',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: C.t1,
                ),
              ),
              const Spacer(),
              Text(
                '$totalScore 分 · $conclusion',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: conclusionColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _scoreBar('利润空间', profitScore, 0.30, Colors.blue),
          const SizedBox(height: 6),
          _scoreBar('周转速度', turnoverScore, 0.25, Colors.teal),
          const SizedBox(height: 6),
          _scoreBar('库存压力', stockScore, 0.25, Colors.indigo),
          const SizedBox(height: 6),
          _scoreBar('价格趋势', trendScore, 0.20, Colors.cyan),
        ],
      ),
    );
  }

  Widget _scoreBar(String label, int score, double weight, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: C.t2)),
            const Spacer(),
            Text(
              '$score 分',
              style: TextStyle(
                fontSize: 11,
                color: C.t1,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: 4),
            Text(
              '(${(weight * 100).toStringAsFixed(0)}%)',
              style: TextStyle(fontSize: 9, color: C.t3),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: score / 100,
            backgroundColor: C.line,
            valueColor: AlwaysStoppedAnimation<Color>(color.withOpacity(0.8)),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  /// KPI 卡片 —— 无框大数字风格
  Widget _buildKpiCard() {
    final a = _analysis!;
    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '历史指标',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: C.t1,
            ),
          ),
          const SizedBox(height: 14),
          // 第一行：4 大核心指标（大数字）
          Row(
            children: [
              Expanded(child: _bigKpi('${a['salesCount']}', '销量(台)', C.brand2)),
              Expanded(
                child: _bigKpi(
                  ((a['avgProfit'] as int) / 100).toStringAsFixed(0),
                  '均利润(元)',
                  C.green,
                ),
              ),
              Expanded(
                child: _bigKpi('${a['avgTurnoverDays']}', '均周转(天)', C.orange),
              ),
              Expanded(
                child: _bigKpi(
                  '${((a['stagnantRate'] as double) * 100).toStringAsFixed(0)}',
                  '压货率(%)',
                  C.pink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 第二行：辅助指标（小标签）
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('在售 ${a['inStockCount']}', C.t2),
              _chip(
                '滞销 ${a['stagnantCount']}',
                a['stagnantCount'] as int > 0 ? C.pink : C.t2,
              ),
              _chip(
                '均价 ${((a['avgSellPrice'] as int) / 100).toStringAsFixed(0)}',
                C.t2,
              ),
              _chip(
                '均成本 ${((a['avgPurchaseCost'] as int) / 100).toStringAsFixed(0)}',
                C.t2,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 大数字 KPI（无框，纯色块）
  Widget _bigKpi(String value, String label, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Text(
        value,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: color,
          height: 1.2,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        label,
        style: TextStyle(fontSize: 10, color: C.t3),
        textAlign: TextAlign.center,
      ),
    ],
  );

  /// 小标签 chip（无框）
  Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
    ),
  );

  Widget _buildSupplierCard() {
    final a = _analysis!;
    final suppliers = a['suppliers'] as List;
    if (suppliers.isEmpty && a['hasHistory'] == false) {
      return CardBox(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '⚠️ 无历史数据',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: C.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '该型号无销售历史，建议参考 AI 判断。',
              style: TextStyle(fontSize: 12, color: C.t2),
            ),
          ],
        ),
      );
    }
    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '供应商表现',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: C.t1,
            ),
          ),
          const SizedBox(height: 10),
          ...suppliers.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: C.brand.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      s['channel'] as String,
                      style: const TextStyle(
                        fontSize: 12,
                        color: C.brand,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${s['count']}台',
                    style: TextStyle(fontSize: 12, color: C.t2),
                  ),
                  const Spacer(),
                  Text(
                    '均利${((s['profit'] as int) / 100).toStringAsFixed(0)}元',
                    style: const TextStyle(
                      fontSize: 13,
                      color: C.green,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [C.purple, C.brand2]),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI 综合判断',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '综合 历史数据 + 采购成本',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: CircularProgressIndicator(color: Colors.white))
          else if (_aiResult != null)
            Text(
              _aiResult!,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white,
                height: 1.8,
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _askAi,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '获取 AI 采购建议',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _analyze() {
    if (_selectedModel == null) {
      toast(context, '请选择型号');
      return;
    }
    final cost = double.tryParse(_costCtrl.text) ?? 0;
    if (cost <= 0) {
      toast(context, '请输入采购成本');
      return;
    }
    setState(() {
      _analysis = gStorage.getModelAnalysis(_selectedModel!);
      _marketPrice = gStorage.getMarketPrice(_selectedModel!);
      _marketHistory = gStorage.getMarketPriceHistory(
        _selectedModel!,
        days: 30,
      );
      _aiResult = null;
    });
  }

  void _askAi() async {
    final costFen = ((double.tryParse(_costCtrl.text) ?? 0) * 100).round();
    final qty = int.tryParse(_qtyCtrl.text) ?? 1;
    setState(() => _loading = true);
    final r = await AiService.purchaseDecision(
      model: _selectedModel!,
      purchaseCost: costFen,
      quantity: qty,
      analysis: _analysis!,
      marketPrice: _marketPrice,
      marketHistory: _marketHistory,
    );
    if (!mounted) return;
    setState(() {
      _aiResult = r;
      _loading = false;
    });
  }
}

// ====== 批量补货建议页 ======
class RestockSuggestionPage extends StatefulWidget {
  const RestockSuggestionPage({Key? key}) : super(key: key);
  @override
  State<RestockSuggestionPage> createState() => _RestockSuggestionPageState();
}

class _RestockSuggestionPageState extends State<RestockSuggestionPage> {
  /// 计算每个型号的补货建议
  List<Map<String, dynamic>> _computeSuggestions() {
    final devices = gStorage.getDevices();
    final sold =
        devices.where((d) => d.status == 'sold' && d.sellDate != null).toList();
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    // 按型号分组
    final modelData = <String, Map<String, dynamic>>{};
    for (final d in devices) {
      final model = d.model;
      if (!modelData.containsKey(model)) {
        modelData[model] = {
          'model': model,
          'inStock': 0,
          'sales30d': 0,
          'avgSellPrice': 0,
          'salesList': <int>[],
        };
      }
      if (d.status == 'in_stock' || d.status == 'listed') {
        modelData[model]!['inStock'] =
            (modelData[model]!['inStock'] as int) + 1;
      }
    }
    for (final d in sold) {
      final model = d.model;
      if (!modelData.containsKey(model)) continue;
      try {
        if (DateTime.parse(d.sellDate!).isAfter(thirtyDaysAgo)) {
          modelData[model]!['sales30d'] =
              (modelData[model]!['sales30d'] as int) + 1;
        }
      } catch (_) {}
      (modelData[model]!['salesList'] as List<int>).add(d.sellPrice);
    }

    // 计算建议
    final suggestions = <Map<String, dynamic>>[];
    for (final entry in modelData.entries) {
      final data = entry.value;
      final inStock = data['inStock'] as int;
      final sales30 = data['sales30d'] as int;

      // 月销 / 4 ≈ 周销
      // 建议库存 = 月销 * 1.5（覆盖6周）
      final suggestedStock = (sales30 * 1.5).round();
      final toPurchase = suggestedStock - inStock;

      // 建议采购上限 = 历史售价均价 * 0.85（留15%利润空间）
      final salesList = data['salesList'] as List<int>;
      final avgPrice =
          salesList.isEmpty
              ? 0
              : salesList.fold(0, (int a, int b) => a + b) ~/ salesList.length;
      final maxPurchase = avgPrice > 0 ? (avgPrice * 0.85).round() : 0;

      if (sales30 > 0 || inStock > 0) {
        suggestions.add({
          'model': data['model'],
          'inStock': inStock,
          'sales30d': sales30,
          'suggestedStock': suggestedStock,
          'toPurchase': toPurchase > 0 ? toPurchase : 0,
          'maxPurchasePrice': maxPurchase,
          'avgSellPrice': avgPrice,
        });
      }
    }

    // 按补货紧迫度排序：库存/月销比越低越紧迫
    suggestions.sort((a, b) {
      final ratioA =
          (a['sales30d'] as int) > 0
              ? (a['inStock'] as int) / (a['sales30d'] as int)
              : 999;
      final ratioB =
          (b['sales30d'] as int) > 0
              ? (b['inStock'] as int) / (b['sales30d'] as int)
              : 999;
      return ratioA.compareTo(ratioB);
    });

    return suggestions;
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _computeSuggestions();
    return appScaffold(
      context,
      '批量补货建议',
      ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Text(
            '基于近 30 天销量 + 当前库存自动计算',
            style: TextStyle(fontSize: 11, color: C.t3),
          ),
          const SizedBox(height: 12),
          if (suggestions.isEmpty)
            CardBox(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    '暂无数据，先录入一些设备和订单吧',
                    style: TextStyle(fontSize: 12, color: C.t3),
                  ),
                ),
              ),
            )
          else
            ...suggestions.map((s) => _buildSuggestionCard(s)),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard(Map<String, dynamic> s) {
    final model = s['model'] as String;
    final inStock = s['inStock'] as int;
    final sales30 = s['sales30d'] as int;
    final toPurchase = s['toPurchase'] as int;
    final maxPrice = s['maxPurchasePrice'] as int;
    final avgPrice = s['avgSellPrice'] as int;

    String action;
    Color actionColor;
    if (toPurchase > 0) {
      action = '建议补 $toPurchase 台';
      actionColor = C.green;
    } else if (inStock > sales30 * 2) {
      action = '库存充足，暂不补货';
      actionColor = C.t3;
    } else {
      action = '观察即可';
      actionColor = C.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: CardBox(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    model,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: C.t1,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: actionColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    action,
                    style: TextStyle(
                      fontSize: 11,
                      color: actionColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _row('库存', '$inStock 台'),
            _row('近30天销量', '$sales30 台'),
            _row('建议库存', '${s['suggestedStock']} 台（覆盖 6 周）'),
            if (avgPrice > 0)
              _row('历史售价均价', '¥${(avgPrice / 100).toStringAsFixed(0)}'),
            if (maxPrice > 0)
              _row('建议采购上限', '¥${(maxPrice / 100).toStringAsFixed(0)}'),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: TextStyle(fontSize: 11, color: C.t2)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              color: C.t1,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ====== 今日批发价页（独立，支持导入） ======
class MarketPricePage extends StatefulWidget {
  const MarketPricePage({Key? key}) : super(key: key);
  @override
  State<MarketPricePage> createState() => _MarketPricePageState();
}

class _MarketPricePageState extends State<MarketPricePage> {
  String? _selectedModel;
  final _priceCtrl = TextEditingController();
  Map<String, Map<String, dynamic>> _allPrices = {};
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _allPrices = gStorage.getAllLatestMarketPrices();
    });
  }

  List<String> get _modelOptions {
    final dbModels = gStorage.getDevices().map((d) => d.model).toSet().toList();
    final preset = iPadModels.map((m) => m['name']!).toList();
    final all = <String>[...preset];
    for (final m in dbModels) {
      if (!all.contains(m)) all.add(m);
    }
    return all;
  }

  void _onModelChanged(String? v) {
    setState(() {
      _selectedModel = v;
      if (v != null) {
        final mp = gStorage.getMarketPrice(v);
        _priceCtrl.text =
            mp != null ? ((mp['price'] as int) / 100).toStringAsFixed(0) : '';
      } else {
        _priceCtrl.clear();
      }
    });
  }

  Future<void> _savePrice() async {
    if (_selectedModel == null) {
      toast(context, '请先选型号');
      return;
    }
    final price = double.tryParse(_priceCtrl.text) ?? 0;
    if (price <= 0) {
      toast(context, '请输入有效批发价');
      return;
    }
    await gStorage.saveMarketPrice(_selectedModel!, (price * 100).round());
    _reload();
    toast(context, '✅ 已保存 ${_selectedModel!} 批发价 $price 元');
  }

  /// 从文件导入（支持 csv / 图片）
  Future<void> _importFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'jpg', 'jpeg', 'png', 'bmp'],
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final path = file.path;
      if (path == null) return;

      final ext = path.split('.').last.toLowerCase();
      if (ext == 'csv') {
        await _importCsv(File(path));
      } else if (['jpg', 'jpeg', 'png', 'bmp'].contains(ext)) {
        await _importImage(File(path));
      } else {
        toast(context, '不支持的文件格式：$ext');
      }
    } catch (e) {
      toast(context, '导入失败：$e');
    }
  }

  /// 解析 CSV：格式 = 型号,批发价(元)
  Future<void> _importCsv(File file) async {
    setState(() => _importing = true);
    try {
      final lines = await file.readAsLines();
      int imported = 0;
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
        final parts = trimmed.split(',');
        if (parts.length < 2) continue;
        final model = parts[0].trim();
        final price = double.tryParse(parts[1].trim());
        if (model.isEmpty || price == null || price <= 0) continue;
        await gStorage.saveMarketPrice(model, (price * 100).round());
        imported++;
      }
      _reload();
      toast(context, '✅ 导入完成，共更新 $imported 个型号');
    } catch (e) {
      toast(context, 'CSV 解析失败：$e');
    } finally {
      setState(() => _importing = false);
    }
  }

  /// 图片调用 AI 识别批发价
  Future<void> _importImage(File file) async {
    setState(() => _importing = true);
    try {
      final bytes = await file.readAsBytes();
      final b64 = base64Encode(bytes);
      final result = await AiService.chatWithImage(
        '你是一个华强北iPad批发价识别专家。用户会上传一张批发价表格截图（含型号和价格），'
            '请把识别到的型号和批发价（元）以CSV格式逐行输出：型号,价格\n'
            '例如：iPad Pro 11 2022,4700\n'
            '如果某个价格看不清填0。不要返回其他文字。',
        b64,
        '请识别这张图片中的所有iPad型号和批发价格。',
        maxTokens: 4096,
      );
      if (result.startsWith('AI调用') || result.startsWith('AI返回')) {
        toast(context, '❌ $result');
        return;
      }
      // 解析 AI 返回的 CSV 格式
      int imported = 0;
      for (final line in result.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
        final parts = trimmed.split(',');
        if (parts.length < 2) continue;
        final model = parts[0].trim();
        final price = double.tryParse(parts[1].trim());
        if (model.isEmpty || price == null || price <= 0) continue;
        await gStorage.saveMarketPrice(model, (price * 100).round());
        imported++;
      }
      _reload();
      toast(context, '✅ AI识别导入完成，共导入 $imported 个型号');
    } catch (e) {
      toast(context, '图片识别失败：$e');
    } finally {
      setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortedModels = _allPrices.keys.toList()..sort();
    return appScaffold(
      context,
      '今日批发价',
      ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // 手动录入卡
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '手动录入',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: C.t1,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: C.bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: C.line),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedModel,
                    isExpanded: true,
                    underline: const SizedBox(),
                    dropdownColor: C.card,
                    hint: Text(
                      '选择型号',
                      style: TextStyle(color: C.t3, fontSize: 14),
                    ),
                    style: TextStyle(color: C.t1, fontSize: 14),
                    items:
                        _modelOptions
                            .map(
                              (m) => DropdownMenuItem(
                                value: m,
                                child: Text(
                                  m,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            )
                            .toList(),
                    onChanged: _onModelChanged,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _priceCtrl,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: C.t1, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: '批发价(元)',
                          labelStyle: TextStyle(color: C.t2, fontSize: 12),
                          filled: true,
                          fillColor: C.bg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: C.line),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _savePrice,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: C.brand,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          '保存',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 导入操作卡
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '批量导入',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: C.t1,
                      ),
                    ),
                    const Spacer(),
                    if (_importing)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: C.brand2,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '支持 CSV 表格 / 批发价截图(图片→AI识别)，格式：型号,价格',
                  style: TextStyle(fontSize: 11, color: C.t2, height: 1.5),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _importing ? null : _importFromFile,
                        icon: const Icon(Icons.file_upload_outlined, size: 18),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: C.brand2,
                          side: const BorderSide(color: C.brand2),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        label: const Text(
                          '选择文件导入',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 已记录行情列表
          if (sortedModels.isNotEmpty) ...[
            const SizedBox(height: 12),
            CardBox(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '已记录行情',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: C.t1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...sortedModels.map((model) {
                    final mp = _allPrices[model]!;
                    final price = mp['price'] as int;
                    final date = mp['date'] as String? ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: C.brand.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              model,
                              style: const TextStyle(
                                fontSize: 11,
                                color: C.brand,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '¥${(price / 100).toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: C.t1,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            date,
                            style: TextStyle(fontSize: 10, color: C.t3),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            'CSV格式示例：\niPad Pro 11 2022,4700\niPad Pro 12.9 2021,4200\niPad Air 5,2300',
            style: TextStyle(fontSize: 10, color: C.t3, height: 1.8),
          ),
        ],
      ),
    );
  }
}

// ====== WebDAV 云同步配置页（v1.5） ======
class WebDavConfigPage extends StatefulWidget {
  const WebDavConfigPage({Key? key}) : super(key: key);
  @override
  State<WebDavConfigPage> createState() => _WebDavConfigPageState();
}

class _WebDavConfigPageState extends State<WebDavConfigPage> {
  late TextEditingController _urlCtrl;
  late TextEditingController _userCtrl;
  late TextEditingController _passCtrl;
  bool _obscurePass = true;
  bool _testing = false;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    final c = WebDavService.getConfig(gStorage);
    _urlCtrl = TextEditingController(text: c.url);
    _userCtrl = TextEditingController(text: c.username);
    _passCtrl = TextEditingController(text: c.password);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lastSync = WebDavService.lastSyncTime(gStorage);
    return appScaffold(
      context,
      'WebDAV 云同步',
      ListView(
        padding: const EdgeInsets.all(14),
        children: [
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('服务器地址', style: TextStyle(fontSize: 13, color: C.t2)),
                const SizedBox(height: 8),
                TextField(
                  controller: _urlCtrl,
                  style: TextStyle(color: C.t1, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'https://dav.jianguoyun.com/dav/',
                    hintStyle: TextStyle(color: C.t3, fontSize: 12),
                    filled: true,
                    fillColor: C.bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: C.line),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text('账号', style: TextStyle(fontSize: 13, color: C.t2)),
                const SizedBox(height: 8),
                TextField(
                  controller: _userCtrl,
                  style: TextStyle(color: C.t1, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '坚果云账号或邮箱',
                    hintStyle: TextStyle(color: C.t3, fontSize: 12),
                    filled: true,
                    fillColor: C.bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: C.line),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text('密码（应用密码）', style: TextStyle(fontSize: 13, color: C.t2)),
                const SizedBox(height: 8),
                TextField(
                  controller: _passCtrl,
                  obscureText: _obscurePass,
                  style: TextStyle(color: C.t1, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '坚果云需用应用密码',
                    hintStyle: TextStyle(color: C.t3, fontSize: 12),
                    filled: true,
                    fillColor: C.bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: C.line),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePass ? Icons.visibility_off : Icons.visibility,
                        color: C.t3,
                        size: 18,
                      ),
                      onPressed:
                          () => setState(() => _obscurePass = !_obscurePass),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_testing)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(color: C.brand2),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _testConnection,
                style: OutlinedButton.styleFrom(
                  foregroundColor: C.brand2,
                  side: const BorderSide(color: C.brand2),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                child: const Text(
                  '测试连接',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          const SizedBox(height: 10),
          if (_syncing)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(color: C.brand2),
              ),
            )
          else
            primaryBtn('保存配置', _save),
          const SizedBox(height: 16),
          // 同步操作区
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '☁️ 云同步',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: C.t1,
                  ),
                ),
                const SizedBox(height: 8),
                if (lastSync != null)
                  Text(
                    '上次同步：${lastSync.month}/${lastSync.day} ${lastSync.hour.toString().padLeft(2, '0')}:${lastSync.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(fontSize: 11, color: C.t3),
                  )
                else
                  Text('从未同步', style: TextStyle(fontSize: 11, color: C.t3)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _syncing ? null : _upload,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: C.brand,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          '⬆️ 上传',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _syncing ? null : _download,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: C.card,
                          foregroundColor: C.t1,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                          side: BorderSide(color: C.line),
                        ),
                        child: Text('⬇️ 下载', style: TextStyle(fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '说明',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: C.t1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '• 坚果云：地址填 https://dav.jianguoyun.com/dav/\n• 密码需用「应用密码」（坚果云官网→安全选项→添加应用）\n• 免费版每月1GB上传流量，数据才几KB，完全够用\n• 上传=把本地数据推到云端\n• 下载=从云端拉取覆盖本地（会自动备份当前数据）',
                  style: TextStyle(fontSize: 11, color: C.t2, height: 1.8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  WebDavConfig _buildConfig() => WebDavConfig(
    url: _urlCtrl.text.trim(),
    username: _userCtrl.text.trim(),
    password: _passCtrl.text.trim(),
  );

  void _testConnection() async {
    final cfg = _buildConfig();
    if (!cfg.isValid) {
      toast(context, '请填写完整配置');
      return;
    }
    setState(() => _testing = true);
    final err = await WebDavService.testConnection(cfg);
    if (!mounted) return;
    setState(() => _testing = false);
    toast(context, err == null ? '✅ 连接成功' : '❌ $err');
  }

  void _save() async {
    final cfg = _buildConfig();
    if (!cfg.isValid) {
      toast(context, '请填写完整配置');
      return;
    }
    await WebDavService.saveConfig(gStorage, cfg);
    if (!mounted) return;
    toast(context, 'WebDAV配置已保存');
    Navigator.pop(context);
  }

  void _upload() async {
    final cfg = WebDavService.getConfig(gStorage);
    if (!cfg.isValid) {
      toast(context, '请先保存配置');
      return;
    }
    setState(() => _syncing = true);
    final tmp = File(
      '${(await getTemporaryDirectory()).path}/ipad_boss_data_sync.json',
    );
    await tmp.writeAsString(json.encode(storagePayloadForSync(gStorage)));
    final err = await WebDavService.upload(config: cfg, dataPath: tmp.path);
    if (err == null) await WebDavService.uploadTimestamp(config: cfg);
    await WebDavService.markSynced(gStorage);
    if (!mounted) return;
    setState(() => _syncing = false);
    toast(context, err == null ? '⬆️ 已上传到云端' : '❌ $err');
  }

  void _download() async {
    final cfg = WebDavService.getConfig(gStorage);
    if (!cfg.isValid) {
      toast(context, '请先保存配置');
      return;
    }
    // 二次确认
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: C.card,
            title: Text('下载确认', style: TextStyle(color: C.t1, fontSize: 16)),
            content: Text(
              '从云端下载数据会覆盖当前本地数据。系统会自动备份当前数据。',
              style: TextStyle(color: C.t2, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('取消', style: TextStyle(color: C.t2)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('下载', style: TextStyle(color: C.brand2)),
              ),
            ],
          ),
    );
    if (ok != true) return;
    setState(() => _syncing = true);
    final token = AuthService.token;
    final email = AuthService.email;
    final localSettings = snapshotLocalOnlySettings(gStorage);
    // 先备份当前数据
    await BackupService.backupCurrent(
      docDir: gDocDir,
      outDir: (await getTemporaryDirectory()).path,
    );
    final dlResult = await WebDavService.download(config: cfg);
    final bytes = dlResult.data;
    final err = dlResult.errMsg;
    if (bytes != null) {
      await File('$gDocDir/ipad_boss_data.json').writeAsBytes(bytes);
      await gStorage.load();
      await restoreLocalOnlySettings(gStorage, localSettings);
      if (token != null && token.isNotEmpty) {
        await AuthService.login(gStorage, token, email ?? '');
      }
      // 同步 AI 配置
      AiService.setConfig(
        AiConfig.fromMap(
          gStorage.getSettings()['aiConfig'] as Map<String, dynamic>?,
        ),
      );
      await WebDavService.markSynced(gStorage);
    }
    if (!mounted) return;
    setState(() => _syncing = false);
    if (err != null) {
      toast(context, '❌ $err');
    } else {
      toast(context, '⬇️ 已从云端恢复');
      setState(() {});
    }
  }
}

// ====== 设置页 ======
class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _fileSize = '';
  bool _updateChecking = false;
  String? _updateError;
  double? _updateProgress;
  bool _cloudSyncing = false;
  String? _cloudError;

  @override
  void initState() {
    super.initState();
    _calcSize();
  }

  void _calcSize() async {
    try {
      final f = File('$gDocDir/ipad_boss_data.json');
      if (await f.exists()) {
        final s = await f.length();
        setState(() => _fileSize = '${(s / 1024).toStringAsFixed(1)}KB');
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final devices = gStorage.getDevices();
    final orders = gStorage.getOrders();
    final agents = gStorage.getAgents();
    return appScaffold(
      context,
      '设置',
      ListView(
        padding: const EdgeInsets.all(14),
        children: [
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('数据统计'),
                const SizedBox(height: 10),
                _row('设备总数', '${devices.length}台'),
                _row('订单总数', '${orders.length}单'),
                _row('代理总数', '${agents.length}人'),
                _row('数据文件大小', _fileSize.isEmpty ? '计算中...' : _fileSize),
                _row('存储路径', gDocDir, small: true),
              ],
            ),
          ),
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('主题'),
                const SizedBox(height: 10),
                _themeItem(Icons.dark_mode_outlined, '深色模式', ThemeMode.dark),
                _themeItem(Icons.light_mode_outlined, '浅色模式', ThemeMode.light),
                _themeItem(
                  Icons.brightness_auto_outlined,
                  '跟随系统',
                  ThemeMode.system,
                ),
              ],
            ),
          ),
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('关于'),
                const SizedBox(height: 10),
                _row('应用名称', '机掌柜'),
                _row('版本', 'v${UpdateService.currentVersion}'),
                _row(
                  'AI引擎',
                  '${AiService.effectiveConfig.providerName} · ${AiService.effectiveConfig.model}',
                ),
                _row('数据存储', '本地JSON持久化 + WebDAV云同步'),
                const SizedBox(height: 10),
                ghostBtn(
                  '配置 AI 引擎',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AiConfigPage()),
                  ),
                ),
                const SizedBox(height: 8),
                ghostBtn(
                  'WebDAV 云同步',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WebDavConfigPage()),
                  ),
                ),
                const SizedBox(height: 8),
                ghostBtn('检查更新', _checkUpdate),
                const SizedBox(height: 8),
                ghostBtn('云端同步', _cloudSync),
              ],
            ),
          ),
          if (_cloudSyncing)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: C.brand2,
                  ),
                ),
              ),
            ),
          if (_cloudError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _cloudError!,
                style: TextStyle(fontSize: 11, color: C.t3),
                textAlign: TextAlign.center,
              ),
            ),
          // 登录状态
          CardBox(
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AuthService.isLoggedIn ? C.green : C.t3,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AuthService.isLoggedIn
                            ? '已登录：${AuthService.email}'
                            : '离线模式',
                        style: TextStyle(fontSize: 12, color: C.t1),
                      ),
                      Text(
                        AuthService.isLoggedIn ? '数据可同步到云端' : '登录后可同步数据到云端',
                        style: TextStyle(fontSize: 10, color: C.t3),
                      ),
                    ],
                  ),
                ),
                if (AuthService.isLoggedIn)
                  TextButton(
                    onPressed: _logout,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      '退出',
                      style: TextStyle(fontSize: 11, color: C.red),
                    ),
                  )
                else
                  TextButton(
                    onPressed:
                        () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                        ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      '登录',
                      style: TextStyle(fontSize: 11, color: C.brand2),
                    ),
                  ),
              ],
            ),
          ),
          if (_updateChecking)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Column(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: C.brand2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '正在检查更新...',
                      style: TextStyle(fontSize: 12, color: C.t2),
                    ),
                  ],
                ),
              ),
            ),
          if (_updateError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _updateError!,
                style: TextStyle(fontSize: 12, color: C.red),
                textAlign: TextAlign.center,
              ),
            ),
          if (_updateProgress != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: _updateProgress,
                    backgroundColor: C.line,
                    valueColor: AlwaysStoppedAnimation<Color>(C.brand2),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '下载中... ${(_updateProgress! * 100).toStringAsFixed(0)}%',
                    style: TextStyle(fontSize: 11, color: C.t2),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ghostBtn('清空所有数据（重新初始化）', () async {
              final ok = await showDialog<bool>(
                context: context,
                builder:
                    (ctx) => AlertDialog(
                      backgroundColor: C.card,
                      title: const Text(
                        '确认清空',
                        style: TextStyle(color: C.red, fontSize: 16),
                      ),
                      content: Text(
                        '将删除所有设备、订单、代理、维修记录，且不可恢复。确定继续吗？',
                        style: TextStyle(color: C.t2, fontSize: 13),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text('取消', style: TextStyle(color: C.t2)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text('清空', style: TextStyle(color: C.red)),
                        ),
                      ],
                    ),
              );
              if (ok == true) {
                await gStorage.clearAll();
                await _seedDemoData();
                _calcSize();
                setState(() {});
                toast(context, '数据已清空并重新初始化');
              }
            }),
          ),
        ],
      ),
    );
  }

  Widget _row(String k, String v, {bool small = false}) => Padding(
    padding: EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(k, style: TextStyle(fontSize: 12, color: C.t2)),
        ),
        Expanded(
          child: Text(
            v,
            style: TextStyle(
              fontSize: small ? 10 : 12,
              color: C.t1,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
  Widget _themeItem(IconData icon, String label, ThemeMode mode) {
    final on = gThemeMode == mode;
    return GestureDetector(
      onTap: () {
        final app = context.findAncestorStateOfType<_IpadBossAppState>();
        app?.changeTheme(mode);
        setState(() {});
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: on ? C.selected : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: on ? C.brand.withOpacity(0.3) : C.line),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: on ? C.brand : C.t2),
            SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: on ? C.brand : C.t1,
              ),
            ),
            Spacer(),
            if (on)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: C.brand,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 检查更新
  Future<void> _checkUpdate() async {
    setState(() {
      _updateChecking = true;
      _updateError = null;
      _updateProgress = null;
    });
    // 1. 检查远端版本
    final info = await UpdateService.check();
    if (!mounted) return;
    if (info == null) {
      setState(() {
        _updateChecking = false;
        _updateError = '当前已是最新版本（v${UpdateService.currentVersion}）';
      });
      return;
    }
    // 2. 有新版本 → 询问是否下载
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: C.card,
            title: Text(
              '发现新版本 v${info.version}',
              style: TextStyle(color: C.t1, fontSize: 16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '当前版本：v${UpdateService.currentVersion}',
                  style: TextStyle(color: C.t2, fontSize: 12),
                ),
                Text(
                  '新版本：v${info.version}',
                  style: TextStyle(
                    color: C.green,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (info.changelog.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('更新内容：', style: TextStyle(color: C.t2, fontSize: 12)),
                  Text(
                    info.changelog,
                    style: TextStyle(color: C.t1, fontSize: 12),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('稍后', style: TextStyle(color: C.t2)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('立即更新', style: TextStyle(color: C.brand2)),
              ),
            ],
          ),
    );
    if (ok != true) {
      setState(() => _updateChecking = false);
      return;
    }
    // 3. 下载 APK
    setState(() {
      _updateChecking = false;
      _updateProgress = 0.0;
    });
    final apkPath = await UpdateService.downloadApk(
      info.apkUrl,
      onProgress: (p) {
        if (mounted) setState(() => _updateProgress = p);
      },
    );
    if (!mounted) return;
    if (apkPath == null) {
      setState(() {
        _updateProgress = null;
        _updateError = '下载失败，请检查网络后重试';
      });
      return;
    }
    setState(() => _updateProgress = null);
    // 4. 安装
    final installed = await UpdateService.installApk(apkPath);
    if (!mounted) return;
    if (!installed) {
      setState(() => _updateError = '安装失败，请在设置中手动开启「安装未知应用」权限');
    }
  }

  Future<void> _restoreLocalAuth(String token, String? email) async {
    await AuthService.login(gStorage, token, email ?? '');
  }

  /// 云端同步（用户选择下载或上传，避免无提示覆盖）
  Future<void> _cloudSync() async {
    if (!AuthService.isLoggedIn) {
      setState(() => _cloudError = '请先登录');
      return;
    }
    setState(() {
      _cloudSyncing = true;
      _cloudError = null;
    });
    final token = AuthService.token!;
    final email = AuthService.email;
    final localSettings = snapshotLocalOnlySettings(gStorage);
    final remoteResult = await ApiService.fetchDataResult(token);
    if (!mounted) return;

    final remoteError = remoteResult['error'] as String?;
    final remoteStatus = remoteResult['statusCode'] as int?;
    if (remoteError != null && remoteStatus != 404) {
      setState(() {
        _cloudSyncing = false;
        _cloudError = remoteError;
      });
      return;
    }

    if (remoteError != null) {
      final err = await ApiService.saveData(
        token,
        storagePayloadForSync(gStorage),
      );
      if (err != null) {
        setState(() {
          _cloudSyncing = false;
          _cloudError = err;
        });
        return;
      }
    } else {
      setState(() => _cloudSyncing = false);
      final action = await showDialog<String>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              backgroundColor: C.card,
              title: Text(
                '云端已有数据',
                style: TextStyle(color: C.t1, fontSize: 16),
              ),
              content: Text(
                '请选择同步方向。下载会先自动备份当前本地数据；上传会用本机数据覆盖云端。',
                style: TextStyle(color: C.t2, fontSize: 13),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('取消', style: TextStyle(color: C.t2)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'download'),
                  child: Text('下载覆盖本地', style: TextStyle(color: C.brand2)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'upload'),
                  child: Text('上传覆盖云端', style: TextStyle(color: C.orange)),
                ),
              ],
            ),
      );
      if (action == null) return;
      setState(() {
        _cloudSyncing = true;
        _cloudError = null;
      });
      if (action == 'download') {
        await BackupService.backupCurrent(
          docDir: gDocDir,
          outDir: (await getTemporaryDirectory()).path,
        );
        gStorage.setFullData(remoteResult);
        await gStorage.save();
        await restoreLocalOnlySettings(gStorage, localSettings);
        await _restoreLocalAuth(token, email);
        AiService.setConfig(
          AiConfig.fromMap(
            gStorage.getSettings()['aiConfig'] as Map<String, dynamic>?,
          ),
        );
      } else {
        final err = await ApiService.saveData(
          token,
          storagePayloadForSync(gStorage),
        );
        if (err != null) {
          if (!mounted) return;
          setState(() {
            _cloudSyncing = false;
            _cloudError = err;
          });
          return;
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _cloudSyncing = false;
    });
    toast(context, '✅ 云端同步完成');
  }

  /// 退出登录
  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: C.card,
            title: Text('退出登录', style: TextStyle(color: C.t1, fontSize: 16)),
            content: Text(
              '退出后数据将保留在本地，登录后可恢复同步。确定退出？',
              style: TextStyle(color: C.t2, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('取消', style: TextStyle(color: C.t2)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('退出', style: TextStyle(color: C.red)),
              ),
            ],
          ),
    );
    if (ok == true) {
      await AuthService.logout(gStorage);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }
}

// ====== 我的页 ======
class MePage extends StatefulWidget {
  const MePage({Key? key}) : super(key: key);
  @override
  State<MePage> createState() => _MePageState();
}

class _MePageState extends State<MePage> {
  bool _backupReminded = false;
  File? _avatarImage;
  String _avatarEmoji = '📱';
  List<Color> _avatarGradientColors = [C.purple, const Color(0xFF6366F1)];
  String _displayName = '老板 · 老张';
  String _shopName = '张记二手iPad';
  final ImagePicker _picker = ImagePicker();

  LinearGradient get _avatarGradient =>
      LinearGradient(colors: _avatarGradientColors);

  void _refresh() => setState(() {});

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _checkBackupReminder();
  }

  void _loadProfile() {
    final settings = gStorage.getSettings();
    _displayName = (settings['userDisplayName'] as String?) ?? '老板 · 老张';
    _shopName = (settings['userShopName'] as String?) ?? '张记二手iPad';
    _avatarEmoji = (settings['userAvatarEmoji'] as String?) ?? '📱';
    final gradientStr = settings['userAvatarGradient'] as String?;
    if (gradientStr != null) {
      final parts = gradientStr.split(',');
      if (parts.length == 2) {
        _avatarGradientColors = [
          Color(int.parse(parts[0])),
          Color(int.parse(parts[1])),
        ];
      }
    }
    final avatarPath = settings['userAvatarPath'] as String?;
    if (avatarPath != null && avatarPath.isNotEmpty) {
      final f = File(avatarPath);
      if (f.existsSync()) _avatarImage = f;
    }
  }

  void _saveProfile() {
    final settings = gStorage.getSettings();
    settings['userDisplayName'] = _displayName;
    settings['userShopName'] = _shopName;
    settings['userAvatarEmoji'] = _avatarEmoji;
    settings['userAvatarGradient'] =
        '${_avatarGradientColors[0].value},${_avatarGradientColors[1].value}';
    settings['userAvatarPath'] = _avatarImage?.path ?? '';
    gStorage.saveSettings(settings);
  }

  void _editProfile() {
    showModalBottomSheet(
      context: context,
      backgroundColor: C.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (ctx) => SafeArea(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '更换头像',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: C.t1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: Icon(Icons.camera_alt, color: C.brand2),
                    title: Text('拍照', style: TextStyle(color: C.t1)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _pickImage(ImageSource.camera);
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.photo_library, color: C.brand2),
                    title: Text('从相册选择', style: TextStyle(color: C.t1)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _pickImage(ImageSource.gallery);
                    },
                  ),
                  Divider(color: C.line),
                  ListTile(
                    leading: Icon(Icons.emoji_emotions, color: C.orange),
                    title: Text('随机头像表情', style: TextStyle(color: C.t1)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _randomEmojiAvatar();
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.palette, color: C.purple),
                    title: Text('随机渐变色头像', style: TextStyle(color: C.t1)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _randomGradientAvatar();
                    },
                  ),
                  if (_avatarImage != null)
                    ListTile(
                      leading: const Icon(Icons.delete, color: C.red),
                      title: const Text(
                        '清除自定义头像',
                        style: TextStyle(color: C.red),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        _clearAvatar();
                      },
                    ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final xfile = await _picker.pickImage(
        source: source,
        maxWidth: 256,
        maxHeight: 256,
      );
      if (xfile != null) {
        final dest = '$gDocDir/avatar.jpg';
        await File(xfile.path).copy(dest);
        setState(() {
          _avatarImage = File(dest);
          _avatarEmoji = '';
        });
        _saveProfile();
      }
    } catch (e) {
      toast(context, '选择图片失败：$e');
    }
  }

  void _randomEmojiAvatar() {
    final emojis = [
      '📱',
      '👤',
      '😎',
      '🦸',
      '🧑‍💼',
      '👨‍💻',
      '🫅',
      '🧙',
      '🎅',
      '🤴',
      '👸',
      '🦊',
      '🐯',
      '🦁',
    ];
    setState(() {
      _avatarEmoji =
          emojis[DateTime.now().millisecondsSinceEpoch % emojis.length];
      _avatarImage = null;
    });
    _saveProfile();
  }

  void _randomGradientAvatar() {
    final gradients = [
      [C.purple, const Color(0xFF6366F1)],
      [C.brand, C.brand2],
      [C.pink, C.purple],
      [C.orange, const Color(0xFFF97316)],
      [C.green, const Color(0xFF059669)],
      [const Color(0xFFEC4899), const Color(0xFFF97316)],
    ];
    setState(() {
      _avatarGradientColors =
          gradients[DateTime.now().millisecondsSinceEpoch % gradients.length];
      _avatarImage = null;
    });
    _saveProfile();
  }

  void _clearAvatar() {
    setState(() {
      _avatarImage = null;
      _avatarEmoji = '📱';
    });
    _saveProfile();
  }

  void _editName() {
    final nameCtrl = TextEditingController(text: _displayName);
    final shopCtrl = TextEditingController(text: _shopName);
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: C.card,
            title: Text('编辑资料', style: TextStyle(color: C.t1, fontSize: 16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: TextStyle(color: C.t1),
                  decoration: InputDecoration(
                    labelText: '昵称',
                    labelStyle: TextStyle(color: C.t2),
                    filled: true,
                    fillColor: C.bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: C.line),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: shopCtrl,
                  style: TextStyle(color: C.t1),
                  decoration: InputDecoration(
                    labelText: '店铺名',
                    labelStyle: TextStyle(color: C.t2),
                    filled: true,
                    fillColor: C.bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: C.line),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('取消', style: TextStyle(color: C.t2)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _displayName = nameCtrl.text;
                    _shopName = shopCtrl.text;
                  });
                  _saveProfile();
                  toast(context, '已保存');
                },
                child: Text('保存', style: TextStyle(color: C.brand2)),
              ),
            ],
          ),
    );
  }

  void _checkBackupReminder() {
    if (!_backupReminded && BackupService.shouldRemindBackup(gStorage)) {
      _backupReminded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder:
              (ctx) => AlertDialog(
                backgroundColor: C.card,
                title: Text(
                  '备份提醒',
                  style: TextStyle(color: C.t1, fontSize: 16),
                ),
                content: Text(
                  BackupService.lastBackupTime(gStorage) == null
                      ? '您还没有备份过数据。建议立即导出备份，以防换机/丢失导致数据丢失。'
                      : '已超过7天未备份，建议导出最新备份。',
                  style: TextStyle(color: C.t2, fontSize: 13),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('下次再说', style: TextStyle(color: C.t2)),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const BackupPage()),
                      ).then((_) => _refresh());
                    },
                    child: const Text('去备份', style: TextStyle(color: C.brand2)),
                  ),
                ],
              ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = gStorage.computeStats();
    final orders = gStorage.getOrders();
    return PageScaffold(
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 6, 16, 16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _editProfile,
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: _avatarGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child:
                          _avatarImage != null
                              ? Image.file(
                                _avatarImage!,
                                fit: BoxFit.cover,
                                width: 54,
                                height: 54,
                              )
                              : Center(
                                child: Text(
                                  _avatarEmoji,
                                  style: TextStyle(fontSize: 24),
                                ),
                              ),
                    ),
                  ),
                ),
                SizedBox(width: 13),
                GestureDetector(
                  onTap: _editName,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _displayName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: C.t1,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '${_shopName} · v${UpdateService.currentVersion}',
                        style: TextStyle(fontSize: 11, color: C.t2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: C.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: C.line),
                    ),
                    child: Column(
                      children: [
                        Text(
                          yuan(s.grossProfit),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: C.green,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '今日毛利',
                          style: TextStyle(fontSize: 10, color: C.t2),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: C.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: C.line),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${s.inStockCount}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: C.t1,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '在售台数',
                          style: TextStyle(fontSize: 10, color: C.t2),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: C.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: C.line),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${orders.length}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: C.t1,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '累计订单',
                          style: TextStyle(fontSize: 10, color: C.t2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: C.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: C.line),
            ),
            child: Column(
              children: [
                _mi(
                  Icons.analytics_outlined,
                  '经营分析 · KPI看板',
                  C.brand2,
                  true,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AnalyticsPage()),
                  ).then((_) => _refresh()),
                ),
                _mi(
                  Icons.bar_chart_rounded,
                  '统计报表 · 六大维度',
                  C.purple,
                  true,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ReportPage()),
                  ).then((_) => _refresh()),
                ),
                _mi(
                  Icons.auto_awesome_rounded,
                  'AI经营日报',
                  C.purple,
                  false,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AiReportPage()),
                  ).then((_) => _refresh()),
                ),
                _mi(
                  Icons.query_stats_rounded,
                  '今日批发价',
                  C.purple,
                  false,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MarketPricePage()),
                  ).then((_) => _refresh()),
                ),
                _mi(
                  Icons.rule_rounded,
                  '采购决策 · 该不该收',
                  C.orange,
                  true,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PurchaseDecisionPage(),
                    ),
                  ).then((_) => _refresh()),
                ),
                _mi(
                  Icons.qr_code_scanner_rounded,
                  '扫码收货',
                  C.brand,
                  false,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ScanPage()),
                  ).then((_) => _refresh()),
                ),
                _mi(
                  Icons.point_of_sale_outlined,
                  '售出设备',
                  C.green,
                  false,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SellPage()),
                  ).then((_) => _refresh()),
                ),
                _mi(
                  Icons.groups_2_outlined,
                  '私域分销 · 代理管理',
                  C.pink,
                  false,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AgentManagerPage()),
                  ).then((_) => _refresh()),
                ),
                _mi(
                  Icons.account_balance_wallet_outlined,
                  '财务中心 · 单台利润',
                  C.green,
                  false,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FinancePage()),
                  ).then((_) => _refresh()),
                ),
                _mi(
                  Icons.contacts_outlined,
                  '客户管理 · 复购召回',
                  C.orange,
                  false,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CustomerPage()),
                  ).then((_) => _refresh()),
                ),
                _mi(
                  Icons.build_circle_outlined,
                  '翻新维修 · 配件库存',
                  C.brand2,
                  false,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RepairPage()),
                  ).then((_) => _refresh()),
                ),
                _mi(
                  Icons.archive_outlined,
                  '备份与恢复',
                  C.green,
                  true,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BackupPage()),
                  ).then((_) => _refresh()),
                ),
                _mi(
                  Icons.cloud_sync_outlined,
                  'WebDAV 云同步',
                  C.brand,
                  true,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WebDavConfigPage()),
                  ).then((_) => _refresh()),
                ),
                _mi(
                  Icons.memory_rounded,
                  'AI 配置',
                  C.purple,
                  true,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AiConfigPage()),
                  ).then((_) => _refresh()),
                ),
                _mi(
                  Icons.settings_outlined,
                  '设置',
                  C.t3,
                  false,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SettingsPage()),
                  ).then((_) => _refresh()),
                  last: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '机掌柜 v${UpdateService.currentVersion}\n数据本地持久化 · AI可配置 · WebDAV云同步\n入库多图+AI识别 + 备份恢复 + 采购决策',
            textAlign: TextAlign.center,
            style: TextStyle(color: C.t3, fontSize: 11, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _mi(
    IconData icon,
    String t,
    Color c,
    bool isNew,
    VoidCallback onTap, {
    bool last = false,
  }) => InkWell(
    onTap: onTap,
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: C.line)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: c.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: c, size: 18),
          ),
          SizedBox(width: 11),
          Expanded(
            child: Text(
              t,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: C.t1,
              ),
            ),
          ),
          if (isNew)
            Container(
              margin: EdgeInsets.only(right: 8),
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: C.selected,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: C.line),
              ),
              child: Text(
                '重点',
                style: TextStyle(
                  fontSize: 10,
                  color: C.brand,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          Icon(Icons.chevron_right_rounded, color: C.t3, size: 18),
        ],
      ),
    ),
  );
}
