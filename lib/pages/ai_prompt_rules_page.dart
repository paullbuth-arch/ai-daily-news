import 'package:flutter/material.dart';
import '../ai_prompts.dart';
import '../ai_service.dart';
import '../components/index.dart';
import '../main.dart';
import '../theme/colors.dart';
import '../utils/utils.dart';

class AiPromptRulesPage extends StatefulWidget {
  const AiPromptRulesPage({Key? key}) : super(key: key);

  @override
  State<AiPromptRulesPage> createState() => _AiPromptRulesPageState();
}

class _AiPromptRulesPageState extends State<AiPromptRulesPage> {
  late final Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    final customRules = gStorage.getAiPromptRules();
    _controllers = {
      for (final definition in AiPrompts.definitions)
        definition.key: TextEditingController(
          text: AiPrompts.resolve(definition.key, customRules),
        ),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => appScaffold(
    context,
    'AI 提示词/规则',
    ListView(
      padding: const EdgeInsets.all(14),
      children: [
        CardBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle('规则用途', icon: Icons.tune_rounded),
              Text(
                '这里管理 AI 在各个功能里的系统规则。保存后会立即生效；设备、订单、库存等真实数据仍由页面自动传入，不需要写进规则里。',
                style: TextStyle(
                  color: C.t2,
                  fontSize: 12,
                  height: 1.55,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        ...AiPrompts.definitions.map(_ruleCard),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: ghostBtn('恢复全部默认', _resetAll, icon: Icons.restore_rounded),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: primaryBtn('保存全部规则', _saveAll, icon: Icons.save_rounded),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _ruleCard(AiPromptDefinition definition) => CardBox(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          definition.title,
          icon: Icons.psychology_alt_outlined,
          trailing: '默认',
          onTap: () => _resetOne(definition),
        ),
        Text(
          definition.description,
          style: TextStyle(
            color: C.t2,
            fontSize: 12,
            height: 1.45,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        AppFormField(
          controller: _controllers[definition.key]!,
          label: '规则内容',
          hint: definition.defaultText,
          icon: Icons.edit_note_rounded,
          keyboardType: TextInputType.multiline,
          maxLines: definition.defaultText.length > 260 ? 10 : 7,
        ),
      ],
    ),
  );

  void _resetOne(AiPromptDefinition definition) {
    _controllers[definition.key]!.text = definition.defaultText.trim();
    toast(context, '已恢复：${definition.title}');
  }

  void _resetAll() {
    for (final definition in AiPrompts.definitions) {
      _controllers[definition.key]!.text = definition.defaultText.trim();
    }
    toast(context, '已恢复全部默认规则');
  }

  Future<void> _saveAll() async {
    final values = <String, String>{};
    for (final definition in AiPrompts.definitions) {
      final text = _controllers[definition.key]!.text.trim();
      if (text.isEmpty) {
        toast(context, '${definition.title} 不能为空');
        return;
      }
      values[definition.key] = text;
    }

    final customRules = AiPrompts.cleanCustomRules(values);
    await gStorage.saveAiPromptRules(customRules);
    AiService.setPromptRules(customRules);
    if (!mounted) return;
    toast(
      context,
      customRules.isEmpty ? '已保存：全部使用默认规则' : '已保存 ${customRules.length} 条自定义规则',
    );
  }
}
