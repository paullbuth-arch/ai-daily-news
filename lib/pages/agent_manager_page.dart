import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../components/index.dart';
import '../utils/utils.dart';
import '../models.dart';
import '../main.dart';

String _fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class AgentManagerPage extends StatefulWidget {
  const AgentManagerPage({Key? key}) : super(key: key);
  @override
  State<AgentManagerPage> createState() => _AgentManagerPageState();
}

class _AgentManagerPageState extends State<AgentManagerPage> {
  void _refresh() => setState(() {});

  Future<void> _addAgent() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final rateCtrl = TextEditingController(text: '10');
    final ok = await showAppFormDialog<bool>(
      context: context,
      title: '新增代理',
      subtitle: '用于私域分销、佣金统计和客户归属',
      maxHeightFactor: 0.62,
      child: Builder(
        builder:
            (sheetContext) => Column(
              children: [
                AppFormField(
                  controller: nameCtrl,
                  label: '代理名称',
                  icon: Icons.person_outline_rounded,
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                AppFormField(
                  controller: phoneCtrl,
                  label: '联系方式',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                AppFormField(
                  controller: rateCtrl,
                  label: '佣金比例(%)',
                  icon: Icons.percent_rounded,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 18),
                AppSheetActions(
                  primaryLabel: '添加',
                  onPrimary: () => Navigator.pop(sheetContext, true),
                ),
              ],
            ),
      ),
    );
    final name = nameCtrl.text.trim();
    if (ok == true && name.isNotEmpty) {
      final now = DateTime.now();
      await gStorage.addAgent(
        Agent(
          id: 'a${now.millisecondsSinceEpoch}',
          name: name,
          phone: phoneCtrl.text.trim(),
          commissionRate: (double.tryParse(rateCtrl.text) ?? 10) / 100,
          totalGmv: 0,
          createdAt: _fmt(now),
        ),
      );
      _refresh();
      toast(context, '已添加代理');
    }
    nameCtrl.dispose();
    phoneCtrl.dispose();
    rateCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final agents = gStorage.getAgents();
    return appScaffold(
      context,
      '私域分销 · 代理管理',
      ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: primaryBtn('新增代理', _addAgent),
          ),
          if (agents.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 40),
              child: Column(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: C.bgCardMuted,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: C.border),
                    ),
                    child: Icon(Icons.groups_2_outlined, color: C.t3, size: 26),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '暂无代理，点击上方添加',
                    style: TextStyle(color: C.t2, fontSize: 13),
                  ),
                ],
              ),
            )
          else
            ...agents.map(
              (a) => CardBox(
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: C.pink.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        Icons.person_outline_rounded,
                        color: C.pink,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: C.t1,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${a.phone} · 佣金${(a.commissionRate * 100).toStringAsFixed(0)}%',
                            style: TextStyle(fontSize: 11, color: C.t2),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '累计GMV ${yuan(a.totalGmv)} · 加入${a.createdAt}',
                            style: TextStyle(fontSize: 10, color: C.t3),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        final ok = await confirmAction(
                          context,
                          title: '删除代理',
                          message: '确定删除代理「${a.name}」吗？此操作不会删除历史订单。',
                          confirmText: '删除',
                        );
                        if (!ok) return;
                        await gStorage.deleteAgent(a.id);
                        _refresh();
                        toast(context, '已删除');
                      },
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          color: C.red,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
