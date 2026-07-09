import 'package:flutter_test/flutter_test.dart';
import 'package:ipad_boss_app/models.dart';

void main() {
  test('Device.fromJson accepts legacy string bool fields', () {
    final device = Device.fromJson({
      'id': 'legacy-bool',
      'serial': 'F1',
      'model': 'iPad Air 5',
      'capacity': '64G',
      'color': 'silver',
      'network': 'WiFi',
      'condition': '95',
      'purchaseCost': 235000,
      'purchaseDate': '2026-06-21',
      'createdAt': '2026-06-21',
      'idLockClean': 'false',
    });

    expect(device.idLockClean, false);
  });

  test('QCReport.fromJson accepts legacy string and numeric bool fields', () {
    final report = QCReport.fromJson({
      'id': 'qc-legacy-bool',
      'deviceId': 'd1',
      'deviceName': 'iPad Air 5',
      'hasFaceId': 'true',
      'hasTouchId': 1,
      'wifiOk': 'false',
      'bluetoothOk': 0,
      'microphoneOk': 'yes',
      'speakerOk': 'no',
      'buttonsOk': 'on',
      'chargingOk': 'off',
      'createdAt': '2026-06-21',
    });

    expect(report.hasFaceId, true);
    expect(report.hasTouchId, true);
    expect(report.wifiOk, false);
    expect(report.bluetoothOk, false);
    expect(report.microphoneOk, true);
    expect(report.speakerOk, false);
    expect(report.buttonsOk, true);
    expect(report.chargingOk, false);
  });
}
