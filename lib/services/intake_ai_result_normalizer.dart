import 'ipad_model_resolver.dart';

class IntakeAiResultNormalizer {
  IntakeAiResultNormalizer._();

  static Map<String, dynamic> normalize(
    Map<String, dynamic> input, {
    required List<String> modelOptions,
    required List<String> capacityOptions,
  }) {
    final result = Map<String, dynamic>.from(input);
    final confidence = _confidenceMap(result);

    _normalizeSerial(result, confidence);
    _normalizeModel(result, confidence, modelOptions);
    _normalizeCapacity(result, confidence, capacityOptions);
    _normalizeBattery(result, confidence);

    if (confidence.isNotEmpty) result['fieldConfidence'] = confidence;
    return result;
  }

  static void _normalizeSerial(
    Map<String, dynamic> result,
    Map<String, dynamic> confidence,
  ) {
    final evidence = _joinedValues(result, const ['serial', 'serialRaw']);
    final serial = _extractSerial(evidence);
    if (serial.isEmpty) return;
    result['serial'] = serial;
    result['serialRaw'] =
        _usable(result['serialRaw']) ? result['serialRaw'] : serial;
    _raise(confidence, 'serial', 0.92);
    _raise(confidence, 'serialRaw', 0.92);
  }

  static void _normalizeModel(
    Map<String, dynamic> result,
    Map<String, dynamic> confidence,
    List<String> options,
  ) {
    final evidence = _joinedValues(result, const [
      'model',
      'modelEvidenceText',
      'modelName',
      'modelNameRaw',
      'modelNumber',
      'partNumber',
      'partNumberRaw',
      'modelIdentifier',
      'generation',
      'inspectionEvidenceText',
    ]);
    final matched = IpadModelResolver.match(evidence, options);
    if (matched.isEmpty) return;
    result['model'] = matched;
    _raise(confidence, 'model', 0.92);
    _raise(confidence, 'modelEvidenceText', 0.92);
  }

  static void _normalizeCapacity(
    Map<String, dynamic> result,
    Map<String, dynamic> confidence,
    List<String> options,
  ) {
    final primaryEvidence = _joinedValues(result, const [
      'capacity',
      'capacityRaw',
      'hardDiskCapacity',
      'storage',
    ]);
    final reportEvidence = _joinedValues(result, const [
      'inspectionEvidenceText',
    ]);
    final primaryMatch = _matchCapacity(primaryEvidence, options);
    final matched =
        primaryMatch.isNotEmpty
            ? primaryMatch
            : _matchCapacity(reportEvidence, options);
    if (matched.isEmpty) return;
    result['capacity'] = matched;
    result['capacityRaw'] =
        _usable(result['capacityRaw']) ? result['capacityRaw'] : matched;
    _raise(confidence, 'capacity', 0.9);
    _raise(confidence, 'capacityRaw', 0.9);
  }

  static void _normalizeBattery(
    Map<String, dynamic> result,
    Map<String, dynamic> confidence,
  ) {
    final health =
        _intFromValue(result['batteryHealth'], min: 50, max: 100) ??
        _intFromBatteryEvidence(_allText(result), min: 50, max: 100);
    if (health != null) {
      result['batteryHealth'] = health.toString();
      _raise(confidence, 'batteryHealth', 0.9);
      _raise(confidence, 'batteryHealthRaw', 0.9);
    }

    final cycles =
        _intFromValue(result['cycleCount'], min: 0, max: 3000) ??
        _intFromCycleEvidence(_allText(result), min: 0, max: 3000);
    if (cycles != null) {
      result['cycleCount'] = cycles.toString();
      _raise(confidence, 'cycleCount', 0.9);
      _raise(confidence, 'cycleCountRaw', 0.9);
    }
  }

  static Map<String, dynamic> _confidenceMap(Map<String, dynamic> result) {
    final raw = result['fieldConfidence'];
    if (raw is Map<String, dynamic>) return Map<String, dynamic>.from(raw);
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  static void _raise(
    Map<String, dynamic> confidence,
    String key,
    double value,
  ) {
    final current = _readConfidence(confidence[key]) ?? 0;
    if (value > current) confidence[key] = value;
  }

  static double? _readConfidence(dynamic raw) {
    final value =
        raw is num ? raw.toDouble() : double.tryParse(raw?.toString() ?? '');
    if (value == null) return null;
    final normalized = value > 1 && value <= 100 ? value / 100 : value;
    return normalized.clamp(0.0, 1.0).toDouble();
  }

  static String _joinedValues(Map<String, dynamic> result, List<String> keys) {
    final parts = <String>[];
    for (final key in keys) {
      final value = result[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (_usable(text)) parts.add(text);
    }
    return parts.join(' ');
  }

  static String _allText(dynamic value, [String key = '']) {
    if (value is Map) {
      return value.entries
          .map((entry) => _allText(entry.value, entry.key.toString()))
          .where((item) => item.isNotEmpty)
          .join(' ');
    }
    if (value is Iterable) {
      return value
          .map((item) => _allText(item, key))
          .where((item) => item.isNotEmpty)
          .join(' ');
    }
    final text = value?.toString().trim() ?? '';
    if (!_usable(text)) return '';
    return key.isEmpty ? text : '$key $text';
  }

  static String _matchCapacity(String raw, List<String> options) {
    final normalized = raw.toUpperCase().replaceAll(RegExp(r'\s+'), '');
    if (normalized.contains('1TB')) {
      return options.contains('1TB') ? '1TB' : '';
    }
    final truncated = RegExp(
      r'(^|[^\d])(64|12|25|51)(?:\.{2,}|…)',
    ).firstMatch(normalized);
    if (truncated != null) {
      final prefix = truncated.group(2);
      final value = switch (prefix) {
        '64' => '64G',
        '12' => '128G',
        '25' => '256G',
        '51' => '512G',
        _ => '',
      };
      if (options.contains(value)) return value;
    }
    final match = RegExp(r'(\d{2,4})(?:GB|G\b)').firstMatch(normalized);
    if (match == null) return '';
    final value = '${match.group(1)}G';
    return options.contains(value) ? value : '';
  }

  static int? _intFromValue(dynamic raw, {required int min, required int max}) {
    final match = RegExp(r'\d+').firstMatch(raw?.toString() ?? '');
    if (match == null) return null;
    final value = int.tryParse(match.group(0)!);
    if (value == null || value < min || value > max) return null;
    return value;
  }

  static String _extractSerial(String raw) {
    for (final match in RegExp(
      r'[A-Z0-9]{10,12}',
    ).allMatches(raw.toUpperCase())) {
      final serial = match.group(0) ?? '';
      if (RegExp(r'^\d+$').hasMatch(serial)) continue;
      if (serial.split('').toSet().length <= 3) continue;
      return serial;
    }
    return '';
  }

  static int? _intFromBatteryEvidence(
    String raw, {
    required int min,
    required int max,
  }) {
    final patterns = [
      RegExp(
        r'(?:电池(?:寿命|健康度|健康|效率)?|battery\s*health)\D{0,16}(\d{2,3})\s*%',
        caseSensitive: false,
      ),
      RegExp(
        r'(\d{2,3})\s*%\D{0,12}(?:电池(?:寿命|健康度|健康|效率)?|battery\s*health)',
        caseSensitive: false,
      ),
    ];
    return _firstPatternInt(raw, patterns, min: min, max: max);
  }

  static int? _intFromCycleEvidence(
    String raw, {
    required int min,
    required int max,
  }) {
    final patterns = [
      RegExp(
        r'(?:充电次数|循环次数|充电循环|循环计数|cycle\s*count)\D{0,16}(\d{1,4})',
        caseSensitive: false,
      ),
    ];
    return _firstPatternInt(raw, patterns, min: min, max: max);
  }

  static int? _firstPatternInt(
    String raw,
    List<RegExp> patterns, {
    required int min,
    required int max,
  }) {
    for (final pattern in patterns) {
      final match = pattern.firstMatch(raw);
      if (match == null) continue;
      final value = int.tryParse(match.group(1)!);
      if (value == null || value < min || value > max) continue;
      return value;
    }
    return null;
  }

  static bool _usable(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isNotEmpty && text != '未知' && text.toLowerCase() != 'unknown';
  }
}
