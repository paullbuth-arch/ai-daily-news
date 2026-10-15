import 'dart:convert';

/// WebView 注入返回值的通用处理。
///
/// `WebViewController.runJavaScriptReturningResult` 在各平台对**字符串**结果的
/// 封装方式不一致：Android 会再 JSON 编码一层（带引号，内部引号被转义），
/// Web/桌面端不会。这个函数把外面那层统一剥掉。
String unwrapWebViewString(String raw) {
  var text = raw.trim();
  if (text.isEmpty) return '';
  if (text == 'null' || text == 'undefined') return '';
  if (text.length >= 2 && text.startsWith('"') && text.endsWith('"')) {
    try {
      final decoded = json.decode(text);
      if (decoded is String) return decoded;
    } catch (_) {
      // 解不开就退回下面的手工去引号
    }
    text = text.substring(1, text.length - 1);
  }
  return text;
}
