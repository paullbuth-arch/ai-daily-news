import 'package:flutter/material.dart';
import '../theme/colors.dart';

class AppBackdrop extends StatelessWidget {
  const AppBackdrop({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors:
            C.isLight
                ? [
                  const Color(0xFF1F1D26),
                  const Color(0xFF15141C),
                  const Color(0xFF211A25),
                ]
                : [const Color(0xFF081018), C.bgDeep, const Color(0xFF05070A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: CustomPaint(
      painter: _OpsBackdropPainter(C.isLight),
      child: SizedBox.expand(),
    ),
  );
}

class _OpsBackdropPainter extends CustomPainter {
  final bool isLight;

  const _OpsBackdropPainter(this.isLight);

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint =
        Paint()
          ..color = (isLight ? const Color(0xFFB7AFFF) : C.primary).withValues(
            alpha: isLight ? 0.060 : 0.035,
          )
          ..strokeWidth = 1;
    final gap = isLight ? 92.0 : 28.0;
    for (double x = 0; x <= size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final horizon =
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.transparent,
              (isLight ? C.selected : C.primary).withValues(
                alpha: isLight ? 0.22 : 1,
              ),
              Colors.transparent,
            ],
          ).createShader(Rect.fromLTWH(0, 0, size.width, 1))
          ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height * 0.18),
      Offset(size.width, size.height * 0.18),
      horizon,
    );

    if (isLight) {
      final orbit =
          Paint()
            ..color = const Color(0xFFC7B7FF).withValues(alpha: 0.13)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1;
      final center = Offset(size.width * 0.58, size.height * 0.30);
      for (final scale in const [1.10, 1.58, 2.08, 2.62]) {
        final rect = Rect.fromCenter(
          center: center,
          width: size.shortestSide * scale,
          height: size.shortestSide * scale * 0.62,
        );
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(-0.34);
        canvas.translate(-center.dx, -center.dy);
        canvas.drawOval(rect, orbit);
        canvas.restore();
      }
      final redWash =
          Paint()
            ..shader = RadialGradient(
              colors: [
                const Color(0xFFFF8B7C).withValues(alpha: 0.28),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromCircle(
                center: Offset(size.width * 0.88, size.height * 0.22),
                radius: size.width * 0.64,
              ),
            );
      canvas.drawRect(Offset.zero & size, redWash);
      final violetWash =
          Paint()
            ..shader = RadialGradient(
              colors: [
                const Color(0xFF9F7DFF).withValues(alpha: 0.24),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromCircle(
                center: Offset(size.width * 0.06, size.height * 0.05),
                radius: size.width * 0.62,
              ),
            );
      canvas.drawRect(Offset.zero & size, violetWash);

      final cross =
          Paint()
            ..color = Colors.white.withValues(alpha: 0.08)
            ..strokeWidth = 1;
      canvas.drawLine(
        Offset(size.width * 0.08, 0),
        Offset(size.width * 0.08, size.height),
        cross,
      );
      canvas.drawLine(
        Offset(0, size.height * 0.34),
        Offset(size.width, size.height * 0.34),
        cross,
      );
    }

    final shade =
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.transparent,
              isLight
                  ? Colors.black.withValues(alpha: 0.42)
                  : Colors.black.withValues(alpha: 0.42),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, shade);
  }

  @override
  bool shouldRepaint(covariant _OpsBackdropPainter oldDelegate) =>
      oldDelegate.isLight != isLight;
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
    final resolvedColor =
        C.isLight && color != null && _isLegacyDarkSurface(color!)
            ? null
            : color;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: borderColor ?? C.border),
    );
    final panelGradient =
        gradient ??
        (C.isLight && resolvedColor == null
            ? const LinearGradient(
              colors: [Color(0xFF30293A), Color(0xFF1F1C28), Color(0xFF4A242E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
            : null);
    final surface = Material(
      color: Colors.transparent,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          color: panelGradient == null ? (resolvedColor ?? C.bgCard) : null,
          gradient: panelGradient,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Stack(
            children: [
              if (C.isLight)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _LightPanelPainter(color: borderColor ?? C.border),
                  ),
                ),
              Padding(padding: padding, child: child),
            ],
          ),
        ),
      ),
    );
    if (margin == null) return surface;
    return Padding(padding: margin!, child: surface);
  }
}

bool _isLegacyDarkSurface(Color color) {
  if (color == C.hudDark || color == C.hudDark2) return false;
  return color.computeLuminance() < 0.08;
}

class _LightPanelPainter extends CustomPainter {
  final Color color;

  const _LightPanelPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 28 || size.height < 28) return;
    final line =
        Paint()
          ..color = color.withValues(alpha: 0.52)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
    final accent =
        Paint()
          ..color = C.purple.withValues(alpha: 0.34)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
    const inset = 7.0;
    const len = 14.0;
    canvas.drawLine(
      const Offset(inset, inset),
      const Offset(inset + len, inset),
      line,
    );
    canvas.drawLine(
      const Offset(inset, inset),
      const Offset(inset, inset + len),
      line,
    );
    canvas.drawLine(
      Offset(size.width - inset - len, inset),
      Offset(size.width - inset, inset),
      line,
    );
    canvas.drawLine(
      Offset(size.width - inset, inset),
      Offset(size.width - inset, inset + len),
      line,
    );
    canvas.drawLine(
      Offset(inset, size.height - inset - len),
      Offset(inset, size.height - inset),
      line,
    );
    canvas.drawLine(
      Offset(inset, size.height - inset),
      Offset(inset + len, size.height - inset),
      line,
    );
    canvas.drawLine(
      Offset(size.width - inset - len, size.height - inset),
      Offset(size.width - inset, size.height - inset),
      line,
    );
    canvas.drawLine(
      Offset(size.width - inset, size.height - inset - len),
      Offset(size.width - inset, size.height - inset),
      line,
    );
    canvas.drawLine(
      Offset(size.width * 0.62, 0),
      Offset(size.width * 0.92, 0),
      accent,
    );
  }

  @override
  bool shouldRepaint(covariant _LightPanelPainter oldDelegate) =>
      oldDelegate.color != color;
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
      color: background ?? (C.isLight ? const Color(0xFF090A13) : C.bgSurface),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(C.radiusMd),
        side: BorderSide(
          color: C.isLight ? C.purple.withValues(alpha: 0.28) : C.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Icon(
          icon,
          color: color ?? (C.isLight ? C.purple : C.t1),
          size: size * 0.48,
        ),
      ),
    ),
  );
}

class AppLayout {
  static const wideBreakpoint = 860.0;
  static const lightWideBreakpoint = 720.0;

  static bool hasSideDock(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= (C.isLight ? lightWideBreakpoint : wideBreakpoint);
  }

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
                    color: C.isLight ? C.purple : C.t1,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
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
