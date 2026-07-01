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

输出格式：
只输出 CSV，不要解释，不要 Markdown 代码块，不要表头。
每行严格两列：行情名,价格
价格单位为元，只写数字。
''';

  static const imageUserPrompt = '''
请按上面的识图方法，逐区扫描这张批发价图片。
重点检查同一型号下的每个容量、网络和成色价格，不要漏掉同一 iPad 的多个价格档位。
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
