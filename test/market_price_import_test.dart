import 'package:flutter_test/flutter_test.dart';
import 'package:ipad_boss_app/services/market_price_import_service.dart';

void main() {
  test('图片识别 CSV 解析支持多档价格和脏输出', () {
    final rows = MarketPriceImportService.parseRows('''
```csv
行情名,价格
iPad Air 5 M1 64G WiFi 国行靓机,2700
iPad Air 5 M1,64G,WiFi,小花,2450
iPad Pro 11 2022 M2 128G WiFi 99新，4700元
iPad Pro 11 2022 M2 128G WiFi 99新,4650
iPad Pro 13 2024 M4 256G WiFi,询价
Apple Pencil 二代,430
```
''');

    expect(rows.map((row) => row.model), [
      'iPad Air 5 M1 64G WiFi 国行靓机',
      'iPad Air 5 M1 64G WiFi 小花',
      'iPad Pro 11 2022 M2 128G WiFi 99新',
      'iPad Pro 11 2022 M2 128G WiFi 99新 档位2',
    ]);
    expect(rows.map((row) => row.priceYuan), [2700, 2450, 4700, 4650]);
  });

  test('识别结果可以反向导出为 CSV 表格', () {
    final csv = MarketPriceImportService.toCsv([
      const MarketPriceImportRow(
        model: 'iPad Air 5 M1 64G WiFi',
        priceYuan: 2700,
      ),
      const MarketPriceImportRow(
        model: 'iPad Pro 11, M2 128G 99新',
        priceYuan: 4700,
      ),
    ]);

    expect(csv.startsWith('\uFEFF行情名,价格'), true);
    expect(csv, contains('iPad Air 5 M1 64G WiFi,2700'));
    expect(csv, contains('"iPad Pro 11, M2 128G 99新",4700'));
  });
}
