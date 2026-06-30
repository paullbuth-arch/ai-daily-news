import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// 标准卡片容器（微阴影 + 细边框）
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final bool gradient;
  final Gradient? customGradient;
  final Color? bgColor;
  final double radius;
  final bool noShadow;

  const AppCard({
    Key? key,
    required this.child,
    this.padding,
    this.margin,
    this.gradient = false,
    this.customGradient,
    this.bgColor,
    this.radius = C.radiusLg,
    this.noShadow = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) => Container(
    margin: margin ?? const EdgeInsets.only(bottom: C.sp12),
    padding: padding ?? const EdgeInsets.all(C.sp16),
    decoration: BoxDecoration(
      color: customGradient != null || gradient ? null : (bgColor ?? C.card),
      gradient: customGradient ?? (gradient ? C.heroGradient : null),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: C.line, width: 0.8),
      boxShadow: noShadow ? null : C.cardShadow,
    ),
    child: child,
  );
}

/// 标准页面卡片（带左右 margin）
class PageCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final bool noShadow;

  const PageCard({
    Key? key,
    required this.child,
    this.padding,
    this.noShadow = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: C.sp16, vertical: 6),
    padding: padding ?? const EdgeInsets.all(C.sp16),
    decoration: BoxDecoration(
      color: C.card,
      borderRadius: BorderRadius.circular(C.radiusLg),
      border: Border.all(color: C.line, width: 0.8),
      boxShadow: noShadow ? null : C.cardShadow,
    ),
    child: child,
  );
}

/// 渐变英雄卡片（用于首页核心指标）
class HeroCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;

  const HeroCard({
    Key? key,
    required this.child,
    this.padding,
    this.margin,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) => Container(
    margin: margin ?? const EdgeInsets.symmetric(horizontal: C.sp16, vertical: 6),
    padding: padding ?? const EdgeInsets.all(C.sp20),
    decoration: BoxDecoration(
      gradient: C.heroGradient,
      borderRadius: BorderRadius.circular(C.radiusXl),
      boxShadow: [
        BoxShadow(
          color: C.primary.withOpacity(0.3),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: child,
  );
}

/// 兼容旧版 CardBox
class CardBox extends StatelessWidget {
  final Widget child;
  const CardBox({Key? key, required this.child}) : super(key: key);
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: C.card,
      borderRadius: BorderRadius.circular(C.radiusMd),
      border: Border.all(color: C.line, width: 0.8),
      boxShadow: C.elevationSm,
    ),
    child: child,
  );
}
