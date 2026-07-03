import 'package:flutter_test/flutter_test.dart';
import 'package:ipad_boss_app/services/ipad_model_resolver.dart';

void main() {
  const models = [
    'iPad mini 7 (A17 Pro)',
    'iPad mini 6 (A15)',
    'iPad mini 5 (A12)',
    'iPad 10 (A14)',
  ];

  test('keeps iPad mini 6 when about-device generation is visible', () {
    expect(
      IpadModelResolver.match('iPad mini（第6代）', models),
      'iPad mini 6 (A15)',
    );
  });

  test('uses mini 6 order number before fuzzy model text', () {
    expect(
      IpadModelResolver.match('iPad mini 7 (A17 Pro) MLWL3CH/A', models),
      'iPad mini 6 (A15)',
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
}
