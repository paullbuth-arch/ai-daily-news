import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ipad_boss_app/update_service.dart';

Future<String> _serveJson(
  Map<String, Object?> body, {
  int statusCode = 200,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(() => server.close(force: true));
  server.listen((request) {
    request.response
      ..statusCode = statusCode
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body))
      ..close();
  });
  return 'http://127.0.0.1:${server.port}/version';
}

void main() {
  test('识别远端新版本并兼容字符串 buildNumber', () async {
    final url = await _serveJson({
      'version': '9.9.9',
      'buildNumber': '999',
      'apkUrl': 'https://deepsell.wiki/uploads/app.apk',
      'changelog': '测试更新',
      'sha256': 'ABCDEF',
    });

    final info = await UpdateService.check(checkUrl: url);

    expect(info, isNotNull);
    expect(info!.version, '9.9.9');
    expect(info.buildNumber, 999);
    expect(info.sha256, 'ABCDEF');
  });

  test('远端构建号不高于当前版本时返回无更新', () async {
    final url = await _serveJson({
      'version': UpdateService.currentVersion,
      'buildNumber': UpdateService.currentBuild,
      'apkUrl': 'https://deepsell.wiki/uploads/app.apk',
    });

    final info = await UpdateService.check(checkUrl: url);

    expect(info, isNull);
  });

  test('更新服务器异常时抛出错误而不是误报最新', () async {
    final url = await _serveJson({'error': 'bad'}, statusCode: 500);

    await expectLater(
      UpdateService.check(checkUrl: url),
      throwsA(isA<UpdateCheckException>()),
    );
  });
}
