import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

class IpadColorRecognitionService {
  static const int _targetWidth = 480;
  static const List<String> knownColors = [
    '\u6df1\u7a7a\u7070',
    '\u94f6\u8272',
    '\u661f\u5149\u8272',
    '\u7c89\u8272',
    '\u7d2b\u8272',
    '\u84dd\u8272',
    '\u73ab\u7470\u91d1',
    '\u91d1\u8272',
    '\u7eff\u8272',
    '\u9ec4\u8272',
  ];

  const IpadColorRecognitionService._();

  static Future<String> estimateFromImages(List<String> imagePaths) async {
    for (final path in imagePaths.take(3)) {
      final color = await estimateBackColor(path);
      if (color.isNotEmpty) return color;
    }
    return '';
  }

  static Future<String> estimateBackColor(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: _targetWidth,
      );
      try {
        final frame = await codec.getNextFrame();
        final image = frame.image;
        try {
          final data = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          if (data == null) return '';
          final rgb = averageBackColorRgb(
            data.buffer.asUint8List(),
            image.width,
            image.height,
          );
          if (rgb == null) return '';
          return classifyRgb(rgb);
        } finally {
          image.dispose();
        }
      } finally {
        codec.dispose();
      }
    } catch (_) {
      return '';
    }
  }

  static List<double>? averageBackColorRgb(
    Uint8List bytes,
    int width,
    int height,
  ) {
    const specs = [
      _ColorSampleSpec(left: 0.25, top: 0.30, width: 0.22, height: 0.18),
      _ColorSampleSpec(left: 0.53, top: 0.30, width: 0.22, height: 0.18),
      _ColorSampleSpec(left: 0.34, top: 0.50, width: 0.32, height: 0.20),
    ];
    var rSum = 0.0;
    var gSum = 0.0;
    var bSum = 0.0;
    var count = 0;
    for (final spec in specs) {
      final left = math.max(0, (width * spec.left).round());
      final top = math.max(0, (height * spec.top).round());
      final right = math.min(width, (width * (spec.left + spec.width)).round());
      final bottom = math.min(
        height,
        (height * (spec.top + spec.height)).round(),
      );
      for (var y = top; y < bottom; y += 2) {
        for (var x = left; x < right; x += 2) {
          final index = (y * width + x) * 4;
          if (index + 2 >= bytes.length) continue;
          final r = bytes[index];
          final g = bytes[index + 1];
          final b = bytes[index + 2];
          if (skipBackColorPixel(r, g, b)) continue;
          rSum += r;
          gSum += g;
          bSum += b;
          count++;
        }
      }
    }
    if (count < 40) return null;
    return [rSum / count, gSum / count, bSum / count];
  }

  static bool skipBackColorPixel(int r, int g, int b) {
    final maxChannel = math.max(r, math.max(g, b));
    final minChannel = math.min(r, math.min(g, b));
    final value = maxChannel / 255.0;
    final saturation =
        maxChannel == 0 ? 0.0 : (maxChannel - minChannel) / maxChannel;
    final isRedMarkup =
        r > 140 && g < 120 && b < 120 && r - g > 40 && r - b > 40;
    final isPureHighlight = value > 0.96 && saturation < 0.06;
    final isCaseOrBackground = saturation > 0.68 && value > 0.45;
    return isRedMarkup || isPureHighlight || isCaseOrBackground || value < 0.22;
  }

  static String classifyRgb(List<double> rgb) {
    final r = rgb[0];
    final g = rgb[1];
    final b = rgb[2];
    final maxChannel = math.max(r, math.max(g, b));
    final minChannel = math.min(r, math.min(g, b));
    final value = maxChannel / 255.0;
    final saturation =
        maxChannel == 0 ? 0.0 : (maxChannel - minChannel) / maxChannel;
    final hue = rgbHue(r, g, b);

    if (saturation < 0.10)
      return value < 0.56 ? '\u6df1\u7a7a\u7070' : '\u94f6\u8272';
    if (hue >= 190 && hue <= 250) return '\u84dd\u8272';
    if (hue >= 250 && hue <= 310) return '\u7d2b\u8272';
    if (hue >= 85 && hue <= 165) return '\u7eff\u8272';
    if (hue >= 40 && hue <= 85) {
      if (value > 0.70 && saturation < 0.24) return '\u661f\u5149\u8272';
      return saturation > 0.30 ? '\u9ec4\u8272' : '\u91d1\u8272';
    }
    if (hue >= 330 || hue <= 20) {
      return saturation < 0.24 ? '\u73ab\u7470\u91d1' : '\u7c89\u8272';
    }
    if (hue > 20 && hue < 40) return '\u73ab\u7470\u91d1';
    return '';
  }

  static double rgbHue(double r, double g, double b) {
    final maxChannel = math.max(r, math.max(g, b));
    final minChannel = math.min(r, math.min(g, b));
    final delta = maxChannel - minChannel;
    if (delta == 0) return 0;
    double hue;
    if (maxChannel == r) {
      hue = 60 * (((g - b) / delta) % 6);
    } else if (maxChannel == g) {
      hue = 60 * (((b - r) / delta) + 2);
    } else {
      hue = 60 * (((r - g) / delta) + 4);
    }
    return hue < 0 ? hue + 360 : hue;
  }
}

class _ColorSampleSpec {
  final double left;
  final double top;
  final double width;
  final double height;

  const _ColorSampleSpec({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });
}
