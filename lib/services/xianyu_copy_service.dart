import 'dart:math' as math;

import '../models.dart';
import '../storage.dart';
import 'xianyu_copy_materials.dart';

class XianyuCopyService {
  static const builtInMaterialCount = 100;
  static const builtInStyleCount = 10;

  static const defaultRules = '''
语气：像专业二手 iPad 卖家，真实、克制、干净，不要像广告。
重点：优先说明型号容量、成色、电池、ID 锁、网络版本、配件和适合场景。
避坑：不要写全新、完美无瑕、官方在保、无任何问题、包满意等过度承诺。
格式：100-180 字，一段话，纯文本，不带价格、emoji、编号和夸张符号。
风控：参考样本只学习表达方式，最终内容必须以当前设备信息为准。
素材：已吸收 docs/闲鱼iPad文案100条大全.md 的风格，但必须安全改写，不照抄素材里的承诺、账号、资源或个人经历。
''';

  static const _builtInStyleGuide = '''
内置素材来源：docs/闲鱼iPad文案100条大全.md，已清理为 10 类风格：极简信息、生活感、硬核参数、专业卖家、急出促销、场景卖点、幽默段子、验机保障、配件套装、故事走心。
选择逻辑：普通库存优先使用极简信息、生活感、场景卖点；高配 Pro 可偏硬核参数、办公生产力、设计创作；低预算机型可偏学生学习、追剧娱乐、急出促销；成色好或配件齐全的机器可偏验机保障、配件套装。
安全改写：素材中出现的全新、假一赔十、包退、付费账号、学习资料、会员资源、官方在保、前任送的、女生自用等内容，只有在当前设备资料明确支持时才允许写；否则只学习节奏，不写事实。
表达要求：少用夸张词，多写可核验信息。把“无任何问题”改成“功能检测正常”，把“完美无瑕”改成“实拍如图，细节可沟通”，把“包退/假一赔十”改成“支持按平台流程验机”。
''';

  static int get builtInExampleCount => xianyuCopySeeds.length;

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
    bool includeCuratedExamples = true,
    bool includeSoldDescriptions = true,
    bool randomizeBuiltIns = true,
  }) {
    final b = StringBuffer();
    b.writeln('【本店文案规则】');
    b.writeln(effectiveRules(storage));
    b.writeln('\n【内置 100 条素材提炼规则】');
    b.writeln(_builtInStyleGuide.trim());

    final examples =
        includeCuratedExamples
            ? relevantExamples(
              storage,
              model: model,
              condition: condition,
              limit: curatedLimit,
            )
            : <XianyuCopyExample>[];
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

    final sold =
        includeSoldDescriptions
            ? _relevantSoldDescriptions(
              storage,
              model: model,
              condition: condition,
              limit: soldLimit,
            )
            : <Device>[];
    if (sold.isNotEmpty) {
      b.writeln('\n【已售设备历史文案】');
      for (var i = 0; i < sold.length; i++) {
        final d = sold[i];
        b.writeln('${i + 1}. ${d.model} ${d.capacity} · ${d.condition}');
        b.writeln('文案：${_clip(d.description ?? '', 180)}');
      }
    }

    final builtIns = _relevantBuiltInExamples(
      model: model,
      condition: condition,
      limit: examples.isEmpty && sold.isEmpty ? 4 : 2,
      randomize: randomizeBuiltIns,
    );
    if (builtIns.isNotEmpty) {
      b.writeln('\n【内置安全改写样本】');
      for (var i = 0; i < builtIns.length; i++) {
        final e = builtIns[i];
        b.writeln(
          '${i + 1}. ${_briefMeta(e.title, e.model, e.condition, e.tags, e.resultNote)}',
        );
        b.writeln('文案：${_clip(e.text, 180)}');
      }
    }

    b.writeln('\n注意：不要照抄样本文案，不要带入样本中的价格、瑕疵、配件或承诺。');
    return b.toString().trim();
  }

  static List<XianyuCopyExample> _relevantBuiltInExamples({
    required String model,
    required String condition,
    required int limit,
    required bool randomize,
  }) {
    final examples =
        xianyuCopySeeds
            .map(
              (s) => XianyuCopyExample(
                id: 'builtin_${s.id}',
                title: s.title,
                model: s.model,
                condition: s.condition,
                text: s.text,
                tags: s.tags,
                resultNote: s.note,
                score: s.score,
                createdAt: '2026-07-03T00:00:00.000',
              ),
            )
            .toList();
    final scored =
        examples
            .map(
              (example) => MapEntry(
                example,
                _scoreBuiltInExample(example, model, condition),
              ),
            )
            .toList();
    scored.sort((a, b) {
      final diff = b.value - a.value;
      if (diff != 0) return diff;
      return b.key.score.compareTo(a.key.score);
    });
    if (!randomize) return scored.map((e) => e.key).take(limit).toList();

    final poolSize = math.min(scored.length, math.max(limit * 4, 12));
    final pool = scored.take(poolSize).map((e) => e.key).toList();
    pool.shuffle(math.Random(DateTime.now().microsecondsSinceEpoch));
    return pool.take(limit).toList();
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

  static int _scoreBuiltInExample(
    XianyuCopyExample example,
    String model,
    String condition,
  ) {
    var score = example.score.clamp(1, 5) * 10;
    final m = model.toLowerCase();
    final c = condition.toLowerCase();
    final tags = '${example.title} ${example.tags}'.toLowerCase();
    if (m.contains('pro') &&
        (tags.contains('专业') ||
            tags.contains('办公') ||
            tags.contains('设计') ||
            tags.contains('数码'))) {
      score += 18;
    }
    if ((m.contains('air') || m.contains('mini')) &&
        (tags.contains('学生') ||
            tags.contains('娱乐') ||
            tags.contains('实用') ||
            tags.contains('性价比'))) {
      score += 12;
    }
    if ((c.contains('99') || c.contains('95') || c.contains('靓')) &&
        (tags.contains('准新') || tags.contains('真实'))) {
      score += 12;
    }
    if ((c.contains('全新') || c.contains('未拆') || c.contains('未激活')) &&
        tags.contains('全新')) {
      score += 20;
    }
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
