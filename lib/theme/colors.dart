import 'package:flutter/material.dart';

ThemeMode gThemeMode = ThemeMode.dark;

class C {
  static const bgDeep = Color(0xFF05070A);
  static const bg = bgDeep;
  static const bgCard = Color(0xFF0D131A);
  static const bgCardMuted = Color(0xFF121A23);
  static const bgSurface = Color(0xFF18232D);
  static const bgElevated = Color(0xFF22303B);

  static const nav = Color(0xF2070B10);
  static const navBorder = Color(0xFF223140);
  static const border = Color(0xFF253444);
  static const borderGlow = Color(0xFF476174);
  static const divider = Color(0xFF1D2A35);

  static const t1 = Color(0xFFF4F7FA);
  static const t2 = Color(0xFFC9D2DC);
  static const t3 = Color(0xFF8D99A6);
  static const tMuted = Color(0xFF65717F);

  static const cyan = Color(0xFF34F0BE);
  static const cyanDim = Color(0x2634F0BE);
  static const purple = Color(0xFF8EA0FF);
  static const purpleDim = Color(0x2691A7FF);
  static const mint = Color(0xFF6ED7A0);
  static const neonGreen = mint;
  static const greenDim = Color(0x266ED7A0);
  static const neonOrange = Color(0xFFF0B45C);
  static const orangeDim = Color(0x26F0B45C);
  static const neonRed = Color(0xFFFF7D86);
  static const redDim = Color(0x26FF7D86);

  static const primary = cyan;
  static const primaryDark = Color(0xFF20B894);
  static const accent = purple;
  static const brand = cyan;
  static const brand2 = purple;

  static const green = Color(0xFF6ED7A0);
  static const red = neonRed;
  static const orange = neonOrange;
  static const blue = Color(0xFF6CB7FF);
  static const pink = Color(0xFFFF9AC1);
  static const teal = Color(0xFF45C8BA);

  static const metricGradient = LinearGradient(
    colors: [Color(0xFF1E5A52), Color(0xFF182633)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const heroGradient = LinearGradient(
    colors: [Color(0xFF13202A), Color(0xFF080B10)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const cyanGradient = LinearGradient(
    colors: [Color(0xFF22C7A9), Color(0xFF17A88F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const successGradient = LinearGradient(
    colors: [Color(0xFF6ED7A0), Color(0xFF3EA978)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const dangerGradient = LinearGradient(
    colors: [Color(0xFFFF8B92), Color(0xFFE4505C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const purpleGradient = LinearGradient(
    colors: [Color(0xFF91A7FF), Color(0xFF677DDB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const glassGradient = LinearGradient(
    colors: [Color(0xFF151B23), Color(0xFF10141B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: const Color(0xFF000000).withValues(alpha: 0.18),
      blurRadius: 8,
      offset: const Offset(0, 3),
    ),
  ];

  static List<BoxShadow> get elevationSm => [
    BoxShadow(
      color: const Color(0xFF000000).withValues(alpha: 0.16),
      blurRadius: 8,
      offset: const Offset(0, 3),
    ),
  ];

  static List<BoxShadow> get glowCyan => [
    BoxShadow(
      color: cyan.withValues(alpha: 0.10),
      blurRadius: 8,
      offset: const Offset(0, 0),
    ),
  ];

  static List<BoxShadow> get glowPurple => [
    BoxShadow(
      color: purple.withValues(alpha: 0.08),
      blurRadius: 8,
      offset: const Offset(0, 0),
    ),
  ];

  static Color get card => bgCard;
  static Color get cardMuted => bgCardMuted;
  static Color get surface => bgSurface;
  static Color get line => border;
  static Color get selected => cyan.withValues(alpha: 0.14);
  static Color get selectedText => cyan;
  static Color get primaryLight => cyanDim;
  static Color get accentLight => purpleDim;

  static const radiusXs = 6.0;
  static const radiusSm = 8.0;
  static const radiusMd = 10.0;
  static const radiusLg = 12.0;
  static const radiusXl = 14.0;

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
