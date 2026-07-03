import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/colors.dart';
import '../components/index.dart';
import '../utils/utils.dart';
import '../models.dart';
import '../ai_service.dart';
import '../serial_decoder.dart';
import '../main.dart';
import '../services/device_export_service.dart';
import '../services/intake_report_service.dart';
import '../services/ipad_model_resolver.dart';
import '../services/xianyu_copy_service.dart';

class _ManualIssueOption {
  final String id;
  final String group;
  final String label;
  final bool isScreen;
  final String part;
  final String location;
  final String type;
  final String severity;
  final String checkKey;
  final String checkValue;

  const _ManualIssueOption({
    required this.id,
    required this.group,
    required this.label,
    required this.part,
    required this.location,
    required this.type,
    required this.severity,
    this.isScreen = false,
    this.checkKey = '',
    this.checkValue = '需复核',
  });
}

const List<_ManualIssueOption> _manualIssueOptions = [
  _ManualIssueOption(
    id: 'screen-left-line',
    group: '屏幕显示',
    label: '屏幕左侧出线',
    isScreen: true,
    part: '屏幕',
    location: '左侧',
    type: '显示异常/出线',
    severity: '明显',
    checkKey: '屏幕显示',
    checkValue: '异常',
  ),
  _ManualIssueOption(
    id: 'screen-right-line',
    group: '屏幕显示',
    label: '屏幕右侧出线',
    isScreen: true,
    part: '屏幕',
    location: '右侧',
    type: '显示异常/出线',
    severity: '明显',
    checkKey: '屏幕显示',
    checkValue: '异常',
  ),
  _ManualIssueOption(
    id: 'screen-scratch',
    group: '屏幕显示',
    label: '屏幕划痕',
    isScreen: true,
    part: '屏幕',
    location: '表面',
    type: '划痕',
    severity: '轻微',
    checkKey: '屏幕显示',
    checkValue: '需复核',
  ),
  _ManualIssueOption(
    id: 'screen-spot',
    group: '屏幕显示',
    label: '亮点/坏点',
    isScreen: true,
    part: '屏幕',
    location: '显示区域',
    type: '亮点/坏点',
    severity: '明显',
    checkKey: '屏幕显示',
    checkValue: '异常',
  ),
  _ManualIssueOption(
    id: 'screen-pressure',
    group: '屏幕显示',
    label: '压伤/漏液',
    isScreen: true,
    part: '屏幕',
    location: '显示区域',
    type: '压伤/漏液',
    severity: '明显',
    checkKey: '屏幕显示',
    checkValue: '异常',
  ),
  _ManualIssueOption(
    id: 'corner-left-top',
    group: '边框四角',
    label: '左上角磕碰',
    part: '边框',
    location: '左上角',
    type: '磕碰',
    severity: '轻微',
    checkKey: '外观边框',
    checkValue: '轻微磕碰',
  ),
  _ManualIssueOption(
    id: 'corner-right-top',
    group: '边框四角',
    label: '右上角磕碰',
    part: '边框',
    location: '右上角',
    type: '磕碰',
    severity: '轻微',
    checkKey: '外观边框',
    checkValue: '轻微磕碰',
  ),
  _ManualIssueOption(
    id: 'corner-left-bottom',
    group: '边框四角',
    label: '左下角磕碰',
    part: '边框',
    location: '左下角',
    type: '磕碰',
    severity: '轻微',
    checkKey: '外观边框',
    checkValue: '轻微磕碰',
  ),
  _ManualIssueOption(
    id: 'corner-right-bottom',
    group: '边框四角',
    label: '右下角磕碰',
    part: '边框',
    location: '右下角',
    type: '磕碰',
    severity: '轻微',
    checkKey: '外观边框',
    checkValue: '轻微磕碰',
  ),
  _ManualIssueOption(
    id: 'frame-paint',
    group: '边框四角',
    label: '边框掉漆',
    part: '边框',
    location: '边缘',
    type: '掉漆',
    severity: '轻微',
    checkKey: '外观边框',
    checkValue: '轻微磕碰',
  ),
  _ManualIssueOption(
    id: 'back-scratch',
    group: '后盖/镜头/接口',
    label: '后盖划痕',
    part: '后盖',
    location: '背面',
    type: '划痕',
    severity: '轻微',
    checkKey: '后盖',
    checkValue: '划痕',
  ),
  _ManualIssueOption(
    id: 'back-dent',
    group: '后盖/镜头/接口',
    label: '后盖凹陷',
    part: '后盖',
    location: '背面',
    type: '凹陷',
    severity: '明显',
    checkKey: '后盖',
    checkValue: '凹陷',
  ),
  _ManualIssueOption(
    id: 'camera-wear',
    group: '后盖/镜头/接口',
    label: '镜头圈磨损',
    part: '摄像头',
    location: '后置镜头',
    type: '磨损',
    severity: '轻微',
    checkKey: '摄像头',
    checkValue: '需复核',
  ),
  _ManualIssueOption(
    id: 'port-wear',
    group: '后盖/镜头/接口',
    label: '接口磨损',
    part: '接口',
    location: '充电口',
    type: '磨损',
    severity: '轻微',
    checkKey: '充电接口',
    checkValue: '需复核',
  ),
  _ManualIssueOption(
    id: 'other-appearance',
    group: '后盖/镜头/接口',
    label: '其他外观问题',
    part: '其他',
    location: '人工补充',
    type: '其他外观问题',
    severity: '需说明',
    checkKey: '外观边框',
    checkValue: '需复核',
  ),
];

class ScanPage extends StatefulWidget {
  const ScanPage({Key? key}) : super(key: key);
  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  // 基本信息
  final _serialCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  String selectedModel = '';
  String selectedCapacity = '';
  String selectedColor = '';
  String selectedNetwork = 'WiFi';
  String selectedCondition = '95新';
  String selectedChannel = '华强北同行';
  bool isCustomChannel = false;
  final _customChannelCtrl = TextEditingController();
  final _appearanceNoteCtrl = TextEditingController();
  final Set<String> selectedManualIssueIds = <String>{};

  // ID锁检测
  bool iCloudLock = false, actLock = false, mdm = false, configLock = false;
  Map<String, dynamic>? idCheck;

  // 多图上传（最多12张）
  List<String> imagePaths = [];

  // 整机图片AI识别
  static const int _aboutDeviceOcrImageLimit = 2;
  static const int _primaryInspectionImageLimit = 3;
  static const int _supplementalInspectionImageLimit = 4;
  bool aiInspecting = false;
  Map<String, dynamic>? aiInspection;
  String? inspectionReportPath;

  // 保存
  bool saving = false;

  // 步骤指引：当前步骤 0=上传图片 1=AI复核 2=成本入库
  int currentStep = 0;

  @override
  void dispose() {
    _serialCtrl.dispose();
    _costCtrl.dispose();
    _customChannelCtrl.dispose();
    _appearanceNoteCtrl.dispose();
    super.dispose();
  }

  void _checkIdLock() {
    final c = IdLockChecker.check(
      iCloudLocked: iCloudLock,
      activationLocked: actLock,
      mdmSupervised: mdm,
      configLock: configLock,
    );
    setState(() {
      idCheck = c;
    });
  }

  List<String> _optionsWithCurrent(List<String> options, String current) {
    final values = [...options];
    if (current.isNotEmpty && !values.contains(current))
      values.insert(0, current);
    return values;
  }

  /// 添加实拍图（原图，不压缩）
  Future<void> _addImage(bool fromCamera) async {
    if (imagePaths.length >= 12) {
      toast(context, '最多上传12张图片');
      return;
    }
    try {
      final picker = ImagePicker();
      final x = await picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 82,
      );
      if (x != null) {
        final now = DateTime.now();
        final dest =
            '$gDocDir/dev_${now.millisecondsSinceEpoch}_${imagePaths.length}.jpg';
        // 原图拷贝，不做压缩
        await File(x.path).copy(dest);
        setState(() {
          imagePaths.add(dest);
          aiInspection = null;
          inspectionReportPath = null;
        });
        toast(context, '已添加第${imagePaths.length}张图片');
      }
    } catch (e) {
      toast(context, '选图失败：$e');
    }
  }

  /// 多选图片（从相册批量选择）
  Future<void> _addMultipleImages() async {
    final remaining = 12 - imagePaths.length;
    if (remaining <= 0) {
      toast(context, '最多上传12张图片');
      return;
    }
    try {
      final picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage(
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 82,
      );
      if (images.isNotEmpty) {
        int added = 0;
        for (final x in images) {
          if (imagePaths.length >= 12) break;
          final now = DateTime.now();
          final dest =
              '$gDocDir/dev_${now.millisecondsSinceEpoch}_${imagePaths.length + added}.jpg';
          await File(x.path).copy(dest);
          imagePaths.add(dest);
          added++;
        }
        setState(() {
          aiInspection = null;
          inspectionReportPath = null;
        });
        toast(context, '已添加${added}张图片，共${imagePaths.length}张');
      }
    } catch (e) {
      toast(context, '批量选图失败：$e');
    }
  }

  /// 删除某张图
  void _removeImage(int index) {
    setState(() {
      imagePaths.removeAt(index);
      aiInspection = null;
      inspectionReportPath = null;
    });
  }

  void _toggleManualIssue(String id) {
    setState(() {
      if (selectedManualIssueIds.contains(id)) {
        selectedManualIssueIds.remove(id);
      } else {
        selectedManualIssueIds.add(id);
      }
      inspectionReportPath = null;
    });
  }

  List<_ManualIssueOption> get _selectedManualIssues =>
      _manualIssueOptions
          .where((issue) => selectedManualIssueIds.contains(issue.id))
          .toList();

  String _manualDefectSummary({int maxItems = 6}) {
    final labels = _selectedManualIssues.map((issue) => issue.label).toList();
    final note = _appearanceNoteCtrl.text.trim();
    if (note.isNotEmpty) labels.add(note);
    if (labels.isEmpty) return '人工未记录明显外观/屏幕问题';
    final visible = labels.take(maxItems).join('、');
    final more = labels.length > maxItems ? '等${labels.length}项' : '';
    return '人工记录：$visible$more';
  }

  String _manualDefectNote() => _manualDefectSummary(maxItems: 12);

  Map<String, dynamic> _inspectionForOutput() {
    final merged = Map<String, dynamic>.from(
      aiInspection ?? const <String, dynamic>{},
    );
    final appearanceDefects = <Map<String, dynamic>>[];
    final screenDefects = <Map<String, dynamic>>[];
    for (final issue in _selectedManualIssues) {
      final target = issue.isScreen ? screenDefects : appearanceDefects;
      target.add(_manualDefectMap(issue));
    }
    final note = _appearanceNoteCtrl.text.trim();
    if (note.isNotEmpty) appearanceDefects.add(_noteDefectMap(note));

    final checks = Map<String, dynamic>.from(
      merged['checks'] is Map ? merged['checks'] as Map : const {},
    );
    for (final issue in _selectedManualIssues) {
      if (issue.checkKey.isNotEmpty) {
        checks[issue.checkKey] = issue.checkValue;
      }
    }
    if (screenDefects.isEmpty) {
      checks['屏幕显示'] = checks['屏幕显示'] ?? '正常';
    }
    if (appearanceDefects.isEmpty) {
      checks['外观边框'] = checks['外观边框'] ?? '正常';
      checks['后盖'] = checks['后盖'] ?? '正常';
    }

    merged['manualAppearanceReview'] = true;
    merged['manualAppearanceSummary'] = _manualDefectSummary(maxItems: 12);
    merged['appearanceDefects'] = appearanceDefects;
    merged['screenDefects'] = screenDefects;
    merged['defectSummary'] = _manualDefectSummary(maxItems: 12);
    merged['appearanceSummary'] =
        appearanceDefects.isEmpty && screenDefects.isEmpty
            ? '人工未记录明显外观/屏幕问题'
            : _manualDefectSummary(maxItems: 12);
    merged['checks'] = checks;
    return merged;
  }

  Map<String, dynamic> _manualDefectMap(_ManualIssueOption issue) => {
    'part': issue.part,
    'location': issue.location,
    'type': issue.type,
    'severity': issue.severity,
    'evidence': '人工勾选',
  };

  Map<String, dynamic> _noteDefectMap(String note) => {
    'part': '其他',
    'location': '人工补充',
    'type': note,
    'severity': '需说明',
    'evidence': '人工补充',
  };

  Future<String> _imageDataUriForAi(String path) async {
    final bytes = await File(path).readAsBytes();
    final mime = _mimeFromBytes(bytes);
    if (mime != null) return 'data:$mime;base64,${base64Encode(bytes)}';
    try {
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 1024);
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      if (data != null) {
        return 'data:image/png;base64,${base64Encode(data.buffer.asUint8List())}';
      }
    } catch (_) {}
    return 'data:image/jpeg;base64,${base64Encode(bytes)}';
  }

  String? _mimeFromBytes(List<int> bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }
    return null;
  }

  Future<void> _runFullAiInspection() async {
    if (imagePaths.isEmpty) {
      toast(context, '请先上传设备图片');
      return;
    }
    if (aiInspecting) return;
    setState(() => aiInspecting = true);
    try {
      final recognizedPaths = <String>{};
      var result = <String, dynamic>{};
      var hasAiResult = false;

      for (final path in imagePaths.take(_aboutDeviceOcrImageLimit)) {
        recognizedPaths.add(path);
        final about = await AiService.recognizeAboutDeviceOcr(
          await _imageDataUriForAi(path),
        );
        if (about['error'] == null) {
          hasAiResult = true;
          result = _mergeAboutDeviceOcrResult(result, about);
        } else {
          result = _withInspectionWarning(
            result,
            '关于本机单图识别失败：${about['error']}',
          );
        }
        if (_hasCoreAboutDeviceInfo(result)) break;
      }

      final primarySupplementalPaths =
          imagePaths
              .take(_primaryInspectionImageLimit)
              .where((path) => !recognizedPaths.contains(path))
              .toList();
      if (primarySupplementalPaths.isNotEmpty) {
        final focusFields = _supplementalInspectionFields(result);
        final supplement = await AiService.recognizeIpadIntake(
          await _encodeInspectionImages(primarySupplementalPaths),
          supplemental: true,
          totalImageCount: imagePaths.length,
          focusFields: focusFields,
        );
        recognizedPaths.addAll(primarySupplementalPaths);
        if (supplement['error'] == null) {
          hasAiResult = true;
          result = _mergeInspectionResults(result, supplement, focusFields);
        } else {
          result = _withInspectionWarning(result, '图1-3补充识别失败，已保留单图识别结果');
        }
      }

      final missingFields = _criticalSupplementalFields(result);
      if (missingFields.isNotEmpty &&
          imagePaths.length > _primaryInspectionImageLimit) {
        final supplementalPaths =
            imagePaths
                .skip(_primaryInspectionImageLimit)
                .take(_supplementalInspectionImageLimit)
                .toList();
        final supplement = await AiService.recognizeIpadIntake(
          await _encodeInspectionImages(supplementalPaths),
          supplemental: true,
          totalImageCount: imagePaths.length,
          focusFields: missingFields,
        );
        recognizedPaths.addAll(supplementalPaths);
        if (supplement['error'] == null) {
          hasAiResult = true;
          result = _mergeInspectionResults(result, supplement, missingFields);
        } else {
          result = _withInspectionWarning(result, '后续图片补充识别失败，已保留前三张识别结果');
        }
      }

      if (!hasAiResult) {
        if (!mounted) return;
        final warning = _inspectionWarnings(result['warnings']).join('；');
        toast(context, warning.isEmpty ? 'AI识别失败，请换一张清晰图片再试' : warning);
        return;
      }
      result['recognitionStrategy'] =
          recognizedPaths.length <= _primaryInspectionImageLimit
              ? '关于本机单图优先，图1-3补充'
              : '关于本机单图优先，缺字段时补看后续${recognizedPaths.length}张内图片';
      result['recognizedImageCount'] = recognizedPaths.length;
      if (!mounted) return;
      final appliedCount = _applyInspection(result);
      setState(() {
        aiInspection = result;
        inspectionReportPath = null;
      });
      toast(
        context,
        appliedCount > 0 ? 'AI已补全可信设备信息，请复核后入库' : 'AI已读取图片，未看清的字段已留给人工复核',
      );
    } catch (e) {
      if (mounted) toast(context, 'AI整机识别失败：$e');
    } finally {
      if (mounted) setState(() => aiInspecting = false);
    }
  }

  Future<List<String>> _encodeInspectionImages(List<String> paths) async {
    final encoded = <String>[];
    for (final path in paths) {
      encoded.add(await _imageDataUriForAi(path));
    }
    return encoded;
  }

  bool _hasCoreAboutDeviceInfo(Map<String, dynamic> result) =>
      _hasReliableInspectionValue(result, 'serial') &&
      _hasReliableInspectionValue(result, 'model') &&
      _hasReliableInspectionValue(result, 'capacity');

  List<String> _supplementalInspectionFields(Map<String, dynamic> result) =>
      {
        ..._missingInspectionFields(result),
        'inspectionTool',
        'machineType',
        'allGreen',
        'inspectionSummary',
        'accessories',
      }.toList();

  List<String> _criticalSupplementalFields(Map<String, dynamic> result) {
    final missing = _missingInspectionFields(result).toSet();
    missing.remove('color');
    if (!_hasReliableInspectionValue(result, 'inspectionTool') ||
        !_hasReliableInspectionValue(result, 'machineType') ||
        !_hasReliableInspectionValue(result, 'allGreen')) {
      missing.addAll(['inspectionTool', 'machineType', 'allGreen']);
    }
    return missing.toList();
  }

  List<String> _missingInspectionFields(Map<String, dynamic> result) {
    final fields = <String>[];
    for (final key in const [
      'serial',
      'model',
      'capacity',
      'color',
      'network',
      'batteryHealth',
      'cycleCount',
    ]) {
      if (!_hasReliableInspectionValue(result, key)) fields.add(key);
    }
    return fields;
  }

  Map<String, dynamic> _mergeAboutDeviceOcrResult(
    Map<String, dynamic> primary,
    Map<String, dynamic> about,
  ) {
    var merged = Map<String, dynamic>.from(primary);
    final isAboutPage = about['isAboutDevicePage'];
    if (isAboutPage is bool &&
        !isAboutPage &&
        _inspectionConfidence(about) < 0.5) {
      return _withInspectionWarning(merged, '前置图片未识别到清晰的关于本机文字');
    }

    for (final key in const [
      'serial',
      'serialRaw',
      'model',
      'modelName',
      'modelNameRaw',
      'modelEvidenceText',
      'modelNumber',
      'partNumber',
      'partNumberRaw',
      'capacity',
      'capacityRaw',
      'availableRaw',
      'ipadOS',
      'network',
    ]) {
      final next = (about[key] ?? '').toString().trim();
      if (!_usable(next) || _hasProtectedInspectionValue(merged, key)) {
        continue;
      }
      merged[key] = about[key];
    }

    final modelNameRaw = (merged['modelNameRaw'] ?? '').toString().trim();
    if (!_usable((merged['modelName'] ?? '').toString()) &&
        _usable(modelNameRaw)) {
      merged['modelName'] = modelNameRaw;
    }
    final partNumberRaw = (merged['partNumberRaw'] ?? '').toString().trim();
    if (!_usable((merged['partNumber'] ?? '').toString()) &&
        _usable(partNumberRaw)) {
      merged['partNumber'] = partNumberRaw;
    }

    final mergedConfidence = <String, dynamic>{
      if (merged['fieldConfidence'] is Map)
        ...Map<String, dynamic>.from(merged['fieldConfidence'] as Map),
    };
    final aboutConfidence =
        about['fieldConfidence'] is Map
            ? Map<String, dynamic>.from(about['fieldConfidence'] as Map)
            : const <String, dynamic>{};
    for (final entry in aboutConfidence.entries) {
      final current = _readConfidence(mergedConfidence[entry.key]) ?? 0;
      final next = _readConfidence(entry.value) ?? 0;
      if (next > current) mergedConfidence[entry.key] = entry.value;
    }
    if (mergedConfidence.isNotEmpty) {
      merged['fieldConfidence'] = mergedConfidence;
    }

    final confidence = math.max(
      _inspectionConfidence(merged),
      _inspectionConfidence(about),
    );
    if (confidence > 0) merged['confidence'] = confidence;
    final warnings = <String>{
      ..._inspectionWarnings(merged['warnings']),
      ..._inspectionWarnings(about['warnings']),
    };
    if (warnings.isNotEmpty) merged['warnings'] = warnings.toList();
    merged['functionSummary'] ??= '关于本机信息已读取，外观由人工记录';
    merged['appearanceSummary'] ??= '外观问题由人工勾选记录';
    return merged;
  }

  bool _hasProtectedInspectionValue(Map<String, dynamic> result, String key) {
    if (key == 'serial') return _hasReliableInspectionValue(result, 'serial');
    if (key == 'model') return _hasReliableInspectionValue(result, 'model');
    if (key == 'capacity') {
      return _hasReliableInspectionValue(result, 'capacity');
    }
    if (key == 'network') return _hasReliableInspectionValue(result, 'network');
    final value = (result[key] ?? '').toString().trim();
    return _usable(value) && _fieldConfidence(result, key) >= 0.78;
  }

  Map<String, dynamic> _mergeInspectionResults(
    Map<String, dynamic> primary,
    Map<String, dynamic> supplement,
    List<String> focusFields,
  ) {
    final merged = Map<String, dynamic>.from(primary);
    final fillable = <String>{
      ...focusFields,
      'inspectionTool',
      'machineType',
      'allGreen',
      'inspectionSummary',
      'accessories',
    };
    for (final key in fillable) {
      if (_hasReliableInspectionValue(merged, key)) continue;
      if (_hasReliableInspectionValue(supplement, key)) {
        merged[key] = supplement[key];
      }
    }

    final mergedConfidence = <String, dynamic>{
      if (merged['fieldConfidence'] is Map)
        ...Map<String, dynamic>.from(merged['fieldConfidence'] as Map),
    };
    final supplementConfidence =
        supplement['fieldConfidence'] is Map
            ? Map<String, dynamic>.from(supplement['fieldConfidence'] as Map)
            : const <String, dynamic>{};
    for (final entry in supplementConfidence.entries) {
      final current = _readConfidence(mergedConfidence[entry.key]) ?? 0;
      final next = _readConfidence(entry.value) ?? 0;
      if (next > current) mergedConfidence[entry.key] = entry.value;
    }
    if (mergedConfidence.isNotEmpty) {
      merged['fieldConfidence'] = mergedConfidence;
    }

    final warnings = <String>{
      ..._inspectionWarnings(merged['warnings']),
      ..._inspectionWarnings(supplement['warnings']),
    };
    if (warnings.isNotEmpty) merged['warnings'] = warnings.toList();
    return merged;
  }

  Map<String, dynamic> _withInspectionWarning(
    Map<String, dynamic> result,
    String warning,
  ) {
    final merged = Map<String, dynamic>.from(result);
    final warnings = <String>{..._inspectionWarnings(merged['warnings'])};
    warnings.add(warning);
    merged['warnings'] = warnings.toList();
    return merged;
  }

  List<String> _inspectionWarnings(dynamic raw) {
    if (raw is List) {
      return raw
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    final text = raw?.toString().trim() ?? '';
    return text.isEmpty ? const <String>[] : <String>[text];
  }

  int _applyInspection(Map<String, dynamic> result) {
    var applied = 0;
    String text(String key) => (result[key] ?? '').toString().trim();
    final serial = _serialEvidence(result).toUpperCase();
    if (_serialCtrl.text.trim().isEmpty &&
        _usable(serial) &&
        _looksLikeSerial(serial) &&
        _shouldApplyInspectionField(result, 'serial', threshold: 0.86)) {
      _serialCtrl.text = serial;
      applied++;
    }

    final model = _trustedModelMatch(result);
    if (selectedModel.isEmpty &&
        model.isNotEmpty &&
        _shouldApplyInspectionField(result, 'model', threshold: 0.84)) {
      selectedModel = model;
      applied++;
    }

    final capacity = _trustedCapacityMatch(result);
    if (selectedCapacity.isEmpty &&
        capacity.isNotEmpty &&
        _shouldApplyInspectionField(result, 'capacity', threshold: 0.82)) {
      selectedCapacity = capacity;
      applied++;
    }

    final color = _matchOption(text('color'), iPadColors);
    if (selectedColor.isEmpty &&
        color.isNotEmpty &&
        _shouldApplyInspectionField(result, 'color', threshold: 0.78)) {
      selectedColor = color;
      applied++;
    }

    final network = _matchOption(text('network'), iPadNetworks);
    if ((selectedNetwork.isEmpty || selectedNetwork == 'WiFi') &&
        network.isNotEmpty &&
        _shouldApplyInspectionField(result, 'network', threshold: 0.84)) {
      if (selectedNetwork != network) applied++;
      selectedNetwork = network;
    }

    final iCloud = result['iCloudLock'];
    final activation = result['activationLock'];
    final mdmValue = result['mdm'];
    final config = result['configLock'];
    var lockChanged = false;
    if (iCloud is bool &&
        _shouldApplyInspectionField(result, 'iCloudLock', threshold: 0.90)) {
      if (iCloudLock != iCloud) applied++;
      iCloudLock = iCloud;
      lockChanged = true;
    }
    if (activation is bool &&
        _shouldApplyInspectionField(
          result,
          'activationLock',
          threshold: 0.90,
        )) {
      if (actLock != activation) applied++;
      actLock = activation;
      lockChanged = true;
    }
    if (mdmValue is bool &&
        _shouldApplyInspectionField(result, 'mdm', threshold: 0.90)) {
      if (mdm != mdmValue) applied++;
      mdm = mdmValue;
      lockChanged = true;
    }
    if (config is bool &&
        _shouldApplyInspectionField(result, 'configLock', threshold: 0.90)) {
      if (configLock != config) applied++;
      configLock = config;
      lockChanged = true;
    }
    if (lockChanged) {
      idCheck = IdLockChecker.check(
        iCloudLocked: iCloudLock,
        activationLocked: actLock,
        mdmSupervised: mdm,
        configLock: configLock,
      );
    }
    return applied;
  }

  String _serialEvidence(Map<String, dynamic> result) {
    final raw = (result['serialRaw'] ?? '').toString().trim();
    if (_usable(raw) && _looksLikeSerial(raw.toUpperCase())) return raw;
    return (result['serial'] ?? '').toString().trim();
  }

  String _modelSourceEvidence(Map<String, dynamic> result) {
    final parts = <String>[];
    for (final key in const [
      'modelEvidenceText',
      'modelName',
      'modelNameRaw',
      'modelNumber',
      'partNumber',
      'partNumberRaw',
      'modelIdentifier',
      'generation',
    ]) {
      final value = (result[key] ?? '').toString().trim();
      if (_usable(value)) parts.add(value);
    }
    return parts.join(' ');
  }

  String _trustedModelMatch(Map<String, dynamic> result) {
    final source = _modelSourceEvidence(result);
    if (!_usable(source)) return '';
    final sourceMatch = _matchModel(source);
    if (sourceMatch.isNotEmpty) return sourceMatch;

    final aiModel = (result['model'] ?? '').toString().trim();
    if (!_usable(aiModel) || !_aiModelAllowedBySource(aiModel, source)) {
      return '';
    }
    return _matchModel(aiModel);
  }

  bool _aiModelAllowedBySource(String model, String source) {
    final m = model.toLowerCase();
    final s = source.toLowerCase();
    if ((m.contains('2024') || m.contains('m4')) &&
        !(s.contains('2024') ||
            s.contains('m4') ||
            s.contains('ultra retina') ||
            s.contains('oled'))) {
      return false;
    }
    if (_hasStructuredModelClue(source) && _matchModel(source).isEmpty) {
      return false;
    }
    return true;
  }

  bool _hasStructuredModelClue(String raw) {
    final value = raw.toUpperCase();
    return RegExp(r'\bA\d{4}\b').hasMatch(value) ||
        RegExp(r'\b[A-Z]{1,4}\d{3,5}[A-Z0-9]{0,4}/A\b').hasMatch(value) ||
        RegExp(r'第\s*\d+\s*代').hasMatch(raw) ||
        RegExp(
          r'\d+(st|nd|rd|th)\s+generation',
          caseSensitive: false,
        ).hasMatch(raw);
  }

  String _trustedCapacityMatch(Map<String, dynamic> result) {
    final raw = (result['capacityRaw'] ?? '').toString().trim();
    final fromRaw = _matchOption(raw, iPadCapacities);
    if (fromRaw.isNotEmpty) return fromRaw;
    return _matchOption((result['capacity'] ?? '').toString(), iPadCapacities);
  }

  bool _usable(String value) =>
      value.isNotEmpty && value != '未知' && value.toLowerCase() != 'unknown';

  bool _looksLikeSerial(String value) {
    final serial = value.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{10,12}$').hasMatch(serial)) return false;
    if (RegExp(r'^\d{10,12}$').hasMatch(serial)) return false;
    return serial.split('').toSet().length > 3;
  }

  double? _readConfidence(dynamic raw) {
    final value =
        raw is num ? raw.toDouble() : double.tryParse(raw?.toString() ?? '');
    if (value == null) return null;
    final normalized = value > 1 && value <= 100 ? value / 100 : value;
    return normalized.clamp(0.0, 1.0).toDouble();
  }

  double _inspectionConfidence(Map<String, dynamic>? result) =>
      _readConfidence(result?['confidence']) ?? 0;

  double _fieldConfidence(Map<String, dynamic> result, String key) {
    final fields = result['fieldConfidence'];
    final aliases = <String>[
      key,
      if (key == 'model') ...[
        'modelName',
        'modelNameRaw',
        'modelEvidenceText',
        'modelNumber',
        'partNumber',
        'partNumberRaw',
        'modelIdentifier',
        'generation',
      ],
      if (key == 'serial') 'serialRaw',
      if (key == 'capacity') 'capacityRaw',
      if (['iCloudLock', 'activationLock', 'mdm', 'configLock'].contains(key))
        'lockStatus',
    ];
    var best = 0.0;
    if (fields is Map) {
      for (final alias in aliases) {
        if (!fields.containsKey(alias)) continue;
        best = math.max(best, _readConfidence(fields[alias]) ?? 0);
      }
    }
    return best > 0 ? best : _inspectionConfidence(result);
  }

  bool _shouldApplyInspectionField(
    Map<String, dynamic> result,
    String key, {
    double threshold = 0.78,
  }) => _fieldConfidence(result, key) >= threshold;

  bool _hasReliableInspectionValue(Map<String, dynamic> result, String key) {
    final threshold = _inspectionThreshold(key);
    if (!_shouldApplyInspectionField(result, key, threshold: threshold)) {
      return false;
    }
    final value = (result[key] ?? '').toString().trim();
    if (key == 'serial') {
      final serial = _serialEvidence(result).toUpperCase();
      return _usable(serial) && _looksLikeSerial(serial);
    }
    if (key == 'model') return _trustedModelMatch(result).isNotEmpty;
    if (key == 'capacity') {
      return _trustedCapacityMatch(result).isNotEmpty;
    }
    if (key == 'color') return _matchOption(value, iPadColors).isNotEmpty;
    if (key == 'network') return _matchOption(value, iPadNetworks).isNotEmpty;
    if (key == 'batteryHealth') {
      return _intFromResult(result, key, min: 50, max: 100) != null;
    }
    if (key == 'cycleCount') {
      return _intFromResult(result, key, min: 0, max: 3000) != null;
    }
    if (key == 'allGreen') {
      final raw = result[key];
      if (raw is bool) return true;
      final text = raw?.toString().trim().toLowerCase() ?? '';
      return text == 'true' ||
          text == 'false' ||
          text == '是' ||
          text == '否' ||
          text.contains('全绿') ||
          text.contains('异常');
    }
    return _usable(value);
  }

  double _inspectionThreshold(String key) {
    if (key == 'serial') return 0.86;
    if (key == 'model') return 0.84;
    if (key == 'capacity' || key == 'batteryHealth' || key == 'cycleCount') {
      return 0.82;
    }
    if (key == 'network') return 0.84;
    if (key == 'color') return 0.78;
    if (key == 'allGreen' ||
        key == 'machineType' ||
        key == 'inspectionTool' ||
        key == 'inspectionSummary') {
      return 0.72;
    }
    return 0.78;
  }

  String _matchOption(String raw, List<String> options) {
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
      return 'WiFi+蜂窝';
    }
    if (normalized.contains('wifi') || normalized.contains('wi-fi')) {
      return 'WiFi';
    }
    if (normalized.contains('tb')) return '1TB';
    final cap = RegExp(r'(\d{2,4})\s*g').firstMatch(normalized);
    if (cap != null) {
      final candidate = '${cap.group(1)}G';
      if (options.contains(candidate)) return candidate;
    }
    return '';
  }

  String _matchModel(String raw) {
    return IpadModelResolver.match(
      raw,
      iPadModels.map((m) => m['name']!).toList(),
    );
  }

  int _intFromInspection(
    String key,
    int fallback, {
    int? min,
    int? max,
    double threshold = 0.78,
  }) {
    final inspection = aiInspection;
    final value = _intFromResult(
      inspection,
      key,
      min: min,
      max: max,
      threshold: threshold,
    );
    return value ?? fallback;
  }

  int? _intFromResult(
    Map<String, dynamic>? inspection,
    String key, {
    int? min,
    int? max,
    double? threshold,
  }) {
    if (inspection == null ||
        !_shouldApplyInspectionField(
          inspection,
          key,
          threshold: threshold ?? _inspectionThreshold(key),
        )) {
      return null;
    }
    final raw = inspection[key];
    if (raw == null) return null;
    final match = RegExp(r'\d+').firstMatch(raw.toString());
    if (match == null) return null;
    final parsed = int.tryParse(match.group(0)!);
    if (parsed == null) return null;
    if (min != null && parsed < min) return null;
    if (max != null && parsed > max) return null;
    return parsed;
  }

  String _inspectionText(String key, {required String fallback}) {
    final raw = aiInspection?[key];
    if (raw == null) return fallback;
    final text = raw.toString().trim();
    if (!_usable(text)) return fallback;
    return text;
  }

  Future<void> _save() async {
    // 校验
    if (selectedModel.isEmpty) {
      toast(context, '请选择iPad型号');
      return;
    }
    if (selectedCapacity.isEmpty) {
      toast(context, '请选择容量');
      return;
    }
    if (_costCtrl.text.isEmpty || (double.tryParse(_costCtrl.text) ?? 0) <= 0) {
      toast(context, '请输入采购成本');
      return;
    }

    setState(() => saving = true);
    final now = DateTime.now();
    final cost = (double.tryParse(_costCtrl.text) ?? 0) * 100;
    final channel = isCustomChannel ? _customChannelCtrl.text : selectedChannel;
    final serial = _serialCtrl.text.trim().toUpperCase();

    int batteryHealth = 100;
    int cycleCount = 0;
    if (aiInspection != null) {
      batteryHealth = _intFromInspection(
        'batteryHealth',
        batteryHealth,
        min: 50,
        max: 100,
        threshold: 0.82,
      );
      cycleCount = _intFromInspection(
        'cycleCount',
        cycleCount,
        min: 0,
        max: 3000,
        threshold: 0.82,
      );
    }

    // 序列号解码（如果有）
    final idClean = idCheck != null ? idCheck!['clean'] as bool : true;
    final accessories = _inspectionText('accessories', fallback: '裸机');
    final inspectionForReport = _inspectionForOutput();

    // 商品描述：入库时每次都基于 100 条基础素材重新生成，不复用历史文案。
    String? description;
    try {
      final copyReference = XianyuCopyService.buildReferenceContext(
        gStorage,
        model: selectedModel,
        condition: selectedCondition,
        includeCuratedExamples: false,
        includeSoldDescriptions: false,
        randomizeBuiltIns: true,
      );
      description = await AiService.generateDescription(
        model: selectedModel,
        capacity: selectedCapacity,
        color: selectedColor.isEmpty ? '未知' : selectedColor,
        network: selectedNetwork,
        condition: selectedCondition,
        batteryHealth: batteryHealth,
        cycleCount: cycleCount,
        idLockClean: idClean,
        accessories: accessories,
        defectNote: _manualDefectNote(),
        copywritingReference: copyReference,
      );
      if (description.startsWith('AI调用') || description.startsWith('AI返回')) {
        description = null;
      }
    } catch (_) {
      description = null;
    }

    final d = Device(
      id: 'd${now.millisecondsSinceEpoch}',
      serial: serial.isEmpty ? '未填写' : serial,
      model: selectedModel,
      capacity: selectedCapacity,
      color: selectedColor.isEmpty ? '未知' : selectedColor,
      network: selectedNetwork,
      condition: selectedCondition,
      batteryHealth: batteryHealth,
      cycleCount: cycleCount,
      idLockClean: idClean,
      accessories: accessories,
      purchaseCost: cost.toInt(),
      purchaseChannel: channel,
      purchaseDate: fmtDate(now),
      sellPrice: calcAutoPrice(cost.toInt()),
      status: 'listed',
      imagePath: imagePaths.isNotEmpty ? imagePaths.join(';') : null,
      description: description,
      createdAt: now.toIso8601String(),
    );
    if (imagePaths.isNotEmpty) {
      try {
        final reportPath = await IntakeReportService.createReport(
          device: d,
          docDir: gDocDir,
          imagePaths: imagePaths,
          inspection: inspectionForReport,
        );
        inspectionReportPath = reportPath;
        final allImages = [reportPath, ...imagePaths];
        d.imagePath = allImages.join(';');
        await DeviceExportService.saveImagesToGallery(
          paths: [reportPath],
          albumName: '货脉验货报告',
        );
      } catch (_) {}
    }
    await gStorage.addDevice(d);
    setState(() => saving = false);
    toast(
      context,
      description != null
          ? '✅ 已入库并自动定价${yuan(d.sellPrice)}：${d.model}（AI描述已生成）'
          : '✅ 已入库并自动定价${yuan(d.sellPrice)}：${d.model}',
    );
    Navigator.pop(context);
  }

  void _handleStepContinue() {
    if (currentStep == 0 && imagePaths.isEmpty) {
      toast(context, '请先上传至少1张验机图片');
      return;
    }
    if (currentStep < 2) setState(() => currentStep++);
  }

  @override
  Widget build(BuildContext context) => appScaffold(
    context,
    'AI入库',
    Stepper(
      type: StepperType.vertical,
      currentStep: currentStep,
      onStepContinue: _handleStepContinue,
      onStepCancel: () {
        if (currentStep > 0) setState(() => currentStep--);
      },
      controlsBuilder:
          (context, details) => Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                if (currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: details.onStepCancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: C.t2,
                        side: const BorderSide(color: C.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                      child: const Text('上一步', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                if (currentStep > 0) const SizedBox(width: 10),
                if (currentStep < 2)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: details.onStepContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: C.t3,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                      child: Text(
                        currentStep == 0 ? '下一步：复核信息' : '下一步：成本入库',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      steps: [_uploadImagesStep(), _reviewStep(), _finishStep()],
    ),
  );

  Text _stepTitle(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w800,
      color: C.t1,
    ),
  );

  Step _uploadImagesStep() => Step(
    title: _stepTitle('上传验机图片'),
    subtitle: const Text(
      '上传图片，并手动记录外观',
      style: TextStyle(color: C.t3, fontSize: 11),
    ),
    state: currentStep > 0 ? StepState.complete : StepState.indexed,
    isActive: currentStep >= 0,
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _imageChecklistCard(),
        const SizedBox(height: 8),
        _devicePhotosCard(),
        const SizedBox(height: 8),
        _manualAppearanceCard(),
        const SizedBox(height: 8),
        _aiInspectionActionCard(),
      ],
    ),
  );

  Step _reviewStep() => Step(
    title: _stepTitle('AI补全与复核'),
    subtitle: const Text(
      '型号、容量、颜色等可信字段自动填',
      style: TextStyle(color: C.t3, fontSize: 11),
    ),
    state: currentStep > 1 ? StepState.complete : StepState.indexed,
    isActive: currentStep >= 1,
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (aiInspection != null) ...[
          _inspectionSummary(),
          const SizedBox(height: 8),
        ] else ...[
          _manualEntryHintCard(),
          const SizedBox(height: 8),
        ],
        _identityReviewCard(),
        const SizedBox(height: 8),
        _conditionReviewCard(),
        const SizedBox(height: 8),
        _idLockReviewCard(),
      ],
    ),
  );

  Step _finishStep() => Step(
    title: _stepTitle('成本与确认'),
    subtitle: const Text(
      '补业务信息后入库',
      style: TextStyle(color: C.t3, fontSize: 11),
    ),
    state: currentStep == 2 ? StepState.indexed : StepState.disabled,
    isActive: currentStep >= 2,
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _purchaseInfoCard(),
        const SizedBox(height: 8),
        _finalConfirmCard(),
      ],
    ),
  );

  Widget _imageChecklistCard() => GlassPanel(
    padding: const EdgeInsets.all(14),
    radius: 14,
    color: C.bgCardMuted,
    borderColor: C.border,
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.fact_check_outlined, color: C.cyan, size: 20),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            '建议一次上传：关于本机、电池信息、正面亮屏、背面、四边、接口、四角和瑕疵近照。AI只补充序列号、型号、容量、颜色、电池等信息；外观问题按下方手动勾选写入报告。',
            style: TextStyle(
              color: C.t2,
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _devicePhotosCard() => CardBox(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '验机实拍',
              style: TextStyle(
                fontSize: 12,
                color: C.t2,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Text(
              '${imagePaths.length}/12张',
              style: const TextStyle(fontSize: 11, color: C.t3),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (imagePaths.isNotEmpty)
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: imagePaths.length + (imagePaths.length < 12 ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                if (i == imagePaths.length) {
                  return GestureDetector(
                    onTap: () => _addImage(false),
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: C.bgDeep,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: C.border),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.add_photo_alternate,
                          color: C.t3,
                          size: 24,
                        ),
                      ),
                    ),
                  );
                }
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Image.file(
                        File(imagePaths[i]),
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _removeImage(i),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: C.t2,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: C.t2,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '#${i + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          )
        else
          Container(
            height: 96,
            width: double.infinity,
            decoration: BoxDecoration(
              color: C.bgDeep,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: C.border),
            ),
            child: const Center(
              child: Text(
                '还没有上传验机图片',
                style: TextStyle(color: C.t3, fontSize: 12),
              ),
            ),
          ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _addMultipleImages,
                style: ElevatedButton.styleFrom(
                  backgroundColor: C.bgCard,
                  foregroundColor: C.t1,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '相册多选',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: () => _addImage(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: C.t3,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '拍照',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _manualAppearanceCard() => CardBox(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.rule_rounded, color: C.orange, size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                '外观问题（手动勾选）',
                style: TextStyle(
                  color: C.t1,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              selectedManualIssueIds.isEmpty
                  ? '未记录'
                  : '${selectedManualIssueIds.length}项',
              style: const TextStyle(
                color: C.t3,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        const Text(
          '未勾选会按“无明显外观/屏幕问题”写入验货报告；有问题就直接点选，位置不在列表里可写补充。',
          style: TextStyle(
            color: C.t3,
            fontSize: 11,
            height: 1.4,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        _manualIssueGroup('屏幕显示'),
        const SizedBox(height: 10),
        _manualIssueGroup('边框四角'),
        const SizedBox(height: 10),
        _manualIssueGroup('后盖/镜头/接口'),
        const SizedBox(height: 12),
        AppFormField(
          controller: _appearanceNoteCtrl,
          label: '其他问题补充（可选）',
          hint: '例如：右侧中框两处磕碰、屏幕左下轻微划痕',
          icon: Icons.edit_note_rounded,
          maxLines: 2,
          onChanged: (_) => setState(() => inspectionReportPath = null),
        ),
      ],
    ),
  );

  Widget _manualIssueGroup(String group) {
    final options =
        _manualIssueOptions.where((issue) => issue.group == group).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          group,
          style: const TextStyle(
            color: C.t2,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: options.map(_manualIssuePill).toList(),
        ),
      ],
    );
  }

  Widget _manualIssuePill(_ManualIssueOption issue) => AppChoicePill(
    label: issue.label,
    selected: selectedManualIssueIds.contains(issue.id),
    color: issue.isScreen ? C.orange : C.cyan,
    onTap: () => _toggleManualIssue(issue.id),
  );

  Widget _aiInspectionActionCard() => CardBox(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: C.purple, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'AI入库识别',
                style: TextStyle(
                  color: C.t1,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          imagePaths.isEmpty
              ? '上传图片后，AI会识别序列号、型号、容量、颜色、电池信息和可见锁机风险。'
              : '已准备 ${imagePaths.length} 张图片，可以让AI补全设备信息。',
          style: const TextStyle(color: C.t3, fontSize: 11, height: 1.4),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed:
                imagePaths.isEmpty || aiInspecting
                    ? null
                    : _runFullAiInspection,
            icon:
                aiInspecting
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                    : const Icon(Icons.auto_awesome_rounded),
            style: FilledButton.styleFrom(
              backgroundColor: imagePaths.isEmpty ? C.bgElevated : C.purple,
              foregroundColor: imagePaths.isEmpty ? C.t3 : Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            label: Text(
              imagePaths.isEmpty
                  ? '请先上传验机图片'
                  : aiInspecting
                  ? 'AI识别中'
                  : '开始AI补全信息',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _manualEntryHintCard() => GlassPanel(
    padding: const EdgeInsets.all(12),
    radius: 12,
    color: C.bgCardMuted,
    borderColor: C.border,
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, color: C.orange, size: 18),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            '还没有AI补全结果。你可以返回上传图片识别；外观问题已按上一页手动勾选记录。',
            style: TextStyle(
              color: C.t2,
              fontSize: 11,
              height: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _identityReviewCard() => CardBox(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '设备信息复核',
          style: TextStyle(
            fontSize: 12,
            color: C.t2,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        AppFormField(
          controller: _serialCtrl,
          label: '序列号',
          hint: '从上传图片自动识别，可手动修正',
          icon: Icons.confirmation_number_outlined,
        ),
        const SizedBox(height: 12),
        AppDropdownField<String>(
          value: selectedModel.isEmpty ? null : selectedModel,
          hint: '选择iPad型号',
          options: _optionsWithCurrent(
            iPadModels.map((m) => m['name']!).toList(),
            selectedModel,
          ),
          labelBuilder: (value) => value,
          onChanged: (v) => setState(() => selectedModel = v ?? ''),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: AppDropdownField<String>(
                value: selectedCapacity.isEmpty ? null : selectedCapacity,
                hint: '容量',
                options: _optionsWithCurrent(iPadCapacities, selectedCapacity),
                labelBuilder: (value) => value,
                fontSize: 12,
                onChanged: (v) => setState(() => selectedCapacity = v ?? ''),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppDropdownField<String>(
                value: selectedColor.isEmpty ? null : selectedColor,
                hint: '颜色',
                options: _optionsWithCurrent(iPadColors, selectedColor),
                labelBuilder: (value) => value,
                fontSize: 12,
                onChanged: (v) => setState(() => selectedColor = v ?? ''),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppDropdownField<String>(
                value: selectedNetwork,
                hint: '网络',
                options: _optionsWithCurrent(iPadNetworks, selectedNetwork),
                labelBuilder: (value) => value,
                fontSize: 12,
                onChanged: (v) => setState(() => selectedNetwork = v ?? ''),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _conditionReviewCard() => CardBox(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '成色复核',
          style: TextStyle(
            fontSize: 12,
            color: C.t2,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        AppDropdownField<String>(
          value: selectedCondition.isEmpty ? null : selectedCondition,
          hint: '选择成色',
          options: _optionsWithCurrent(iPadConditions, selectedCondition),
          labelBuilder: (value) => value,
          onChanged: (v) => setState(() => selectedCondition = v ?? ''),
        ),
      ],
    ),
  );

  Widget _idLockReviewCard() => CardBox(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ID锁安全检测',
          style: TextStyle(
            fontSize: 12,
            color: C.t2,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          children: [
            _lockCheck(
              'iCloud锁',
              iCloudLock,
              (v) => setState(() => iCloudLock = v),
            ),
            _lockCheck('激活锁', actLock, (v) => setState(() => actLock = v)),
            _lockCheck('MDM监管', mdm, (v) => setState(() => mdm = v)),
            _lockCheck(
              '配置锁',
              configLock,
              (v) => setState(() => configLock = v),
            ),
          ],
        ),
        const SizedBox(height: 8),
        primaryBtn('检测ID锁', _checkIdLock),
        if (idCheck != null && !(idCheck!['clean'] as bool))
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: C.red.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: C.red.withValues(alpha: 0.40)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: C.neonRed,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${idCheck!["risk"]}：${(idCheck!["issues"] as List).join("、")}',
                    style: const TextStyle(fontSize: 12, color: C.neonRed),
                  ),
                ),
              ],
            ),
          ),
        if (idCheck != null && idCheck!['clean'] as bool)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: C.green.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: C.green.withValues(alpha: 0.40)),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_outline, size: 18, color: C.green),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ID锁检测通过：无iCloud锁、无激活锁、非监管机',
                    style: TextStyle(fontSize: 12, color: C.neonGreen),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _purchaseInfoCard() => CardBox(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '采购信息',
          style: TextStyle(
            fontSize: 12,
            color: C.t2,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        AppFormField(
          controller: _costCtrl,
          keyboardType: TextInputType.number,
          label: '采购成本(元)',
          icon: Icons.payments_outlined,
        ),
        const SizedBox(height: 10),
        AppDropdownField<String>(
          value: isCustomChannel ? '自定义' : selectedChannel,
          hint: '选择采购渠道',
          options: const [...PurchaseChannels, '自定义'],
          labelBuilder: (value) => value,
          onChanged:
              (v) => setState(() {
                if (v == '自定义') {
                  isCustomChannel = true;
                } else {
                  selectedChannel = v ?? selectedChannel;
                  isCustomChannel = false;
                }
              }),
        ),
        if (isCustomChannel)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: AppFormField(
              controller: _customChannelCtrl,
              label: '输入渠道名称',
              icon: Icons.storefront_outlined,
            ),
          ),
      ],
    ),
  );

  Widget _finalConfirmCard() => CardBox(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '入库确认',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: C.t1,
          ),
        ),
        const SizedBox(height: 12),
        if (selectedModel.isNotEmpty) _kv('型号', selectedModel),
        if (selectedCapacity.isNotEmpty)
          _kv('容量/颜色/网络', '$selectedCapacity $selectedColor $selectedNetwork'),
        if (_serialCtrl.text.isNotEmpty) _kv('序列号', _serialCtrl.text),
        _kv('成色', selectedCondition),
        _kv('采购成本', _costCtrl.text.isEmpty ? '未填写' : '${_costCtrl.text}元'),
        _kv(
          '采购渠道',
          isCustomChannel ? _customChannelCtrl.text : selectedChannel,
        ),
        if (idCheck != null)
          _kv('ID锁', idCheck!['clean'] as bool ? '安全' : '${idCheck!["risk"]}'),
        _kv('验机图片', '${imagePaths.length}张'),
        _kv('外观记录', _manualDefectSummary(maxItems: 3)),
        _kv(
          '验货报告',
          imagePaths.isEmpty
              ? '未上传图片'
              : aiInspection == null
              ? '将按人工外观记录生成报告'
              : '将生成AI信息+人工外观报告',
        ),
        const SizedBox(height: 14),
        saving
            ? const Center(child: CircularProgressIndicator(color: C.t3))
            : primaryBtn('确认入库', _save),
      ],
    ),
  );

  Widget _lockCheck(String label, bool val, ValueChanged<bool> onChanged) =>
      Padding(
        padding: EdgeInsets.only(right: 8, bottom: 6),
        child: AppChoicePill(
          label: label,
          selected: val,
          color: C.red,
          onTap: () => onChanged(!val),
        ),
      );

  Widget _inspectionSummary() {
    final data = aiInspection ?? {};
    final confidence = _inspectionConfidence(data);
    final warnings = data['warnings'];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: C.purple.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.purple.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fact_check_outlined, color: C.purple, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'AI设备信息已补全',
                  style: TextStyle(
                    color: C.t1,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (confidence > 0)
                Text(
                  '${(confidence.clamp(0, 1) * 100).round()}%',
                  style: const TextStyle(
                    color: C.purple,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _inspectionLine('功能', data['functionSummary']),
          _inspectionLine('外观记录', _manualDefectSummary(maxItems: 6)),
          if (confidence > 0 && confidence < 0.72) ...[
            const SizedBox(height: 6),
            const Text(
              '图片信息不足，关键字段已保守处理，请人工复核后再入库。',
              style: TextStyle(
                color: C.orange,
                fontSize: 11,
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (warnings is List && warnings.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'AI提醒：${warnings.take(3).join('、')}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: C.orange,
                fontSize: 11,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 6),
          const Text(
            '确认入库后会自动生成验货报告图并保存到相册；外观结论以人工勾选为准。',
            style: TextStyle(color: C.t3, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _inspectionLine(String label, dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text == '未知') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '$label：$text',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: C.t2,
          fontSize: 11,
          height: 1.35,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
    padding: EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(k, style: TextStyle(fontSize: 12, color: C.t2)),
        ),
        Expanded(
          child: Text(
            v,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: C.t1,
            ),
          ),
        ),
      ],
    ),
  );
}
