import '../models.dart';
import '../storage.dart';

class XianyuCopyService {
  static const defaultRules = '''
语气：像专业二手 iPad 卖家，真实、克制、干净，不要像广告。
重点：优先说明型号容量、成色、电池、ID 锁、网络版本、配件和适合场景。
避坑：不要写全新、完美无瑕、官方在保、无任何问题、包满意等过度承诺。
格式：100-180 字，一段话，纯文本，不带价格、emoji、编号和夸张符号。
风控：参考样本只学习表达方式，最终内容必须以当前设备信息为准。
''';

  static String effectiveRules(Storage storage) {
    final saved = storage.getXianyuCopyRules().trim();
    return saved.isEmpty ? defaultRules.trim() : saved;
  }

  static List<XianyuCopyExample> relevantExamples(
    Storage storage, {
    required String model,
    required String condition,
    int limit = 3,
  }) {
    final examples = storage.getXianyuCopyExamples();
    final ranked = [...examples];
    ranked.sort((a, b) {
      final diff =
          _scoreExample(b, model, condition) -
          _scoreExample(a, model, condition);
      if (diff != 0) return diff;
      return b.createdAt.compareTo(a.createdAt);
    });
    return ranked.take(limit).toList();
  }

  static String buildReferenceContext(
    Storage storage, {
    required String model,
    required String condition,
    int curatedLimit = 3,
    int soldLimit = 2,
  }) {
    final b = StringBuffer();
    b.writeln('【本店文案规则】');
    b.writeln(effectiveRules(storage));

    final examples = relevantExamples(
      storage,
      model: model,
      condition: condition,
      limit: curatedLimit,
    );
    if (examples.isNotEmpty) {
      b.writeln('\n【高转化参考样本】');
      for (var i = 0; i < examples.length; i++) {
        final e = examples[i];
        b.writeln(
          '${i + 1}. ${_briefMeta(e.title, e.model, e.condition, e.tags, e.resultNote)}',
        );
        b.writeln('文案：${_clip(e.text, 180)}');
      }
    }

    final sold = _relevantSoldDescriptions(
      storage,
      model: model,
      condition: condition,
      limit: soldLimit,
    );
    if (sold.isNotEmpty) {
      b.writeln('\n【已售设备历史文案】');
      for (var i = 0; i < sold.length; i++) {
        final d = sold[i];
        b.writeln('${i + 1}. ${d.model} ${d.capacity} · ${d.condition}');
        b.writeln('文案：${_clip(d.description ?? '', 180)}');
      }
    }

    b.writeln('\n注意：不要照抄样本文案，不要带入样本中的价格、瑕疵、配件或承诺。');
    return b.toString().trim();
  }

  static int _scoreExample(
    XianyuCopyExample example,
    String model,
    String condition,
  ) {
    var score = example.score.clamp(1, 5) * 10;
    final m = model.trim();
    final em = example.model.trim();
    if (m.isNotEmpty && em.isNotEmpty) {
      if (m == em) {
        score += 40;
      } else if (m.contains(em) || em.contains(m)) {
        score += 25;
      }
    }
    final c = condition.trim();
    final ec = example.condition.trim();
    if (c.isNotEmpty && ec.isNotEmpty) {
      if (c == ec) {
        score += 18;
      } else if (c.contains(ec) || ec.contains(c)) {
        score += 10;
      }
    }
    if (example.tags.contains('已售') || example.resultNote.contains('成交')) {
      score += 8;
    }
    return score;
  }

  static List<Device> _relevantSoldDescriptions(
    Storage storage, {
    required String model,
    required String condition,
    required int limit,
  }) {
    final m = model.trim();
    final c = condition.trim();
    final sold =
        storage
            .getDevices()
            .where(
              (d) =>
                  d.status == 'sold' && (d.description ?? '').trim().isNotEmpty,
            )
            .toList();
    sold.sort((a, b) {
      final diff =
          _scoreDeviceDescription(b, m, c) - _scoreDeviceDescription(a, m, c);
      if (diff != 0) return diff;
      return b.createdAt.compareTo(a.createdAt);
    });
    return sold.take(limit).toList();
  }

  static int _scoreDeviceDescription(Device d, String model, String condition) {
    var score = 0;
    if (model.isNotEmpty) {
      if (d.model == model) {
        score += 30;
      } else if (d.model.contains(model) || model.contains(d.model)) {
        score += 18;
      }
    }
    if (condition.isNotEmpty) {
      if (d.condition == condition) {
        score += 12;
      } else if (d.condition.contains(condition) ||
          condition.contains(d.condition)) {
        score += 6;
      }
    }
    if (d.netProfit > 0) score += 8;
    return score;
  }

  static String _briefMeta(
    String title,
    String model,
    String condition,
    String tags,
    String resultNote,
  ) {
    final parts = [
      if (title.trim().isNotEmpty) title.trim(),
      if (model.trim().isNotEmpty) model.trim(),
      if (condition.trim().isNotEmpty) condition.trim(),
      if (tags.trim().isNotEmpty) tags.trim(),
      if (resultNote.trim().isNotEmpty) resultNote.trim(),
    ];
    return parts.isEmpty ? '通用样本' : parts.join(' · ');
  }

  static String _clip(String text, int max) {
    final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length <= max) return clean;
    return '${clean.substring(0, max)}...';
  }
}
