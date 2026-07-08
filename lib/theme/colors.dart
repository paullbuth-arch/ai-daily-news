import 'package:flutter/material.dart';

ThemeMode gThemeMode = ThemeMode.dark;

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
  static bool _isLight = false;

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
    bgDeep: Color(0xFFF3F8F1),
    bgCard: Color(0xFFFFFFFF),
    bgCardMuted: Color(0xFFEEF5EE),
    bgSurface: Color(0xFFE8F1E8),
    bgElevated: Color(0xFFDDE9DE),
    nav: Color(0xF7FAFCF7),
    navBorder: Color(0xFFD2DFD5),
    border: Color(0xFFD8E4DA),
    borderGlow: Color(0xFFAEC6B5),
    divider: Color(0xFFE4ECE5),
    t1: Color(0xFF15211B),
    t2: Color(0xFF43564D),
    t3: Color(0xFF6B7D73),
    tMuted: Color(0xFF8C9A91),
    cyan: Color(0xFF4D861B),
    cyanDim: Color(0x1F7EC92C),
    purple: Color(0xFF3867D6),
    purpleDim: Color(0x1F3867D6),
    mint: Color(0xFF247B5A),
    greenDim: Color(0x1F247B5A),
    neonOrange: Color(0xFFB66A18),
    orangeDim: Color(0x1FB66A18),
    neonRed: Color(0xFFBF3C49),
    redDim: Color(0x1FBF3C49),
    primaryDark: Color(0xFF396A13),
    green: Color(0xFF247B5A),
    blue: Color(0xFF2F68C8),
    pink: Color(0xFFA83F74),
    teal: Color(0xFF167A72),
    metricGradient: LinearGradient(
      colors: [Color(0xFFE8F7D6), Color(0xFFFFFFFF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    heroGradient: LinearGradient(
      colors: [Color(0xFFF8FBF5), Color(0xFFEAF4E6)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    cyanGradient: LinearGradient(
      colors: [Color(0xFFD9F36A), Color(0xFFA9DB38)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    successGradient: LinearGradient(
      colors: [Color(0xFFBEE8CF), Color(0xFF73C998)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    dangerGradient: LinearGradient(
      colors: [Color(0xFFFFD7DC), Color(0xFFE66A74)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    purpleGradient: LinearGradient(
      colors: [Color(0xFFDDE6FF), Color(0xFF86A0F2)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    glassGradient: LinearGradient(
      colors: [Color(0xFFFFFFFF), Color(0xFFF1F7F0)],
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
      color: (_isLight ? const Color(0xFF213B28) : const Color(0xFF000000))
          .withValues(alpha: _isLight ? 0.08 : 0.18),
      blurRadius: 8,
      offset: const Offset(0, 3),
    ),
  ];

  static List<BoxShadow> get elevationSm => [
    BoxShadow(
      color: (_isLight ? const Color(0xFF213B28) : const Color(0xFF000000))
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
  static Color get selected => cyan.withValues(alpha: _isLight ? 0.12 : 0.14);
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
