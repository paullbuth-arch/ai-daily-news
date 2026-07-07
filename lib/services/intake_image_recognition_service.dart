import 'dart:math' as math;

import 'intake_ai_result_normalizer.dart';
import 'intake_ocr_service.dart';
import 'ipad_model_resolver.dart';

typedef IntakeOcrReader = Future<IntakeOcrResult> Function(List<String> paths);

class IntakeImageRecognitionService {
  final List<String> modelOptions;
  final List<String> capacityOptions;
  final IntakeOcrReader ocrReader;

  const IntakeImageRecognitionService({
    required this.modelOptions,
    required this.capacityOptions,
    this.ocrReader = MobileIntakeOcrService.recognize,
  });

  Future<Map<String, dynamic>> recognize(List<String> imagePaths) async {
    if (imagePaths.isEmpty) return {'error': '请先上传设备图片'};

    var result = <String, dynamic>{};
    var hasOcrResult = false;
    final recognizedPaths = <String>{};
    final warnings = <String>{};
    final passes = <String>[];

    try {
      final ocr = await ocrReader(imagePaths);
      warnings.addAll(ocr.warnings);
      final ocrResult = IntakeOcrInspectionMapper.toInspectionResult(ocr);
      if (ocrResult.isNotEmpty) {
        result = mergeInspectionResults(
          result,
          ocrResult,
          modelOptions: modelOptions,
          capacityOptions: capacityOptions,
        );
        recognizedPaths.addAll(ocr.recognizedPaths);
        hasOcrResult = true;
        passes.add('本地OCR识别');
      }
    } catch (e) {
      warnings.add('OCR读取失败：$e');
    }

    if (!hasOcrResult) {
      return {
        'error':
            warnings.isEmpty
                ? 'OCR没有识别到可用文字，请换清晰的关于本机、爱思/沙漏报告或电池页截图'
                : warnings.join('；'),
        'warnings': warnings.toList(),
        'recognizedImageCount': recognizedPaths.length,
        'recognitionPasses': passes,
        'missingCriticalFields': missingCriticalFields(result),
      };
    }

    result = _normalize(result);
    final missing = missingCriticalFields(result);
    if (missing.isNotEmpty) warnings.add('未识别到：${missing.join('、')}');

    result['recognizedImageCount'] = recognizedPaths.length;
    result['recognitionPasses'] = passes;
    result['recognitionStrategy'] =
        '本地OCR识别：使用 ML Kit 读取图片文字，不再调用远程AI，也不再触发 mobile_ocr 原生模型。';
    final mergedWarnings = <String>{
      ..._warnings(result['warnings']),
      ...warnings,
    };
    if (mergedWarnings.isNotEmpty) result['warnings'] = mergedWarnings.toList();
    result['missingCriticalFields'] = missing;
    return result;
  }

  Map<String, dynamic> _normalize(Map<String, dynamic> value) {
    return IntakeAiResultNormalizer.normalize(
      value,
      modelOptions: modelOptions,
      capacityOptions: capacityOptions,
    );
  }

  List<String> missingCriticalFields(Map<String, dynamic> result) {
    final missing = <String>[];
    if (!_hasSerial(result)) missing.add('序列号');
    if (!_hasModel(result)) missing.add('型号');
    if (!_hasCapacity(result)) missing.add('容量');
    if (!_hasOption(result, 'color', const [
      '深空灰',
      '银色',
      '星光色',
      '粉色',
      '紫色',
      '蓝色',
      '玫瑰金',
      '金色',
      '绿色',
      '黄色',
    ], threshold: 0.74)) {
      missing.add('颜色');
    }
    if (!_hasOption(result, 'network', const [
      'WiFi',
      'WiFi+蜂窝',
    ], threshold: 0.82)) {
      missing.add('网络');
    }
    if (!_hasBoundedInt(result, 'batteryHealth', min: 50, max: 100)) {
      missing.add('电池健康');
    }
    if (!_hasBoundedInt(result, 'cycleCount', min: 0, max: 3000)) {
      missing.add('充电次数');
    }
    return missing;
  }

  static Map<String, dynamic> mergeInspectionResults(
    Map<String, dynamic> base,
    Map<String, dynamic> incoming, {
    required List<String> modelOptions,
    required List<String> capacityOptions,
  }) {
    final normalizedIncoming = IntakeAiResultNormalizer.normalize(
      Map<String, dynamic>.from(incoming),
      modelOptions: modelOptions,
      capacityOptions: capacityOptions,
    );
    if (base.isEmpty) return normalizedIncoming;

    final normalizedBase = IntakeAiResultNormalizer.normalize(
      Map<String, dynamic>.from(base),
      modelOptions: modelOptions,
      capacityOptions: capacityOptions,
    );
    final merged = Map<String, dynamic>.from(normalizedBase);
    final baseConfidence = _confidenceMap(normalizedBase);
    final incomingConfidence = _confidenceMap(normalizedIncoming);

    void mergeTextField(String key) {
      final next = _cleanText(normalizedIncoming[key]);
      if (!_usable(next)) return;
      final current = _cleanText(merged[key]);
      final nextConfidence = _confidenceForReplacement(
        normalizedIncoming,
        incoming,
        key,
      );
      final currentConfidence = _fieldConfidence(merged, key);
      if (!_usable(current) || nextConfidence >= currentConfidence) {
        merged[key] = next;
      }
    }

    for (final key in const [
      'serial',
      'serialRaw',
      'model',
      'modelName',
      'modelNameRaw',
      'modelNumber',
      'partNumber',
      'partNumberRaw',
      'generation',
      'capacity',
      'capacityRaw',
      'color',
      'network',
      'condition',
      'batteryHealth',
      'batteryHealthRaw',
      'cycleCount',
      'cycleCountRaw',
      'inspectionTool',
      'machineType',
      'allGreen',
      'inspectionSummary',
      'accessories',
      'appearanceSummary',
      'functionSummary',
      'defectSummary',
    ]) {
      mergeTextField(key);
    }

    for (final key in const ['modelEvidenceText', 'inspectionEvidenceText']) {
      final text = _joinEvidence(
        _cleanText(merged[key]),
        _cleanText(normalizedIncoming[key]),
      );
      if (text.isNotEmpty) merged[key] = text;
    }

    for (final key in const [
      'iCloudLock',
      'activationLock',
      'mdm',
      'configLock',
      'idLockClean',
    ]) {
      final next = normalizedIncoming[key];
      if (next is! bool) continue;
      final currentConfidence = _fieldConfidence(merged, key);
      final nextConfidence = _confidenceForReplacement(
        normalizedIncoming,
        incoming,
        key,
      );
      if (merged[key] is! bool || nextConfidence >= currentConfidence) {
        merged[key] = next;
      }
    }

    final checks = Map<String, dynamic>.from(
      merged['checks'] is Map ? merged['checks'] as Map : const {},
    );
    final incomingChecks = normalizedIncoming['checks'];
    if (incomingChecks is Map) {
      for (final entry in incomingChecks.entries) {
        final value = _cleanText(entry.value);
        if (!_usable(value)) continue;
        final current = _cleanText(checks[entry.key]);
        if (!_usable(current) || current == '未知') checks[entry.key] = value;
      }
    }
    if (checks.isNotEmpty) merged['checks'] = checks;

    final confidence = <String, dynamic>{...baseConfidence};
    for (final entry in incomingConfidence.entries) {
      final next = _readConfidence(entry.value) ?? 0;
      final current = _readConfidence(confidence[entry.key]) ?? 0;
      if (next > current) confidence[entry.key.toString()] = next;
    }
    if (confidence.isNotEmpty) merged['fieldConfidence'] = confidence;

    final baseOverall = _readConfidence(normalizedBase['confidence']) ?? 0;
    final nextOverall = _readConfidence(normalizedIncoming['confidence']) ?? 0;
    merged['confidence'] = math.max(baseOverall, nextOverall);

    final warnings = <String>{
      ..._warnings(normalizedBase['warnings']),
      ..._warnings(normalizedIncoming['warnings']),
    };
    if (warnings.isNotEmpty) merged['warnings'] = warnings.toList();

    return IntakeAiResultNormalizer.normalize(
      merged,
      modelOptions: modelOptions,
      capacityOptions: capacityOptions,
    );
  }

  static double _confidenceForReplacement(
    Map<String, dynamic> normalized,
    Map<String, dynamic> original,
    String key,
  ) {
    final normalizedConfidence = _fieldConfidence(normalized, key);
    final originalConfidence = _fieldConfidence(original, key);
    if (originalConfidence <= 0) return normalizedConfidence;
    return math.min(normalizedConfidence, originalConfidence);
  }

  bool _hasSerial(Map<String, dynamic> result) {
    final serial = _cleanText(result['serial']).toUpperCase();
    if (!_looksLikeSerial(serial)) return false;
    return _fieldConfidence(result, 'serial') >= 0.84;
  }

  bool _hasModel(Map<String, dynamic> result) {
    final evidence = _joinedValues(result, const [
      'model',
      'modelEvidenceText',
      'modelName',
      'modelNameRaw',
      'modelNumber',
      'partNumber',
      'partNumberRaw',
      'generation',
      'inspectionEvidenceText',
    ]);
    if (IpadModelResolver.match(evidence, modelOptions).isEmpty) return false;
    return _fieldConfidence(result, 'model') >= 0.82;
  }

  bool _hasCapacity(Map<String, dynamic> result) {
    final capacity = _matchOption(
      _joinedValues(result, const ['capacity', 'capacityRaw']),
      capacityOptions,
    );
    if (capacity.isEmpty) return false;
    return _fieldConfidence(result, 'capacity') >= 0.8;
  }

  bool _hasOption(
    Map<String, dynamic> result,
    String key,
    List<String> options, {
    required double threshold,
  }) {
    final value = _matchOption(_cleanText(result[key]), options);
    return value.isNotEmpty && _fieldConfidence(result, key) >= threshold;
  }

  bool _hasBoundedInt(
    Map<String, dynamic> result,
    String key, {
    required int min,
    required int max,
  }) {
    final value = _intFromValue(result[key], min: min, max: max);
    if (value == null) return false;
    return _fieldConfidence(result, key) >= 0.8;
  }

  static Map<String, dynamic> _confidenceMap(Map<String, dynamic> value) {
    final raw = value['fieldConfidence'];
    if (raw is Map<String, dynamic>) return Map<String, dynamic>.from(raw);
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  static double _fieldConfidence(Map<String, dynamic> result, String key) {
    final confidence = _confidenceMap(result);
    final aliases = <String>[
      key,
      if (key == 'model') ...[
        'modelName',
        'modelNameRaw',
        'modelEvidenceText',
        'modelNumber',
        'partNumber',
        'partNumberRaw',
        'generation',
      ],
      if (key == 'serial') 'serialRaw',
      if (key == 'capacity') 'capacityRaw',
      if (key == 'batteryHealth') ...[
        'batteryHealthRaw',
        'inspectionEvidenceText',
      ],
      if (key == 'cycleCount') ...['cycleCountRaw', 'inspectionEvidenceText'],
      if ([
        'iCloudLock',
        'activationLock',
        'mdm',
        'configLock',
        'idLockClean',
      ].contains(key))
        'lockStatus',
    ];
    var best = 0.0;
    for (final alias in aliases) {
      best = math.max(best, _readConfidence(confidence[alias]) ?? 0);
    }
    return best > 0 ? best : (_readConfidence(result['confidence']) ?? 0);
  }

  static double? _readConfidence(dynamic raw) {
    final value =
        raw is num ? raw.toDouble() : double.tryParse(raw?.toString() ?? '');
    if (value == null) return null;
    final normalized = value > 1 && value <= 100 ? value / 100 : value;
    return normalized.clamp(0.0, 1.0).toDouble();
  }

  static String _joinedValues(Map<String, dynamic> result, List<String> keys) {
    return keys.map((key) => _cleanText(result[key])).where(_usable).join(' ');
  }

  static String _matchOption(String raw, List<String> options) {
    final value = raw.trim();
    if (!_usable(value)) return '';
    for (final option in options) {
      if (option == value) return option;
    }
    final normalized = value.toLowerCase().replaceAll(' ', '');
    for (final option in options) {
      final opt = option.toLowerCase().replaceAll(' ', '');
      if (normalized.contains(opt) || opt.contains(normalized)) return option;
    }
    if (normalized.contains('cell') || normalized.contains('蜂窝')) {
      return options.contains('WiFi+蜂窝') ? 'WiFi+蜂窝' : '';
    }
    if (normalized.contains('wifi') || normalized.contains('wi-fi')) {
      return options.contains('WiFi') ? 'WiFi' : '';
    }
    if (normalized.contains('tb')) return options.contains('1TB') ? '1TB' : '';
    final cap = RegExp(r'(\d{2,4})\s*g').firstMatch(normalized);
    if (cap != null) {
      final candidate = '${cap.group(1)}G';
      if (options.contains(candidate)) return candidate;
    }
    return '';
  }

  static int? _intFromValue(dynamic raw, {required int min, required int max}) {
    final match = RegExp(r'\d+').firstMatch(raw?.toString() ?? '');
    if (match == null) return null;
    final parsed = int.tryParse(match.group(0)!);
    if (parsed == null || parsed < min || parsed > max) return null;
    return parsed;
  }

  static bool _looksLikeSerial(String value) {
    final serial = value.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{10,12}$').hasMatch(serial)) return false;
    if (RegExp(r'^\d{10,12}$').hasMatch(serial)) return false;
    return serial.split('').toSet().length > 3;
  }

  static String _joinEvidence(String left, String right) {
    final parts = <String>[];
    for (final item in [left, right]) {
      final text = item.trim();
      if (!_usable(text)) continue;
      if (!parts.contains(text)) parts.add(text);
    }
    return parts.join('；');
  }

  static List<String> _warnings(dynamic raw) {
    if (raw is List) {
      return raw
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    final text = raw?.toString().trim() ?? '';
    return text.isEmpty ? const <String>[] : <String>[text];
  }

  static String _cleanText(Object? value) => value?.toString().trim() ?? '';

  static bool _usable(String value) =>
      value.isNotEmpty && value != '未知' && value.toLowerCase() != 'unknown';
}
