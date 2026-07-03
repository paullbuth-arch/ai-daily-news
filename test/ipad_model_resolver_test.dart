import 'package:flutter_test/flutter_test.dart';
import 'package:ipad_boss_app/services/ipad_model_resolver.dart';

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
    'iPad Pro 12.9 2018 (A12X)',
    'iPad Pro 11 2018 (A12X)',
    'iPad Air 13 2026 (M4)',
    'iPad Air 11 2026 (M4)',
    'iPad Air 13 2025 (M3)',
    'iPad Air 11 2025 (M3)',
    'iPad Air 13 2024 (M2)',
    'iPad Air 11 2024 (M2)',
    'iPad Air 5 (M1)',
    'iPad Air 4 (A14)',
    'iPad Air 3 (A12)',
    'iPad A16 (A16)',
    'iPad 10 (A14)',
    'iPad 9 (A13)',
    'iPad 8 (A12)',
    'iPad 7 (A10)',
    'iPad mini 7 (A17 Pro)',
    'iPad mini 6 (A15)',
    'iPad mini 5 (A12)',
  ];

  test('keeps iPad mini 6 when about-device generation is visible', () {
    expect(
      IpadModelResolver.match('iPad mini（第6代）', models),
      'iPad mini 6 (A15)',
    );
  });

  test('does not override explicit mini 7 text with local order table', () {
    expect(
      IpadModelResolver.match('iPad mini 7 (A17 Pro) MLWL3CH/A', models),
      'iPad mini 7 (A17 Pro)',
    );
  });

  test('uses sparse order-number prefix only as fallback', () {
    expect(IpadModelResolver.match('MLWL3CH/A', models), 'iPad mini 6 (A15)');
  });

  test('does not guess mini generation from generic mini text', () {
    expect(IpadModelResolver.match('iPad mini', models), isEmpty);
  });

  test('still accepts explicit iPad mini 7 evidence', () {
    expect(
      IpadModelResolver.match('iPad mini 7 (A17 Pro)', models),
      'iPad mini 7 (A17 Pro)',
    );
  });

  test('maps Pro generation when size and generation are visible', () {
    expect(
      IpadModelResolver.match('iPad Pro (12.9英寸)(第5代) MHNH3TA/A', models),
      'iPad Pro 12.9 2021 (M1)',
    );
  });

  test('maps Pro 11 second generation to 2020 instead of guessing M4', () {
    expect(
      IpadModelResolver.match('iPad Pro（11英寸）（第2代） MY252KH/A A2228', models),
      'iPad Pro 11 2020 (A12Z)',
    );
  });

  test('maps Pro model numbers across supported generations', () {
    expect(
      IpadModelResolver.match('iPad Pro 13英寸 M5 A3360', models),
      'iPad Pro 13 2025 (M5)',
    );
    expect(
      IpadModelResolver.match('iPad Pro 11英寸 M4 A2836', models),
      'iPad Pro 11 2024 (M4)',
    );
    expect(
      IpadModelResolver.match('iPad Pro 12.9英寸 A2436', models),
      'iPad Pro 12.9 2022 (M2)',
    );
  });

  test('maps Air model numbers and chip clues', () {
    expect(
      IpadModelResolver.match('iPad Air 13英寸 M4 A3461', models),
      'iPad Air 13 2026 (M4)',
    );
    expect(
      IpadModelResolver.match('iPad Air 11英寸 M3 A3266', models),
      'iPad Air 11 2025 (M3)',
    );
    expect(
      IpadModelResolver.match('iPad Air 11英寸 M2 A2902', models),
      'iPad Air 11 2024 (M2)',
    );
    expect(
      IpadModelResolver.match('iPad Air（第5代） A2588', models),
      'iPad Air 5 (M1)',
    );
    expect(
      IpadModelResolver.match('iPad Air（第4代） A2316', models),
      'iPad Air 4 (A14)',
    );
    expect(
      IpadModelResolver.match('iPad Air（第3代） A2152', models),
      'iPad Air 3 (A12)',
    );
  });

  test('maps base iPad generations and model numbers', () {
    expect(
      IpadModelResolver.match('iPad（第11代） A3354', models),
      'iPad A16 (A16)',
    );
    expect(
      IpadModelResolver.match('iPad（第10代） A2696', models),
      'iPad 10 (A14)',
    );
    expect(IpadModelResolver.match('iPad（第9代） A2602', models), 'iPad 9 (A13)');
    expect(IpadModelResolver.match('iPad（第8代） A2270', models), 'iPad 8 (A12)');
    expect(IpadModelResolver.match('iPad（第7代） A2197', models), 'iPad 7 (A10)');
  });

  test('keeps unknown structured clues unresolved instead of guessing', () {
    expect(IpadModelResolver.match('iPad A9999', models), isEmpty);
  });

  test('keeps structured Pro clues unresolved when target model is absent', () {
    expect(
      IpadModelResolver.match('iPad Pro（11英寸）（第2代） MY252KH/A A2228', [
        'iPad Pro 11 2024 (M4)',
        'iPad Pro 11 2022 (M2)',
      ]),
      isEmpty,
    );
  });
}
