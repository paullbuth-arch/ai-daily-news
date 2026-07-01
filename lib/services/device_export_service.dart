import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../theme/colors.dart';
import '../utils/utils.dart';

class DeviceExportResult {
  final int savedImages;
  final bool copiedDescription;
  final bool requestedXianyu;
  final bool openedXianyu;
  final bool xianyuInstalled;

  const DeviceExportResult({
    required this.savedImages,
    required this.copiedDescription,
    required this.requestedXianyu,
    required this.openedXianyu,
    required this.xianyuInstalled,
  });

  String get message {
    final parts = <String>[];
    if (savedImages > 0) parts.add('已保存$savedImages张图到相册');
    if (copiedDescription) parts.add('描述已复制');
    if (parts.isEmpty) parts.add('暂无可下载的图片与描述');
    if (requestedXianyu && openedXianyu) parts.add('已打开闲鱼');
    if (requestedXianyu && !xianyuInstalled) parts.add('未检测到闲鱼');
    return parts.join('，');
  }
}

class DeviceExportService {
  static const MethodChannel _galleryChannel = MethodChannel(
    'ipad_boss_app/gallery',
  );

  static Future<DeviceExportResult> downloadListing({
    required Device device,
    required String docDir,
    bool openXianyu = false,
  }) async {
    final images = <String>[];
    final coverPath = await _createCoverImage(device, docDir);
    if (coverPath != null) images.add(coverPath);

    final rawImages = device.imagePath;
    if (rawImages != null && rawImages.isNotEmpty) {
      images.addAll(
        rawImages
            .split(';')
            .where((s) => s.trim().isNotEmpty && File(s).existsSync()),
      );
    }

    final desc = (device.description ?? '').trim();
    final copiedDescription = desc.isNotEmpty;
    if (copiedDescription) {
      await Clipboard.setData(ClipboardData(text: desc));
    }

    var saved = 0;
    if (images.isNotEmpty) {
      final result = await _galleryChannel.invokeMethod('saveImagesToGallery', {
        'paths': images,
        'albumName': '货脉',
      });
      saved = (result is Map) ? (result['saved'] as int? ?? 0) : 0;
    }

    var opened = false;
    var installed = true;
    if (openXianyu) {
      await Future.delayed(const Duration(milliseconds: 650));
      final result = await _galleryChannel.invokeMethod('openXianyu');
      if (result is Map) {
        opened = result['success'] == true;
        installed = result['reason'] != 'not_installed';
      }
    }

    return DeviceExportResult(
      savedImages: saved,
      copiedDescription: copiedDescription,
      requestedXianyu: openXianyu,
      openedXianyu: opened,
      xianyuInstalled: installed,
    );
  }

  static Future<String?> _createCoverImage(Device device, String docDir) async {
    try {
      const width = 720.0;
      const height = 960.0;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final rect = Rect.fromLTWH(0, 0, width, height);

      final bg =
          Paint()
            ..shader = ui.Gradient.linear(
              Offset.zero,
              const Offset(width, height),
              const [C.bgSurface, C.bgDeep],
            );
      canvas.drawRect(rect, bg);

      final glow =
          Paint()
            ..shader = ui.Gradient.radial(
              const Offset(width * 0.22, height * 0.1),
              430,
              [C.cyan.withOpacity(0.26), Colors.transparent],
            );
      canvas.drawRect(rect, glow);

      _roundRect(
        canvas,
        Rect.fromLTWH(48, 54, 624, 852),
        36,
        Colors.white.withOpacity(0.06),
        stroke: Colors.white.withOpacity(0.10),
      );

      _roundRect(canvas, Rect.fromLTWH(80, 86, 72, 72), 18, C.selected);
      _iconLike(canvas, const Offset(116, 122));
      _drawText(
        canvas,
        '货脉',
        const Offset(168, 92),
        const TextStyle(color: C.t1, fontSize: 34, fontWeight: FontWeight.w900),
      );
      _drawText(
        canvas,
        '闲鱼上架素材',
        const Offset(168, 134),
        const TextStyle(color: C.t3, fontSize: 18, fontWeight: FontWeight.w700),
      );

      final cleanColor = device.idLockClean ? C.green : C.red;
      final cleanText = device.idLockClean ? 'ID无锁' : 'ID异常';
      _roundRect(
        canvas,
        Rect.fromLTWH(522, 98, 104, 42),
        16,
        cleanColor.withOpacity(0.18),
        stroke: cleanColor.withOpacity(0.42),
      );
      _drawText(
        canvas,
        cleanText,
        const Offset(544, 108),
        TextStyle(color: cleanColor, fontSize: 18, fontWeight: FontWeight.w900),
      );

      _drawText(
        canvas,
        device.model,
        const Offset(80, 218),
        const TextStyle(
          color: C.t1,
          fontSize: 48,
          fontWeight: FontWeight.w900,
          height: 1.05,
        ),
        maxWidth: 560,
        maxLines: 2,
      );
      _drawText(
        canvas,
        '${device.capacity} · ${device.color} · ${device.network}',
        const Offset(82, 330),
        const TextStyle(color: C.t3, fontSize: 26, fontWeight: FontWeight.w800),
        maxWidth: 560,
      );

      var y = 410.0;
      y = _coverRow(canvas, y, '成色', device.condition);
      y = _coverRow(canvas, y, '电池健康', '${device.batteryHealth}%');
      y = _coverRow(canvas, y, '充电循环', '${device.cycleCount}次');
      y = _coverRow(
        canvas,
        y,
        '序列号',
        device.serial.isEmpty ? '暂无' : device.serial,
      );

      _roundRect(
        canvas,
        Rect.fromLTWH(80, 742, 560, 86),
        24,
        Colors.white.withOpacity(0.07),
        stroke: Colors.white.withOpacity(0.12),
      );
      _drawText(
        canvas,
        '售价',
        const Offset(110, 770),
        const TextStyle(color: C.t2, fontSize: 22, fontWeight: FontWeight.w800),
      );
      final price = device.sellPrice > 0 ? yuan(device.sellPrice) : '未定价';
      _drawText(
        canvas,
        price,
        const Offset(398, 758),
        const TextStyle(
          color: C.cyan,
          fontSize: 38,
          fontWeight: FontWeight.w900,
        ),
        maxWidth: 220,
      );

      _drawText(
        canvas,
        '${device.purchaseDate} · 实拍图见后续',
        const Offset(226, 858),
        const TextStyle(color: C.t3, fontSize: 18, fontWeight: FontWeight.w700),
      );

      final picture = recorder.endRecording();
      final image = await picture.toImage(width.toInt(), height.toInt());
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      picture.dispose();
      image.dispose();
      if (bytes == null) return null;

      final file = File(
        '$docDir/cover_${device.id}_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes.buffer.asUint8List());
      return file.path;
    } catch (_) {
      return null;
    }
  }

  static double _coverRow(Canvas canvas, double y, String label, String value) {
    _drawText(
      canvas,
      label,
      Offset(82, y),
      const TextStyle(color: C.t2, fontSize: 22, fontWeight: FontWeight.w700),
    );
    _drawText(
      canvas,
      value,
      Offset(244, y - 2),
      const TextStyle(color: C.t1, fontSize: 24, fontWeight: FontWeight.w900),
      maxWidth: 380,
    );
    return y + 58;
  }

  static void _roundRect(
    Canvas canvas,
    Rect rect,
    double radius,
    Color color, {
    Color? stroke,
  }) {
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.drawRRect(rrect, Paint()..color = color);
    if (stroke != null) {
      canvas.drawRRect(
        rrect.deflate(0.5),
        Paint()
          ..color = stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }
  }

  static void _iconLike(Canvas canvas, Offset center) {
    final paint =
        Paint()
          ..color = C.cyan
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5;
    final rect = Rect.fromCenter(center: center, width: 34, height: 44);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      paint,
    );
  }

  static void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style, {
    double maxWidth = double.infinity,
    int? maxLines,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: maxLines == null ? null : '...',
    )..layout(maxWidth: maxWidth);
    painter.paint(canvas, offset);
  }
}
