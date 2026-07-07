import 'dart:math' as math;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'
    as mlkit;

class IntakeOcrLine {
  final String imagePath;
  final String text;
  final double confidence;
  final double left;
  final double top;
  final double right;
  final double bottom;

  const IntakeOcrLine({
    required this.imagePath,
    required this.text,
    required this.confidence,
    this.left = 0,
    this.top = 0,
    this.right = 0,
    this.bottom = 0,
  });

  double get centerY => top + height / 2;

  double get height => math.max(1, bottom - top);
}

class IntakeOcrResult {
  final List<IntakeOcrLine> lines;
  final List<String> recognizedPaths;
  final List<String> warnings;

  const IntakeOcrResult({
    this.lines = const <IntakeOcrLine>[],
    this.recognizedPaths = const <String>[],
    this.warnings = const <String>[],
  });

  bool get hasText => lines.any((line) => line.text.trim().isNotEmpty);

  String get fullText =>
      lines.map((line) => line.text.trim()).where(_usable).join('\n');

  static bool _usable(String value) => value.trim().isNotEmpty;
}

class MobileIntakeOcrService {
  MobileIntakeOcrService._();

  static const int imageLimit = 8;
  static final mlkit.TextRecognizer _textRecognizer = mlkit.TextRecognizer(
    script: mlkit.TextRecognitionScript.chinese,
  );
  static final mlkit.TextRecognizer _latinTextRecognizer = mlkit.TextRecognizer(
    script: mlkit.TextRecognitionScript.latin,
  );

  static Future<IntakeOcrResult> recognize(List<String> imagePaths) async {
    if (imagePaths.isEmpty) return const IntakeOcrResult();

    return _recognizeWithMlKit(imagePaths);
  }

  static Future<IntakeOcrResult> _recognizeWithMlKit(
    List<String> imagePaths,
  ) async {
    final lines = <IntakeOcrLine>[];
    final recognizedPaths = <String>{};
    final warnings = <String>[];

    for (final path in imagePaths.take(imageLimit)) {
      try {
        final input = mlkit.InputImage.fromFilePath(path);
        final detected = await _textRecognizer.processImage(input);
        final latinDetected = await _latinTextRecognizer.processImage(input);
        final textLines = <mlkit.TextLine>[
          for (final block in detected.blocks) ...block.lines,
          for (final block in latinDetected.blocks) ...block.lines,
        ]..sort((a, b) {
          final byTop = a.boundingBox.top.compareTo(b.boundingBox.top);
          if (byTop != 0) return byTop;
          return a.boundingBox.left.compareTo(b.boundingBox.left);
        });
        final seen = <String>{};

        for (final line in textLines) {
          final text = line.text.trim();
          if (text.isEmpty) continue;
          final rect = line.boundingBox;
          final key =
              '${text.replaceAll(RegExp(r'\s+'), '').toLowerCase()}@'
              '${(rect.left / 8).round()}:${(rect.top / 8).round()}';
          if (!seen.add(key)) continue;
          lines.add(
            IntakeOcrLine(
              imagePath: path,
              text: text,
              confidence: (line.confidence ?? 0.82).clamp(0.0, 1.0).toDouble(),
              left: rect.left.toDouble(),
              top: rect.top.toDouble(),
              right: rect.right.toDouble(),
              bottom: rect.bottom.toDouble(),
            ),
          );
        }
        if (textLines.isNotEmpty) recognizedPaths.add(path);
      } catch (_) {
        warnings.add('ML Kit读取失败：${_fileName(path)}');
      }
    }

    return IntakeOcrResult(
      lines: lines,
      recognizedPaths: recognizedPaths.toList(),
      warnings: warnings,
    );
  }

  static String _fileName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final index = normalized.lastIndexOf('/');
    return index >= 0 ? normalized.substring(index + 1) : normalized;
  }
}

class IntakeOcrInspectionMapper {
  IntakeOcrInspectionMapper._();

  static Map<String, dynamic> toInspectionResult(IntakeOcrResult ocr) {
    final sourceLines =
        ocr.lines
            .map(
              (line) => _OcrTextLine(
                text: _normalizeText(line.text),
                confidence: line.confidence,
                left: line.left,
                top: line.top,
                right: line.right,
                bottom: line.bottom,
              ),
            )
            .where((line) => line.text.isNotEmpty)
            .toList();
    if (sourceLines.isEmpty) return <String, dynamic>{};

    final result = <String, dynamic>{
      'ocrText': sourceLines.map((line) => line.text).join('\n'),
    };
    final fieldConfidence = <String, dynamic>{};

    final serialLine = _firstLine(
      sourceLines,
      (line) => RegExp(
        r'(序列号|serial\s*number|serial)',
        caseSensitive: false,
      ).hasMatch(line.text),
    );
    final serialRaw = _labelValueText(sourceLines, serialLine);
    final serial = _extractSerial(serialRaw);
    if (serial.isNotEmpty) {
      final serialConfidence =
          serialLine == null
              ? _bestConfidence(sourceLines)
              : serialLine.confidence;
      result['serial'] = serial;
      result['serialRaw'] = serialRaw;
      _raise(fieldConfidence, 'serial', _confidence(serialConfidence));
      _raise(fieldConfidence, 'serialRaw', _confidence(serialConfidence));
    }

    final modelEvidence = _uniqueLines(
      sourceLines.where(
        (line) =>
            RegExp(
              r'(ipad|型号|机型|设备型号|销售型号|监管型号|model|ML|MY|A\d{4})',
              caseSensitive: false,
            ).hasMatch(line.text) ||
            _partNumberPattern.hasMatch(line.text),
      ),
    );
    if (modelEvidence.isNotEmpty) {
      result['modelEvidenceText'] = modelEvidence.join('；');
      _raise(
        fieldConfidence,
        'modelEvidenceText',
        _bestConfidence(sourceLines),
      );
    }

    final modelNameLine = _firstLine(
      sourceLines,
      (line) =>
          RegExp(
            r'(型号名称|model\s*name)',
            caseSensitive: false,
          ).hasMatch(line.text) ||
          (line.text.toLowerCase().contains('ipad') &&
              !RegExp(
                r'(容量|capacity|可用|available)',
                caseSensitive: false,
              ).hasMatch(line.text)),
    );
    if (modelNameLine != null) {
      final modelNameText = _labelValueText(sourceLines, modelNameLine);
      result['modelName'] = modelNameText;
      result['modelNameRaw'] = modelNameText;
      _raise(
        fieldConfidence,
        'modelName',
        _confidence(modelNameLine.confidence),
      );
      _raise(
        fieldConfidence,
        'modelNameRaw',
        _confidence(modelNameLine.confidence),
      );
    }

    final modelNumber = _extractModelNumber(sourceLines);
    if (modelNumber.isNotEmpty) {
      result['modelNumber'] = modelNumber;
      _raise(fieldConfidence, 'modelNumber', 0.9);
    }

    final partNumber = _extractPartNumber(sourceLines);
    if (partNumber.isNotEmpty) {
      result['partNumber'] = partNumber;
      result['partNumberRaw'] = partNumber;
      _raise(fieldConfidence, 'partNumber', 0.9);
      _raise(fieldConfidence, 'partNumberRaw', 0.9);
    }

    final capacityLine = _firstLine(
      sourceLines,
      (line) =>
          RegExp(
            r'(总容量|硬盘容量|存储容量|容量|capacity|storage)',
            caseSensitive: false,
          ).hasMatch(line.text) &&
          !RegExp(r'(可用|available)', caseSensitive: false).hasMatch(line.text),
    );
    final capacityText =
        capacityLine == null
            ? _capacityFallback(sourceLines)
            : _labelValueText(sourceLines, capacityLine);
    if (capacityText.isNotEmpty) {
      result['capacityRaw'] = capacityText;
      _raise(
        fieldConfidence,
        'capacityRaw',
        _confidence(capacityLine?.confidence ?? _bestConfidence(sourceLines)),
      );
    }

    final batteryLine = _firstLine(
      sourceLines,
      (line) => RegExp(
        r'(电池(?:寿命|健康度|健康|效率)?|battery\s*health)',
        caseSensitive: false,
      ).hasMatch(line.text),
    );
    if (batteryLine != null) {
      result['batteryHealthRaw'] = _labelValueText(sourceLines, batteryLine);
      _raise(
        fieldConfidence,
        'batteryHealthRaw',
        _confidence(batteryLine.confidence),
      );
    }

    final cycleLine = _firstLine(
      sourceLines,
      (line) => RegExp(
        r'(充电次数|循环次数|充电循环|循环计数|cycle\s*count)',
        caseSensitive: false,
      ).hasMatch(line.text),
    );
    if (cycleLine != null) {
      result['cycleCountRaw'] = _labelValueText(sourceLines, cycleLine);
      _raise(
        fieldConfidence,
        'cycleCountRaw',
        _confidence(cycleLine.confidence),
      );
    }

    final inspectionEvidence = _uniqueLines(
      sourceLines.where(
        (line) => RegExp(
          r'(爱思|沙漏|验机|设备型号|销售型号|监管型号|电池|充电|循环|零售机|官换机|官修机|全绿|ID锁|激活锁|监管|MDM)',
          caseSensitive: false,
        ).hasMatch(line.text),
      ),
    );
    if (inspectionEvidence.isNotEmpty) {
      result['inspectionEvidenceText'] = inspectionEvidence.join('；');
      _raise(
        fieldConfidence,
        'inspectionEvidenceText',
        _bestConfidence(sourceLines),
      );
    }

    final fullText = sourceLines.map((line) => line.text).join('\n');
    _mapColor(sourceLines, result, fieldConfidence);
    _mapInspectionMeta(fullText, result, fieldConfidence);
    _mapNetwork(fullText, result, fieldConfidence);

    if (fieldConfidence.isNotEmpty) result['fieldConfidence'] = fieldConfidence;
    result['confidence'] = fieldConfidence.values.whereType<num>().fold<double>(
      0,
      (best, value) => math.max(best, value.toDouble()),
    );
    final warnings = <String>[...ocr.warnings];
    if (warnings.isNotEmpty) result['warnings'] = warnings;

    return result;
  }

  static final RegExp _partNumberPattern = RegExp(
    r'\b[A-Z0-9]{5,8}/A\b',
    caseSensitive: false,
  );

  static String _normalizeText(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim();

  static _OcrTextLine? _firstLine(
    List<_OcrTextLine> lines,
    bool Function(_OcrTextLine line) test,
  ) {
    for (final line in lines) {
      if (test(line)) return line;
    }
    return null;
  }

  static List<String> _uniqueLines(Iterable<_OcrTextLine> lines) {
    final result = <String>[];
    for (final line in lines) {
      if (line.text.isEmpty || result.contains(line.text)) continue;
      result.add(line.text);
    }
    return result;
  }

  static String _labelValueText(
    List<_OcrTextLine> lines,
    _OcrTextLine? labelLine,
  ) {
    if (labelLine == null) return '';
    final sameRowValues = _sameRowValues(lines, labelLine);
    if (sameRowValues.isEmpty) return labelLine.text;
    final parts = <String>[labelLine.text];
    for (final value in sameRowValues) {
      if (!parts.contains(value)) parts.add(value);
    }
    return parts.join(' ');
  }

  static List<String> _sameRowValues(
    List<_OcrTextLine> lines,
    _OcrTextLine labelLine,
  ) {
    if (labelLine.right <= labelLine.left ||
        labelLine.bottom <= labelLine.top) {
      return const <String>[];
    }
    final tolerance = math.max(8.0, labelLine.height * 0.85);
    final values =
        lines
            .where(
              (line) =>
                  !identical(line, labelLine) &&
                  line.left > labelLine.left + 18 &&
                  (line.centerY - labelLine.centerY).abs() <= tolerance &&
                  !_looksLikeColumnHeader(line.text),
            )
            .toList()
          ..sort((a, b) => a.left.compareTo(b.left));
    return values.map((line) => line.text).toList();
  }

  static bool _looksLikeColumnHeader(String text) {
    final compact = text.replaceAll(' ', '');
    return compact == '出厂值' ||
        compact == '读出值' ||
        compact == '检测结果' ||
        compact == '检测项目';
  }

  static String _extractSerial(String raw) {
    final value = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), ' ');
    for (final match in RegExp(r'\b[A-Z0-9]{10,12}\b').allMatches(value)) {
      final serial = match.group(0) ?? '';
      if (RegExp(r'^\d+$').hasMatch(serial)) continue;
      if (serial.split('').toSet().length <= 3) continue;
      return serial;
    }
    return '';
  }

  static String _extractModelNumber(List<_OcrTextLine> lines) {
    for (final line in lines) {
      final match = RegExp(
        r'\bA\d{4}\b',
        caseSensitive: false,
      ).firstMatch(line.text);
      if (match != null) return match.group(0)!.toUpperCase();
    }
    return '';
  }

  static String _extractPartNumber(List<_OcrTextLine> lines) {
    for (final line in lines) {
      final match = _partNumberPattern.firstMatch(line.text.toUpperCase());
      if (match != null) return match.group(0)!;
    }
    return '';
  }

  static String _capacityFallback(List<_OcrTextLine> lines) {
    for (final line in lines) {
      final text = line.text.toUpperCase();
      if (RegExp(r'\b(64|128|256|512)\s*(GB|G)\b').hasMatch(text) ||
          RegExp(r'\b1\s*TB\b').hasMatch(text)) {
        return line.text;
      }
    }
    return '';
  }

  static void _mapInspectionMeta(
    String fullText,
    Map<String, dynamic> result,
    Map<String, dynamic> confidence,
  ) {
    if (fullText.contains('爱思')) {
      result['inspectionTool'] = '爱思';
      _raise(confidence, 'inspectionTool', 0.88);
    } else if (fullText.contains('沙漏')) {
      result['inspectionTool'] = '沙漏';
      _raise(confidence, 'inspectionTool', 0.88);
    }

    for (final type in const ['零售机', '官换机', '官修机', '演示机']) {
      if (!fullText.contains(type)) continue;
      result['machineType'] = type;
      _raise(confidence, 'machineType', 0.86);
      break;
    }

    if (fullText.contains('全绿')) {
      result['allGreen'] = true;
      result['inspectionSummary'] = '验机报告全绿';
      _raise(confidence, 'allGreen', 0.86);
      _raise(confidence, 'inspectionSummary', 0.86);
    }

    if (RegExp(
      r'(ID锁|激活锁|iCloud).{0,8}(无|关闭|未开启|clean|off)',
      caseSensitive: false,
    ).hasMatch(fullText)) {
      result['idLockClean'] = true;
      result['iCloudLock'] = false;
      result['activationLock'] = false;
      _raise(confidence, 'lockStatus', 0.84);
    }

    if (RegExp(
      r'(监管|MDM).{0,8}(无|未开启|正常|关闭)',
      caseSensitive: false,
    ).hasMatch(fullText)) {
      result['mdm'] = false;
      result['configLock'] = false;
      _raise(confidence, 'lockStatus', 0.84);
    }
  }

  static void _mapColor(
    List<_OcrTextLine> lines,
    Map<String, dynamic> result,
    Map<String, dynamic> confidence,
  ) {
    final colorLine = _firstLine(
      lines,
      (line) => RegExp(
        r'(颜色|colour|color)',
        caseSensitive: false,
      ).hasMatch(line.text),
    );
    final raw = _labelValueText(lines, colorLine);
    if (raw.isEmpty) return;
    final normalized = raw.toLowerCase();
    final color =
        normalized.contains('深空') ||
                normalized.contains('太空灰') ||
                normalized.contains('space gray') ||
                normalized.contains('space grey')
            ? '深空灰'
            : normalized.contains('银') || normalized.contains('silver')
            ? '银色'
            : normalized.contains('星光') || normalized.contains('starlight')
            ? '星光色'
            : normalized.contains('粉') || normalized.contains('pink')
            ? '粉色'
            : normalized.contains('紫') || normalized.contains('purple')
            ? '紫色'
            : normalized.contains('蓝') || normalized.contains('blue')
            ? '蓝色'
            : normalized.contains('玫瑰金') || normalized.contains('rose')
            ? '玫瑰金'
            : normalized.contains('金') || normalized.contains('gold')
            ? '金色'
            : normalized.contains('绿') || normalized.contains('green')
            ? '绿色'
            : normalized.contains('黄') || normalized.contains('yellow')
            ? '黄色'
            : '';
    if (color.isEmpty) return;
    result['color'] = color;
    _raise(confidence, 'color', 0.86);
  }

  static void _mapNetwork(
    String fullText,
    Map<String, dynamic> result,
    Map<String, dynamic> confidence,
  ) {
    if (RegExp(
      r'(蜂窝|cellular|5G|LTE)',
      caseSensitive: false,
    ).hasMatch(fullText)) {
      result['network'] = 'WiFi+蜂窝';
      _raise(confidence, 'network', 0.84);
    } else if (RegExp(
      r'(wi-?fi|无线局域网|wlan)',
      caseSensitive: false,
    ).hasMatch(fullText)) {
      result['network'] = 'WiFi';
      _raise(confidence, 'network', 0.82);
    }
  }

  static double _confidence(double value) =>
      value.isNaN ? 0.8 : value.clamp(0.72, 0.95).toDouble();

  static double _bestConfidence(List<_OcrTextLine> lines) {
    var best = 0.0;
    for (final line in lines) {
      best = math.max(best, line.confidence);
    }
    return _confidence(best);
  }

  static void _raise(
    Map<String, dynamic> confidence,
    String key,
    double value,
  ) {
    final current =
        confidence[key] is num ? (confidence[key] as num).toDouble() : 0.0;
    if (value > current) confidence[key] = value;
  }
}

class _OcrTextLine {
  final String text;
  final double confidence;
  final double left;
  final double top;
  final double right;
  final double bottom;

  const _OcrTextLine({
    required this.text,
    required this.confidence,
    this.left = 0,
    this.top = 0,
    this.right = 0,
    this.bottom = 0,
  });

  double get centerY => top + height / 2;

  double get height => math.max(1, bottom - top);
}
