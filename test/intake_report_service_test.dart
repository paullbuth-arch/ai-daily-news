import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipad_boss_app/models.dart';
import 'package:ipad_boss_app/services/intake_report_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('creates customer report when no manual defect is selected', () async {
    final dir = await Directory.systemTemp.createTemp('intake_report_test_');
    try {
      final imagePath = await _writeSampleImage(dir.path);
      final device = Device(
        id: 'report-test-001',
        serial: 'WR70CWX1R0',
        model: 'iPad mini 6 (A15)',
        capacity: '64G',
        color: '粉色',
        network: 'WiFi',
        condition: '95新',
        batteryHealth: 100,
        purchaseCost: 180000,
        purchaseDate: '2026-07-03',
        createdAt: '2026-07-03T10:00:00',
      );

      final reportPath = await IntakeReportService.createReport(
        device: device,
        docDir: dir.path,
        imagePaths: [imagePath],
        inspection: const {
          'manualAppearanceReview': true,
          'appearanceDefects': [],
          'screenDefects': [],
          'repairSummary': '需复核',
          'warranty': '未知',
          'checks': {'屏幕显示': '未知', '摄像头': '需复核'},
        },
      );

      final report = File(reportPath);
      expect(await report.exists(), isTrue);
      expect(await report.length(), greaterThan(1000));
    } finally {
      await dir.delete(recursive: true);
    }
  });
}

Future<String> _writeSampleImage(String dir) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 200, 200),
    Paint()..color = const Color(0xFFF2F6FA),
  );
  canvas.drawCircle(
    const Offset(100, 100),
    58,
    Paint()..color = const Color(0xFFB7C4D6),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(200, 200);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  picture.dispose();
  image.dispose();
  final file = File('$dir/sample.png');
  await file.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
  return file.path;
}
