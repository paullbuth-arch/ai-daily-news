class MarketPriceImportRow {
  final String model;
  final int priceYuan;

  const MarketPriceImportRow({required this.model, required this.priceYuan});
}

class MarketPriceImportService {
  static List<MarketPriceImportRow> parseRows(String raw) {
    final cleaned = _stripCodeFence(raw);
    final rows = <MarketPriceImportRow>[];
    final seen = <String, int>{};

    for (final line in cleaned.split(RegExp(r'[\r\n]+'))) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      if (_looksLikeHeader(trimmed)) continue;

      final parts =
          trimmed
              .split(RegExp(r'[,，\t]'))
              .map((part) => part.trim())
              .where((part) => part.isNotEmpty)
              .toList();
      if (parts.length < 2) continue;

      final price = _parsePrice(parts.last);
      if (price == null || price <= 0) continue;

      var model = _normalizeModel(parts.take(parts.length - 1).join(' '));
      if (model.isEmpty || _isNonIpadAccessory(model)) continue;

      final count = seen.update(model, (value) => value + 1, ifAbsent: () => 1);
      if (count > 1) model = '$model 档位$count';
      rows.add(MarketPriceImportRow(model: model, priceYuan: price));
    }
    return rows;
  }

  static List<String> validateRows(List<MarketPriceImportRow> rows) {
    final warnings = <String>[];
    if (rows.isEmpty) {
      return ['没有识别到有效 iPad 行情，请检查图片清晰度、表头或 CSV 格式。'];
    }

    final lowConfidence = rows.where((row) => row.model.contains('低置信')).length;
    if (lowConfidence > 0) {
      warnings.add('有 $lowConfidence 条低置信行情，保存前建议对照原图核价。');
    }

    final oddPrices =
        rows
            .where((row) => row.priceYuan < 500 || row.priceYuan > 12000)
            .take(3)
            .toList();
    if (oddPrices.isNotEmpty) {
      warnings.add(
        '发现异常价格：${oddPrices.map((row) => '${row.model} ¥${row.priceYuan}').join('、')}',
      );
    }

    final missingCapacity =
        rows.where((row) => !_hasCapacity(row.model)).take(3).toList();
    if (missingCapacity.isNotEmpty) {
      warnings.add(
        '有 ${missingCapacity.length} 条预览结果缺少容量：${missingCapacity.map((row) => row.model).join('、')}',
      );
    }

    final missingNetwork =
        rows.where((row) => !_hasNetwork(row.model)).take(3).toList();
    if (missingNetwork.isNotEmpty) {
      warnings.add(
        '有 ${missingNetwork.length} 条预览结果缺少网络版本：${missingNetwork.map((row) => row.model).join('、')}',
      );
    }

    final duplicateSlotCount =
        rows.where((row) => RegExp(r'档位\d+$').hasMatch(row.model)).length;
    if (duplicateSlotCount > 0) {
      warnings.add('有 $duplicateSlotCount 条同名行情被自动标为档位，请确认成色/版本是否已写清。');
    }

    return warnings.take(5).toList();
  }

  static String toCsv(List<MarketPriceImportRow> rows) {
    final b = StringBuffer('\uFEFF行情名,价格\n');
    for (final row in rows) {
      b.writeln('${_csvCell(row.model)},${row.priceYuan}');
    }
    return b.toString();
  }

  static String _csvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    if (escaped.contains(',') ||
        escaped.contains('，') ||
        escaped.contains('\n') ||
        escaped.contains('"')) {
      return '"$escaped"';
    }
    return escaped;
  }

  static String _stripCodeFence(String raw) {
    var text = raw.trim();
    text = text.replaceAll(RegExp(r'^```(?:csv)?', multiLine: true), '');
    text = text.replaceAll(RegExp(r'```$', multiLine: true), '');
    return text.trim();
  }

  static bool _looksLikeHeader(String line) {
    final compact = line.replaceAll(' ', '');
    return compact.contains('型号') &&
        (compact.contains('价格') || compact.contains('批发价'));
  }

  static bool _hasCapacity(String model) {
    return RegExp(
      r'(\b|[^0-9])(32|64|128|256|512)G(\b|[^0-9])|1TB|2TB',
      caseSensitive: false,
    ).hasMatch(model);
  }

  static bool _hasNetwork(String model) {
    final lower = model.toLowerCase();
    return lower.contains('wifi') ||
        lower.contains('wi-fi') ||
        lower.contains('蜂窝') ||
        lower.contains('插卡') ||
        lower.contains('cellular') ||
        lower.contains('5g');
  }

  static int? _parsePrice(String raw) {
    final value =
        raw
            .replaceAll('¥', '')
            .replaceAll('￥', '')
            .replaceAll('元', '')
            .replaceAll(',', '')
            .trim();
    if (value.contains('询价') || value.contains('/') || value.contains('一')) {
      return null;
    }
    final match = RegExp(r'\d{2,5}').firstMatch(value);
    if (match == null) return null;
    return int.tryParse(match.group(0)!);
  }

  static String _normalizeModel(String raw) {
    return raw
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[\-\*\d\.\s]+'), '')
        .trim();
  }

  static bool _isNonIpadAccessory(String model) {
    final lower = model.toLowerCase();
    return lower.contains('pencil') ||
        model.contains('键盘') ||
        model.contains('保护壳') ||
        model.contains('手写笔');
  }
}
