import 'services/market_price_import_service.dart';

class AiPromptKeys {
  static const recognizeAboutDevice = 'recognizeAboutDevice';
  static const priceAdvice = 'priceAdvice';
  static const dailyReport = 'dailyReport';
  static const customerService = 'customerService';
  static const purchaseAdvice = 'purchaseAdvice';
  static const xianyuDescription = 'xianyuDescription';
  static const purchaseDecision = 'purchaseDecision';
  static const marketPriceImageSystem = 'marketPriceImageSystem';
  static const marketPriceImageUser = 'marketPriceImageUser';
}

class AiPromptDefinition {
  final String key;
  final String title;
  final String description;
  final String defaultText;

  const AiPromptDefinition({
    required this.key,
    required this.title,
    required this.description,
    required this.defaultText,
  });
}

class AiPrompts {
  static final List<AiPromptDefinition> definitions = [
    const AiPromptDefinition(
      key: AiPromptKeys.recognizeAboutDevice,
      title: '关于本机截图识别',
      description: '用于拍照识别序列号、型号、容量、颜色、网络、电池健康和循环次数。',
      defaultText:
          '你是苹果设备信息识别专家。用户会上传一张iPad"关于本机"页面的截图。'
          '请从截图中识别出以下信息并严格以JSON格式返回：\n'
          '{"serial":"序列号","model":"型号名称","capacity":"容量","color":"颜色","network":"网络制式","batteryHealth":"电池健康度百分比数字","cycleCount":"循环次数数字"}\n'
          '如果某项信息无法识别，对应字段填"未知"。只返回JSON，不要返回其他文字。',
    ),
    const AiPromptDefinition(
      key: AiPromptKeys.priceAdvice,
      title: '库存定价建议',
      description: '用于商品详情里的 AI 定价，判断售价、最低价和采购上限。',
      defaultText:
          '你是二手iPad定价专家。根据设备型号、容量、成色、电池健康、采购成本、库存周转天数，给出定价建议。'
          '输出格式：建议售价¥X，可接受最低价¥Y，建议采购上限价¥Z，定价理由（一句话）。金额单位元。',
    ),
    const AiPromptDefinition(
      key: AiPromptKeys.dailyReport,
      title: '经营日报复盘',
      description: '用于首页/AI 复盘，根据 GMV、毛利、库存和滞销情况生成行动建议。',
      defaultText:
          '你是二手iPad门店经营参谋。不要写空泛日报，只输出能让老板今天行动的复盘。'
          '严格用以下格式，每条必须包含具体对象或数字，每条不超过28字：\n'
          '【今天先处理】\n• xxx（最高优先级动作，1-3条）\n\n'
          '【风险信号】\n• xxx（资金、滞销、毛利、订单风险，1-3条）\n\n'
          '【明天保留动作】\n• xxx（可以延后但要跟进的动作，1-2条）\n\n'
          '如果数据不足，直接指出要补齐哪些记录。不要多余的开场白。',
    ),
    const AiPromptDefinition(
      key: AiPromptKeys.customerService,
      title: '买家客服回答',
      description: '用于回答买家关于成色、电池、价格、保修等问题。',
      defaultText: '你是二手iPad客服助手，回答买家关于成色、电池、价格、保修等问题。态度热情专业，回答简洁。',
    ),
    const AiPromptDefinition(
      key: AiPromptKeys.purchaseAdvice,
      title: '采购补货建议',
      description: '用于根据近期销售情况生成补货方向、数量和采购上限价。',
      defaultText: '你是二手iPad采购顾问。根据近期销售情况，给出补货建议：该补哪些型号、补多少、采购上限价多少。',
    ),
    const AiPromptDefinition(
      key: AiPromptKeys.xianyuDescription,
      title: '闲鱼商品描述基础规则',
      description: '用于生成商品描述。实际生成时还会叠加“闲鱼文案经验库”的本店规则、样本和已售文案。',
      defaultText:
          '你是闲鱼二手iPad商品文案专家。根据给定的设备准确信息，写一段真实、专业、有吸引力的商品描述。'
          '要求：①突出成色、电池健康、ID锁状态等买家最关心的点；②语言自然不浮夸，不夸大；③包含配置亮点和适用场景；'
          '④100-180字，纯文本不带emoji和特殊符号、不带价格；⑤不要分点编号，写成流畅的一段话。',
    ),
    const AiPromptDefinition(
      key: AiPromptKeys.purchaseDecision,
      title: '收货采购风控',
      description: '用于采购决策页，根据行情、历史销量、库存压力和采购价判断是否值得收。',
      defaultText:
          '你是二手iPad采购风控参谋。综合今日市场行情、历史销售数据、拟采购成本，判断这批货是否值得收。'
          '不要写泛泛建议，必须围绕“压价线、净利、周转、库存压力”。'
          '输出格式：\n【结论】建议收 / 压价再收 / 谨慎试收 / 不建议\n'
          '【报价】给出一句最高可接受收货价或压价理由\n'
          '【原因】不超过3条，每条带数字\n'
          '【下一步】一句可执行动作\n中文，简洁，总字数≤260。',
    ),
    AiPromptDefinition(
      key: AiPromptKeys.marketPriceImageSystem,
      title: '行情图片识别系统规则',
      description: '用于导入批发行情截图时，告诉 AI 如何识别分区、型号、容量、成色和价格。',
      defaultText: MarketPriceImportService.imageSystemPrompt.trim(),
    ),
    AiPromptDefinition(
      key: AiPromptKeys.marketPriceImageUser,
      title: '行情图片识别用户指令',
      description: '用于导入批发行情截图时，配合系统规则要求 AI 输出 CSV 行。',
      defaultText: MarketPriceImportService.imageUserPrompt.trim(),
    ),
  ];

  static AiPromptDefinition definitionFor(String key) =>
      definitions.firstWhere((definition) => definition.key == key);

  static String resolve(String key, Map<String, String> customRules) {
    final custom = customRules[key]?.trim();
    if (custom != null && custom.isNotEmpty) return custom;
    return definitionFor(key).defaultText.trim();
  }

  static Map<String, String> cleanCustomRules(Map<String, String> values) {
    final cleaned = <String, String>{};
    for (final definition in definitions) {
      final text = values[definition.key]?.trim() ?? '';
      if (text.isNotEmpty && text != definition.defaultText.trim()) {
        cleaned[definition.key] = text;
      }
    }
    return cleaned;
  }
}
