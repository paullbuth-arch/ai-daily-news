import 'package:flutter/material.dart';
import '../theme/colors.dart';

class AppBackdrop extends StatelessWidget {
  const AppBackdrop({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF081018), C.bgDeep, Color(0xFF05070A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: CustomPaint(
      painter: _OpsBackdropPainter(),
      child: SizedBox.expand(),
    ),
  );
}

class _OpsBackdropPainter extends CustomPainter {
  const _OpsBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint =
        Paint()
          ..color = C.primary.withValues(alpha: 0.035)
          ..strokeWidth = 1;
    const gap = 28.0;
    for (double x = 0; x <= size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final horizon =
        Paint()
          ..shader = const LinearGradient(
            colors: [Colors.transparent, C.primary, Colors.transparent],
          ).createShader(Rect.fromLTWH(0, 0, size.width, 1))
          ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height * 0.18),
      Offset(size.width, size.height * 0.18),
      horizon,
    );

    final shade =
        Paint()
          ..shader = LinearGradient(
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.42)],
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
  final bool realtimeBlur;

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
    this.realtimeBlur = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: borderColor ?? C.border),
    );
    final surface = Material(
      color: Colors.transparent,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          color: gradient == null ? (color ?? C.bgCard) : null,
          gradient: gradient,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    if (margin == null) return surface;
    return Padding(padding: margin!, child: surface);
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
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Material(
      color: background ?? C.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(C.radiusMd),
        side: const BorderSide(color: C.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Icon(icon, color: color ?? C.t1, size: size * 0.48),
      ),
    ),
  );
}

class AppLayout {
  static const wideBreakpoint = 860.0;

  static bool hasSideDock(BuildContext context) =>
      MediaQuery.of(context).size.width >= wideBreakpoint;

  static double pageHorizontal(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 900) return 24;
    if (width >= 720) return 20;
    if (width <= 380) return 14;
    return 16;
  }

  static double titleSize(BuildContext context) =>
      MediaQuery.of(context).size.width <= 390 ? 21 : 22;

  static double scrollBottomPadding(BuildContext context) =>
      hasSideDock(context) ? 28 : 104;

  static EdgeInsets pagePadding(BuildContext context) {
    final horizontal = pageHorizontal(context);
    return EdgeInsets.fromLTRB(
      horizontal,
      14,
      horizontal,
      scrollBottomPadding(context),
    );
  }
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
  Widget build(BuildContext context) {
    final padding = AppLayout.pagePadding(context);
    return Stack(
      children: [
        const AppBackdrop(),
        SafeArea(
          child: ListView(
            padding: padding,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              if (title != null || action != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
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
                                padding: const EdgeInsets.only(top: 4),
                                child: subtitle!,
                              ),
                          ],
                        ),
                      ),
                      if (action != null) ...[
                        const SizedBox(width: 12),
                        action!,
                      ],
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
    borderColor: (glowColor ?? C.cyan).withValues(alpha: 0.36),
    onTap: onTap,
    child: child,
  );
}
