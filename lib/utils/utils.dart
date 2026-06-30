import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// 货币格式化（分→元）
String yuan(int fen) => '¥${(fen / 100).round()}';

/// 货币格式化（分→元，带小数）
String yuanDecimal(int fen) {
  final v = fen / 100;
  if (v == v.roundToDouble()) return '¥${v.toInt()}';
  return '¥${v.toStringAsFixed(2)}';
}

/// Toast 消息
void toast(BuildContext ctx, String m) {
  ScaffoldMessenger.of(ctx).hideCurrentSnackBar();
  ScaffoldMessenger.of(ctx).showSnackBar(
    SnackBar(
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: C.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.info_rounded, color: C.primary, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                m,
                style: TextStyle(
                  fontSize: 13,
                  color: C.t1,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(40, 0, 40, 200),
      duration: const Duration(milliseconds: 2000),
      backgroundColor: C.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(C.radiusMd),
        side: BorderSide(color: C.line, width: 1),
      ),
      elevation: 8,
    ),
  );
}

/// 确认对话框
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmText = '确定',
  Color confirmColor = C.red,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder:
        (ctx) => AlertDialog(
          backgroundColor: C.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.white.withOpacity(0.12)),
          ),
          title: Text(
            title,
            style: TextStyle(
              color: C.t1,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            message,
            style: TextStyle(
              color: C.t2,
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('取消', style: TextStyle(color: C.t2)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: confirmColor),
              child: Text(
                confirmText,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
  );
  return ok == true;
}

/// 日期格式化
String fmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// 同步相关的工具函数（从 main.dart 搬过来）
const Set<String> localOnlySettingKeys = {
  'auth_token',
  'auth_email',
  'webdavConfig',
};

dynamic cloneJsonValue(dynamic value) {
  if (value is Map) {
    return value.map(
      (key, child) => MapEntry(key.toString(), cloneJsonValue(child)),
    );
  }
  if (value is List) {
    return value.map(cloneJsonValue).toList();
  }
  return value;
}

Map<String, dynamic> snapshotLocalOnlySettings(dynamic storage) {
  final settings = storage.getSettings();
  final local = <String, dynamic>{};
  for (final key in localOnlySettingKeys) {
    if (settings.containsKey(key)) {
      local[key] = cloneJsonValue(settings[key]);
    }
  }
  return local;
}

Future<void> restoreLocalOnlySettings(
  dynamic storage,
  Map<String, dynamic> localSettings,
) async {
  final settings = Map<String, dynamic>.from(storage.getSettings());
  for (final key in localOnlySettingKeys) {
    if (localSettings.containsKey(key)) {
      settings[key] = cloneJsonValue(localSettings[key]);
    } else {
      settings.remove(key);
    }
  }
  await storage.saveSettings(settings);
}

Map<String, dynamic> storagePayloadForSync(dynamic storage) {
  final data = Map<String, dynamic>.from(storage.toFullMap());
  final settings = Map<String, dynamic>.from((data['settings'] as Map?) ?? {});
  for (final key in localOnlySettingKeys) {
    settings.remove(key);
  }
  data['settings'] = settings;
  return data;
}
