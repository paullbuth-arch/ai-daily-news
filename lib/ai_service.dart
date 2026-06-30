// AI 服务层 —— 支持主流国产模型（OpenAI 协议）
// 零外部依赖，用 dart:io HttpClient 直接发 HTTP 请求
import 'dart:convert';
import 'dart:io';

// ==================== 模型提供商定义 ====================

class ModelInfo {
  final String label; // 展示名
  final String model; // 模型 ID
  final int score; // 性能评分（越高越强）
  const ModelInfo(this.label, this.model, this.score);
}

class ModelProvider {
  final String name; // 展示名
  final String baseUrl; // Chat API 端点 URL
  final String modelsUrl; // 模型列表 API 端点 URL
  const ModelProvider(this.name, this.baseUrl, this.modelsUrl);
}

const String kDefaultAiProviderName = 'GLM (智谱)';
const String kDefaultAiBaseUrl =
    'https://open.bigmodel.cn/api/paas/v4/chat/completions';
const String kDefaultAiModelsUrl =
    'https://open.bigmodel.cn/api/paas/v4/models';
const String kDefaultAiModel = 'glm-4.7-flash';
const String kDefaultAiVisionModel = 'glm-4.1v-thinking-flash';
const String kDefaultAiApiKey =
    '7caa9ea50e4247c9ac479d0f1d457c04.eh8Big07dnQ3NjV6';

const List<ModelProvider> kModelProviders = [
  ModelProvider(kDefaultAiProviderName, kDefaultAiBaseUrl, kDefaultAiModelsUrl),
  ModelProvider(
    'DeepSeek',
    'https://api.deepseek.com/v1/chat/completions',
    'https://api.deepseek.com/v1/models',
  ),
  ModelProvider(
    'MiniMax',
    'https://api.minimax.chat/v1/chat/completions',
    'https://api.minimax.chat/v1/models',
  ),
  ModelProvider(
    'Kimi (月之暗面)',
    'https://api.moonshot.cn/v1/chat/completions',
    'https://api.moonshot.cn/v1/models',
  ),
  ModelProvider(
    'Qwen (通义千问)',
    'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions',
    'https://dashscope.aliyuncs.com/compatible-mode/v1/models',
  ),
];

// ==================== AI 配置 ====================

class AiConfig {
  final String providerName;
  final String baseUrl;
  final String apiKey;
  final String model; // 自定义模型名（空=未配置）
  final String protocol;

  const AiConfig({
    this.providerName = '',
    this.baseUrl = '',
    this.apiKey = '',
    this.model = '',
    this.protocol = '',
  });

  factory AiConfig.defaultConfig() => const AiConfig(
    providerName: kDefaultAiProviderName,
    baseUrl: kDefaultAiBaseUrl,
    apiKey: kDefaultAiApiKey,
    model: kDefaultAiModel,
    protocol: 'openai',
  );

  factory AiConfig.fromMap(Map<String, dynamic>? m) {
    if (m == null) return AiConfig.defaultConfig();
    return AiConfig(
      providerName: (m['providerName'] as String?) ?? '',
      baseUrl: (m['baseUrl'] as String?) ?? '',
      apiKey: (m['apiKey'] as String?) ?? '',
      model: (m['model'] as String?) ?? '',
      protocol: (m['protocol'] as String?) ?? '',
    );
  }

  AiConfig get effective {
    final d = AiConfig.defaultConfig();
    return AiConfig(
      providerName: providerName.isNotEmpty ? providerName : d.providerName,
      baseUrl: baseUrl.isNotEmpty ? baseUrl : d.baseUrl,
      apiKey: apiKey.isNotEmpty ? apiKey : d.apiKey,
      model: model.isNotEmpty ? model : d.model,
      protocol: protocol.isNotEmpty ? protocol : d.protocol,
    );
  }

  Map<String, dynamic> toMap() => {
    'providerName': providerName,
    'baseUrl': baseUrl,
    'apiKey': apiKey,
    'model': model,
    'protocol': protocol,
  };

  bool get isConfigured =>
      apiKey.isNotEmpty && baseUrl.isNotEmpty && model.isNotEmpty;
}

// ==================== 模型拉取 ====================

/// 判断模型是否偏向"性能强"（排除轻量版，优选 Pro/Plus/Turbo/Max/Ultra）
int _scoreModel(String id) {
  final lower = id.toLowerCase();
  int score = 0;

  // 排除非对话模型
  if (lower.contains('embedding') ||
      lower.contains('moderation') ||
      lower.contains('tts') ||
      lower.contains('whisper') ||
      lower.contains('dall') ||
      lower.contains('image')) {
    return -100;
  }

  // 排除已废弃/下线的
  if (lower.contains('deprecated') ||
      lower.contains('legacy') ||
      lower.contains('old')) {
    return -50;
  }

  // 轻量版/廉价版 → 低分
  if (lower.contains('mini') ||
      lower.contains('lite') ||
      lower.contains('small') ||
      lower.contains('tiny') ||
      lower.contains('nano') ||
      lower.contains('fast')) {
    score -= 30;
  }

  // 高性能版 → 高分
  if (lower.contains('pro')) score += 40;
  if (lower.contains('plus')) score += 35;
  if (lower.contains('turbo')) score += 30;
  if (lower.contains('max')) score += 25;
  if (lower.contains('ultra')) score += 20;
  if (lower.contains('flash')) score += 15; // DeepSeek Flash 系列
  if (lower.contains('code')) score += 5; // 代码模型通常更强

  // 更高版本号 = 更高分（从字符串中提取版本号）
  final versionMatch = RegExp(r'[vV]?(\d+)[\._]?(\d+)?').firstMatch(id);
  if (versionMatch != null) {
    final major = int.tryParse(versionMatch.group(1) ?? '0') ?? 0;
    final minor = int.tryParse(versionMatch.group(2) ?? '0') ?? 0;
    score += major * 10 + minor;
  }

  // 纯文本聊天模型加分（不是多模态/视觉）
  // 视觉模型如果包含 vision/visual 标记，说明是多模态，不一定更强
  if (lower.contains('chat') || lower.contains('general')) score += 5;

  // 模型名越长通常越新/越强（简单 heuristic）
  score += id.length ~/ 2;

  return score;
}

/// 从 API 响应中解析模型列表，返回按性能评分降序排列的列表
/// 失败时返回 null（无兜底）
Future<List<ModelInfo>?> fetchModels(String modelsUrl, String apiKey) async {
  try {
    final uri = Uri.parse(modelsUrl);
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    final req = await client.getUrl(uri);
    req.headers.set('Authorization', 'Bearer $apiKey');
    final resp = await req.close();
    final raw = await resp.transform(utf8.decoder).join();
    client.close();

    if (resp.statusCode != 200) return null;

    final data = json.decode(raw) as Map<String, dynamic>;
    final modelsList = data['data'] as List? ?? [];
    if (modelsList.isEmpty) return null;

    final result = <ModelInfo>[];
    for (final m in modelsList) {
      final id =
          (m is Map
              ? (m['id'] as String? ?? m['model'] as String? ?? '')
              : m.toString());
      if (id.isEmpty) continue;
      final score = _scoreModel(id);
      if (score < 0) continue; // 跳过废弃/非对话模型
      result.add(ModelInfo(id, id, score));
    }

    if (result.isEmpty) return null;

    // 按性能评分降序排列（第一个就是最强的）
    result.sort((a, b) => b.score.compareTo(a.score));
    return result;
  } catch (_) {
    return null;
  }
}

/// 获取提供商对应的 baseUrl
String? providerBaseUrl(String providerName) {
  for (final p in kModelProviders) {
    if (p.name == providerName) return p.baseUrl;
  }
  return null;
}

String? providerModelsUrl(String providerName) {
  for (final p in kModelProviders) {
    if (p.name == providerName) return p.modelsUrl;
  }
  return null;
}

// ==================== AI 服务 ====================

class AiService {
  static AiConfig _config = AiConfig.defaultConfig();
  static AiConfig get config => _config;
  static void setConfig(AiConfig c) => _config = c;
  static AiConfig get effectiveConfig => _config.effective;

  static Future<Map<String, dynamic>> _callOpenAI({
    required String systemPrompt,
    required List<Map<String, dynamic>> messages,
    int maxTokens = 4096,
  }) async {
    final cfg = effectiveConfig;
    if (cfg.baseUrl.isEmpty) return {'error': 'AI配置不完整：缺少 API 端点'};
    if (cfg.model.isEmpty) return {'error': 'AI配置不完整：缺少模型名称'};
    if (cfg.apiKey.isEmpty) return {'error': 'AI配置不完整：缺少 API 密钥'};

    final uri = Uri.parse(cfg.baseUrl);
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 30);

    try {
      final req = await client.postUrl(uri);
      req.headers.contentType = ContentType.json;
      req.headers.set('Authorization', 'Bearer ${cfg.apiKey}');

      final msgs = <Map<String, dynamic>>[
        {'role': 'system', 'content': systemPrompt},
        ...messages,
      ];

      final hasImage = messages.any((m) {
        final content = m['content'];
        return content is List &&
            content.any((item) => item is Map && item['type'] == 'image_url');
      });
      final useBigModelVision =
          hasImage && cfg.baseUrl.contains('open.bigmodel.cn');
      final body = <String, dynamic>{
        'model': useBigModelVision ? kDefaultAiVisionModel : cfg.model,
        'max_tokens': maxTokens,
        'messages': msgs,
      };
      if (cfg.baseUrl.contains('open.bigmodel.cn')) {
        body['temperature'] = 0.7;
        if (!hasImage) body['thinking'] = {'type': 'enabled'};
      }
      req.write(json.encode(body));

      final resp = await req.close().timeout(const Duration(seconds: 90));
      final raw = await resp.transform(utf8.decoder).join();
      client.close();

      if (resp.statusCode != 200) {
        return {
          'error':
              'AI调用失败(${resp.statusCode})：${raw.substring(0, raw.length > 200 ? 200 : raw.length)}',
        };
      }

      final data = json.decode(raw) as Map<String, dynamic>;
      return {'data': data};
    } catch (e) {
      client.close();
      return {'error': 'AI调用异常：$e'};
    }
  }

  static String _extractOpenAIText(Map<String, dynamic> data) {
    final choices = data['choices'] as List? ?? [];
    if (choices.isEmpty) return 'AI返回为空';
    final first = choices[0] as Map<String, dynamic>;
    final message = first['message'] as Map<String, dynamic>?;
    if (message == null) return 'AI返回为空';
    final content = message['content'] as String?;
    if (content != null && content.isNotEmpty) return content;
    final finishReason = first['finish_reason'] as String?;
    if (finishReason == 'length') {
      return 'AI返回内容为空（输出被 max_tokens 截断，请尝试增大 max_tokens）';
    }
    final reasoning = message['reasoning_content'] as String?;
    if (reasoning != null && reasoning.isNotEmpty) {
      return 'AI返回内容为空（reasoning 内容已生成但未输出最终文本，请尝试增大 max_tokens）';
    }
    return 'AI返回内容为空';
  }

  static Future<String> chat(
    String systemPrompt,
    String userPrompt, {
    int maxTokens = 4096,
  }) async {
    final result = await _callOpenAI(
      systemPrompt: systemPrompt,
      messages: [
        {'role': 'user', 'content': userPrompt},
      ],
      maxTokens: maxTokens,
    );
    if (result['error'] != null) return result['error'] as String;
    return _extractOpenAIText(result['data'] as Map<String, dynamic>);
  }

  static Future<String> chatWithImage(
    String systemPrompt,
    String imageBase64,
    String textPrompt, {
    int maxTokens = 4096,
  }) async {
    final result = await _callOpenAI(
      systemPrompt: systemPrompt,
      messages: [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image_url',
              'image_url': {'url': 'data:image/jpeg;base64,$imageBase64'},
            },
            {'type': 'text', 'text': textPrompt},
          ],
        },
      ],
      maxTokens: maxTokens,
    );
    if (result['error'] != null) return result['error'] as String;
    return _extractOpenAIText(result['data'] as Map<String, dynamic>);
  }

  static Future<Map<String, String>> recognizeAboutThisDevice(
    String imageBase64,
  ) async {
    final sys =
        '你是苹果设备信息识别专家。用户会上传一张iPad"关于本机"页面的截图。'
        '请从截图中识别出以下信息并严格以JSON格式返回：\n'
        '{"serial":"序列号","model":"型号名称","capacity":"容量","color":"颜色","network":"网络制式","batteryHealth":"电池健康度百分比数字","cycleCount":"循环次数数字"}\n'
        '如果某项信息无法识别，对应字段填"未知"。只返回JSON，不要返回其他文字。';
    final result = await chatWithImage(
      sys,
      imageBase64,
      '请识别这张iPad关于本机截图中的信息。',
      maxTokens: 2048,
    );
    try {
      String jsonStr = result;
      final jsonMatch = RegExp(r'\{[^{}]+\}').firstMatch(jsonStr);
      if (jsonMatch != null) jsonStr = jsonMatch.group(0)!;
      final map = json.decode(jsonStr) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      final serialMatch = RegExp(r'[A-Z0-9]{8,12}').firstMatch(result);
      return {
        'serial': serialMatch?.group(0) ?? '未知',
        'model': '未知',
        'capacity': '未知',
        'color': '未知',
        'network': '未知',
        'batteryHealth': '未知',
        'cycleCount': '未知',
        '_raw': result,
      };
    }
  }

  static Future<String> priceAdvice({
    required String model,
    required String capacity,
    required String color,
    required String network,
    required String condition,
    required int batteryHealth,
    required int purchaseCost,
    required int stockDays,
  }) async {
    final sys =
        '你是二手iPad定价专家。根据设备型号、容量、成色、电池健康、采购成本、库存周转天数，给出定价建议。'
        '输出格式：建议售价¥X，可接受最低价¥Y，建议采购上限价¥Z，定价理由（一句话）。金额单位元。';
    return chat(
      sys,
      '设备：$model $capacity $color $network，成色$condition，电池健康度$batteryHealth%，'
      '采购成本${(purchaseCost / 100).toStringAsFixed(0)}元，已在库$stockDays天。请给出定价建议。',
      maxTokens: 2048,
    );
  }

  static Future<String> dailyReport({
    required int gmv,
    required int grossProfit,
    required int orderCount,
    required int inStock,
    required int stagnant,
    required int capital,
    required List<String> stagnantModels,
  }) async {
    final sys =
        '你是二手iPad生意经营顾问。用结构化格式输出今日经营日报。'
        '严格用以下固定格式（emoji标记不能少，每条不超过20字）：\n'
        '【亮点】\n• xxx（今日表现好的地方，不超过3条）\n\n'
        '【待关注】\n• xxx（需要留意的问题，不超过3条）\n\n'
        '【明日建议】\n• xxx（具体可执行的行动，不超过3条）\n\n'
        '不要多余的文字。';
    return chat(
      sys,
      '今日GMV ${(gmv / 100).toStringAsFixed(0)}元，毛利${(grossProfit / 100).toStringAsFixed(0)}元'
      '（毛利率${gmv > 0 ? (grossProfit / gmv * 100).toStringAsFixed(1) : 0}%），订单$orderCount单。'
      '在售$inStock台，滞销$stagnant台，资金占用${(capital / 100).toStringAsFixed(0)}元。'
      '滞销机型：${stagnantModels.isEmpty ? "无" : stagnantModels.join("、")}。请生成日报。',
      maxTokens: 2048,
    );
  }

  static Future<String> customerService(String question) async {
    return chat(
      '你是二手iPad客服助手，回答买家关于成色、电池、价格、保修等问题。态度热情专业，回答简洁。',
      question,
      maxTokens: 1024,
    );
  }

  static Future<String> purchaseAdvice(String recentSalesSummary) async {
    return chat(
      '你是二手iPad采购顾问。根据近期销售情况，给出补货建议：该补哪些型号、补多少、采购上限价多少。',
      '近期销售：$recentSalesSummary\n请给出本周采购建议。',
      maxTokens: 2048,
    );
  }

  static Future<String> generateDescription({
    required String model,
    required String capacity,
    required String color,
    required String network,
    required String condition,
    required int batteryHealth,
    required int cycleCount,
    required bool idLockClean,
    String accessories = '裸机',
  }) async {
    final sys =
        '你是闲鱼二手iPad商品文案专家。根据给定的设备准确信息，写一段真实、专业、有吸引力的商品描述。'
        '要求：①突出成色、电池健康、ID锁状态等买家最关心的点；②语言自然不浮夸，不夸大；③包含配置亮点和适用场景；'
        '④100-180字，纯文本不带emoji和特殊符号、不带价格；⑤不要分点编号，写成流畅的一段话。';
    final r = await chat(
      sys,
      '请为以下设备写商品描述：\n型号：$model\n容量：$capacity\n颜色：$color\n网络：$network\n成色：$condition\n'
      '电池健康度：$batteryHealth%\n充电循环：$cycleCount次\nID锁：${idLockClean ? "无锁（干净）" : "有锁"}\n配件：$accessories',
      maxTokens: 2048,
    );
    if (r.startsWith('AI调用') || r.startsWith('AI返回')) return r;
    return r.trim();
  }

  static Future<String?> testConnection() async {
    try {
      final r = await chat('你是连接测试助手', '请回复 ok', maxTokens: 256);
      if (r.startsWith('AI调用') || r.startsWith('AI返回')) return r;
      return null;
    } catch (e) {
      return '异常：$e';
    }
  }

  static Future<String> purchaseDecision({
    required String model,
    required int purchaseCost,
    required int quantity,
    required Map<String, dynamic> analysis,
    Map<String, dynamic>? marketPrice,
    List<Map<String, dynamic>>? marketHistory,
  }) async {
    final sys =
        '你是二手iPad采购决策顾问。综合"今日市场行情、历史销售数据、拟采购成本"判断"是否建议按此成本采购该数量"。'
        '输出格式：\n【结论】建议收 / 谨慎收 / 不建议\n【理由】不超过3条\n【风险】1条\n中文，简洁，总字数≤260。';
    final a = analysis;
    final suppliersStr = (a['suppliers'] as List)
        .map(
          (s) =>
              '${s['channel']}(${s['count']}台,均利${((s['profit'] as int) / 100).toStringAsFixed(0)}元)',
        )
        .join('、');
    String marketStr = '无今日行情数据', trendStr = '';
    if (marketPrice != null) {
      final mp = (marketPrice['price'] as int) ~/ 100;
      final diff = mp - (purchaseCost ~/ 100);
      final margin = mp > 0 ? (diff / mp * 100).toStringAsFixed(1) : '0';
      marketStr =
          '今日批发价${mp}元（${marketPrice['date']}），采购成本${(purchaseCost / 100).toStringAsFixed(0)}元，差价${diff > 0 ? "+" : ""}$diff元（毛利率$margin%）';
      if (marketHistory != null && marketHistory.length >= 2) {
        final oldest = (marketHistory.first['price'] as int) ~/ 100;
        final newest = (marketHistory.last['price'] as int) ~/ 100;
        final change = newest - oldest;
        final pct =
            oldest > 0 ? (change / oldest * 100).toStringAsFixed(1) : '0';
        trendStr =
            '\n- 行情趋势：近${marketHistory.length}天从${oldest}元→${newest}元（${change > 0
                ? "↑"
                : change < 0
                ? "↓"
                : "→"}${pct}%）';
      }
    }
    return chat(
      sys,
      '型号：$model\n拟采购：${(purchaseCost / 100).toStringAsFixed(0)}元/台 × $quantity 台\n'
      '市场行情：\n- $marketStr$trendStr\n历史数据：\n销量${a['salesCount']}台，在售${a['inStockCount']}台，'
      '滞销${a['stagnantCount']}台（压货率${((a['stagnantRate'] as double) * 100).toStringAsFixed(0)}%）\n'
      '均售价${((a['avgSellPrice'] as int) / 100).toStringAsFixed(0)}元，均采购成本${((a['avgPurchaseCost'] as int) / 100).toStringAsFixed(0)}元，'
      '均单台利润${((a['avgProfit'] as int) / 100).toStringAsFixed(0)}元\n平均周转${a['avgTurnoverDays']}天\n'
      '供应商：${suppliersStr.isEmpty ? "无历史" : suppliersStr}\n请给出采购决策。',
      maxTokens: 4096,
    );
  }
}
