import 'package:flutter/material.dart';
import '../theme/colors.dart';
import 'page_scaffold.dart';

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
  Widget build(BuildContext context) => Padding(
    padding: margin ?? EdgeInsets.only(bottom: C.sp12),
    child: GlassPanel(
      padding: padding ?? EdgeInsets.all(C.sp16),
      radius: radius,
      color: bgColor ?? C.bgCard,
      gradient: customGradient ?? (gradient ? C.glassGradient : null),
      child: child,
    ),
  );
}

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
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: C.sp12),
    child: GlassPanel(
      padding: padding ?? EdgeInsets.all(C.sp16),
      radius: C.radiusLg,
      color: C.bgCard,
      child: child,
    ),
  );
}

class HeroCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;

  const HeroCard({Key? key, required this.child, this.padding, this.margin})
    : super(key: key);

  @override
  Widget build(BuildContext context) => Padding(
    padding: margin ?? EdgeInsets.only(bottom: C.sp12),
    child: GlassPanel(
      padding: padding ?? EdgeInsets.all(C.sp20),
      radius: C.radiusXl,
      gradient: C.heroGradient,
      borderColor: C.navBorder,
      child: child,
    ),
  );
}

class CardBox extends StatelessWidget {
  final Widget child;
  const CardBox({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: GlassPanel(
      padding: const EdgeInsets.all(16),
      radius: C.radiusLg,
      color: C.bgCard,
      child: child,
    ),
  );
}
