import 'package:flutter_test/flutter_test.dart';
import 'package:ipad_boss_app/services/ipad_color_recognition_service.dart';
import 'package:ipad_boss_app/services/intake_image_recognition_service.dart';
import 'package:ipad_boss_app/services/intake_ocr_service.dart';

void main() {
  const models = ['iPad Pro 11 2020 (A12Z)', 'iPad mini 6 (A15)'];
  const capacities = ['64G', '128G', '256G', '512G', '1TB'];

  test('uses local OCR to fill intake fields', () async {
    var ocrCalls = 0;
    final service = IntakeImageRecognitionService(
      modelOptions: models,
      capacityOptions: capacities,
      ocrReader: (_) async {
        ocrCalls++;
        return const IntakeOcrResult(
          recognizedPaths: ['about.png', 'report.png'],
          lines: [
            IntakeOcrLine(
              imagePath: 'about.png',
              text: '型号名称 iPad Pro（11英寸）（第2代）',
              confidence: 0.91,
            ),
            IntakeOcrLine(
              imagePath: 'about.png',
              text: '型号 MY252KH/A',
              confidence: 0.9,
            ),
            IntakeOcrLine(
              imagePath: 'about.png',
              text: '序列号 DMPCF4FWPTRK',
              confidence: 0.93,
            ),
            IntakeOcrLine(
              imagePath: 'about.png',
              text: '总容量 128 GB',
              confidence: 0.92,
            ),
            IntakeOcrLine(
              imagePath: 'report.png',
              text: '爱思助手 电池寿命 93% 充电次数 676次',
              confidence: 0.88,
            ),
          ],
        );
      },
    );

    final result = await service.recognize(['about.png', 'report.png']);

    expect(ocrCalls, 1);
    expect(result['serial'], 'DMPCF4FWPTRK');
    expect(result['model'], 'iPad Pro 11 2020 (A12Z)');
    expect(result['capacity'], '128G');
    expect(result['batteryHealth'], '93');
    expect(result['cycleCount'], '676');
    expect(result['recognitionPasses'], contains('本地OCR识别'));
    expect(result['recognitionStrategy'], contains('不再调用远程AI'));
  });

  test('keeps OCR-only result and reports missing fields', () async {
    final service = IntakeImageRecognitionService(
      modelOptions: models,
      capacityOptions: capacities,
      ocrReader:
          (_) async => const IntakeOcrResult(
            recognizedPaths: ['about.png'],
            lines: [
              IntakeOcrLine(
                imagePath: 'about.png',
                text: '序列号 DMPCF4FWPTRK',
                confidence: 0.93,
              ),
            ],
          ),
    );

    final result = await service.recognize(['about.png']);

    expect(result['serial'], 'DMPCF4FWPTRK');
    expect(result['missingCriticalFields'], contains('型号'));
    expect(result['missingCriticalFields'], contains('容量'));
    expect(result['warnings'], contains('未识别到：型号、容量、颜色、网络、电池健康、充电次数'));
  });

  test('uses back color sampling when OCR finds no text', () async {
    final service = IntakeImageRecognitionService(
      modelOptions: models,
      capacityOptions: capacities,
      ocrReader: (_) async => const IntakeOcrResult(),
      colorEstimator: (_) async => '\u84dd\u8272',
    );

    final result = await service.recognize(['back.jpg']);
    final confidence = result['fieldConfidence'] as Map;

    expect(result['error'], isNull);
    expect(result['color'], '\u84dd\u8272');
    expect(
      result['recognitionPasses'],
      contains('\u673a\u8eab\u989c\u8272\u91c7\u6837'),
    );
    expect(confidence['color'], 0.82);
    expect(result['missingCriticalFields'], isNot(contains('\u989c\u8272')));
  });

  test('classifies sampled iPad back colors', () {
    expect(
      IpadColorRecognitionService.classifyRgb([88, 92, 96]),
      '\u6df1\u7a7a\u7070',
    );
    expect(
      IpadColorRecognitionService.classifyRgb([194, 196, 198]),
      '\u94f6\u8272',
    );
    expect(
      IpadColorRecognitionService.classifyRgb([112, 146, 184]),
      '\u84dd\u8272',
    );
  });

  test('keeps stronger primary evidence when incoming evidence is weaker', () {
    final merged = IntakeImageRecognitionService.mergeInspectionResults(
      {
        'modelEvidenceText': '关于本机 iPad mini（第6代） A2567',
        'model': 'iPad mini 6 (A15)',
        'capacityRaw': '容量 256 GB',
        'fieldConfidence': {'model': 0.92, 'capacity': 0.9},
        'confidence': 0.9,
      },
      {
        'model': 'iPad mini 7',
        'modelEvidenceText': '外观像新款',
        'capacity': '64G',
        'fieldConfidence': {'model': 0.45, 'capacity': 0.55},
        'confidence': 0.6,
      },
      modelOptions: models,
      capacityOptions: capacities,
    );

    expect(merged['model'], 'iPad mini 6 (A15)');
    expect(merged['capacity'], '256G');
    expect(merged['modelEvidenceText'], contains('A2567'));
    expect(merged['modelEvidenceText'], contains('外观像新款'));
  });

  test('returns readable error when OCR finds no text', () async {
    final service = IntakeImageRecognitionService(
      modelOptions: models,
      capacityOptions: capacities,
      ocrReader: (_) async => const IntakeOcrResult(),
    );

    final result = await service.recognize(['a.jpg']);

    expect(result['error'], contains('OCR没有识别到可用文字'));
    expect(result['recognizedImageCount'], 0);
  });
}
