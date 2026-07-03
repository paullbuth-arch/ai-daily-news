import 'package:flutter_test/flutter_test.dart';
import 'package:ipad_boss_app/services/ipad_model_resolver.dart';

void main() {
  const models = [
    'iPad mini 7 (A17 Pro)',
    'iPad mini 6 (A15)',
    'iPad mini 5 (A12)',
    'iPad Pro 12.9 2022 (M2)',
    'iPad Pro 12.9 2021 (M1)',
    'iPad Pro 12.9 2020 (A12Z)',
    'iPad Pro 12.9 2018 (A12X)',
    'iPad Pro 11 2022 (M2)',
    'iPad Pro 11 2021 (M1)',
    'iPad Pro 11 2020 (A12Z)',
    'iPad Pro 11 2018 (A12X)',
    'iPad 10 (A14)',
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
