import '../models.dart';
import '../storage.dart';

class XianyuCopyService {
  static const builtInMaterialCount = 50;
  static const builtInStyleCount = 14;

  static const defaultRules = '''
语气：像专业二手 iPad 卖家，真实、克制、干净，不要像广告。
重点：优先说明型号容量、成色、电池、ID 锁、网络版本、配件和适合场景。
避坑：不要写全新、完美无瑕、官方在保、无任何问题、包满意等过度承诺。
格式：100-180 字，一段话，纯文本，不带价格、emoji、编号和夸张符号。
风控：参考样本只学习表达方式，最终内容必须以当前设备信息为准。
素材：已吸收 docs/闲鱼iPad文案素材50条.md 的风格，但必须安全改写，不照抄素材里的承诺、账号、资源或个人经历。
''';

  static const _builtInStyleGuide = '''
内置素材来源：docs/闲鱼iPad文案素材50条.md，已归纳为 14 类风格：性价比捡漏、个人自用真实、专业参数、轻松幽默、极简直接、学生学习、宝妈带娃、办公生产力、追剧娱乐、急出回血、送礼全新、小红书种草、实用主义、数码爱好者。
选择逻辑：普通库存优先使用真实自用、实用主义、性价比；高配 Pro 可偏办公生产力、专业参数、设计创作；低预算机型可偏学生学习、追剧娱乐；成色特别好的机器可偏准新、数码爱好者。
安全改写：素材中出现的全新、假一赔十、包退、付费账号、学习资料、会员资源、官方在保、前任送的、女生自用等内容，只有在当前设备资料明确支持时才允许写；否则只学习节奏，不写事实。
表达要求：少用夸张词，多写可核验信息。把“无任何问题”改成“功能检测正常”，把“完美无瑕”改成“实拍如图，细节可沟通”，把“包退/假一赔十”改成“支持按平台流程验机”。
''';

  static int get builtInExampleCount => _builtInCopySeeds.length;

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
    b.writeln('\n【内置 50 条素材提炼规则】');
    b.writeln(_builtInStyleGuide.trim());

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

    final builtIns = _relevantBuiltInExamples(
      model: model,
      condition: condition,
      limit: examples.isEmpty && sold.isEmpty ? 4 : 2,
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
  }) {
    final examples =
        _builtInCopySeeds
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
                createdAt: '2026-07-01T00:00:00.000',
              ),
            )
            .toList();
    examples.sort((a, b) {
      final diff =
          _scoreBuiltInExample(b, model, condition) -
          _scoreBuiltInExample(a, model, condition);
      if (diff != 0) return diff;
      return b.score.compareTo(a.score);
    });
    return examples.take(limit).toList();
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

class _CopySeed {
  final String id;
  final String title;
  final String model;
  final String condition;
  final String text;
  final String tags;
  final int score;

  String get note => '来自 50 条素材的安全改写';

  const _CopySeed({
    required this.id,
    required this.title,
    required this.text,
    required this.tags,
    this.model = '',
    this.condition = '',
    this.score = 4,
  });
}

const _builtInCopySeeds = [
  _CopySeed(
    id: 'value',
    title: '性价比捡漏风',
    tags: '性价比 捡漏 实用',
    text:
        'iPad Air 5 256G WiFi，外观保持得比较干净，边框和屏幕细节都可以看实拍。平时看课、追剧、记笔记都够用，电池健康和功能已检查，ID 状态干净。适合想省预算又想要稳定体验的朋友，配件按实际随机器一起发。',
  ),
  _CopySeed(
    id: 'real_user',
    title: '个人自用真实风',
    tags: '真实 自用 成色',
    condition: '95新',
    text:
        '这台 iPad Pro 11 寸是自用标准整理出来的，机身保护得不错，屏幕显示、触控、扬声器、摄像头这些常用功能都检测正常。适合日常办公、学习和影音使用，成色以实拍为准，有细节问题可以直接沟通。',
    score: 5,
  ),
  _CopySeed(
    id: 'spec',
    title: '专业参数风',
    tags: '专业 参数 验机',
    text:
        'iPad 主要信息都已经核对：容量、网络版本、颜色、电池健康、循环次数和 ID 状态以页面标注为准。屏幕、边框、后盖、摄像头、麦克风、扬声器、WiFi 和蓝牙均按常规验机流程检查，适合想先看清楚参数再下单的买家。',
    score: 5,
  ),
  _CopySeed(
    id: 'minimal',
    title: '极简直接风',
    tags: '极简 直接',
    text:
        'iPad 一台，配置和成色看页面信息。功能检测正常，ID 状态干净，屏幕和外观细节以实拍为准。适合学习、追剧、办公和日常使用。想确认电池、配件或细节图的可以直接问。',
  ),
  _CopySeed(
    id: 'student',
    title: '学生学习风',
    tags: '学生 学习 网课 笔记',
    text:
        '这台 iPad 很适合上网课、刷题、看资料和做笔记，容量日常学习够用，续航表现以电池健康为准。机器已经做过基础功能检查，屏幕触控和声音正常，配合触控笔或键盘会更适合学习场景。',
  ),
  _CopySeed(
    id: 'parent',
    title: '宝妈带娃风',
    tags: '宝妈 带娃 网课 娱乐',
    text:
        '适合给孩子上网课、看绘本、学英语或者家庭娱乐使用。机器操作简单，屏幕显示和声音表现正常，外观细节看实拍。建议到手后按自己的需求安装学习类应用，不预装不承诺额外账号资源。',
  ),
  _CopySeed(
    id: 'office',
    title: '办公生产力风',
    tags: '办公 生产力 出差',
    model: 'iPad Pro',
    text:
        '这台 iPad 适合轻办公、会议记录、文档批注和移动处理资料，搭配键盘或触控笔会更顺手。机身便携，屏幕观感和性能都适合日常工作流，功能检测正常，具体配件以页面写明为准。',
    score: 5,
  ),
  _CopySeed(
    id: 'design',
    title: '设计创作风',
    tags: '设计 绘画 Procreate 专业',
    model: 'iPad Pro',
    text:
        '如果你主要用来画画、修图、做设计或者无纸化创作，这台 iPad 的屏幕和性能会比较合适。触控、显示和常用功能已检查，外观细节看实拍。是否搭配 Apple Pencil 或键盘，以当前配件信息为准。',
    score: 5,
  ),
  _CopySeed(
    id: 'entertainment',
    title: '追剧娱乐风',
    tags: '追剧 娱乐 游戏',
    text:
        '平时追剧、刷视频、看电影和轻度游戏都很合适，屏幕尺寸和扬声器体验比手机舒服很多。机器功能检测正常，电池状态看页面标注，容量足够日常安装常用应用。外观细节都建议结合实拍确认。',
  ),
  _CopySeed(
    id: 'urgent',
    title: '急出回血风',
    tags: '急出 回血 爽快',
    text:
        '这台 iPad 当前整理好直接出，配置、成色和电池信息都写在页面里。功能检测正常，ID 状态已核对，适合想快速入手自用机的朋友。爽快沟通可以优先安排发货，细节图和验机信息都可以补充。',
  ),
  _CopySeed(
    id: 'new_like',
    title: '准新送礼风',
    tags: '准新 全新 送礼 成色好',
    condition: '99新',
    text:
        '这台机器成色比较好，适合对外观要求高、想接近新机体验但又想控制预算的朋友。屏幕、边框和后盖细节以实拍为准，功能检测正常。如果是未激活或未拆封状态，必须以页面和实拍信息为准。',
  ),
  _CopySeed(
    id: 'soft_lifestyle',
    title: '小红书种草风',
    tags: '种草 生活感 温和',
    text:
        '这台 iPad 属于比较百搭的日常平板，学习、追剧、画画、轻办公都能覆盖。外观保持得不错，实际细节看图更直观。整体更适合想要稳定体验、又不想买新机花太多预算的朋友。',
  ),
  _CopySeed(
    id: 'practical',
    title: '实用主义风',
    tags: '实用 耐用 预算',
    text:
        '不追新款、只想买一台稳定好用的 iPad，可以重点看这台。日常上网课、看视频、做笔记、处理文档都够用，功能检测正常。外观和电池按页面信息确认，适合预算有限但想要靠谱体验的买家。',
  ),
  _CopySeed(
    id: 'enthusiast',
    title: '数码爱好者风',
    tags: '数码 准新 高配 细节',
    model: 'iPad Pro',
    text:
        '这台更适合对配置和细节比较在意的买家，容量、网络版本、电池、循环次数和 ID 状态都建议一起看。性能释放和屏幕体验适合长期使用，外观细节以实拍为准，确认清楚再下单更安心。',
    score: 5,
  ),
];
