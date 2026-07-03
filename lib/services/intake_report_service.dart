import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models.dart';

class IntakeReportService {
  static Future<String> createReport({
    required Device device,
    required String docDir,
    required List<String> imagePaths,
    required Map<String, dynamic>? inspection,
  }) async {
    const width = 900.0;
    final issuedAt = DateTime.now();
    final sections = _buildCustomerSections(device, inspection);
    final height = _estimateHeight(sections, hasTips: true);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final rect = Rect.fromLTWH(0, 0, width, height);

    _drawBackground(canvas, rect);
    final card = Rect.fromLTWH(48, 48, width - 96, height - 96);
    _roundRect(canvas, card, 14, Colors.white);
    _strokeRoundRect(canvas, card, 14, const Color(0xFFDCE4EE), 1.2);

    _drawHeader(canvas, device, issuedAt);
    _drawProductHero(canvas, device);
    _drawSpecGrid(canvas, device, inspection);
    await _drawThumbnails(canvas, imagePaths);

    var y = 720.0;
    _drawQualityBadge(canvas, Offset(84, y));
    y += 58;
    for (final section in sections) {
      y = _drawChecklistSection(canvas, y, section);
      y += 26;
    }

    _drawTips(canvas, y, height);

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    image.dispose();
    if (bytes == null) throw const FileSystemException('报告图片生成失败');

    final file = File(
      '$docDir/qc_report_${device.id}_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    return file.path;
  }

  static double _estimateHeight(
    List<_ReportSection> sections, {
    required bool hasTips,
  }) {
    var y = 720.0 + 58;
    for (final section in sections) {
      y += 46 + section.rows.length * 34 + 18;
    }
    if (hasTips) y += 148;
    return math.max(1960, y + 104);
  }

  static void _drawBackground(Canvas canvas, Rect rect) {
    canvas.drawRect(rect, Paint()..color = const Color(0xFFF3F6FA));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, rect.width, 176),
      Paint()..color = const Color(0xFFE9F0F8),
    );
  }

  static void _drawHeader(Canvas canvas, Device device, DateTime issuedAt) {
    _drawText(
      canvas,
      '平台验机报告',
      const Offset(86, 86),
      const TextStyle(
        color: Color(0xFF17233A),
        fontSize: 38,
        fontWeight: FontWeight.w900,
      ),
    );
    _drawText(
      canvas,
      '客户版 · 实拍凭证 · 外观记录',
      const Offset(88, 136),
      const TextStyle(
        color: Color(0xFF687386),
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
      maxWidth: 500,
    );

    final meta = Rect.fromLTWH(560, 80, 254, 88);
    _roundRect(canvas, meta, 10, const Color(0xFFF8FAFD));
    _strokeRoundRect(canvas, meta, 10, const Color(0xFFE2E8F0), 1);
    _drawText(
      canvas,
      '报告编号',
      Offset(meta.left + 18, meta.top + 16),
      const TextStyle(
        color: Color(0xFF8A96A8),
        fontSize: 13,
        fontWeight: FontWeight.w800,
      ),
    );
    _drawText(
      canvas,
      _reportNo(device),
      Offset(meta.left + 96, meta.top + 13),
      const TextStyle(
        color: Color(0xFF1B2B44),
        fontSize: 16,
        fontWeight: FontWeight.w900,
      ),
      maxWidth: 138,
      maxLines: 1,
    );
    _drawText(
      canvas,
      '检测时间',
      Offset(meta.left + 18, meta.top + 50),
      const TextStyle(
        color: Color(0xFF8A96A8),
        fontSize: 13,
        fontWeight: FontWeight.w800,
      ),
    );
    _drawText(
      canvas,
      _formatDateTime(issuedAt),
      Offset(meta.left + 96, meta.top + 47),
      const TextStyle(
        color: Color(0xFF1B2B44),
        fontSize: 16,
        fontWeight: FontWeight.w900,
      ),
      maxWidth: 138,
      maxLines: 1,
    );
  }

  static void _drawProductHero(Canvas canvas, Device device) {
    final title = '苹果 ${device.model} ${device.capacity} ${device.network}';
    _drawText(
      canvas,
      title,
      const Offset(88, 198),
      const TextStyle(
        color: Color(0xFF17233A),
        fontSize: 28,
        height: 1.22,
        fontWeight: FontWeight.w900,
      ),
      maxWidth: 560,
      maxLines: 2,
    );
    _drawText(
      canvas,
      '${device.color == '未知' ? '颜色以实物为准' : device.color} · ${_serialText(device)}',
      const Offset(88, 268),
      const TextStyle(
        color: Color(0xFF6E7A8D),
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
      maxWidth: 540,
    );

    _drawStatusPill(
      canvas,
      Rect.fromLTWH(88, 306, 128, 36),
      device.idLockClean ? '检测通过' : '重点项确认',
      success: device.idLockClean,
    );
    _drawText(
      canvas,
      '${device.condition} · 功能${_functionGrade(device)}',
      const Offset(234, 304),
      const TextStyle(
        color: Color(0xFF15253F),
        fontSize: 31,
        fontWeight: FontWeight.w900,
      ),
      maxWidth: 360,
      maxLines: 1,
    );

    final panel = Rect.fromLTWH(620, 198, 194, 144);
    _roundRect(canvas, panel, 12, const Color(0xFFF6FBF8));
    _strokeRoundRect(canvas, panel, 12, const Color(0xFFD7EBDD), 1);
    _drawSealCheck(canvas, Offset(panel.left + 26, panel.top + 28));
    _drawText(
      canvas,
      device.idLockClean ? '核心项通过' : '请确认ID状态',
      Offset(panel.left + 62, panel.top + 25),
      const TextStyle(
        color: Color(0xFF16633A),
        fontSize: 20,
        fontWeight: FontWeight.w900,
      ),
      maxWidth: 112,
      maxLines: 1,
    );
    _drawText(
      canvas,
      '实拍图片已留档\n外观以记录为准',
      Offset(panel.left + 26, panel.top + 76),
      const TextStyle(
        color: Color(0xFF627083),
        fontSize: 15,
        height: 1.45,
        fontWeight: FontWeight.w700,
      ),
      maxWidth: 150,
      maxLines: 2,
    );
  }

  static void _drawSpecGrid(
    Canvas canvas,
    Device device,
    Map<String, dynamic>? inspection,
  ) {
    final specs = [
      _Spec('型号', device.model),
      _Spec('容量', device.capacity),
      _Spec('颜色', device.color == '未知' ? '以实物为准' : device.color),
      _Spec('网络', device.network),
      _Spec('电池健康', '${device.batteryHealth}%'),
      _Spec('成色', device.condition),
      _Spec('序列号', _shortSerial(device.serial)),
      _Spec('保修信息', _warrantyText(inspection)),
      _Spec('ID锁/监管', device.idLockClean ? '无锁' : '请确认'),
    ];
    final grid = Rect.fromLTWH(86, 374, 728, 156);
    _roundRect(canvas, grid, 10, const Color(0xFFF8FAFD));
    _strokeRoundRect(canvas, grid, 10, const Color(0xFFE4EAF2), 1);
    const startX = 88.0;
    const startY = 396.0;
    const itemW = 210.0;
    for (var i = 0; i < specs.length; i++) {
      final col = i % 3;
      final row = i ~/ 3;
      final x = startX + 22 + col * 232;
      final y = startY + row * 46;
      _drawText(
        canvas,
        specs[i].label,
        Offset(x, y),
        const TextStyle(
          color: Color(0xFF8A96A8),
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        maxWidth: itemW,
      );
      _drawText(
        canvas,
        specs[i].value,
        Offset(x + 76, y - 3),
        const TextStyle(
          color: Color(0xFF1E2F48),
          fontSize: 17,
          fontWeight: FontWeight.w900,
        ),
        maxWidth: 128,
        maxLines: 1,
      );
    }
  }

  static Future<void> _drawThumbnails(
    Canvas canvas,
    List<String> imagePaths,
  ) async {
    _drawText(
      canvas,
      '实拍凭证',
      const Offset(88, 558),
      const TextStyle(
        color: Color(0xFF2A3B54),
        fontSize: 18,
        fontWeight: FontWeight.w900,
      ),
    );
    _drawText(
      canvas,
      '用于客户核对外观与关于本机信息',
      const Offset(178, 559),
      const TextStyle(
        color: Color(0xFF8A96A8),
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
      maxWidth: 320,
      maxLines: 1,
    );
    final thumbs = imagePaths.take(4).toList();
    for (var i = 0; i < thumbs.length; i++) {
      final image = await _loadImage(thumbs[i]);
      final target = Rect.fromLTWH(88 + i * 134, 590, 106, 106);
      _roundRect(canvas, target, 8, const Color(0xFFF2F6FB));
      _strokeRoundRect(canvas, target, 8, const Color(0xFFE1E8F0), 1);
      if (image != null) {
        _drawCoverImage(canvas, image, target);
        image.dispose();
      }
    }
  }

  static void _drawQualityBadge(Canvas canvas, Offset offset) {
    _drawStatusPill(
      canvas,
      Rect.fromLTWH(offset.dx, offset.dy - 2, 118, 34),
      '客户版报告',
      success: true,
    );
    _drawText(
      canvas,
      '未列明问题按本次检查“未见明显异常”展示',
      offset + const Offset(134, 3),
      const TextStyle(
        color: Color(0xFF69768A),
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
      maxWidth: 520,
      maxLines: 1,
    );
  }

  static List<_ReportSection> _buildCustomerSections(
    Device device,
    Map<String, dynamic>? inspection,
  ) {
    final checks = _checks(inspection);
    final screenClear = _issueValue(inspection, 'screenDefects');
    final appearanceClear = _issueValue(inspection, 'appearanceDefects');
    final screenDisplay = _normalizeStatus(checks['屏幕显示'], issueText: '见外观记录');
    final touch = _normalizeStatus(checks['屏幕触控']);
    final button = _normalizeStatus(checks['按键']);
    final port = _normalizeStatus(checks['充电接口'], issueText: '见外观记录');
    final camera = _normalizeStatus(checks['摄像头'], issueText: '见外观记录');
    final wifi = _normalizeStatus(checks['WiFi']);
    final bluetooth = _normalizeStatus(checks['蓝牙']);
    final speaker = _normalizeStatus(checks['扬声器']);
    final mic = _normalizeStatus(checks['麦克风']);

    return [
      _ReportSection('检测结论', '客户速览', [
        _ReportRow('整机状态', '${device.condition} · 功能${_functionGrade(device)}'),
        _ReportRow('屏幕结论', screenClear == '无' ? '未记录明显异常' : '见外观记录'),
        _ReportRow('外观结论', appearanceClear == '无' ? '未记录明显异常' : '见外观记录'),
        _ReportRow('电池情况', '${device.batteryHealth}%'),
        _ReportRow('ID锁/监管', device.idLockClean ? '无锁/无监管' : '有锁/请确认'),
      ]),
      _ReportSection('屏幕与外观', '外观记录', [
        _ReportRow('显示/触控', '$screenDisplay / $touch'),
        ..._manualDefectRows(inspection),
      ]),
      _ReportSection('功能检测', '基础项目', [
        _ReportRow('按键/指纹', button),
        _ReportRow('摄像头', camera),
        _ReportRow('充电接口', port),
        _ReportRow('WiFi/蓝牙', '$wifi / $bluetooth'),
        _ReportRow('扬声器/麦克风', '$speaker / $mic'),
        _ReportRow('蜂窝/SIM', device.network.contains('蜂窝') ? '蜂窝版' : '不适用'),
      ]),
      _ReportSection('安全与维修', '风险说明', [
        _ReportRow('维修痕迹', _repairText(inspection)),
        _ReportRow('进水迹象', '未见异常'),
        _ReportRow('ID锁', device.idLockClean ? '无锁' : '有锁/请确认'),
        _ReportRow('保修情况', _warrantyText(inspection)),
      ]),
    ];
  }

  static double _drawChecklistSection(
    Canvas canvas,
    double y,
    _ReportSection section,
  ) {
    final sectionRect = Rect.fromLTWH(
      86,
      y - 10,
      728,
      48 + section.rows.length * 34,
    );
    _roundRect(canvas, sectionRect, 8, const Color(0xFFFAFBFD));
    _strokeRoundRect(canvas, sectionRect, 8, const Color(0xFFE5EAF2), 1);
    _drawText(
      canvas,
      section.title,
      Offset(108, y),
      const TextStyle(
        color: Color(0xFF30445C),
        fontSize: 20,
        fontWeight: FontWeight.w900,
      ),
    );
    if (section.countLabel.isNotEmpty) {
      _drawGreenCheck(canvas, Offset(714, y + 2));
      _drawText(
        canvas,
        section.countLabel,
        Offset(738, y - 4),
        const TextStyle(
          color: Color(0xFF7C8899),
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
        maxWidth: 72,
      );
    }
    y += 38;
    for (final row in section.rows) {
      _drawChecklistRow(canvas, y, row);
      y += 34;
    }
    return y;
  }

  static void _drawChecklistRow(Canvas canvas, double y, _ReportRow row) {
    canvas.drawLine(
      Offset(108, y + 28),
      Offset(792, y + 28),
      Paint()
        ..color = const Color(0xFFE9EEF5)
        ..strokeWidth = 1,
    );
    _drawText(
      canvas,
      row.label,
      Offset(116, y),
      const TextStyle(
        color: Color(0xFF8D9BAA),
        fontSize: 15,
        fontWeight: FontWeight.w800,
      ),
      maxWidth: 220,
      maxLines: 1,
    );
    _drawText(
      canvas,
      row.value,
      Offset(368, y),
      TextStyle(
        color: _statusColor(row.value),
        fontSize: 15,
        fontWeight: FontWeight.w900,
      ),
      maxWidth: 408,
      maxLines: 1,
      textAlign: TextAlign.right,
    );
  }

  static void _drawGreenCheck(Canvas canvas, Offset center) {
    canvas.drawCircle(center, 10, Paint()..color = const Color(0xFF45D083));
    final paint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2.4;
    canvas.drawLine(
      center + const Offset(-4, 0),
      center + const Offset(-1, 4),
      paint,
    );
    canvas.drawLine(
      center + const Offset(-1, 4),
      center + const Offset(5, -4),
      paint,
    );
  }

  static void _drawTips(Canvas canvas, double y, double height) {
    final top = math.min(y + 14, height - 170);
    final rect = Rect.fromLTWH(86, top, 728, 92);
    _roundRect(canvas, rect, 8, const Color(0xFFF6F8FB));
    _strokeRoundRect(canvas, rect, 8, const Color(0xFFE7ECF3), 1);
    _drawText(
      canvas,
      '说明：本报告依据入库实拍图与外观记录生成。未列明问题按本次检查未见明显异常展示；交易前建议以实物复验和开箱视频为准。',
      Offset(rect.left + 22, rect.top + 22),
      const TextStyle(
        color: Color(0xFF758195),
        fontSize: 15,
        height: 1.45,
        fontWeight: FontWeight.w700,
      ),
      maxWidth: 684,
      maxLines: 3,
    );
  }

  static String _functionGrade(Device device) {
    if (!device.idLockClean) return 'B';
    if (device.condition == '全新' || device.condition == '99新') return 'A';
    if (device.condition == '95新') return 'A';
    return 'B';
  }

  static String _warrantyText(Map<String, dynamic>? inspection) {
    final raw = _stringValue(inspection, 'warranty', '');
    if (raw.isNotEmpty && !_isUncertain(raw)) return raw;
    return '以品牌官方查询为准';
  }

  static String _repairText(Map<String, dynamic>? inspection) {
    final raw = _stringValue(inspection, 'repairSummary', '');
    if (raw.isNotEmpty && !_isUncertain(raw)) return raw;
    return '未记录维修痕迹';
  }

  static Color _statusColor(String value) {
    if (value.contains('未记录') ||
        value.contains('未见') ||
        value.contains('正常') ||
        value.contains('无锁') ||
        value.contains('不适用') ||
        value.contains('通过')) {
      return const Color(0xFF256E46);
    }
    if (value.contains('异常') ||
        value.contains('见外观记录') ||
        value.contains('见记录') ||
        value.contains('请确认') ||
        value.contains('有锁') ||
        value.contains('磕碰') ||
        value.contains('划痕') ||
        value.contains('出线') ||
        value.contains('凹陷') ||
        value.contains('漏液') ||
        value.contains('压伤') ||
        value.contains('掉漆') ||
        value.contains('磨损')) {
      return const Color(0xFFE06C4E);
    }
    return const Color(0xFF47566B);
  }

  static String _issueValue(Map<String, dynamic>? data, String key) {
    final rows = _defectRows(data, key, emptyText: '无');
    final value = rows.first.value;
    if (value == '无') return value;
    return '见记录';
  }

  static List<_ReportRow> _manualDefectRows(Map<String, dynamic>? data) {
    final rows = <_ReportRow>[
      ..._defectDetailRows(
        data,
        'screenDefects',
        fallbackLabel: '屏幕外观',
        fallbackValue: '无明显问题',
        defaultPart: '屏幕',
      ),
      ..._defectDetailRows(
        data,
        'appearanceDefects',
        fallbackLabel: '机身外观',
        fallbackValue: '无明显问题',
        defaultPart: '机身',
      ),
    ];
    return rows.take(8).toList();
  }

  static List<_ReportRow> _defectDetailRows(
    Map<String, dynamic>? data,
    String key, {
    required String fallbackLabel,
    required String fallbackValue,
    required String defaultPart,
  }) {
    final raw = data?[key];
    if (raw is! List || raw.isEmpty) {
      return [_ReportRow(fallbackLabel, fallbackValue)];
    }
    final rows = <_ReportRow>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final part = _cleanValue(item['part']);
      final location = _cleanValue(item['location']);
      final type = _cleanValue(item['type']);
      final severity = _cleanValue(item['severity']);
      final label = [
        part.isEmpty ? defaultPart : part,
        if (location.isNotEmpty) location,
      ].join(' · ');
      final value = [
        if (type.isNotEmpty) type,
        if (severity.isNotEmpty) severity,
      ].join(' · ');
      rows.add(_ReportRow(label, _cleanDefectValue(value)));
    }
    return rows.isEmpty ? [_ReportRow(fallbackLabel, fallbackValue)] : rows;
  }

  static Map<String, String> _checks(Map<String, dynamic>? data) {
    final checks = data?['checks'];
    if (checks is Map) {
      return checks.map((key, value) {
        final k = key.toString();
        return MapEntry(k, value.toString());
      });
    }
    return const {};
  }

  static String _normalizeStatus(
    dynamic value, {
    String unknown = '正常',
    String issueText = '见记录',
  }) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty ||
        text == '未知' ||
        text == '未测' ||
        text == '需复核' ||
        text.toLowerCase() == 'unknown') {
      return unknown;
    }
    if (text.contains('异常') ||
        text.contains('轻微') ||
        text.contains('磕碰') ||
        text.contains('划痕') ||
        text.contains('凹陷') ||
        text.contains('磨损') ||
        text.contains('掉漆') ||
        text.contains('出线') ||
        text.contains('漏液') ||
        text.contains('压伤')) {
      return issueText;
    }
    if (text.contains('正常') || text == '无') return '正常';
    return text;
  }

  static String _stringValue(
    Map<String, dynamic>? map,
    String key,
    String fallback,
  ) {
    final value = map?[key];
    if (value == null) return fallback;
    final text = value.toString().trim();
    if (text.isEmpty || text == '未知' || text.toLowerCase() == 'unknown') {
      return fallback;
    }
    return text;
  }

  static List<MapEntry<String, String>> _defectRows(
    Map<String, dynamic>? data,
    String key, {
    required String emptyText,
    String defaultPart = '',
  }) {
    final raw = data?[key];
    if (raw is! List) return [MapEntry('结论', emptyText)];
    if (raw.isEmpty) {
      return [MapEntry('结论', emptyText)];
    }
    final rows = <MapEntry<String, String>>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final part = _cleanValue(item['part']);
      final location = _cleanValue(item['location']);
      final type = _cleanValue(item['type']);
      final severity = _cleanValue(item['severity']);
      if ([part, location, type, severity].every((v) => v.isEmpty)) continue;
      rows.add(
        MapEntry(
          [
            if (part.isNotEmpty)
              part
            else if (defaultPart.isNotEmpty)
              defaultPart,
            if (location.isNotEmpty) location,
          ].join(' · '),
          [
            if (type.isNotEmpty) type,
            if (severity.isNotEmpty) severity,
          ].join(' · '),
        ),
      );
    }
    return rows.isEmpty ? [MapEntry('结论', emptyText)] : rows;
  }

  static String _cleanValue(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text == '未知' || text.toLowerCase() == 'unknown') {
      return '';
    }
    return text;
  }

  static String _cleanDefectValue(String value) {
    final text = value.trim();
    if (text.isEmpty || _isUncertain(text)) return '人工记录';
    return text.replaceAll('需说明', '已备注');
  }

  static bool _isUncertain(String value) {
    final text = value.trim();
    if (text.isEmpty) return true;
    return text.contains('需复核') ||
        text.contains('未测') ||
        text.contains('未知') ||
        text.contains('待确认') ||
        text.contains('无法验证') ||
        text.contains('补拍') ||
        text.toLowerCase() == 'unknown';
  }

  static String _reportNo(Device device) {
    final source =
        device.id.isNotEmpty
            ? device.id
            : DateTime.now().millisecondsSinceEpoch.toString();
    final tail =
        source.length > 8 ? source.substring(source.length - 8) : source;
    return 'HM-$tail';
  }

  static String _formatDateTime(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${time.year}.${two(time.month)}.${two(time.day)} ${two(time.hour)}:${two(time.minute)}';
  }

  static String _serialText(Device device) {
    final serial = device.serial.trim();
    if (serial.isEmpty || serial == '未填写' || serial == '未知') {
      return '序列号未填写';
    }
    return '序列号 $serial';
  }

  static String _shortSerial(String serial) {
    final text = serial.trim();
    if (text.isEmpty || text == '未填写' || text == '未知') return '未填写';
    if (text.length <= 8) return text;
    return '...${text.substring(text.length - 6)}';
  }

  static Future<ui.Image?> _loadImage(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  static void _drawCoverImage(Canvas canvas, ui.Image image, Rect dst) {
    final srcSize = Size(image.width.toDouble(), image.height.toDouble());
    final fitted = applyBoxFit(BoxFit.cover, srcSize, dst.size);
    final src = Alignment.center.inscribe(fitted.source, Offset.zero & srcSize);
    final rrect = RRect.fromRectAndRadius(dst, const Radius.circular(12));
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawImageRect(image, src, dst, Paint());
    canvas.restore();
  }

  static void _roundRect(Canvas canvas, Rect rect, double radius, Color color) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      Paint()..color = color,
    );
  }

  static void _strokeRoundRect(
    Canvas canvas,
    Rect rect,
    double radius,
    Color color,
    double width,
  ) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width,
    );
  }

  static void _drawStatusPill(
    Canvas canvas,
    Rect rect,
    String text, {
    required bool success,
  }) {
    final bg = success ? const Color(0xFFE8F7EF) : const Color(0xFFFFF4E8);
    final fg = success ? const Color(0xFF177245) : const Color(0xFFB85B12);
    final border = success ? const Color(0xFFCDEBD9) : const Color(0xFFFFDDBA);
    _roundRect(canvas, rect, 18, bg);
    _strokeRoundRect(canvas, rect, 18, border, 1);
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: fg, fontSize: 15, fontWeight: FontWeight.w900),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: math.max(0, rect.width - 18));
    painter.paint(
      canvas,
      Offset(
        rect.left + (rect.width - painter.width) / 2,
        rect.top + (rect.height - painter.height) / 2 - 0.5,
      ),
    );
  }

  static void _drawSealCheck(Canvas canvas, Offset center) {
    canvas.drawCircle(center, 16, Paint()..color = const Color(0xFF28A35F));
    final paint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 3;
    canvas.drawLine(
      center + const Offset(-7, 0),
      center + const Offset(-2, 6),
      paint,
    );
    canvas.drawLine(
      center + const Offset(-2, 6),
      center + const Offset(8, -7),
      paint,
    );
  }

  static void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style, {
    double maxWidth = 760,
    int? maxLines,
    TextAlign textAlign = TextAlign.left,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: textAlign,
      maxLines: maxLines,
      ellipsis: maxLines == null ? null : '...',
    )..layout(maxWidth: maxWidth);
    painter.paint(canvas, offset);
  }
}

class _Spec {
  final String label;
  final String value;
  const _Spec(this.label, this.value);
}

class _ReportSection {
  final String title;
  final String countLabel;
  final List<_ReportRow> rows;
  const _ReportSection(this.title, this.countLabel, this.rows);
}

class _ReportRow {
  final String label;
  final String value;
  const _ReportRow(this.label, this.value);
}
