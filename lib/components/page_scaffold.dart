import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../theme/colors.dart';

class AppBackdrop extends StatelessWidget {
  const AppBackdrop({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _BackdropPainter(),
    child: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF46484F), Color(0xFF2C3035), Color(0xFF1F2228)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    ),
  );
}

class _BackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final tealGlow =
        Paint()
          ..shader = RadialGradient(
            colors: [C.cyan.withOpacity(0.14), Colors.transparent],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.18, size.height * 0.08),
              radius: size.shortestSide * 0.72,
            ),
          );
    canvas.drawRect(Offset.zero & size, tealGlow);

    final violetGlow =
        Paint()
          ..shader = RadialGradient(
            colors: [C.purple.withOpacity(0.12), Colors.transparent],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.92, size.height * 0.82),
              radius: size.shortestSide * 0.58,
            ),
          );
    canvas.drawRect(Offset.zero & size, violetGlow);

    final grain = Paint()..color = Colors.white.withOpacity(0.018);
    const gap = 5.0;
    for (double y = 0; y < size.height; y += gap) {
      for (double x = 0; x < size.width; x += gap) {
        final v = ((x * 17 + y * 31).round() % 11);
        if (v == 0 || v == 3) {
          canvas.drawCircle(Offset(x, y), 0.45, grain);
        }
      }
    }

    final shade =
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.black.withOpacity(0.04),
              Colors.black.withOpacity(0.42),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, shade);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Gradient? gradient;
  final double radius;
  final Color? borderColor;
  final VoidCallback? onTap;

  const GlassPanel({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.color,
    this.gradient,
    this.radius = C.radiusLg,
    this.borderColor,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final panel = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          margin: margin,
          padding: padding,
          decoration: BoxDecoration(
            color:
                gradient == null ? (color ?? C.bgCard.withOpacity(0.82)) : null,
            gradient: gradient,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: borderColor ?? Colors.white.withOpacity(0.08),
              width: 1,
            ),
            boxShadow: C.cardShadow,
          ),
          child: child,
        ),
      ),
    );
    if (onTap == null) return panel;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: panel,
      ),
    );
  }
}

class RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final Color? background;
  final double size;

  const RoundIconButton({
    Key? key,
    required this.icon,
    required this.onTap,
    this.color,
    this.background,
    this.size = 42,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size / 2),
      child: Ink(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: background ?? Colors.white.withOpacity(0.08),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.09)),
        ),
        child: Icon(icon, color: color ?? C.t1, size: size * 0.48),
      ),
    ),
  );
}

class PageScaffold extends StatelessWidget {
  final Widget child;
  final Widget? title;
  final Widget? subtitle;
  final Widget? action;
  final bool hasGridBg;

  const PageScaffold({
    Key? key,
    required this.child,
    this.title,
    this.subtitle,
    this.action,
    this.hasGridBg = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      const AppBackdrop(),
      SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            if (title != null || action != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (title != null) title!,
                          if (subtitle != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 5),
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
      ),
    ],
  );
}

Widget appScaffold(
  BuildContext context,
  String title,
  Widget body, {
  Widget? trailing,
}) => Scaffold(
  backgroundColor: C.bgDeep,
  body: Stack(
    children: [
      const AppBackdrop(),
      SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Row(
                children: [
                  RoundIconButton(
                    icon: Icons.chevron_left_rounded,
                    onTap: () => Navigator.pop(context),
                    color: C.t1,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: C.t1,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing,
                ],
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    ],
  ),
);

class NeonCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? glowColor;
  final double borderWidth;
  final VoidCallback? onTap;

  const NeonCard({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.glowColor,
    this.borderWidth = 1,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: padding,
    borderColor: (glowColor ?? C.cyan).withOpacity(0.18),
    onTap: onTap,
    child: child,
  );
}
