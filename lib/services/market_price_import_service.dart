class MarketPriceImportRow {
  final String model;
  final int priceYuan;

  const MarketPriceImportRow({required this.model, required this.priceYuan});
}

class MarketPriceImportService {
  static const imageSystemPrompt = '''
你是华强北二手 iPad 批发价表 OCR 专家，正在识别一张可能很长、很密、位置不固定的报价截图。

识图方法：
1. 先按彩色分区标题识别系列，例如 iPad 数字、iPad mini、iPad Air、iPad Pro 11、iPad Pro 12.9、Apple Pencil。只导入 iPad，跳过 Apple Pencil、键盘和其他配件。
2. 每个系列下面通常是合并单元格：左侧是大型号，中间可能有小型号/机型码，后面是网络、内存，右侧多列是不同成色、版本、瑕疵或渠道价格。
3. 不要把同一台 iPad 压成一个价格。只要同一型号因为容量、网络、成色、版本、外版、靓机/小花/大花/换壳/资源机等原因出现多个价格，就必须拆成多行。
4. 每行第一列必须是唯一行情名，尽量拼完整：系列 + 年份/芯片 + 尺寸 + 容量 + 网络 + 成色/版本/备注。例：iPad Air 5 M1 64G WiFi 国行靓机。
5. 价格列只取明确的阿拉伯数字价格。遇到“询价”、斜杠、空白、看不清、补差、扣费、外版加/减价说明，不要输出。
6. 不要把右侧黄色“外版”备注当成批发价；只有表格主体价格格里的数字才算。
7. 如果表头能看出价格档位，例如 99新、95新、靓机、小花、大花、国行、外版，把档位写进第一列行情名。
8. 如果图片局部模糊，宁可少输出，不要猜价格。
9. 如果某一行信息看得不够确定，但价格和主体型号能确认，请在行情名末尾追加【低置信】。

输出格式：
只输出 CSV，不要解释，不要 Markdown 代码块，不要表头。
每行严格两列：行情名,价格
价格单位为元，只写数字。
''';

  static const imageUserPrompt = '''
请按上面的识图方法，逐区扫描这张批发价图片。
重点检查同一型号下的每个容量、网络和成色价格，不要漏掉同一 iPad 的多个价格档位。
先理解表头、分组、备注和跨行关系，再输出标准行。
只返回 CSV 行：行情名,价格
''';

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
