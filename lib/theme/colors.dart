import 'package:flutter/material.dart';

/// 全局主题模式。
///
/// 默认使用深色，因为店主常在店内、仓库和夜间快速扫状态。
ThemeMode gThemeMode = ThemeMode.dark;

/// 机掌柜视觉系统。
///
/// 方向：深色石墨背景、磨砂玻璃面板、柔和青蓝/浅紫/薄荷功能色。
class C {
  static const bgDeep = Color(0xFF202228);
  static const bg = bgDeep;
  static const bgCard = Color(0xFF121720);
  static const bgCardMuted = Color(0xFF1B202A);
  static const bgSurface = Color(0xFF262D38);
  static const bgElevated = Color(0xFF313846);

  static const nav = Color(0xE60B0D12);
  static const navBorder = Color(0xFF2A303B);
  static const border = Color(0xFF3B4554);
  static const borderGlow = Color(0xFF536073);
  static const divider = Color(0xFF303846);

  static const t1 = Color(0xFFF4F7FB);
  static const t2 = Color(0xFFC8D1DD);
  static const t3 = Color(0xFF98A5B4);
  static const tMuted = Color(0xFF6E7A8A);

  static const cyan = Color(0xFF8FEAF2);
  static const cyanDim = Color(0x268FEAF2);
  static const purple = Color(0xFFB9B8FF);
  static const purpleDim = Color(0x26B9B8FF);
  static const mint = Color(0xFFC5EFA6);
  static const neonGreen = mint;
  static const greenDim = Color(0x26C5EFA6);
  static const neonOrange = Color(0xFFFFD06A);
  static const orangeDim = Color(0x26FFD06A);
  static const neonRed = Color(0xFFFF8796);
  static const redDim = Color(0x26FF8796);

  static const primary = cyan;
  static const primaryDark = Color(0xFF5BC8D3);
  static const accent = purple;
  static const brand = cyan;
  static const brand2 = purple;

  static const green = Color(0xFF76DCA6);
  static const red = neonRed;
  static const orange = neonOrange;
  static const blue = Color(0xFF9BC7FF);
  static const pink = Color(0xFFFFA4CF);
  static const teal = Color(0xFF6ED7CC);

  static const metricGradient = LinearGradient(
    colors: [Color(0xFF8FEAF2), Color(0xFFB9B8FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const heroGradient = LinearGradient(
    colors: [Color(0xFF232B35), Color(0xFF11141B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const cyanGradient = LinearGradient(
    colors: [Color(0xFFB7F4F8), Color(0xFF81DDE8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const successGradient = LinearGradient(
    colors: [Color(0xFFC5EFA6), Color(0xFF76DCA6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const dangerGradient = LinearGradient(
    colors: [Color(0xFFFF9AA7), Color(0xFFFF6578)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const purpleGradient = LinearGradient(
    colors: [Color(0xFFD9D6FF), Color(0xFFAAA8F2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const glassGradient = LinearGradient(
    colors: [Color(0x662D3440), Color(0x3311151D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: const Color(0xFF000000).withOpacity(0.22),
      blurRadius: 12,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> get elevationSm => [
    BoxShadow(
      color: const Color(0xFF000000).withOpacity(0.18),
      blurRadius: 10,
      offset: const Offset(0, 5),
    ),
  ];

  static List<BoxShadow> get glowCyan => [
    BoxShadow(
      color: cyan.withOpacity(0.16),
      blurRadius: 18,
      offset: const Offset(0, 0),
    ),
  ];

  static List<BoxShadow> get glowPurple => [
    BoxShadow(
      color: purple.withOpacity(0.14),
      blurRadius: 18,
      offset: const Offset(0, 0),
    ),
  ];

  static Color get card => bgCard;
  static Color get cardMuted => bgCardMuted;
  static Color get surface => bgSurface;
  static Color get line => border;
  static Color get selected => cyan.withOpacity(0.14);
  static Color get selectedText => cyan;
  static Color get primaryLight => cyanDim;
  static Color get accentLight => purpleDim;

  static const radiusXs = 6.0;
  static const radiusSm = 8.0;
  static const radiusMd = 12.0;
  static const radiusLg = 16.0;
  static const radiusXl = 20.0;

  static const sp4 = 4.0;
  static const sp8 = 8.0;
  static const sp12 = 12.0;
  static const sp14 = 14.0;
  static const sp16 = 16.0;
  static const sp20 = 20.0;
  static const sp24 = 24.0;
  static const sp32 = 32.0;

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 320);
}
