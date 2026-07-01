import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../utils/utils.dart';

/// 折线图绘制器（科技感）
class LineChartPainter extends CustomPainter {
  final List<double> data;
  final List<String> labels;
  final Color lineColor;
  final bool showArea;
  final bool showPointLabels;
  final String Function(double value)? pointLabelBuilder;

  LineChartPainter(
    this.data,
    this.labels, {
    this.lineColor = C.cyan,
    this.showArea = true,
    this.showPointLabels = false,
    this.pointLabelBuilder,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final maxV = data.reduce(math.max);
    final minV = data.reduce(math.min);
    final range = maxV == minV ? 1.0 : (maxV - minV).toDouble();
    final w = size.width;
    final h = size.height;
    final padTop = showPointLabels ? 38.0 : 20.0;
    final padBot = 24.0;
    final chartH = h - padTop - padBot;
    final stepX = data.length > 1 ? w / (data.length - 1) : w;

    // Grid lines
    final gridPaint =
        Paint()
          ..color = C.border.withOpacity(0.5)
          ..strokeWidth = 0.5;
    for (int i = 0; i <= 3; i++) {
      final y = padTop + chartH * i / 3;
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    // Data path
    final path = Path();
    final points = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = padTop + chartH - ((data[i] - minV) / range) * chartH;
      points.add(Offset(x, y));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        // Smooth curve
        final prev = points[i - 1];
        final cpx = (prev.dx + x) / 2;
        path.cubicTo(cpx, prev.dy, cpx, y, x, y);
      }
    }

    // Area fill
    if (showArea && points.isNotEmpty) {
      final areaPath =
          Path.from(path)
            ..lineTo(points.last.dx, h - padBot)
            ..lineTo(points.first.dx, h - padBot)
            ..close();
      final areaPaint =
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [lineColor.withOpacity(0.2), lineColor.withOpacity(0.02)],
            ).createShader(Rect.fromLTWH(0, 0, w, h));
      canvas.drawPath(areaPath, areaPaint);
    }

    // Line
    final linePaint =
        Paint()
          ..color = lineColor
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    // Data points
    final dotPaint = Paint()..color = lineColor;
    final dotBg = Paint()..color = C.bgCard;
    for (final p in points) {
      canvas.drawCircle(p, 5, dotBg);
      canvas.drawCircle(p, 3, dotPaint);
    }

    // Profit labels above non-zero positive points.
    if (showPointLabels) {
      final labelStyle = TextStyle(
        fontSize: 10,
        color: lineColor,
        fontWeight: FontWeight.w900,
      );
      final bgPaint = Paint()..color = C.bgCard.withOpacity(0.92);
      final borderPaint =
          Paint()
            ..color = lineColor.withOpacity(0.26)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1;
      for (int i = 0; i < points.length; i++) {
        final value = data[i];
        if (value <= 0) continue;
        final text = pointLabelBuilder?.call(value) ?? yuan(value.round());
        final tp = TextPainter(
          text: TextSpan(text: text, style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        final p = points[i];
        final labelW = tp.width + 10;
        final labelH = tp.height + 5;
        final left = (p.dx - labelW / 2).clamp(0.0, w - labelW);
        final top = (p.dy - labelH - 8).clamp(1.0, h - padBot - labelH);
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, labelW, labelH),
          const Radius.circular(7),
        );
        canvas.drawRRect(rect, bgPaint);
        canvas.drawRRect(rect, borderPaint);
        tp.paint(canvas, Offset(left + 5, top + 2));
      }
    }

    // Labels
    if (labels.isNotEmpty) {
      final labelStyle = TextStyle(
        fontSize: 9,
        color: C.t3,
        fontWeight: FontWeight.w500,
      );
      final step = labels.length > 7 ? (labels.length / 6).ceil() : 1;
      for (int i = 0; i < labels.length; i += step) {
        final tp = TextPainter(
          text: TextSpan(text: labels[i], style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        final x = i * stepX - tp.width / 2;
        tp.paint(canvas, Offset(x.clamp(0.0, w - tp.width), h - 16));
      }
    }
  }

  @override
  bool shouldRepaint(covariant LineChartPainter old) =>
      old.data != data ||
      old.labels != labels ||
      old.lineColor != lineColor ||
      old.showArea != showArea ||
      old.showPointLabels != showPointLabels;
}

/// 甜甜圈图绘制器
class DonutPainter extends CustomPainter {
  final List<DonutSegment> segments;
  final double thickness;

  DonutPainter(this.segments, {this.thickness = 14});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 4;
    final total = segments.fold<double>(0, (a, s) => a + s.value);
    if (total <= 0) return;

    double startAngle = -math.pi / 2;
    for (final seg in segments) {
      final sweep = (seg.value / total) * 2 * math.pi;
      final paint =
          Paint()
            ..color = seg.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = thickness
            ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - thickness / 2),
        startAngle,
        sweep - 0.04,
        false,
        paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant DonutPainter old) => old.segments != segments;
}

class DonutSegment {
  final double value;
  final Color color;
  final String? label;
  DonutSegment(this.value, this.color, {this.label});
}
