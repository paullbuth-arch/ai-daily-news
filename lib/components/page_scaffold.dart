import 'package:flutter/material.dart';
import '../theme/colors.dart';

class AppBackdrop extends StatelessWidget {
  const AppBackdrop({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            C.isLight ? const Color(0xFF292337) : const Color(0xFF071018),
            C.isLight ? const Color(0xFF0B0A11) : C.bgDeep,
            C.isLight ? const Color(0xFF201018) : const Color(0xFF05070A),
            C.isLight ? const Color(0xFF07060B) : const Color(0xFF020406),
          ],
          stops: const [0, 0.42, 0.78, 1],
          begin: Alignment.topCenter,
          end: Alignment.bottomRight,
        ),
      ),
      child: CustomPaint(
        painter: _OpsBackdropPainter(C.isLight),
        child: SizedBox.expand(),
      ),
    ),
  );
}

class _OpsBackdropPainter extends CustomPainter {
  final bool isLight;

  const _OpsBackdropPainter(this.isLight);

  @override
  void paint(Canvas canvas, Size size) {
    final base = Offset.zero & size;
    final violetWash =
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFF9F7DFF).withValues(alpha: isLight ? 0.20 : 0.10),
              const Color(0xFF4D357E).withValues(alpha: isLight ? 0.08 : 0.04),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.04, size.height * 0.05),
              radius: size.shortestSide * 0.92,
            ),
          );
    canvas.drawRect(base, violetWash);

    final marsWash =
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFF7D6C).withValues(alpha: isLight ? 0.22 : 0.10),
              const Color(0xFFAB4A57).withValues(alpha: isLight ? 0.16 : 0.07),
              const Color(0xFF4E1924).withValues(alpha: isLight ? 0.14 : 0.05),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.98, size.height * 0.26),
              radius: size.shortestSide * 1.05,
            ),
          );
    canvas.drawRect(base, marsWash);

    final gridPaint =
        Paint()
          ..color = Colors.white.withValues(alpha: isLight ? 0.060 : 0.032)
          ..strokeWidth = 1;
    final gap = isLight ? 88.0 : 42.0;
    for (double x = 0; x <= size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final diagonal =
        Paint()
          ..color = const Color(
            0xFFC8BDFF,
          ).withValues(alpha: isLight ? 0.075 : 0.030)
          ..strokeWidth = 1;
    for (double x = -size.width; x < size.width * 1.7; x += 82) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.width * 0.38, size.height),
        diagonal,
      );
    }

    final horizon =
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.transparent,
              const Color(0xFFE5D9FF).withValues(alpha: isLight ? 0.24 : 0.08),
              Colors.transparent,
            ],
          ).createShader(Rect.fromLTWH(0, 0, size.width, 1))
          ..strokeWidth = 1;
    for (final y in [0.16, 0.34, 0.68]) {
      canvas.drawLine(
        Offset(0, size.height * y),
        Offset(size.width, size.height * y),
        horizon,
      );
    }

    final orbit =
        Paint()
          ..color = const Color(
            0xFFC7B7FF,
          ).withValues(alpha: isLight ? 0.19 : 0.06)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
    final center = Offset(size.width * 0.70, size.height * 0.24);
    for (final scale in const [1.10, 1.62, 2.22, 2.96, 3.58]) {
      final rect = Rect.fromCenter(
        center: center,
        width: size.shortestSide * scale,
        height: size.shortestSide * scale * 0.58,
      );
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(-0.28);
      canvas.translate(-center.dx, -center.dy);
      canvas.drawOval(rect, orbit);
      canvas.restore();
    }

    final wideOrbit =
        Paint()
          ..color = const Color(
            0xFFE2DAFF,
          ).withValues(alpha: isLight ? 0.12 : 0.044)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
    final wideCenter = Offset(size.width * 0.50, size.height * 0.28);
    for (final scale in const [2.55, 3.35, 4.35, 5.20]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: wideCenter,
          width: size.shortestSide * scale,
          height: size.shortestSide * scale * 0.68,
        ),
        wideOrbit,
      );
    }

    final cross =
        Paint()
          ..color = Colors.white.withValues(alpha: isLight ? 0.075 : 0.045)
          ..strokeWidth = 1;
    for (final x in [0.08, 0.92]) {
      canvas.drawLine(
        Offset(size.width * x, 0),
        Offset(size.width * x, size.height),
        cross,
      );
    }

    final frame =
        Paint()
          ..color = Colors.white.withValues(alpha: isLight ? 0.075 : 0.045)
          ..strokeWidth = 1;
    canvas.drawLine(
      Offset(size.width * 0.03, size.height * 0.34),
      Offset(size.width * 0.97, size.height * 0.34),
      frame,
    );
    canvas.drawLine(
      Offset(size.width * 0.19, 0),
      Offset(size.width * 0.19, size.height),
      frame,
    );

    final terrain =
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.transparent,
              const Color(0xFF7C2E38).withValues(alpha: isLight ? 0.20 : 0.06),
              const Color(0xFF210A12).withValues(alpha: 0.34),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(
            Rect.fromLTWH(
              0,
              size.height * 0.46,
              size.width,
              size.height * 0.54,
            ),
          );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.46, size.width, size.height * 0.54),
      terrain,
    );

    final contour =
        Paint()
          ..color = const Color(
            0xFFFFB0B6,
          ).withValues(alpha: isLight ? 0.07 : 0.03)
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke;
    for (double y = size.height * 0.56; y < size.height; y += 36) {
      final path = Path()..moveTo(0, y);
      path.cubicTo(
        size.width * 0.22,
        y - 18,
        size.width * 0.44,
        y + 20,
        size.width * 0.66,
        y + 2,
      );
      path.cubicTo(
        size.width * 0.82,
        y - 12,
        size.width * 0.94,
        y + 10,
        size.width,
        y,
      );
      canvas.drawPath(path, contour);
    }

    _drawBrand(canvas, Offset(size.width * 0.83, size.height * 0.04), 0.52);
    _drawBrand(canvas, Offset(size.width * 0.07, size.height * 0.68), 0.42);

    final speck =
        Paint()..color = Colors.white.withValues(alpha: isLight ? 0.035 : 0.02);
    for (int i = 0; i < 120; i++) {
      final x = ((i * 47) % 1000) / 1000 * size.width;
      final y = ((i * 83) % 1000) / 1000 * size.height;
      canvas.drawCircle(Offset(x, y), i.isEven ? 0.5 : 0.8, speck);
    }

    final shade =
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.black.withValues(alpha: 0.02),
              Colors.black.withValues(alpha: 0.18),
              Colors.black.withValues(alpha: 0.48),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(base);
    canvas.drawRect(base, shade);
  }

  @override
  bool shouldRepaint(covariant _OpsBackdropPainter oldDelegate) =>
      oldDelegate.isLight != isLight;

  void _drawBrand(Canvas canvas, Offset origin, double scale) {
    final style = TextStyle(
      color: Colors.white.withValues(alpha: isLight ? 0.44 : 0.24),
      fontSize: 18 * scale,
      fontWeight: FontWeight.w900,
      height: 1.45,
    );
    final tp = TextPainter(
      text: TextSpan(text: 'S  E  A\nT  L  R', style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, origin);

    final dash =
        Paint()
          ..color = Colors.white.withValues(alpha: isLight ? 0.18 : 0.10)
          ..strokeWidth = 1;
    for (int i = 0; i < 3; i++) {
      final y = origin.dy + (9 + i * 16) * scale;
      canvas.drawLine(
        Offset(origin.dx + 42 * scale, y),
        Offset(origin.dx + 72 * scale, y),
        dash,
      );
    }
  }
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
              colors: [
                Color(0xFF30283B),
                Color(0xFF14121B),
                Color(0xFF2B1520),
                Color(0xFF5F2932),
              ],
              stops: [0, 0.43, 0.76, 1],
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
                    painter: _LightPanelPainter(
                      color: borderColor ?? C.border,
                      accent: C.mars,
                    ),
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
  final Color accent;

  const _LightPanelPainter({required this.color, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 28 || size.height < 28) return;
    final wash =
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.transparent,
              accent.withValues(alpha: 0.11),
              const Color(0xFF120810).withValues(alpha: 0.26),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, wash);

    final terrain =
        Paint()
          ..color = accent.withValues(alpha: 0.13)
          ..strokeWidth = 1;
    for (double y = size.height * 0.54; y < size.height; y += 20) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), terrain);
    }
    for (double x = -size.width * 0.4; x < size.width * 1.1; x += 42) {
      canvas.drawLine(
        Offset(x, size.height * 0.50),
        Offset(x + size.width * 0.18, size.height),
        terrain,
      );
    }

    final line =
        Paint()
          ..color = color.withValues(alpha: 0.68)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
    final glow =
        Paint()
          ..color = accent.withValues(alpha: 0.32)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
    const inset = 7.0;
    const len = 18.0;
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
      Offset(size.width * 0.62, inset),
      Offset(size.width * 0.92, inset),
      glow,
    );
    canvas.drawLine(
      Offset(size.width - inset * 2, size.height * 0.38),
      Offset(size.width - inset * 2, size.height * 0.82),
      glow,
    );
    canvas.drawLine(
      Offset(size.width * 0.08, size.height - inset),
      Offset(size.width * 0.34, size.height - inset),
      glow,
    );

    final hatch =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.045)
          ..strokeWidth = 1;
    for (double x = 18; x < size.width; x += 38) {
      canvas.drawLine(
        Offset(x, size.height * 0.58),
        Offset(x + size.width * 0.10, size.height),
        hatch,
      );
    }

    final scan =
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.transparent,
              Colors.white.withValues(alpha: 0.20),
              accent.withValues(alpha: 0.16),
              Colors.transparent,
            ],
          ).createShader(Rect.fromLTWH(0, 0, size.width, 1))
          ..strokeWidth = 1;
    canvas.drawLine(
      Offset(size.width * 0.10, size.height * 0.44),
      Offset(size.width * 0.88, size.height * 0.44),
      scan,
    );
  }

  @override
  bool shouldRepaint(covariant _LightPanelPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.accent != accent;
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
