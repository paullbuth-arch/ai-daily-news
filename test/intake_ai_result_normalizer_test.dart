import 'package:flutter_test/flutter_test.dart';
import 'package:ipad_boss_app/services/intake_ai_result_normalizer.dart';

void main() {
  const models = [
    'iPad Pro 13 2025 (M5)',
    'iPad Pro 11 2025 (M5)',
    'iPad Pro 13 2024 (M4)',
    'iPad Pro 11 2024 (M4)',
    'iPad Pro 12.9 2022 (M2)',
    'iPad Pro 11 2022 (M2)',
    'iPad Pro 12.9 2021 (M1)',
    'iPad Pro 11 2021 (M1)',
    'iPad Pro 12.9 2020 (A12Z)',
    'iPad Pro 11 2020 (A12Z)',
  ];
  const capacities = ['64G', '128G', '256G', '512G', '1TB'];

  test('normalizes about-device and Aisi report evidence', () {
    final result = IntakeAiResultNormalizer.normalize(
      {
        'modelName': 'iPad Pro（11英寸）（第2代）',
        'partNumber': 'MY252KH/A',
        'modelEvidenceText': '关于本机 型号名称 iPad Pro（11英寸）（第2代） 型号 MY252KH/A',
        'capacityRaw': '总容量 128 GB',
        'inspectionEvidenceText':
            '爱思助手验机报告 设备型号 11寸 iPad Pro 第2代 销售型号 MY252 监管型号 A2228 电池寿命 93% 充电次数 676次',
        'fieldConfidence': {
          'model': 0.4,
          'capacity': 0.4,
          'batteryHealth': 0.4,
          'cycleCount': 0.4,
        },
      },
      modelOptions: models,
      capacityOptions: capacities,
    );

    expect(result['model'], 'iPad Pro 11 2020 (A12Z)');
    expect(result['capacity'], '128G');
    expect(result['batteryHealth'], '93');
    expect(result['cycleCount'], '676');

    final confidence = result['fieldConfidence'] as Map;
    expect(confidence['model'], greaterThanOrEqualTo(0.9));
    expect(confidence['batteryHealth'], greaterThanOrEqualTo(0.9));
    expect(confidence['cycleCount'], greaterThanOrEqualTo(0.9));
  });

  test('cleans fast-region form values', () {
    final result = IntakeAiResultNormalizer.normalize(
      {
        'model': 'iPad Pro 11 2020 (A12Z)',
        'capacity': '25...',
        'batteryHealth': '如 93',
        'cycleCount': '0次',
        'fieldConfidence': {
          'model': 0.9,
          'capacity': 0.9,
          'batteryHealth': 0.9,
          'cycleCount': 0.9,
        },
      },
      modelOptions: models,
      capacityOptions: capacities,
    );

    expect(result['capacity'], '256G');
    expect(result['batteryHealth'], '93');
    expect(result['cycleCount'], '0');
  });

  test('normalizes directed three-image output without field confidence', () {
    final result = IntakeAiResultNormalizer.normalize(
      {
        'serial': 'DMPCF4FWPTRK',
        'serialRaw': '序列号 DMPCF4FWPTRK',
        'model': 'MY252KH/A',
        'modelName': 'iPad Pro (11英寸) (第2代)',
        'modelNumber': 'MY252KH/A',
        'capacity': '128 GB',
        'capacityRaw': '总容量 128 GB',
        'batteryHealth': '93%',
        'batteryHealthRaw': '电池寿命 93%',
        'cycleCount': '676次',
        'cycleCountRaw': '充电次数 676次',
      },
      modelOptions: models,
      capacityOptions: capacities,
    );

    expect(result['serial'], 'DMPCF4FWPTRK');
    expect(result['model'], 'iPad Pro 11 2020 (A12Z)');
    expect(result['capacity'], '128G');
    expect(result['batteryHealth'], '93');
    expect(result['cycleCount'], '676');

    final confidence = result['fieldConfidence'] as Map;
    expect(confidence['serial'], greaterThanOrEqualTo(0.9));
    expect(confidence['model'], greaterThanOrEqualTo(0.9));
  });
}
