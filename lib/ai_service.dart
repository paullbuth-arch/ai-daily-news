// AI 服务层 —— 支持主流国产模型（OpenAI 协议）
// 零外部依赖，用 dart:io HttpClient 直接发 HTTP 请求
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'ai_prompts.dart';

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
const String kDefaultAiModel = 'GLM-4-Flash-250414';
const String kDefaultAiVisionModel = 'GLM-4.1V-Thinking-Flash';
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
  static Map<String, String> _promptRules = {};
  static const int _bigModelVisionConcurrencyLimit = 5;
  static int _bigModelVisionInFlight = 0;
  static final List<Completer<void>> _bigModelVisionQueue = <Completer<void>>[];
  static AiConfig get config => _config;
  static void setConfig(AiConfig c) => _config = c;
  static AiConfig get effectiveConfig => _config.effective;
  static void setPromptRules(Map<String, String> rules) =>
      _promptRules = Map<String, String>.from(rules);
  static String prompt(String key) => AiPrompts.resolve(key, _promptRules);

  static Future<T> _withBigModelVisionGate<T>(Future<T> Function() task) async {
    await _acquireBigModelVisionSlot();
    try {
      return await task();
    } finally {
      _releaseBigModelVisionSlot();
    }
  }

  static Future<void> _acquireBigModelVisionSlot() {
    if (_bigModelVisionInFlight < _bigModelVisionConcurrencyLimit) {
      _bigModelVisionInFlight++;
      return Future.value();
    }
    final waiter = Completer<void>();
    _bigModelVisionQueue.add(waiter);
    return waiter.future;
  }

  static void _releaseBigModelVisionSlot() {
    if (_bigModelVisionQueue.isNotEmpty) {
      final waiter = _bigModelVisionQueue.removeAt(0);
      if (!waiter.isCompleted) waiter.complete();
      return;
    }
    if (_bigModelVisionInFlight > 0) _bigModelVisionInFlight--;
  }

  static Future<Map<String, dynamic>> _callOpenAI({
    required String systemPrompt,
    required List<Map<String, dynamic>> messages,
    int maxTokens = 4096,
    bool jsonResponse = false,
  }) async {
    final cfg = effectiveConfig;
    if (cfg.baseUrl.isEmpty) return {'error': 'AI配置不完整：缺少 API 端点'};
    if (cfg.model.isEmpty) return {'error': 'AI配置不完整：缺少模型名称'};
    if (cfg.apiKey.isEmpty) return {'error': 'AI配置不完整：缺少 API 密钥'};

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
    if (jsonResponse) {
      body['response_format'] = {'type': 'json_object'};
    }
    if (cfg.baseUrl.contains('open.bigmodel.cn')) {
      body['temperature'] = hasImage ? 0.1 : 0.7;
      body['thinking'] = {'type': hasImage ? 'disabled' : 'enabled'};
    }

    Future<Map<String, dynamic>> sendRequest() async {
      final uri = Uri.parse(cfg.baseUrl);
      for (var attempt = 0; attempt < 2; attempt++) {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 30);
        try {
          final req = await client.postUrl(uri);
          req.headers.contentType = ContentType.json;
          req.headers.set('Authorization', 'Bearer ${cfg.apiKey}');
          req.write(json.encode(body));

          final resp = await req.close().timeout(const Duration(seconds: 90));
          final raw = await resp.transform(utf8.decoder).join();
          client.close();

          if (resp.statusCode != 200) {
            if (_retryableStatus(resp.statusCode) && attempt == 0) {
              await Future<void>.delayed(const Duration(milliseconds: 600));
              continue;
            }
            return {
              'error':
                  'AI调用失败(${resp.statusCode})：${raw.substring(0, raw.length > 200 ? 200 : raw.length)}',
            };
          }

          final data = json.decode(raw) as Map<String, dynamic>;
          return {'data': data};
        } catch (e) {
          client.close(force: true);
          if (attempt == 0) {
            await Future<void>.delayed(const Duration(milliseconds: 600));
            continue;
          }
          return {'error': 'AI调用异常：$e'};
        }
      }
      return {'error': 'AI调用异常：重试后仍无响应'};
    }

    return useBigModelVision
        ? _withBigModelVisionGate(sendRequest)
        : sendRequest();
  }

  static bool _retryableStatus(int statusCode) =>
      statusCode == 408 || statusCode == 429 || statusCode >= 500;

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

  static Map<String, dynamic>? _decodeJsonObjectFromAi(String result) {
    final candidates = <String>[];
    candidates.add(result.trim());
    for (final match in RegExp(
      r'<answer>([\s\S]*?)</answer>',
      caseSensitive: false,
    ).allMatches(result)) {
      candidates.add(match.group(1) ?? '');
    }
    for (final match in RegExp(
      r'```(?:json)?\s*([\s\S]*?)```',
      caseSensitive: false,
    ).allMatches(result)) {
      candidates.add(match.group(1) ?? '');
    }
    final withoutThink = result.replaceAll(
      RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false),
      '',
    );
    candidates.addAll(_jsonObjectCandidates(withoutThink).reversed);
    candidates.addAll(_jsonObjectCandidates(result).reversed);

    for (final candidate in candidates) {
      final text = candidate.trim();
      if (text.isEmpty) continue;
      try {
        final decoded = json.decode(text);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) return item;
            if (item is Map) return Map<String, dynamic>.from(item);
          }
        }
      } catch (_) {}
    }
    return null;
  }

  static List<String> _jsonObjectCandidates(String text) {
    final candidates = <String>[];
    var start = -1;
    var depth = 0;
    var inString = false;
    var escape = false;
    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (inString) {
        if (escape) {
          escape = false;
        } else if (char == '\\') {
          escape = true;
        } else if (char == '"') {
          inString = false;
        }
        continue;
      }
      if (char == '"') {
        inString = true;
        continue;
      }
      if (char == '{') {
        if (depth == 0) start = i;
        depth++;
      } else if (char == '}' && depth > 0) {
        depth--;
        if (depth == 0 && start >= 0) {
          candidates.add(text.substring(start, i + 1));
          start = -1;
        }
      }
    }
    return candidates;
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
    bool jsonResponse = false,
  }) async {
    final image = imageBase64.trim();
    final imageUrl =
        image.startsWith('data:image/')
            ? image
            : 'data:image/jpeg;base64,$image';
    final result = await _callOpenAI(
      systemPrompt: systemPrompt,
      messages: [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image_url',
              'image_url': {'url': imageUrl},
            },
            {'type': 'text', 'text': textPrompt},
          ],
        },
      ],
      maxTokens: maxTokens,
      jsonResponse: jsonResponse,
    );
    if (result['error'] != null) return result['error'] as String;
    return _extractOpenAIText(result['data'] as Map<String, dynamic>);
  }

  static Future<String> chatWithImages(
    String systemPrompt,
    List<String> imageBase64List,
    String textPrompt, {
    int maxTokens = 4096,
    bool jsonResponse = false,
  }) async {
    final content = <Map<String, dynamic>>[];
    for (final imageBase64 in imageBase64List) {
      final image = imageBase64.trim();
      final url =
          image.startsWith('data:image/')
              ? image
              : 'data:image/jpeg;base64,$image';
      content.add({
        'type': 'image_url',
        'image_url': {'url': url},
      });
    }
    content.add({'type': 'text', 'text': textPrompt});
    final result = await _callOpenAI(
      systemPrompt: systemPrompt,
      messages: [
        {'role': 'user', 'content': content},
      ],
      maxTokens: maxTokens,
      jsonResponse: jsonResponse,
    );
    if (result['error'] != null) return result['error'] as String;
    return _extractOpenAIText(result['data'] as Map<String, dynamic>);
  }

  static Future<Map<String, String>> recognizeAboutThisDevice(
    String imageBase64,
  ) async {
    final sys = prompt(AiPromptKeys.recognizeAboutDevice);
    final result = await chatWithImage(
      sys,
      imageBase64,
      '请识别这张iPad关于本机截图中的信息。',
      maxTokens: 1536,
      jsonResponse: true,
    );
    try {
      final map = _decodeJsonObjectFromAi(result);
      if (map == null) throw const FormatException('AI返回格式无法解析');
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

  static Future<Map<String, dynamic>> recognizeAboutDeviceOcr(
    String imageBase64,
  ) async {
    if (imageBase64.trim().isEmpty) {
      return {'error': '请先上传关于本机图片'};
    }
    const sys = '''
你只做单张 iPad“关于本机/设置/验机文字页”的 OCR 识别。
目标是读取图片中真实可见文字，尤其是型号名称、型号/订货号、序列号、容量、系统版本、可用容量、网络信息。

强制规则：
1. 优先逐字抄写图片里的原文，不要凭外观、摄像头、边框、颜色猜型号。
2. 如果图片不是“关于本机/设置/验机文字页”，isAboutDevicePage 填 false，关键字段填"未知"，confidence 不得超过 0.35。
3. modelNameRaw/modelEvidenceText/partNumberRaw/serialRaw/capacityRaw 必须尽量保留图片里的原文。
4. model 可以写成 App 常用标准型号，但只能来自清晰文字证据；不确定就填"未知"。例如：
   - 图里写 iPad mini（第6代）或 iPad mini (6th generation)，model 写 iPad mini 6 (A15)，不要写 mini 7。
   - 图里写 iPad Pro（11英寸）（第2代）或 iPad Pro 11-inch (2nd generation)，model 写 iPad Pro 11 2020 (A12Z)，不要写 2024/M4。
   - 只有图里清晰出现 2024、M4、Ultra Retina、OLED 这类直接证据时，才允许 model 写 2024/M4。
5. capacity 只根据容量字段读取，输出 64G/128G/256G/512G/1TB/未知。
6. serial/serialRaw 只填写看清楚的 10-12 位序列号，不能把型号、系统版本、容量当序列号。
7. network 只有图片文字能确认蜂窝/Cellular/5G/无线局域网等信息时填写 WiFi 或 WiFi+蜂窝，否则"未知"。
8. 输出必须是严格 JSON，不要 Markdown，不要解释。

JSON 字段：
{
  "isAboutDevicePage": true,
  "serial": "序列号或未知",
  "serialRaw": "图片中逐字读到的序列号或未知",
  "model": "标准型号或未知",
  "modelName": "型号名称原文或未知",
  "modelNameRaw": "型号名称原文或未知",
  "modelEvidenceText": "型号相关原始证据汇总或未知",
  "modelNumber": "Axxxx 或未知",
  "partNumber": "订货号如 MLWL3CH/A 或未知",
  "partNumberRaw": "订货号原文或未知",
  "capacity": "64G/128G/256G/512G/1TB/未知",
  "capacityRaw": "容量原文或未知",
  "availableRaw": "可用容量原文或未知",
  "ipadOS": "系统版本原文或未知",
  "network": "WiFi/WiFi+蜂窝/未知",
  "fieldConfidence": {
    "serial": 0.0,
    "serialRaw": 0.0,
    "model": 0.0,
    "modelName": 0.0,
    "modelNameRaw": 0.0,
    "modelEvidenceText": 0.0,
    "modelNumber": 0.0,
    "partNumber": 0.0,
    "partNumberRaw": 0.0,
    "capacity": 0.0,
    "capacityRaw": 0.0,
    "availableRaw": 0.0,
    "ipadOS": 0.0,
    "network": 0.0
  },
  "confidence": 0.0,
  "warnings": []
}
''';
    final result = await chatWithImage(
      sys,
      imageBase64,
      '请只读取这张图片中的可见文字，并返回严格 JSON。',
      maxTokens: 1536,
      jsonResponse: true,
    );
    if (result.startsWith('AI调用') || result.startsWith('AI返回')) {
      return {'error': result};
    }
    final decoded = _decodeJsonObjectFromAi(result);
    return decoded ?? {'error': 'AI返回格式无法解析', '_raw': result};
  }

  static Future<Map<String, dynamic>> recognizeIpadIntake(
    List<String> imageBase64List, {
    bool supplemental = false,
    bool croppedRegions = false,
    int totalImageCount = 0,
    List<String> focusFields = const [],
  }) async {
    if (imageBase64List.isEmpty) {
      return {'error': '请先上传设备图片'};
    }
    if (croppedRegions && !supplemental) {
      return _recognizeFastCroppedIpadIntake(
        imageBase64List,
        totalImageCount: totalImageCount,
      );
    }
    final modePrompt =
        supplemental
            ? '本次只是在主识别缺字段时补看后续图片，重点字段：${focusFields.isEmpty ? "缺失字段" : focusFields.join("、")}。只填写图片中能直接确认的信息；后续外观图只能补充颜色/配件/可见风险，不能推翻关于本机、设置页、爱思/沙漏图里的文字证据，也不要根据外观猜型号。'
            : '本次是主识别：默认优先看图1、图2、图3。图1/图2通常是关于本机或设置截图，用来确认型号、容量、序列号、网络；图3通常是爱思/沙漏验机图，用来确认电池健康、充电次数、全绿状态、零售机/官换机。后续外观图不能推翻图1/图2/图3里的文字证据；如果文字证据不足，宁可返回"未知"，不要为了补齐字段而猜测。';
    final countPrompt = totalImageCount > 0 ? '用户本次共上传$totalImageCount张图。' : '';
    final cropPrompt =
        croppedRegions
            ? '本次传入的是自动框选后的关键区域裁剪图，通常包含：关于本机右侧信息区、爱思/沙漏检测表、底部电池寿命/充电次数信息栏。请把这些裁剪图当作原图证据读取，优先识别文字，不要因为缺少整机外观而降低关于本机和验机报告字段置信度。'
            : '';
    const sys = '''
你是二手 iPad 入库验货助手。你会同时看到最多 12 张图片，可能包含：
- 设置 > 关于本机截图
- 电池健康/循环截图
- 机身正反面、边框、接口、屏幕、配件、瑕疵近照

请只根据图片可见内容判断，不要编造。看不清就填"未知"，并在 warnings 里说明。
图片优先级：
1. 图1优先级最高，一般是“关于本机”。型号名称、订货号、序列号、容量、系统里显示的网络信息，以图1清晰文字为准。
2. 图2作为第二优先级，可用于交叉确认；如果它只是本 App 的识别结果页或非原始检测来源，不要用它覆盖图1/图3。
3. 图3一般是爱思/沙漏验机报告。优先从这里读取电池健康、充电次数、验机是否全绿、零售机/官换机/官修机状态。
   - 爱思/沙漏报告里的“电池寿命 93%”必须输出 batteryHealth="93"、batteryHealthRaw="电池寿命 93%"。
   - 爱思/沙漏报告里的“充电次数 676次”必须输出 cycleCount="676"、cycleCountRaw="充电次数 676次"。
   - 爱思/沙漏报告里的“设备型号/销售型号/监管型号”要写入 modelEvidenceText，例如“11寸 iPad Pro 第2代 / MY252 / A2228”。
4. 外观实拍图只可辅助颜色判断，不能用来猜代数、容量、网络或电池。
5. 后续补看图片只能补缺失字段，不能覆盖已经从关于本机、设置页、爱思/沙漏图中读到的直接文字证据。
外观和屏幕瑕疵由人工勾选录入，你不要替用户判断划痕、磕碰、掉漆、屏幕出线、亮点、坏点、压伤、漏液等外观细节。
你只负责补全图片里能稳定读到或能清晰判断的设备信息：序列号、型号、容量、颜色、网络、电池健康、循环次数、配件、可见锁机/监管风险。
强制规则：
1. serial/model/capacity/network/batteryHealth/cycleCount 只有在图片里出现清晰文字、关于本机截图、系统设置页、电池截图、机身铭牌、可读 Axxxx 型号或 MLWL3CH/A 这类订货号时才填写；否则必须填"未知"。
2. 不要根据外观比例、摄像头位置、边框宽窄猜具体型号或容量。没有清晰证据时 model/capacity/network 填"未知"。
3. color 可以参考清晰实拍图；遇到保护壳、贴膜、反光、偏色、遮挡、光线不足时必须填"未知"。
4. iCloudLock/activationLock/mdm/configLock 只有在设置页、锁屏提示、监管提示或清晰文字证据可见时判断；否则保持 false，并在 fieldConfidence 对应字段给 0。
5. confidence 低于 0.72 时，关键字段必须保守，宁可多写"未知"，不要给用户制造错误回填。
6. fieldConfidence 是每个字段的可信度，0 到 1；没有直接证据的字段必须低于 0.6。
7. condition 不要根据外观推断；默认填"未知"，由人工成色和外观勾选决定。
8. appearanceDefects 和 screenDefects 必须返回空数组 []。checks 里的外观边框/后盖/屏幕显示等外观项填"未知"，不要写"正常"。
9. 普通远景照片不能给 confidence 1.0。照片角度不足、虚焦、反光、遮挡时 confidence 必须低于 0.75。
10. iPad mini 6 和 iPad mini 7 外观相似，严禁凭外观猜代数。关于本机写着"iPad mini（第6代）"、"iPad mini (6th generation)"、A2567/A2568/A2569 或 MLWL3CH/A 时，model 必须是 "iPad mini 6 (A15)"，不能写 mini 7。
11. 严禁把旧款 iPad Pro 识别成 2024/M4。只有图片里清晰出现 "2024"、"M4"、"Ultra Retina"、"OLED" 这类新款直接证据时，model 才允许写 2024/M4；否则必须写"未知"或按可见原文保守输出。
12. 关于本机或爱思报告写着"iPad Pro（11英寸）（第2代）"、"iPad Pro 11-inch (2nd generation)"、"A2228"、"MY252" 时，不能输出 2024/M4；如果你不能稳定映射到可选型号，就把 model 填"未知"，并把原始文字写进 modelEvidenceText。
13. 爱思/沙漏验机报告中如果“零售机/官换机/官修机/全绿/异常”文字清晰可见，需要写入 machineType、allGreen、inspectionSummary；看不清填"未知"。
14. 必须保留原始证据：serialRaw/capacityRaw/modelEvidenceText 要写从图里逐字读到的内容。最终 serial/capacity/model 不得与原始证据冲突；冲突时最终字段填"未知"。
输出必须是严格 JSON，不要 Markdown，不要解释。

JSON 字段：
{
  "serial": "序列号或未知",
  "serialRaw": "图中逐字读到的序列号原文或未知",
  "model": "最接近的 iPad 型号，如 iPad mini 6 (A15)，未知则未知",
  "modelName": "关于本机里看到的型号名称原文，如 iPad mini（第6代）或未知",
  "modelEvidenceText": "型号相关原始证据，如 关于本机型号名称/型号/监管型号/爱思设备型号/销售型号",
  "modelNumber": "Axxxx 型号或未知",
  "partNumber": "MLWL3CH/A 这类订货号或未知",
  "generation": "第几代/芯片证据，如 第6代/A15/未知",
  "capacity": "64G/128G/256G/512G/1TB/未知",
  "capacityRaw": "图中逐字读到的容量原文或未知",
  "color": "深空灰/银色/星光色/粉色/紫色/蓝色/玫瑰金/金色/绿色/黄色/未知",
  "network": "WiFi/WiFi+蜂窝/未知",
  "condition": "全新/99新/95新/9成新/8成新/7成新/未知",
  "batteryHealth": "数字百分比，不带%或未知",
  "batteryHealthRaw": "验机报告或电池页原文，如 电池寿命 93% 或未知",
  "cycleCount": "数字或未知",
  "cycleCountRaw": "验机报告或电池页原文，如 充电次数 676次 或未知",
  "inspectionTool": "爱思/沙漏/系统设置/未知",
  "machineType": "零售机/官换机/官修机/演示机/未知",
  "allGreen": "true/false/未知",
  "inspectionSummary": "验机报告核心结论，如 爱思全绿零售机/未知",
  "inspectionEvidenceText": "验机报告中逐字读到的关键原文汇总，如 设备型号/销售型号/监管型号/电池寿命/充电次数",
  "accessories": "裸机/盒装/原装充电器/妙控键盘/Apple Pencil/未知",
  "idLockClean": true,
  "iCloudLock": false,
  "activationLock": false,
  "mdm": false,
  "configLock": false,
  "fieldConfidence": {
    "serial": 0.0,
    "serialRaw": 0.0,
    "model": 0.0,
    "modelName": 0.0,
    "modelEvidenceText": 0.0,
    "modelNumber": 0.0,
    "partNumber": 0.0,
    "generation": 0.0,
    "capacity": 0.0,
    "capacityRaw": 0.0,
    "color": 0.0,
    "network": 0.0,
    "condition": 0.0,
    "batteryHealth": 0.0,
    "batteryHealthRaw": 0.0,
    "cycleCount": 0.0,
    "cycleCountRaw": 0.0,
    "inspectionTool": 0.0,
    "machineType": 0.0,
    "allGreen": 0.0,
    "inspectionSummary": 0.0,
    "inspectionEvidenceText": 0.0,
    "iCloudLock": 0.0,
    "activationLock": 0.0,
    "mdm": 0.0,
    "configLock": 0.0,
    "lockStatus": 0.0
  },
  "appearanceSummary": "一句话概括外观",
  "functionSummary": "一句话概括功能/屏幕/按键/接口/摄像头等",
  "defectSummary": "外观问题由人工勾选记录",
  "appearanceDefects": [],
  "screenDefects": [],
  "confidence": 0.0,
  "warnings": ["需要人工复核的点"],
  "checks": {
    "屏幕显示": "正常/异常/未知",
    "屏幕触控": "正常/异常/未知",
    "外观边框": "正常/轻微磕碰/明显磕碰/未知",
    "后盖": "正常/划痕/凹陷/未知",
    "摄像头": "正常/异常/未知",
    "充电接口": "正常/异常/未知",
    "按键": "正常/异常/未知",
    "扬声器": "正常/异常/未知",
    "麦克风": "正常/异常/未知",
    "WiFi": "正常/异常/未知",
    "蓝牙": "正常/异常/未知",
    "ID锁": "无/有/未知"
  }
}
''';
    final result = await chatWithImages(
      sys,
      imageBase64List,
      '$countPrompt$cropPrompt$modePrompt\n请识别这批 iPad 入库图片，并返回严格 JSON。',
      maxTokens: 3072,
      jsonResponse: true,
    );
    if (result.startsWith('AI调用') || result.startsWith('AI返回')) {
      return {'error': result};
    }
    final decoded = _decodeJsonObjectFromAi(result);
    return decoded ?? {'error': 'AI返回格式无法解析', '_raw': result};
  }

  static Future<Map<String, dynamic>> _recognizeFastCroppedIpadIntake(
    List<String> imageBase64List, {
    int totalImageCount = 0,
  }) async {
    final countPrompt = totalImageCount > 0 ? '用户本次共上传$totalImageCount张图。' : '';
    const sys = '''
你是二手 iPad 入库的三图定向识别助手。本次只会看到前三张上传原图的自动裁剪区域；第4张上传原图及后续原图不会提供，也不要推断。

裁剪图顺序固定：
1. 第1张上传图的背面颜色采样点A，只用于判断机身颜色。
2. 第1张上传图的背面颜色采样点B，只用于判断机身颜色。
3. 第2张上传图的“关于本机”信息区域，用于读取型号名称、订货号、序列号、容量、系统版本。
4. 第3张上传图的爱思/沙漏中下方信息区域，用于读取电池寿命、充电次数、激活/越狱/锁状态、序列号匹配、五码匹配。

强制规则：
1. 只读取这些裁剪图中清晰可见的信息。不要根据外观猜型号、容量、网络、电池。
2. 第1、2张裁剪图只判断颜色，不要从它们读取贴纸、序列号、容量或电池字段。
3. 型号、序列号、容量必须优先来自第3张“关于本机”裁剪图。
4. 电池健康度、充电次数必须优先来自第4张爱思/沙漏底部裁剪图，并且只输出纯数字。例如“电池寿命 93%”输出 batteryHealth="93"；“充电次数 676次”输出 cycleCount="676"。
5. 如果容量显示“128 GB/256 GB/512 GB/1 TB”，capacity 分别输出 128G/256G/512G/1TB。
6. 如果关于本机写着“iPad Pro（11英寸）（第2代）/ MY252 / A2228”，model 输出 "iPad Pro 11 2020 (A12Z)"，不要输出 2024/M4。
7. 如果爱思底部显示“Apple ID锁 未开启/激活状态 已激活/越狱状态 未越狱/Wi-Fi模块 高通Wi-Fi/序列号匹配 是/五码匹配 是”，写入 inspectionEvidenceText，可把 idLockClean 写 true；看不清就保持 false 并降低置信度。
8. 输出必须是严格 JSON，不要 Markdown，不要解释。

JSON 字段：
{
  "serial": "序列号或未知",
  "serialRaw": "序列号原文或未知",
  "model": "标准型号或未知",
  "modelName": "型号名称原文或未知",
  "modelEvidenceText": "型号相关原文或未知",
  "modelNumber": "Axxxx 或未知",
  "partNumber": "订货号或未知",
  "capacity": "64G/128G/256G/512G/1TB/未知",
  "capacityRaw": "容量原文或未知",
  "color": "颜色或未知",
  "network": "WiFi/WiFi+蜂窝/未知",
  "batteryHealth": "纯数字或未知",
  "batteryHealthRaw": "电池健康原文或未知",
  "cycleCount": "纯数字或未知",
  "cycleCountRaw": "充电次数原文或未知",
  "inspectionTool": "爱思/沙漏/系统设置/本App截图/未知",
  "machineType": "零售机/官换机/官修机/演示机/未知",
  "allGreen": "true/false/未知",
  "inspectionSummary": "核心结论或未知",
  "inspectionEvidenceText": "关键原文汇总或未知",
  "idLockClean": true,
  "iCloudLock": false,
  "activationLock": false,
  "mdm": false,
  "configLock": false,
  "fieldConfidence": {
    "serial": 0.0,
    "model": 0.0,
    "capacity": 0.0,
    "color": 0.0,
    "network": 0.0,
    "batteryHealth": 0.0,
    "cycleCount": 0.0,
    "inspectionTool": 0.0,
    "machineType": 0.0,
    "allGreen": 0.0,
    "lockStatus": 0.0
  },
  "confidence": 0.0,
  "warnings": []
}
''';
    final result = await chatWithImages(
      sys,
      imageBase64List,
      '$countPrompt请快速读取这些裁剪区域，返回严格 JSON。核心字段看不清就填"未知"。',
      maxTokens: 1280,
      jsonResponse: true,
    );
    if (result.startsWith('AI调用') || result.startsWith('AI返回')) {
      return {'error': result};
    }
    final decoded = _decodeJsonObjectFromAi(result);
    return decoded ?? {'error': 'AI返回格式无法解析', '_raw': result};
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
    final sys = prompt(AiPromptKeys.priceAdvice);
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
    final sys = prompt(AiPromptKeys.dailyReport);
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
      prompt(AiPromptKeys.customerService),
      question,
      maxTokens: 1024,
    );
  }

  static Future<String> purchaseAdvice(String recentSalesSummary) async {
    return chat(
      prompt(AiPromptKeys.purchaseAdvice),
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
    String defectNote = '',
    String copywritingReference = '',
    String previousDescription = '',
  }) async {
    final reference = copywritingReference.trim();
    final previous = previousDescription.trim();
    final variantSeed = DateTime.now().microsecondsSinceEpoch.toString();
    final sys =
        '${prompt(AiPromptKeys.xianyuDescription)}${reference.isEmpty ? "" : "\n\n$reference"}';
    final r = await chat(
      sys,
      '请为以下设备写一版新的闲鱼商品描述。本次随机码：$variantSeed。\n'
      '强制要求：这次必须换开头、换卖点顺序、换句式；不要固定写“这台…搭载…适合…”，不要像参数表。\n'
      '${previous.isEmpty ? "" : "上一版文案如下，本次必须明显不同，不能复用开头和核心句式：\n$previous\n\n"}'
      '设备信息：\n型号：$model\n容量：$capacity\n颜色：$color\n网络：$network\n成色：$condition\n'
      '电池健康度：$batteryHealth%\n充电循环：$cycleCount次\nID锁：${idLockClean ? "无锁（干净）" : "有锁"}\n配件：$accessories'
      '${defectNote.trim().isEmpty ? "" : "\n外观记录：${defectNote.trim()}"}',
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
    final sys = prompt(AiPromptKeys.purchaseDecision);
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
