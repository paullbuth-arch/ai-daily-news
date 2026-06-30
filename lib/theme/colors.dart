import 'package:flutter/material.dart';

/// 全局主题模式（light/dark/system）
ThemeMode gThemeMode = ThemeMode.light;

/// 机掌柜 · 商务科技设计系统
/// Stripe/Linear 风格：冷色调、微阴影、精致边框、渐变点缀
class C {
  // ────────────── 背景 & 表面 ──────────────
  static Color get bg =>
      gThemeMode == ThemeMode.light
          ? const Color(0xFFF0F2F5)
          : const Color(0xFF0B0F19);

  static Color get card =>
      gThemeMode == ThemeMode.light
          ? const Color(0xFFFFFFFF)
          : const Color(0xFF151A28);

  static Color get cardMuted =>
      gThemeMode == ThemeMode.light
          ? const Color(0xFFF8FAFC)
          : const Color(0xFF1C2235);

  static Color get surface =>
      gThemeMode == ThemeMode.light
          ? const Color(0xFFFFFFFF)
          : const Color(0xFF151A28);

  // ────────────── 边框 & 分割 ──────────────
  static Color get line =>
      gThemeMode == ThemeMode.light
          ? const Color(0xFFE5E7EB)
          : const Color(0xFF232B3E);

  static Color get divider =>
      gThemeMode == ThemeMode.light
          ? const Color(0xFFEEF0F3)
          : const Color(0xFF1C2235);

  // ────────────── 文字层级 ──────────────
  static Color get t1 =>
      gThemeMode == ThemeMode.light
          ? const Color(0xFF111827)
          : const Color(0xFFF1F5F9);

  static Color get t2 =>
      gThemeMode == ThemeMode.light
          ? const Color(0xFF6B7280)
          : const Color(0xFF94A3B8);

  static Color get t3 =>
      gThemeMode == ThemeMode.light
          ? const Color(0xFF9CA3AF)
          : const Color(0xFF64748B);

  // ────────────── 导航 ──────────────
  static Color get nav =>
      gThemeMode == ThemeMode.light
          ? const Color(0xFFFFFFFF)
          : const Color(0xFF0F1320);

  static Color get navBorder =>
      gThemeMode == ThemeMode.light
          ? const Color(0xFFE5E7EB)
          : const Color(0xFF1E2538);

  static Color get selected =>
      gThemeMode == ThemeMode.light
          ? const Color(0xFFEEF2FF)
          : const Color(0xFF1E1B4B);

  static Color get selectedText =>
      gThemeMode == ThemeMode.light
          ? const Color(0xFF4338CA)
          : const Color(0xFFA5B4FC);

  // ────────────── 品牌色（商务科技·靛蓝主色） ──────────────
  static const primary = Color(0xFF4F46E5);       // indigo-600
  static const primaryLight = Color(0xFFEEF2FF);   // indigo-50
  static const primaryDark = Color(0xFF3730A3);    // indigo-800
  static const accent = Color(0xFF0EA5E9);         // sky-500
  static const accentLight = Color(0xFFE0F2FE);    // sky-100

  // ────────────── 旧版兼容名 ──────────────
  static const brand = Color(0xFF4F46E5);
  static const brand2 = Color(0xFF334155);
  static const brandLight = Color(0xFFEEF2FF);

  // ────────────── 语义色 ──────────────
  static const green = Color(0xFF10B981);
  static const red = Color(0xFFEF4444);
  static const orange = Color(0xFFF59E0B);
  static const pink = Color(0xFFEC4899);
  static const purple = Color(0xFF8B5CF6);
  static const blue = Color(0xFF3B82F6);
  static const teal = Color(0xFF14B8A6);

  // ────────────── 渐变 ──────────────
  static const heroGradient = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED), Color(0xFF0EA5E9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const metricGradient = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const successGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF34D399)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const dangerGradient = LinearGradient(
    colors: [Color(0xFFEF4444), Color(0xFFF87171)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ────────────── 阴影 ──────────────
  static List<BoxShadow> get cardShadow =>
      gThemeMode == ThemeMode.light
          ? [
            BoxShadow(
              color: const Color(0xFF000000).withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: const Color(0xFF000000).withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ]
          : [
            BoxShadow(
              color: const Color(0xFF000000).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ];

  static List<BoxShadow> get elevationSm =>
      gThemeMode == ThemeMode.light
          ? [
            BoxShadow(
              color: const Color(0xFF000000).withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ]
          : [
            BoxShadow(
              color: const Color(0xFF000000).withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ];

  static List<BoxShadow> get elevationLg =>
      gThemeMode == ThemeMode.light
          ? [
            BoxShadow(
              color: const Color(0xFF000000).withOpacity(0.06),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: const Color(0xFF000000).withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ]
          : [
            BoxShadow(
              color: const Color(0xFF000000).withOpacity(0.4),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ];

  // ────────────── 圆角 ──────────────
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
