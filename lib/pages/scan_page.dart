import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
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
import '../services/intake_ai_result_normalizer.dart';
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

class _AiCropSpec {
  final double left;
  final double top;
  final double width;
  final double height;

  const _AiCropSpec({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
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
  final _batteryCtrl = TextEditingController();
  final _cycleCtrl = TextEditingController();
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
  static const int _orderedInspectionImageLimit = 3;
  static const double _pickedImageMaxDimension = 1280;
  static const int _pickedImageQuality = 76;
  static const int _aiCropTargetWidth = 980;
  static const int _aiFastCropTargetWidth = 720;
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
    _batteryCtrl.dispose();
    _cycleCtrl.dispose();
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

  /// 添加实拍图（入库保存压缩副本，降低 AI 识别上传体积）
  Future<void> _addImage(bool fromCamera) async {
    if (imagePaths.length >= 12) {
      toast(context, '最多上传12张图片');
      return;
    }
    try {
      final picker = ImagePicker();
      final x = await picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: _pickedImageMaxDimension,
        maxHeight: _pickedImageMaxDimension,
        imageQuality: _pickedImageQuality,
      );
      if (x != null) {
        final now = DateTime.now();
        final dest =
            '$gDocDir/dev_${now.millisecondsSinceEpoch}_${imagePaths.length}.jpg';
        // image_picker 已按上面的尺寸和质量参数生成压缩副本。
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
        maxWidth: _pickedImageMaxDimension,
        maxHeight: _pickedImageMaxDimension,
        imageQuality: _pickedImageQuality,
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

  Future<String> _croppedImageDataUriForAi(
    String path,
    _AiCropSpec spec, {
    int targetWidth = _aiCropTargetWidth,
  }) async {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      final left = (image.width * spec.left).clamp(0.0, image.width - 1.0);
      final top = (image.height * spec.top).clamp(0.0, image.height - 1.0);
      final cropWidth = (image.width * spec.width).clamp(
        1.0,
        image.width - left,
      );
      final cropHeight = (image.height * spec.height).clamp(
        1.0,
        image.height - top,
      );
      final src = Rect.fromLTWH(left, top, cropWidth, cropHeight);

      final scale = cropWidth > targetWidth ? targetWidth / cropWidth : 1.0;
      final outWidth = math.max(1, (cropWidth * scale).round());
      final outHeight = math.max(1, (cropHeight * scale).round());
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint()..filterQuality = FilterQuality.medium;
      canvas.drawImageRect(
        image,
        src,
        Rect.fromLTWH(0, 0, outWidth.toDouble(), outHeight.toDouble()),
        paint,
      );
      final picture = recorder.endRecording();
      final cropped = await picture.toImage(outWidth, outHeight);
      picture.dispose();
      final data = await cropped.toByteData(format: ui.ImageByteFormat.png);
      cropped.dispose();
      if (data == null) return _imageDataUriForAi(path);
      return 'data:image/png;base64,${base64Encode(data.buffer.asUint8List())}';
    } finally {
      image.dispose();
    }
  }

  Future<Map<String, dynamic>> _withBackColorFallback(
    Map<String, dynamic> result,
  ) async {
    if (imagePaths.isEmpty ||
        _matchOption(
          (result['color'] ?? '').toString(),
          iPadColors,
        ).isNotEmpty) {
      return result;
    }
    final color = await _estimateBackColor(imagePaths.first);
    if (color.isEmpty) return result;
    final merged = Map<String, dynamic>.from(result);
    merged['color'] = color;
    _raiseInspectionConfidence(merged, 'color', 0.82);
    return merged;
  }

  Future<String> _estimateBackColor(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 480);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (data == null) return '';
        final rgb = _averageBackColorRgb(
          data.buffer.asUint8List(),
          image.width,
          image.height,
        );
        if (rgb == null) return '';
        return _classifyBackColor(rgb);
      } finally {
        image.dispose();
      }
    } catch (_) {
      return '';
    }
  }

  List<double>? _averageBackColorRgb(Uint8List bytes, int width, int height) {
    const specs = [
      _AiCropSpec(left: 0.26, top: 0.32, width: 0.20, height: 0.18),
      _AiCropSpec(left: 0.56, top: 0.54, width: 0.22, height: 0.20),
    ];
    var rSum = 0.0;
    var gSum = 0.0;
    var bSum = 0.0;
    var count = 0;
    for (final spec in specs) {
      final left = math.max(0, (width * spec.left).round());
      final top = math.max(0, (height * spec.top).round());
      final right = math.min(width, (width * (spec.left + spec.width)).round());
      final bottom = math.min(
        height,
        (height * (spec.top + spec.height)).round(),
      );
      for (var y = top; y < bottom; y += 2) {
        for (var x = left; x < right; x += 2) {
          final index = (y * width + x) * 4;
          if (index + 2 >= bytes.length) continue;
          final r = bytes[index];
          final g = bytes[index + 1];
          final b = bytes[index + 2];
          if (_skipBackColorPixel(r, g, b)) continue;
          rSum += r;
          gSum += g;
          bSum += b;
          count++;
        }
      }
    }
    if (count < 40) return null;
    return [rSum / count, gSum / count, bSum / count];
  }

  bool _skipBackColorPixel(int r, int g, int b) {
    final maxChannel = math.max(r, math.max(g, b));
    final minChannel = math.min(r, math.min(g, b));
    final value = maxChannel / 255.0;
    final saturation =
        maxChannel == 0 ? 0.0 : (maxChannel - minChannel) / maxChannel;
    final isRedMarkup =
        r > 140 && g < 120 && b < 120 && r - g > 40 && r - b > 40;
    return isRedMarkup || value < 0.25 || (value > 0.94 && saturation < 0.08);
  }

  String _classifyBackColor(List<double> rgb) {
    final r = rgb[0];
    final g = rgb[1];
    final b = rgb[2];
    final maxChannel = math.max(r, math.max(g, b));
    final minChannel = math.min(r, math.min(g, b));
    final value = maxChannel / 255.0;
    final saturation =
        maxChannel == 0 ? 0.0 : (maxChannel - minChannel) / maxChannel;
    final hue = _rgbHue(r, g, b);

    if (saturation < 0.11) return value < 0.45 ? '深空灰' : '银色';
    if (hue >= 190 && hue <= 250) return '蓝色';
    if (hue >= 250 && hue <= 310) return '紫色';
    if (hue >= 85 && hue <= 165) return '绿色';
    if (hue >= 40 && hue <= 85) {
      if (value > 0.72 && saturation < 0.22) return '星光色';
      return saturation > 0.28 ? '黄色' : '金色';
    }
    if (hue >= 330 || hue <= 20) {
      return saturation < 0.22 ? '玫瑰金' : '粉色';
    }
    if (hue > 20 && hue < 40) return '玫瑰金';
    return '';
  }

  double _rgbHue(double r, double g, double b) {
    final maxChannel = math.max(r, math.max(g, b));
    final minChannel = math.min(r, math.min(g, b));
    final delta = maxChannel - minChannel;
    if (delta == 0) return 0;
    double hue;
    if (maxChannel == r) {
      hue = 60 * (((g - b) / delta) % 6);
    } else if (maxChannel == g) {
      hue = 60 * (((b - r) / delta) + 2);
    } else {
      hue = 60 * (((r - g) / delta) + 4);
    }
    return hue < 0 ? hue + 360 : hue;
  }

  void _raiseInspectionConfidence(
    Map<String, dynamic> result,
    String key,
    double value,
  ) {
    final raw = result['fieldConfidence'];
    final fields =
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final current = _readConfidence(fields[key]) ?? 0;
    if (value > current) fields[key] = value;
    result['fieldConfidence'] = fields;
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
    if (imagePaths.length < _orderedInspectionImageLimit) {
      toast(context, '请按顺序上传3张关键图：背面、关于本机、爱思/沙漏报告');
      return;
    }
    if (aiInspecting) return;
    setState(() => aiInspecting = true);
    try {
      final recognizedPaths = <String>{};
      var result = <String, dynamic>{};
      var hasAiResult = false;

      final primaryPaths =
          imagePaths.take(_orderedInspectionImageLimit).toList();
      if (primaryPaths.isNotEmpty) {
        final primaryImages = await _encodeOrderedInspectionImages(
          primaryPaths,
        );
        final primary = await AiService.recognizeIpadIntake(
          primaryImages,
          croppedRegions: true,
          totalImageCount: imagePaths.length,
        );
        recognizedPaths.addAll(primaryPaths);
        if (primary['error'] == null) {
          hasAiResult = true;
          result = _normalizeInspectionResult(primary);
        } else {
          result = _withInspectionWarning(
            result,
            '图1-3主识别失败：${primary['error']}',
          );
        }
      }

      if (!hasAiResult) {
        if (!mounted) return;
        final warning = _inspectionWarnings(result['warnings']).join('；');
        toast(context, warning.isEmpty ? 'AI识别失败，请换一张清晰图片再试' : warning);
        return;
      }
      result['recognitionStrategy'] =
          '三张关键图识别：图1取背面颜色点，图2取关于本机区域，图3取爱思底部区域；第4张以后不上传AI';
      result['recognizedImageCount'] = recognizedPaths.length;
      result = _normalizeInspectionResult(result);
      result = await _withBackColorFallback(result);
      if (!mounted) return;
      final appliedCount = _applyInspection(result);
      setState(() {
        aiInspection = result;
        inspectionReportPath = null;
      });
      final missing = _missingReviewFields();
      toast(
        context,
        missing.isEmpty
            ? '三张关键图已补全可信设备信息，请复核后入库'
            : appliedCount > 0
            ? 'AI已读取，仍需补：${missing.join('、')}'
            : 'AI未读到关键字段，请按顺序重拍或手动补全',
      );
    } catch (e) {
      if (mounted) toast(context, 'AI整机识别失败：$e');
    } finally {
      if (mounted) setState(() => aiInspecting = false);
    }
  }

  Future<List<String>> _encodeOrderedInspectionImages(
    List<String> paths,
  ) async {
    final encoded = <String>[];
    for (var i = 0; i < paths.length; i++) {
      final path = paths[i];
      final specs = switch (i) {
        0 => const [
          // 图1：背面颜色采样点，避开右上贴纸文字。
          _AiCropSpec(left: 0.26, top: 0.32, width: 0.20, height: 0.18),
          _AiCropSpec(left: 0.56, top: 0.54, width: 0.22, height: 0.20),
        ],
        1 => const [
          // 图2：关于本机右侧信息区域。
          _AiCropSpec(left: 0.43, top: 0.14, width: 0.50, height: 0.48),
        ],
        _ => const [
          // 图3：爱思报告中下方电池/锁/匹配信息区域。
          _AiCropSpec(left: 0.18, top: 0.64, width: 0.64, height: 0.28),
        ],
      };
      for (final spec in specs) {
        try {
          encoded.add(
            await _croppedImageDataUriForAi(
              path,
              spec,
              targetWidth: _aiFastCropTargetWidth,
            ),
          );
        } catch (_) {
          encoded.add(await _imageDataUriForAi(path));
        }
      }
    }
    return encoded;
  }

  Map<String, dynamic> _normalizeInspectionResult(Map<String, dynamic> result) {
    return IntakeAiResultNormalizer.normalize(
      result,
      modelOptions: iPadModels.map((m) => m['name']!).toList(),
      capacityOptions: iPadCapacities,
    );
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

    final batteryHealth = _intFromResult(
      result,
      'batteryHealth',
      min: 50,
      max: 100,
      threshold: 0.82,
    );
    if (batteryHealth != null &&
        _shouldReplaceNumericController(
          _batteryCtrl,
          batteryHealth,
          'batteryHealth',
          min: 50,
          max: 100,
        )) {
      _batteryCtrl.text = batteryHealth.toString();
      applied++;
    }

    final cycleCount = _intFromResult(
      result,
      'cycleCount',
      min: 0,
      max: 3000,
      threshold: 0.82,
    );
    if (cycleCount != null &&
        _shouldReplaceNumericController(
          _cycleCtrl,
          cycleCount,
          'cycleCount',
          min: 0,
          max: 3000,
        )) {
      _cycleCtrl.text = cycleCount.toString();
      applied++;
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
      if (key == 'batteryHealth') ...[
        'batteryHealthRaw',
        'inspectionEvidenceText',
      ],
      if (key == 'cycleCount') ...['cycleCountRaw', 'inspectionEvidenceText'],
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
    if (key == 'model' &&
        _matchModel(_modelSourceEvidence(result)).isNotEmpty) {
      best = math.max(best, 0.9);
    }
    return best > 0 ? best : _inspectionConfidence(result);
  }

  bool _shouldApplyInspectionField(
    Map<String, dynamic> result,
    String key, {
    double threshold = 0.78,
  }) => _fieldConfidence(result, key) >= threshold;

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
    if (options.contains('银色') &&
        (normalized.contains('银') || normalized.contains('silver'))) {
      return '银色';
    }
    if (options.contains('深空灰') &&
        (normalized.contains('深空') ||
            normalized.contains('太空灰') ||
            normalized.contains('spacegray') ||
            normalized.contains('spacegrey'))) {
      return '深空灰';
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

  bool _shouldReplaceNumericController(
    TextEditingController controller,
    int nextValue,
    String inspectionKey, {
    int? min,
    int? max,
  }) {
    final text = controller.text.trim();
    if (text.isEmpty) return true;
    final current = _nullableBoundedInt(text, min: min, max: max);
    if (current == null) return true;
    if (!RegExp(r'^\d+$').hasMatch(text)) return true;

    final previous = _intFromResult(
      aiInspection,
      inspectionKey,
      min: min,
      max: max,
    );
    return previous != null && current == previous && current != nextValue;
  }

  String _inspectionText(String key, {required String fallback}) {
    final raw = aiInspection?[key];
    if (raw == null) return fallback;
    final text = raw.toString().trim();
    if (!_usable(text)) return fallback;
    return text;
  }

  int? _nullableBoundedInt(String raw, {int? min, int? max}) {
    final match = RegExp(r'\d+').firstMatch(raw);
    if (match == null) return null;
    final value = int.tryParse(match.group(0)!);
    if (value == null) return null;
    if (min != null && value < min) return null;
    if (max != null && value > max) return null;
    return value;
  }

  List<String> _missingReviewFields() {
    final missing = <String>[];
    if (_serialCtrl.text.trim().isEmpty) missing.add('序列号');
    if (selectedModel.trim().isEmpty) missing.add('型号');
    if (selectedCapacity.trim().isEmpty) missing.add('容量');
    if (selectedColor.trim().isEmpty) missing.add('颜色');
    if (selectedNetwork.trim().isEmpty) missing.add('网络');
    if (_nullableBoundedInt(_batteryCtrl.text, min: 50, max: 100) == null) {
      missing.add('电池健康');
    }
    if (_nullableBoundedInt(_cycleCtrl.text, min: 0, max: 3000) == null) {
      missing.add('充电次数');
    }
    return missing;
  }

  String _reviewDeviceSummary() {
    final parts = <String>[
      if (selectedModel.trim().isNotEmpty) selectedModel.trim(),
      if (selectedCapacity.trim().isNotEmpty) selectedCapacity.trim(),
      if (selectedColor.trim().isNotEmpty) selectedColor.trim(),
      if (selectedNetwork.trim().isNotEmpty) selectedNetwork.trim(),
    ];
    return parts.join(' ');
  }

  String _batteryReviewText() {
    final value =
        _nullableBoundedInt(_batteryCtrl.text, min: 50, max: 100) ??
        _intFromResult(aiInspection, 'batteryHealth', min: 50, max: 100);
    return value == null ? '未识别' : '$value%';
  }

  String _cycleReviewText() {
    final value =
        _nullableBoundedInt(_cycleCtrl.text, min: 0, max: 3000) ??
        _intFromResult(aiInspection, 'cycleCount', min: 0, max: 3000);
    return value == null ? '未识别' : '$value次';
  }

  String _batteryCycleSummary() {
    final battery = _batteryReviewText();
    final cycle = _cycleReviewText();
    if (battery == '未识别' && cycle == '未识别') return '';
    return '$battery / $cycle';
  }

  Future<void> _save() async {
    // 校验
    final missing = _missingReviewFields();
    if (missing.isNotEmpty) {
      setState(() => currentStep = 1);
      toast(context, '请先补全：${missing.join('、')}');
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
    final batteryHealth =
        _nullableBoundedInt(_batteryCtrl.text, min: 50, max: 100)!;
    final cycleCount = _nullableBoundedInt(_cycleCtrl.text, min: 0, max: 3000)!;

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
    if (currentStep == 0) {
      if (imagePaths.length < _orderedInspectionImageLimit) {
        toast(context, '请按顺序上传3张关键图：背面、关于本机、爱思/沙漏报告');
        return;
      }
    }
    if (currentStep == 1) {
      final missing = _missingReviewFields();
      if (missing.isNotEmpty) {
        toast(context, '请先补全：${missing.join('、')}');
        return;
      }
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
            '请按顺序上传：第1张背面颜色图、第2张关于本机、第3张爱思/沙漏报告。AI只识别前三张的指定区域；后续外观、屏幕、边框和瑕疵图仅供人工复核。',
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
              ? '按顺序上传：1背面颜色图、2关于本机、3爱思报告；AI只看前三张关键区域。'
              : '已准备 ${imagePaths.length} 张图片，AI只上传前三张裁剪区域；第4张以后留给人工复核。',
          style: const TextStyle(color: C.t3, fontSize: 11, height: 1.4),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed:
                imagePaths.length < _orderedInspectionImageLimit || aiInspecting
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
                    : const Icon(Icons.filter_3_rounded),
            style: FilledButton.styleFrom(
              backgroundColor:
                  imagePaths.length < _orderedInspectionImageLimit
                      ? C.bgElevated
                      : C.purple,
              foregroundColor:
                  imagePaths.length < _orderedInspectionImageLimit
                      ? C.t3
                      : Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            label: Text(
              imagePaths.length < _orderedInspectionImageLimit
                  ? '请先上传3张关键图'
                  : aiInspecting
                  ? 'AI识别中'
                  : '识别前三张关键图',
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

  Widget _reviewFieldGrid(
    List<Widget> children, {
    required int maxColumns,
    required double minItemWidth,
  }) => LayoutBuilder(
    builder: (context, constraints) {
      const spacing = 8.0;
      final width = constraints.maxWidth;
      if (!constraints.hasBoundedWidth || width <= minItemWidth) {
        return Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: spacing),
              children[i],
            ],
          ],
        );
      }
      final columns = math.max(
        1,
        math.min(
          maxColumns,
          ((width + spacing) / (minItemWidth + spacing)).floor(),
        ),
      );
      final itemWidth = (width - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final child in children)
            SizedBox(width: itemWidth, child: child),
        ],
      );
    },
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
        _reviewFieldGrid(
          [
            AppDropdownField<String>(
              value: selectedCapacity.isEmpty ? null : selectedCapacity,
              hint: '容量',
              options: _optionsWithCurrent(iPadCapacities, selectedCapacity),
              labelBuilder: (value) => value,
              fontSize: 12,
              onChanged: (v) => setState(() => selectedCapacity = v ?? ''),
            ),
            AppDropdownField<String>(
              value: selectedColor.isEmpty ? null : selectedColor,
              hint: '颜色',
              options: _optionsWithCurrent(iPadColors, selectedColor),
              labelBuilder: (value) => value,
              fontSize: 12,
              onChanged: (v) => setState(() => selectedColor = v ?? ''),
            ),
            AppDropdownField<String>(
              value: selectedNetwork,
              hint: '网络',
              options: _optionsWithCurrent(iPadNetworks, selectedNetwork),
              labelBuilder: (value) => value,
              fontSize: 12,
              onChanged: (v) => setState(() => selectedNetwork = v ?? ''),
            ),
          ],
          maxColumns: 3,
          minItemWidth: 124,
        ),
        const SizedBox(height: 10),
        _reviewFieldGrid(
          [
            AppFormField(
              controller: _batteryCtrl,
              keyboardType: TextInputType.number,
              label: '电池健康(%)',
              hint: '如 93',
              icon: Icons.battery_5_bar_rounded,
              onChanged: (_) => setState(() => inspectionReportPath = null),
            ),
            AppFormField(
              controller: _cycleCtrl,
              keyboardType: TextInputType.number,
              label: '充电次数',
              hint: '如 676',
              icon: Icons.battery_charging_full_rounded,
              onChanged: (_) => setState(() => inspectionReportPath = null),
            ),
          ],
          maxColumns: 2,
          minItemWidth: 176,
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
        _kv('电池/循环', '${_batteryReviewText()} / ${_cycleReviewText()}'),
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
    final missing = _missingReviewFields();
    final isComplete = missing.isEmpty;
    final statusColor = isComplete ? C.purple : C.orange;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isComplete
                    ? Icons.fact_check_outlined
                    : Icons.assignment_late_outlined,
                color: statusColor,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isComplete ? 'AI设备信息已补全' : 'AI已识别，仍需补全',
                  style: const TextStyle(
                    color: C.t1,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (confidence > 0)
                Text(
                  '${(confidence.clamp(0, 1) * 100).round()}%',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (!isComplete) _inspectionLine('待补', missing.join('、')),
          _inspectionLine('序列号', _serialCtrl.text.trim().toUpperCase()),
          _inspectionLine('设备', _reviewDeviceSummary()),
          _inspectionLine('电池/循环', _batteryCycleSummary()),
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
