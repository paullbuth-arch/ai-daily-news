import 'package:flutter/material.dart';

ThemeMode gThemeMode = ThemeMode.light;

class _AppPalette {
  final Color bgDeep;
  final Color bgCard;
  final Color bgCardMuted;
  final Color bgSurface;
  final Color bgElevated;
  final Color nav;
  final Color navBorder;
  final Color border;
  final Color borderGlow;
  final Color divider;
  final Color t1;
  final Color t2;
  final Color t3;
  final Color tMuted;
  final Color cyan;
  final Color cyanDim;
  final Color purple;
  final Color purpleDim;
  final Color mint;
  final Color greenDim;
  final Color neonOrange;
  final Color orangeDim;
  final Color neonRed;
  final Color redDim;
  final Color primaryDark;
  final Color green;
  final Color blue;
  final Color pink;
  final Color teal;
  final LinearGradient metricGradient;
  final LinearGradient heroGradient;
  final LinearGradient cyanGradient;
  final LinearGradient successGradient;
  final LinearGradient dangerGradient;
  final LinearGradient purpleGradient;
  final LinearGradient glassGradient;

  const _AppPalette({
    required this.bgDeep,
    required this.bgCard,
    required this.bgCardMuted,
    required this.bgSurface,
    required this.bgElevated,
    required this.nav,
    required this.navBorder,
    required this.border,
    required this.borderGlow,
    required this.divider,
    required this.t1,
    required this.t2,
    required this.t3,
    required this.tMuted,
    required this.cyan,
    required this.cyanDim,
    required this.purple,
    required this.purpleDim,
    required this.mint,
    required this.greenDim,
    required this.neonOrange,
    required this.orangeDim,
    required this.neonRed,
    required this.redDim,
    required this.primaryDark,
    required this.green,
    required this.blue,
    required this.pink,
    required this.teal,
    required this.metricGradient,
    required this.heroGradient,
    required this.cyanGradient,
    required this.successGradient,
    required this.dangerGradient,
    required this.purpleGradient,
    required this.glassGradient,
  });
}

class C {
  static bool _isLight = true;

  static bool get isLight => _isLight;

  static void useLightTheme(bool value) {
    _isLight = value;
  }

  static const _dark = _AppPalette(
    bgDeep: Color(0xFF05070A),
    bgCard: Color(0xFF0D131A),
    bgCardMuted: Color(0xFF121A23),
    bgSurface: Color(0xFF18232D),
    bgElevated: Color(0xFF22303B),
    nav: Color(0xF2070B10),
    navBorder: Color(0xFF223140),
    border: Color(0xFF253444),
    borderGlow: Color(0xFF476174),
    divider: Color(0xFF1D2A35),
    t1: Color(0xFFF4F7FA),
    t2: Color(0xFFC9D2DC),
    t3: Color(0xFF8D99A6),
    tMuted: Color(0xFF65717F),
    cyan: Color(0xFF34F0BE),
    cyanDim: Color(0x2634F0BE),
    purple: Color(0xFF8EA0FF),
    purpleDim: Color(0x2691A7FF),
    mint: Color(0xFF6ED7A0),
    greenDim: Color(0x266ED7A0),
    neonOrange: Color(0xFFF0B45C),
    orangeDim: Color(0x26F0B45C),
    neonRed: Color(0xFFFF7D86),
    redDim: Color(0x26FF7D86),
    primaryDark: Color(0xFF20B894),
    green: Color(0xFF6ED7A0),
    blue: Color(0xFF6CB7FF),
    pink: Color(0xFFFF9AC1),
    teal: Color(0xFF45C8BA),
    metricGradient: LinearGradient(
      colors: [Color(0xFF1E5A52), Color(0xFF182633)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    heroGradient: LinearGradient(
      colors: [Color(0xFF13202A), Color(0xFF080B10)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    cyanGradient: LinearGradient(
      colors: [Color(0xFF22C7A9), Color(0xFF17A88F)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    successGradient: LinearGradient(
      colors: [Color(0xFF6ED7A0), Color(0xFF3EA978)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    dangerGradient: LinearGradient(
      colors: [Color(0xFFFF8B92), Color(0xFFE4505C)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    purpleGradient: LinearGradient(
      colors: [Color(0xFF91A7FF), Color(0xFF677DDB)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    glassGradient: LinearGradient(
      colors: [Color(0xFF151B23), Color(0xFF10141B)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  static const _light = _AppPalette(
    bgDeep: Color(0xFF111018),
    bgCard: Color(0xFF1A1723),
    bgCardMuted: Color(0xFF251F2D),
    bgSurface: Color(0xFF31283A),
    bgElevated: Color(0xFF472E3E),
    nav: Color(0xF20A0910),
    navBorder: Color(0xFF3A3146),
    border: Color(0xFF62576E),
    borderGlow: Color(0xFFE7DAFF),
    divider: Color(0xFF382F40),
    t1: Color(0xFFFAF7FF),
    t2: Color(0xFFE5DDF3),
    t3: Color(0xFFB9AEC8),
    tMuted: Color(0xFF877B93),
    cyan: Color(0xFFB79AFF),
    cyanDim: Color(0x38B79AFF),
    purple: Color(0xFFF4EDFF),
    purpleDim: Color(0x38F4EDFF),
    mint: Color(0xFF74E7C5),
    greenDim: Color(0x2674E7C5),
    neonOrange: Color(0xFFFF907C),
    orangeDim: Color(0x38FF907C),
    neonRed: Color(0xFFFF6F98),
    redDim: Color(0x38FF6F98),
    primaryDark: Color(0xFF0A0911),
    green: Color(0xFF74E7C5),
    blue: Color(0xFFAAB7FF),
    pink: Color(0xFFFF8EC7),
    teal: Color(0xFF83D8F0),
    metricGradient: LinearGradient(
      colors: [Color(0xFF0B0A12), Color(0xFF3E2C61), Color(0xFFAA4F59)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    heroGradient: LinearGradient(
      colors: [Color(0xFFF0EEF8), Color(0xFFB7B7C8), Color(0xFF17151D)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    cyanGradient: LinearGradient(
      colors: [Color(0xFFB99AFF), Color(0xFF6849E8)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    successGradient: LinearGradient(
      colors: [Color(0xFF89ECCF), Color(0xFF168B6F)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    dangerGradient: LinearGradient(
      colors: [Color(0xFFFFA0B8), Color(0xFFC24666)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    purpleGradient: LinearGradient(
      colors: [Color(0xFF332744), Color(0xFFC4A9FF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    glassGradient: LinearGradient(
      colors: [Color(0xFF2B2535), Color(0xFF17151F), Color(0xFF43202A)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  static _AppPalette get _p => _isLight ? _light : _dark;

  static Color get bgDeep => _p.bgDeep;
  static Color get bg => bgDeep;
  static Color get bgCard => _p.bgCard;
  static Color get bgCardMuted => _p.bgCardMuted;
  static Color get bgSurface => _p.bgSurface;
  static Color get bgElevated => _p.bgElevated;

  static Color get nav => _p.nav;
  static Color get navBorder => _p.navBorder;
  static Color get border => _p.border;
  static Color get borderGlow => _p.borderGlow;
  static Color get divider => _p.divider;

  static Color get t1 => _p.t1;
  static Color get t2 => _p.t2;
  static Color get t3 => _p.t3;
  static Color get tMuted => _p.tMuted;

  static Color get cyan => _p.cyan;
  static Color get cyanDim => _p.cyanDim;
  static Color get purple => _p.purple;
  static Color get purpleDim => _p.purpleDim;
  static Color get mint => _p.mint;
  static Color get neonGreen => mint;
  static Color get greenDim => _p.greenDim;
  static Color get neonOrange => _p.neonOrange;
  static Color get orangeDim => _p.orangeDim;
  static Color get neonRed => _p.neonRed;
  static Color get redDim => _p.redDim;

  static Color get primary => cyan;
  static Color get primaryDark => _p.primaryDark;
  static Color get accent => purple;
  static Color get brand => cyan;
  static Color get brand2 => purple;

  static Color get green => _p.green;
  static Color get red => neonRed;
  static Color get orange => neonOrange;
  static Color get blue => _p.blue;
  static Color get pink => _p.pink;
  static Color get teal => _p.teal;

  static LinearGradient get metricGradient => _p.metricGradient;
  static LinearGradient get heroGradient => _p.heroGradient;
  static LinearGradient get cyanGradient => _p.cyanGradient;
  static LinearGradient get successGradient => _p.successGradient;
  static LinearGradient get dangerGradient => _p.dangerGradient;
  static LinearGradient get purpleGradient => _p.purpleGradient;
  static LinearGradient get glassGradient => _p.glassGradient;

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: (_isLight ? const Color(0xFF1B1C2D) : const Color(0xFF000000))
          .withValues(alpha: _isLight ? 0.08 : 0.18),
      blurRadius: 8,
      offset: const Offset(0, 3),
    ),
  ];

  static List<BoxShadow> get elevationSm => [
    BoxShadow(
      color: (_isLight ? const Color(0xFF1B1C2D) : const Color(0xFF000000))
          .withValues(alpha: _isLight ? 0.07 : 0.16),
      blurRadius: 8,
      offset: const Offset(0, 3),
    ),
  ];

  static List<BoxShadow> get glowCyan => [
    BoxShadow(
      color: cyan.withValues(alpha: _isLight ? 0.08 : 0.10),
      blurRadius: 8,
      offset: const Offset(0, 0),
    ),
  ];

  static List<BoxShadow> get glowPurple => [
    BoxShadow(
      color: purple.withValues(alpha: _isLight ? 0.07 : 0.08),
      blurRadius: 8,
      offset: const Offset(0, 0),
    ),
  ];

  static Color get card => bgCard;
  static Color get cardMuted => bgCardMuted;
  static Color get surface => bgSurface;
  static Color get line => border;
  static Color get selected =>
      _isLight ? const Color(0xFF342A49) : cyan.withValues(alpha: 0.14);
  static Color get selectedText => _isLight ? purple : cyan;
  static Color get primaryLight => _isLight ? const Color(0x337F5BFF) : cyanDim;
  static Color get accentLight => purpleDim;

  static Color get hudDark =>
      _isLight ? const Color(0xFF090811) : const Color(0xFF0D131A);
  static Color get hudDark2 =>
      _isLight ? const Color(0xFF171521) : const Color(0xFF121A23);
  static Color get mars =>
      _isLight ? const Color(0xFFFF8A7D) : const Color(0xFFF0B45C);
  static Color get hudText => _isLight ? const Color(0xFFF7F4FF) : t1;
  static Color get hudSubtext => _isLight ? const Color(0xFFD8D1F6) : t2;
  static Color get hudMuted => _isLight ? const Color(0xFFA79ED0) : t3;
  static Color get hudLine =>
      _isLight ? const Color(0xFFD8CBFF).withValues(alpha: 0.34) : border;

  static Color get primaryButtonBg => _isLight ? hudDark : primary;
  static Color get primaryButtonFg => _isLight ? purple : Colors.black;
  static Color get primaryButtonBorder =>
      _isLight ? purple.withValues(alpha: 0.58) : primary;

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
