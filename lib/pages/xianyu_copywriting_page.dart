import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../components/index.dart';
import '../utils/utils.dart';
import '../models.dart';
import '../main.dart';
import '../services/xianyu_copy_service.dart';

class XianyuCopywritingPage extends StatefulWidget {
  const XianyuCopywritingPage({Key? key}) : super(key: key);

  @override
  State<XianyuCopywritingPage> createState() => _XianyuCopywritingPageState();
}

class _XianyuCopywritingPageState extends State<XianyuCopywritingPage> {
  late final TextEditingController _rulesCtrl;
  List<XianyuCopyExample> _examples = [];

  int get _soldDescriptionCount =>
      gStorage
          .getDevices()
          .where(
            (d) =>
                d.status == 'sold' && (d.description ?? '').trim().isNotEmpty,
          )
          .length;

  @override
  void initState() {
    super.initState();
    _rulesCtrl = TextEditingController(
      text: XianyuCopyService.effectiveRules(gStorage),
    );
    _reload();
  }

  @override
  void dispose() {
    _rulesCtrl.dispose();
    super.dispose();
  }

  void _reload() {
    _examples = gStorage.getXianyuCopyExamples();
  }

  @override
  Widget build(BuildContext context) => appScaffold(
    context,
    '闲鱼文案经验库',
    ListView(
      padding: const EdgeInsets.all(14),
      children: [
        CardBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('文案来源', icon: Icons.auto_awesome_outlined),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: _StatPill(
                      label: '样本',
                      value: '${_examples.length}',
                      color: C.cyan,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatPill(
                      label: '已售可导入',
                      value: '$_soldDescriptionCount',
                      color: C.mint,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                '生成闲鱼描述时会自动参考这些规则和样本，只学习表达方式，设备参数仍以当前商品为准。',
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
        CardBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('文案规则', icon: Icons.rule_rounded),
              AppFormField(
                controller: _rulesCtrl,
                label: '本店文案规则',
                hint: '写清楚语气、重点、禁止表达和售后避坑规则',
                icon: Icons.edit_note_rounded,
                keyboardType: TextInputType.multiline,
                maxLines: 8,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _resetRules,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: C.t2,
                        side: const BorderSide(color: C.border),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('恢复默认'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saveRules,
                      style: FilledButton.styleFrom(
                        backgroundColor: C.cyan,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('保存规则'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        CardBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(
                '成交文案样本',
                icon: Icons.library_books_outlined,
                trailing: '新增',
                onTap: () => _editExample(),
              ),
              if (_soldDescriptionCount > 0) ...[
                ghostBtn(
                  '从已售设备导入文案',
                  _importSoldDescriptions,
                  icon: Icons.download_done_rounded,
                ),
                const SizedBox(height: 10),
              ],
              if (_examples.isEmpty)
                const _EmptyCopyState()
              else
                ..._examples.map(
                  (e) => _ExampleTile(
                    example: e,
                    onTap: () => _editExample(e),
                    onDelete: () => _deleteExample(e),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );

  Future<void> _saveRules() async {
    await gStorage.saveXianyuCopyRules(_rulesCtrl.text.trim());
    if (!mounted) return;
    toast(context, '文案规则已保存');
  }

  Future<void> _resetRules() async {
    _rulesCtrl.text = XianyuCopyService.defaultRules.trim();
    await gStorage.saveXianyuCopyRules(_rulesCtrl.text);
    if (!mounted) return;
    toast(context, '已恢复默认文案规则');
  }

  Future<void> _importSoldDescriptions() async {
    final count = await gStorage.importSoldDescriptionsAsCopyExamples();
    if (!mounted) return;
    setState(_reload);
    toast(context, count > 0 ? '已导入 $count 条已售文案' : '没有新的已售文案可导入');
  }

  Future<void> _deleteExample(XianyuCopyExample example) async {
    final ok = await confirmAction(
      context,
      title: '删除样本',
      message: '删除后这条文案不会再参与 AI 生成参考。',
      confirmText: '删除',
    );
    if (!ok) return;
    await gStorage.deleteXianyuCopyExample(example.id);
    if (!mounted) return;
    setState(_reload);
    toast(context, '样本已删除');
  }

  Future<void> _editExample([XianyuCopyExample? example]) async {
    final titleCtrl = TextEditingController(text: example?.title ?? '');
    final modelCtrl = TextEditingController(text: example?.model ?? '');
    final conditionCtrl = TextEditingController(text: example?.condition ?? '');
    final tagsCtrl = TextEditingController(text: example?.tags ?? '');
    final noteCtrl = TextEditingController(text: example?.resultNote ?? '');
    final textCtrl = TextEditingController(text: example?.text ?? '');
    var score = example?.score ?? 4;

    try {
      final result = await showAppFormSheet<XianyuCopyExample>(
        context: context,
        title: example == null ? '新增文案样本' : '编辑文案样本',
        subtitle: '建议放实际成交快、询问少、纠纷少的描述',
        initialChildSize: 0.84,
        child: Builder(
          builder:
              (sheetContext) => StatefulBuilder(
                builder:
                    (context, setSheetState) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppFormField(
                          controller: titleCtrl,
                          label: '标题',
                          hint: '例如：Air 5 靓机成交文案',
                          icon: Icons.title_rounded,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: AppFormField(
                                controller: modelCtrl,
                                label: '机型',
                                hint: '可留空',
                                icon: Icons.tablet_mac_rounded,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: AppFormField(
                                controller: conditionCtrl,
                                label: '成色',
                                hint: '例如 95新',
                                icon: Icons.verified_outlined,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        AppFormField(
                          controller: tagsCtrl,
                          label: '标签',
                          hint: '例如 成交快、低售后、适合自用',
                          icon: Icons.sell_outlined,
                        ),
                        const SizedBox(height: 10),
                        AppFormField(
                          controller: noteCtrl,
                          label: '效果备注',
                          hint: '例如 2天售出，买家问题少',
                          icon: Icons.insights_rounded,
                        ),
                        const SizedBox(height: 10),
                        AppDropdownField<int>(
                          value: score,
                          hint: '样本质量',
                          options: const [5, 4, 3, 2, 1],
                          labelBuilder: (v) => '$v 星参考价值',
                          onChanged:
                              (v) => setSheetState(() => score = v ?? score),
                        ),
                        const SizedBox(height: 10),
                        AppFormField(
                          controller: textCtrl,
                          label: '文案内容',
                          hint: '粘贴你觉得值得学习的闲鱼描述',
                          icon: Icons.notes_rounded,
                          keyboardType: TextInputType.multiline,
                          maxLines: 8,
                        ),
                        const SizedBox(height: 16),
                        AppSheetActions(
                          primaryLabel: example == null ? '保存样本' : '保存修改',
                          primaryColor: C.cyan,
                          onPrimary: () {
                            final text = textCtrl.text.trim();
                            if (text.isEmpty) {
                              toast(sheetContext, '请填写文案内容');
                              return;
                            }
                            final now = DateTime.now();
                            Navigator.pop(
                              sheetContext,
                              XianyuCopyExample(
                                id:
                                    example?.id ??
                                    'copy_${now.microsecondsSinceEpoch}',
                                title:
                                    titleCtrl.text.trim().isEmpty
                                        ? '未命名样本'
                                        : titleCtrl.text.trim(),
                                model: modelCtrl.text.trim(),
                                condition: conditionCtrl.text.trim(),
                                text: text,
                                tags: tagsCtrl.text.trim(),
                                resultNote: noteCtrl.text.trim(),
                                score: score,
                                createdAt:
                                    example?.createdAt ?? now.toIso8601String(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
              ),
        ),
      );
      if (result == null) return;
      if (example == null) {
        await gStorage.addXianyuCopyExample(result);
      } else {
        await gStorage.updateXianyuCopyExample(result);
      }
      if (!mounted) return;
      setState(_reload);
      toast(context, '样本已保存');
    } finally {
      titleCtrl.dispose();
      modelCtrl.dispose();
      conditionCtrl.dispose();
      tagsCtrl.dispose();
      noteCtrl.dispose();
      textCtrl.dispose();
    }
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.32)),
    ),
    child: Row(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: C.t2,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ExampleTile extends StatelessWidget {
  final XianyuCopyExample example;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ExampleTile({
    required this.example,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: GlassPanel(
      padding: const EdgeInsets.all(12),
      radius: 10,
      color: C.bgDeep,
      borderColor: C.border,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  example.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: C.t1,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${example.score.clamp(1, 5)}星',
                style: const TextStyle(
                  color: C.mint,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 4),
              iconBtn(
                Icons.delete_outline_rounded,
                onDelete,
                color: C.red,
                size: 32,
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            [
              if (example.model.isNotEmpty) example.model,
              if (example.condition.isNotEmpty) example.condition,
              if (example.tags.isNotEmpty) example.tags,
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: C.t3,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            example.text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: C.t2,
              fontSize: 12,
              height: 1.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

class _EmptyCopyState extends StatelessWidget {
  const _EmptyCopyState();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: C.bgDeep,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: C.border),
    ),
    child: const Text(
      '还没有手工样本。可以先导入已售设备文案，或者新增几条你觉得成交效果好的描述。',
      style: TextStyle(
        color: C.t2,
        fontSize: 12,
        height: 1.55,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
