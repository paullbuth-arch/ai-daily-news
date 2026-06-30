import 'package:flutter/material.dart';

/// 全局主题模式（强制暗色主题）
ThemeMode gThemeMode = ThemeMode.dark;

/// ═══════════════════════════════════════════════
/// 机掌柜 · 暗黑科技设计系统 (Cyber-Industrial)
/// 极暗背景 + 霓虹光效 + 工业网格 + 呼吸动画
/// ═══════════════════════════════════════════════
class C {
  // ────────────── 核心背景 ──────────────
  static const bgDeep = Color(0xFF050507);       // 极暗背景
  static const bgCard = Color(0xFF0c0e14);       // 卡片背景
  static const bgCardMuted = Color(0xFF111318);  // 弱卡片
  static const bgSurface = Color(0xFF151920);    // 表面层
  static const bgElevated = Color(0xFF1a1e2a);   // 悬浮层

  // ────────────── 边框 & 分割 ──────────────
  static const border = Color(0xFF1a1d28);       // 边框线
  static const borderGlow = Color(0xFF2a2d3a); // 发光边框
  static const divider = Color(0xFF1c1f2a);      // 分割线

  // ────────────── 文字层级 ──────────────
  static const t1 = Color(0xFFE0E2E8);           // 主文字
  static const t2 = Color(0xFF8B8F99);           // 次要
  static const t3 = Color(0xFF4A4D55);           // 弱化
  static const tMuted = Color(0xFF3a3d45);       // 极弱

  // ────────────── 导航 ──────────────
  static const nav = Color(0xFF0a0c14);          // 导航栏
  static const navBorder = Color(0xFF1a1d28);   // 导航边框

  // ────────────── 霓虹主色 ──────────────
  static const cyan = Color(0xFF00F0FF);         // 霓虹青
  static const cyanDim = Color(0x1500F0FF);     // 青色透明
  static const purple = Color(0xFFB829FF);       // 霓虹紫
  static const purpleDim = Color(0x15B829FF);     // 紫色透明
  static const neonGreen = Color(0xFF00FF9D);    // 霓虹绿
  static const greenDim = Color(0x1500FF9D);    // 绿色透明
  static const neonOrange = Color(0xFFFF6B35);   // 霓虹橙
  static const orangeDim = Color(0x15FF6B35);    // 橙色透明
  static const neonRed = Color(0xFFFF2E63);      // 霓虹红
  static const redDim = Color(0x15FF2E63);       // 红色透明

  // ────────────── 语义色（新版兼容） ──────────────
  static const primary = Color(0xFF00F0FF);      // 主色=青色
  static const primaryDark = Color(0xFF00C8D4);  // 主色暗
  static const accent = Color(0xFFB829FF);       // 强调色=紫色
  static const brand = Color(0xFF00F0FF);        // 品牌兼容
  static const brand2 = Color(0xFF4A4D55);       // 品牌2兼容

  // ────────────── 语义色 ──────────────
  static const green = Color(0xFF00FF9D);
  static const red = Color(0xFFFF2E63);
  static const orange = Color(0xFFFF6B35);
  static const blue = Color(0xFF4F8BFF);
  static const pink = Color(0xFFFF5AAE);
  static const teal = Color(0xFF14B8A6);

  // ────────────── 渐变 ──────────────
  // ────────────── 旧版兼容渐变 ──────────────
  static const metricGradient = LinearGradient(
    colors: [Color(0xFF00F0FF), Color(0xFFB829FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const heroGradient = LinearGradient(
    colors: [Color(0xFF00F0FF), Color(0xFFB829FF), Color(0xFF4F8BFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const cyanGradient = LinearGradient(
    colors: [Color(0xFF00F0FF), Color(0xFF00C8D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const successGradient = LinearGradient(
    colors: [Color(0xFF00FF9D), Color(0xFF34D399)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const dangerGradient = LinearGradient(
    colors: [Color(0xFFFF2E63), Color(0xFFFF6B6B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const purpleGradient = LinearGradient(
    colors: [Color(0xFFB829FF), Color(0xFF7C3AED)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ────────────── 阴影 ──────────────
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: const Color(0xFF000000).withOpacity(0.4),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get elevationSm => [
    BoxShadow(
      color: const Color(0xFF000000).withOpacity(0.2),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get glowCyan => [
    BoxShadow(color: cyan.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 0)),
  ];

  static List<BoxShadow> get glowPurple => [
    BoxShadow(color: purple.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 0)),
  ];

  // ────────────── 向后兼容属性 ──────────────
  static Color get bg => bgDeep;
  static Color get card => bgCard;
  static Color get cardMuted => bgCardMuted;
  static Color get surface => bgSurface;
  static Color get line => border;
  static Color get selected => cyan.withOpacity(0.1);
  static Color get selectedText => cyan;

  // ────────────── 旧版兼容 ──────────────
  static Color get primaryLight => cyanDim;
  static Color get accentLight => purpleDim;
  static const radiusSm = 8.0;
  static const radiusMd = 12.0;
  static const radiusLg = 16.0;
  static const radiusXl = 20.0;

  // ────────────── 间距 ──────────────
  static const sp4 = 4.0;
  static const sp8 = 8.0;
  static const sp12 = 12.0;
  static const sp14 = 14.0;
  static const sp16 = 16.0;
  static const sp20 = 20.0;
  static const sp24 = 24.0;
  static const sp32 = 32.0;

  // ────────────── 动效时长 ──────────────
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
}
