// 爱管机 ERP 扩展功能页面：采购管理 / 质检管理 / 分货管理 / 租借管理
// 以及分期付款 / 预付定金 / 机器追踪 / 库存预警配置
import 'dart:math';
import 'package:flutter/material.dart';
import 'main.dart' as app;
import 'models.dart';
import 'storage.dart';

final Storage _s = app.gStorage;

// ========== 通用短工具 ==========
String yuan(int fen) => '¥${(fen / 100).toStringAsFixed(0)}';
void toast(BuildContext c, String msg) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(msg, style: const TextStyle(fontSize: 13)), duration: const Duration(seconds: 2), backgroundColor: const Color(0xFF1A1A2E)));
String _uid() => DateTime.now().millisecondsSinceEpoch.toString() + Random().nextInt(999).toString().padLeft(3, '0');

// ======================================================================
// 1. 采购管理
// ======================================================================
class PurchaseManagementPage extends StatefulWidget {
  const PurchaseManagementPage({Key? key}) : super(key: key);
  @override
  State<PurchaseManagementPage> createState() => _PurchaseManagementPageState();
}

class _PurchaseManagementPageState extends State<PurchaseManagementPage> {
  List<PurchaseOrder> _orders = [];

  @override
  void initState() { super.initState(); _refresh(); }

  void _refresh() { setState(() { _orders = _s.getPurchaseOrders(); }); }

  @override
  Widget build(BuildContext context) {
    return _appScaffold(context, '采购管理', Column(children: [
      // 统计栏
      Container(margin: const EdgeInsets.all(14), padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(color: app.C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: app.C.line)),
        child: Row(children: [
          _statItem('采购单', '${_orders.length}', app.C.brand2),
          _statItem('总金额', yuan(_orders.fold<int>(0, (s, o) => s + o.totalCost)), app.C.green),
          _statItem('退货', '${_orders.fold<int>(0, (s, o) => s + o.returnedCount)}台', app.C.red),
        ])),
      // 操作按钮
      Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Row(children: [
        Expanded(child: _actionBtn('📥 手动录入', app.C.brand2, () => _showCreateDialog())),
        const SizedBox(width: 8),
        Expanded(child: _actionBtn('📤 从平台导入', app.C.orange, () => _showImportDialog())),
      ])),
      const SizedBox(height: 8),
      // 列表
      Expanded(child: _orders.isEmpty
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('📋', style: TextStyle(fontSize: 48)), const SizedBox(height: 8), Text('暂无采购单\n点击上方按钮创建', textAlign: TextAlign.center, style: TextStyle(color: app.C.t2, fontSize: 13))]))
        : ListView.builder(padding: const EdgeInsets.fromLTRB(14, 8, 14, 14), itemCount: _orders.length, itemBuilder: (_, i) => _buildCard(_orders[i]))),
    ]));
  }

  Widget _statItem(String label, String value, Color c) => Expanded(child: Column(children: [Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c)), Text(label, style: TextStyle(fontSize: 10, color: app.C.t2))]));

  Widget _actionBtn(String t, Color c, VoidCallback onTap) => InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: c.withOpacity(0.3))), child: Center(child: Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c)))));

  Widget _buildCard(PurchaseOrder po) {
    final pct = po.deviceCount > 0 ? ((po.deviceCount - po.returnedCount) / po.deviceCount * 100).round() : 0;
    return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: app.C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: app.C.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: po.status == 'done' ? app.C.green.withOpacity(0.15) : app.C.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
            child: Text(po.status == 'done' ? '已完成' : po.status == 'cancelled' ? '已取消' : '处理中', style: TextStyle(fontSize: 10, color: po.status == 'done' ? app.C.green : app.C.orange, fontWeight: FontWeight.w600))),
          const SizedBox(width: 8),
          Expanded(child: Text(po.supplier, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: app.C.t1))),
          Text(po.sourcePlatform, style: TextStyle(fontSize: 10, color: app.C.t3)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Text(yuan(po.totalCost), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: app.C.brand2)),
          const SizedBox(width: 8),
          Text('${po.deviceCount}台 · 退货${po.returnedCount}', style: TextStyle(fontSize: 11, color: app.C.t2)),
          const Spacer(),
          if (po.afterSaleAmount != null && po.afterSaleAmount! > 0)
            Text('议价-${yuan(po.afterSaleAmount!)}', style: TextStyle(fontSize: 11, color: app.C.red)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(4), child: Container(height: 4, width: 200, color: app.C.bg, child: FractionallySizedBox(widthFactor: pct / 100.0, child: Container(color: pct > 80 ? app.C.green : app.C.orange)))),
          const SizedBox(width: 8),
          Text('$pct%', style: TextStyle(fontSize: 10, color: app.C.t2)),
          const Spacer(),
          Text(po.createdAt.substring(0, 10), style: TextStyle(fontSize: 10, color: app.C.t3)),
        ]),
        if (po.afterSaleNote != null && po.afterSaleNote!.isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 6), child: Row(children: [Text('售后: ', style: TextStyle(fontSize: 10, color: app.C.t3)), Expanded(child: Text(po.afterSaleNote!, style: TextStyle(fontSize: 10, color: app.C.t2)))]))
      ]));
  }

  void _showCreateDialog() {
    final nameC = TextEditingController();
    final amountC = TextEditingController();
    String platform = '手动';
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: app.C.card, title: const Text('新建采购单', style: TextStyle(fontSize: 16)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameC, decoration: const InputDecoration(labelText: '供应商/来源', border: OutlineInputBorder()), style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(value: platform, items: ['手动','闲鱼','转转','爱回收','拼多多','淘宝','微信','其他'].map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 13)))).toList(),
          onChanged: (v) { platform = v ?? '手动'; }, decoration: const InputDecoration(labelText: '来源平台', border: OutlineInputBorder()), style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 10),
        TextField(controller: amountC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '总金额(元)', border: OutlineInputBorder()), style: const TextStyle(fontSize: 14)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('取消', style: TextStyle(color: app.C.t2))),
        TextButton(onPressed: () async {
          if (nameC.text.isEmpty) { toast(ctx, '请输入供应商'); return; }
          final po = PurchaseOrder(id: _uid(), supplier: nameC.text, sourcePlatform: platform,
            totalCost: ((double.tryParse(amountC.text) ?? 0) * 100).round(), createdAt: DateTime.now().toIso8601String());
          await _s.addPurchaseOrder(po);
          Navigator.pop(ctx); _refresh();
        }, child: const Text('创建', style: TextStyle(color: Color(0xFF06B6D4)))),
      ],
    ));
  }

  void _showImportDialog() {
    String platform = '闲鱼';
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: app.C.card, title: const Text('从平台导入', style: TextStyle(fontSize: 16)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(value: platform, items: ['闲鱼','转转','爱回收','拼多多','淘宝','其他'].map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 13)))).toList(),
          onChanged: (v) { platform = v ?? '闲鱼'; }, decoration: const InputDecoration(labelText: '选择平台', border: OutlineInputBorder()), style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 14),
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: app.C.brand.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
          child: Row(children: [const Text('📋', style: TextStyle(fontSize: 20)), const SizedBox(width: 10), Expanded(child: Text('从$platform复制订单号粘贴到这里', style: TextStyle(fontSize: 12, color: app.C.t2)))]))
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('取消', style: TextStyle(color: app.C.t2))),
        TextButton(onPressed: () async {
          final po = PurchaseOrder(id: _uid(), supplier: '${platform}导入', sourcePlatform: platform,
            totalCost: 0, createdAt: DateTime.now().toIso8601String());
          await _s.addPurchaseOrder(po);
          Navigator.pop(ctx); _refresh();
          toast(context, '已创建$platform采购单，请编辑补全信息');
        }, child: const Text('导入', style: TextStyle(color: Color(0xFF06B6D4)))),
      ],
    ));
  }
}

// ======================================================================
// 2. 质检管理
// ======================================================================
class QCManagementPage extends StatefulWidget {
  const QCManagementPage({Key? key}) : super(key: key);
  @override
  State<QCManagementPage> createState() => _QCManagementPageState();
}

class _QCManagementPageState extends State<QCManagementPage> {
  List<Device> _pendingDevices = [];
  List<QCReport> _reports = [];

  @override
  void initState() { super.initState(); _refresh(); }

  void _refresh() {
    setState(() {
      _pendingDevices = _s.getDevices().where((d) => d.status == 'in_stock' && d.sellPrice == 0).toList();
      _reports = _s.getQCReports();
      _pendingDevices.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    });
  }

  @override
  Widget build(BuildContext context) {
    return _appScaffold(context, '质检管理', Column(children: [
      Container(margin: const EdgeInsets.all(14), padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(color: app.C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: app.C.line)),
        child: Row(children: [
          _statItem('待质检', '${_pendingDevices.length}', app.C.orange),
          _statItem('已质检', '${_reports.length}', app.C.green),
          _statItem('A品率', '${_reports.isEmpty ? 0 : (_reports.where((r) => r.grade == 'A').length / _reports.length * 100).round()}%', app.C.brand2),
        ])),
      // 待质检列表
      Expanded(child: _pendingDevices.isEmpty && _reports.isEmpty
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('✅', style: TextStyle(fontSize: 48)), const SizedBox(height: 8), Text('所有设备已完成质检', style: TextStyle(color: app.C.t2, fontSize: 13))]))
        : ListView(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14), children: [
          if (_pendingDevices.isNotEmpty) ...[
            Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [Text('📋 待质检 (${_pendingDevices.length})', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: app.C.t1))])),
            ..._pendingDevices.map((d) => _buildPendingCard(d)),
            const SizedBox(height: 12),
          ],
          if (_reports.isNotEmpty) ...[
            Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [Text('📋 质检历史', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: app.C.t1))])),
            ..._reports.take(20).map((r) => _buildReportCard(r)),
          ],
        ])),
    ]));
  }

  Widget _statItem(String label, String value, Color c) => Expanded(child: Column(children: [Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c)), Text(label, style: TextStyle(fontSize: 10, color: app.C.t2))]));

  Widget _buildPendingCard(Device d) {
    return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: app.C.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: app.C.line)),
      child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: app.C.orange.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: const Center(child: Text('🔍', style: TextStyle(fontSize: 18)))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${d.model} ${d.capacity} ${d.color}', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: app.C.t1)),
          Text('采购${yuan(d.purchaseCost)} · 电池${d.batteryHealth}% · ${d.cycleCount}次', style: TextStyle(fontSize: 10, color: app.C.t2)),
        ])),
        InkWell(onTap: () => _startQC(d), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: app.C.brand2.withOpacity(0.12), borderRadius: BorderRadius.circular(8)), child: Text('质检', style: TextStyle(fontSize: 12, color: app.C.brand2, fontWeight: FontWeight.w700)))),
      ]));
  }

  Widget _buildReportCard(QCReport r) {
    return Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: app.C.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: app.C.line)),
      child: Row(children: [
        Container(width: 28, height: 28, decoration: BoxDecoration(color: r.grade == 'A' ? app.C.green.withOpacity(0.15) : app.C.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(7)),
          child: Center(child: Text(r.grade, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: r.grade == 'A' ? app.C.green : app.C.orange)))),
        const SizedBox(width: 8),
        Expanded(child: Text(r.deviceName, style: TextStyle(fontSize: 12, color: app.C.t1))),
        Text('${r.conclusion} · ${r.createdAt.substring(0, 10)}', style: TextStyle(fontSize: 10, color: app.C.t3)),
      ]));
  }

  void _startQC(Device d) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => _QCFormPage(d))).then((_) => _refresh());
  }
}

/// 质检表单页面
class _QCFormPage extends StatefulWidget {
  final Device device;
  const _QCFormPage(this.device);
  @override
  State<_QCFormPage> createState() => _QCFormPageState();
}

class _QCFormPageState extends State<_QCFormPage> {
  late QCReport _r;
  final _inspectorC = TextEditingController();
  final _noteC = TextEditingController();
  final _repairSugC = TextEditingController();
  final _repairCostC = TextEditingController();

  @override
  void initState() {
    super.initState();
    final existing = _s.getQCReportByDevice(widget.device.id);
    _r = existing ?? QCReport(id: _uid(), deviceId: widget.device.id, deviceName: '${widget.device.model} ${widget.device.capacity}', createdAt: DateTime.now().toIso8601String());
    _inspectorC.text = _r.inspector;
    _noteC.text = _r.note ?? '';
    _repairSugC.text = _r.repairSuggestion ?? '';
    if (_r.estimatedRepairCost != null) _repairCostC.text = (_r.estimatedRepairCost! / 100).toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: app.C.bg,
      appBar: AppBar(title: const Text('质检报告', style: TextStyle(fontWeight: FontWeight.w700)), backgroundColor: app.C.card, elevation: 0.5,
        actions: [TextButton(onPressed: _save, child: const Text('保存', style: TextStyle(fontWeight: FontWeight.w700)))], leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        // 设备信息
        Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: app.C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: app.C.line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.device.model, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: app.C.t1)),
            const SizedBox(height: 4),
            Text('${widget.device.capacity} · ${widget.device.color} · 电池${widget.device.batteryHealth}% · ${widget.device.cycleCount}次', style: TextStyle(fontSize: 12, color: app.C.t2)),
            const SizedBox(height: 10),
            TextField(controller: _inspectorC, decoration: const InputDecoration(labelText: '质检员', border: OutlineInputBorder(), isDense: true), style: const TextStyle(fontSize: 13)),
          ])),
        const SizedBox(height: 12),
        // 外观检测
        _section('📱 外观检测', [
          _dropdown('屏幕', QCReport.screenOptions, _r.screenCondition, (v) => setState(() => _r.screenCondition = v)),
          _dropdown('边框', QCReport.frameOptions, _r.frameCondition, (v) => setState(() => _r.frameCondition = v)),
          _dropdown('背板', QCReport.backOptions, _r.backCondition, (v) => setState(() => _r.backCondition = v)),
          _dropdown('摄像头', QCReport.cameraOptions, _r.cameraCondition, (v) => setState(() => _r.cameraCondition = v)),
        ]),
        const SizedBox(height: 12),
        // 功能检测
        _section('⚙️ 功能检测', [
          _switch('Face ID', _r.hasFaceId, (v) => setState(() => _r.hasFaceId = v)),
          _switch('Touch ID', _r.hasTouchId, (v) => setState(() => _r.hasTouchId = v)),
          _switch('WiFi', _r.wifiOk, (v) => setState(() => _r.wifiOk = v)),
          _switch('蓝牙', _r.bluetoothOk, (v) => setState(() => _r.bluetoothOk = v)),
          _switch('麦克风', _r.microphoneOk, (v) => setState(() => _r.microphoneOk = v)),
          _switch('扬声器', _r.speakerOk, (v) => setState(() => _r.speakerOk = v)),
          _switch('按键', _r.buttonsOk, (v) => setState(() => _r.buttonsOk = v)),
          _switch('充电', _r.chargingOk, (v) => setState(() => _r.chargingOk = v)),
        ]),
        const SizedBox(height: 12),
        // 结论
        _section('📋 质检结论', [
          _dropdown('品级', QCReport.grades, _r.grade, (v) => setState(() => _r.grade = v)),
          _choice('结论', ['通过', '需维修', '报废'], _r.conclusion, (v) => setState(() => _r.conclusion = v)),
          if (_r.conclusion == '需维修') ...[
            const SizedBox(height: 8),
            TextField(controller: _repairSugC, decoration: const InputDecoration(labelText: '维修建议', border: OutlineInputBorder(), isDense: true), style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            TextField(controller: _repairCostC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '预估维修费(元)', border: OutlineInputBorder(), isDense: true), style: const TextStyle(fontSize: 13)),
          ],
        ]),
        const SizedBox(height: 12),
        TextField(controller: _noteC, maxLines: 3, decoration: const InputDecoration(labelText: '备注', border: OutlineInputBorder(), isDense: true), style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 40),
      ]));
  }

  Widget _section(String title, List<Widget> children) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: app.C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: app.C.line)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: app.C.t1))),
      ...children
    ]));

  Widget _dropdown(String label, List<String> options, String value, ValueChanged<String> onChanged) {
    final chips = options.map((o) => Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => onChanged(o),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: value == o ? app.C.brand2.withOpacity(0.15) : app.C.bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: value == o ? app.C.brand2 : app.C.line)),
          child: Text(o, style: TextStyle(fontSize: 11, color: value == o ? app.C.brand2 : app.C.t2, fontWeight: value == o ? FontWeight.w600 : FontWeight.normal)),
        ),
      ),
    )).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        SizedBox(width: 60, child: Text(label, style: TextStyle(fontSize: 12, color: app.C.t2))),
        const SizedBox(width: 8),
        Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: chips))),
      ]),
    );
  }

  Widget _switch(String label, bool value, ValueChanged<bool> onChanged) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [Text(label, style: TextStyle(fontSize: 12, color: app.C.t1)), const Spacer(), Switch(value: value, onChanged: onChanged, activeColor: app.C.green, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)]));

  Widget _choice(String label, List<String> options, String value, ValueChanged<String> onChanged) {
    final btns = options.map((o) => Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: InkWell(
          onTap: () => onChanged(o),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: value == o ? app.C.brand2.withOpacity(0.15) : app.C.bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: value == o ? app.C.brand2 : app.C.line)),
            child: Center(child: Text(o, style: TextStyle(fontSize: 11, color: value == o ? app.C.brand2 : app.C.t2, fontWeight: value == o ? FontWeight.w600 : FontWeight.normal))),
          ),
        ),
      ),
    )).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        SizedBox(width: 60, child: Text(label, style: TextStyle(fontSize: 12, color: app.C.t2))),
        const SizedBox(width: 8),
        Expanded(child: Row(children: btns)),
      ]),
    );
  }

  Future<void> _save() async {
    _r.inspector = _inspectorC.text;
    _r.repairSuggestion = _repairSugC.text.isNotEmpty ? _repairSugC.text : null;
    _r.estimatedRepairCost = _repairCostC.text.isNotEmpty ? ((double.tryParse(_repairCostC.text) ?? 0) * 100).round() : null;
    _r.note = _noteC.text.isNotEmpty ? _noteC.text : null;

    // 自动计算品级
    final failed = [!_r.hasFaceId, !_r.hasTouchId, !_r.wifiOk, !_r.bluetoothOk, !_r.microphoneOk, !_r.speakerOk, !_r.buttonsOk, !_r.chargingOk].where((b) => b).length;
    final hasScreenIssue = _r.screenCondition != '完美';
    final hasFrameIssue = _r.frameCondition != '完美';
    final hasBackIssue = _r.backCondition != '完美';
    if (failed > 2 || _r.screenCondition == '碎裂' || _r.backCondition == '碎裂') {
      _r.grade = 'D'; _r.conclusion = '报废';
    } else if (failed > 1 || hasScreenIssue || hasFrameIssue || hasBackIssue) {
      _r.grade = 'C'; _r.conclusion = '需维修';
    } else if (failed > 0) {
      _r.grade = 'B';
    } else {
      _r.grade = 'A';
    }

    await _s.addQCReport(_r);
    toast(context, '质检完成: ${_r.grade}品');
    Navigator.pop(context);
  }
}

// ======================================================================
// 3. 分货管理
// ======================================================================
class AllocationPage extends StatefulWidget {
  const AllocationPage({Key? key}) : super(key: key);
  @override
  State<AllocationPage> createState() => _AllocationPageState();
}

class _AllocationPageState extends State<AllocationPage> {
  List<AllocationRecord> _records = [];
  final _filterC = TextEditingController();

  @override
  void initState() { super.initState(); _refresh(); }

  void _refresh() { setState(() { _records = _s.getAllocations(); }); }

  @override
  Widget build(BuildContext context) {
    final assigned = _records.where((a) => a.status == 'assigned').length;
    final returned = _records.where((a) => a.status == 'returned').length;
    return _appScaffold(context, '分货管理', Column(children: [
      Container(margin: const EdgeInsets.all(14), padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(color: app.C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: app.C.line)),
        child: Row(children: [
          _statItem('已分配', '$assigned', app.C.brand2),
          _statItem('已归还', '$returned', app.C.green),
          _statItem('未归还', _records.isEmpty ? '0' : '${_records.where((a) => a.status == 'assigned').length}', app.C.orange),
        ])),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: _actionBtn('➕ 分配设备', app.C.brand2, () => _showAllocateDialog())),
      const SizedBox(height: 8),
      Expanded(child: _records.isEmpty
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('📦', style: TextStyle(fontSize: 48)), const SizedBox(height: 8), Text('暂无分货记录\n点击上方分配设备', textAlign: TextAlign.center, style: TextStyle(color: app.C.t2, fontSize: 13))]))
        : ListView(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14), children: _records.map((a) => _buildCard(a)).toList())),
    ]));
  }

  Widget _statItem(String label, String value, Color c) => Expanded(child: Column(children: [Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c)), Text(label, style: TextStyle(fontSize: 10, color: app.C.t2))]));

  Widget _actionBtn(String t, Color c, VoidCallback onTap) => SizedBox(width: double.infinity, child: InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: c.withOpacity(0.3))), child: Center(child: Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c))))));

  Widget _buildCard(AllocationRecord a) {
    return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: app.C.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: app.C.line)),
      child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: (a.status == 'assigned' ? app.C.brand2 : app.C.green).withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Center(child: Text(a.status == 'assigned' ? '📤' : '📥', style: const TextStyle(fontSize: 16)))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(a.deviceName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: app.C.t1)),
          Text('${a.assignee} · ${a.department} · ${a.purpose}', style: TextStyle(fontSize: 10, color: app.C.t2)),
          Text(a.createdAt.substring(0, 10), style: TextStyle(fontSize: 10, color: app.C.t3)),
        ])),
        if (a.status == 'assigned')
          InkWell(onTap: () => _returnDevice(a), child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: app.C.green.withOpacity(0.12), borderRadius: BorderRadius.circular(8)), child: Text('归还', style: TextStyle(fontSize: 11, color: app.C.green, fontWeight: FontWeight.w700)))),
      ]));
  }

  void _showAllocateDialog() {
    final devices = _s.getDevices().where((d) => d.status == 'in_stock').toList();
    if (devices.isEmpty) { toast(context, '暂无可用库存设备'); return; }

    final nameC = TextEditingController();
    final deptC = TextEditingController();
    String? selectedId;
    String purpose = '销售';

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
      backgroundColor: app.C.card, title: const Text('分配设备', style: TextStyle(fontSize: 16)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(value: selectedId, items: devices.map((d) => DropdownMenuItem(value: d.id, child: Text('${d.model} ${d.capacity}', style: const TextStyle(fontSize: 12)))).toList(),
          onChanged: (v) => setD(() => selectedId = v), decoration: const InputDecoration(labelText: '选择设备', border: OutlineInputBorder()), style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 10),
        TextField(controller: nameC, decoration: const InputDecoration(labelText: '领用人', border: OutlineInputBorder()), style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 10),
        TextField(controller: deptC, decoration: const InputDecoration(labelText: '部门/门店', border: OutlineInputBorder()), style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(value: purpose, items: ['销售','门店展示','维修备机','测试','其他'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
          onChanged: (v) => setD(() => purpose = v ?? '销售'), decoration: const InputDecoration(labelText: '用途', border: OutlineInputBorder()), style: const TextStyle(fontSize: 13)),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('取消', style: TextStyle(color: app.C.t2))),
        TextButton(onPressed: () async {
          if (selectedId == null) { toast(ctx, '请选择设备'); return; }
          if (nameC.text.isEmpty) { toast(ctx, '请输入领用人'); return; }
          final d = devices.firstWhere((d) => d.id == selectedId);
          final a = AllocationRecord(id: _uid(), deviceId: d.id, deviceName: '${d.model} ${d.capacity}', assignee: nameC.text, department: deptC.text, purpose: purpose, createdAt: DateTime.now().toIso8601String());
          await _s.addAllocation(a);
          Navigator.pop(ctx); _refresh();
        }, child: const Text('分配', style: TextStyle(color: Color(0xFF06B6D4)))),
      ],
    )));
  }

  Future<void> _returnDevice(AllocationRecord a) async {
    a.status = 'returned';
    a.returnedAt = DateTime.now().toIso8601String();
    await _s.updateAllocation(a);
    _refresh();
    toast(context, '${a.deviceName} 已归还');
  }
}

// ======================================================================
// 4. 租借管理
// ======================================================================
class RentalPage extends StatefulWidget {
  const RentalPage({Key? key}) : super(key: key);
  @override
  State<RentalPage> createState() => _RentalPageState();
}

class _RentalPageState extends State<RentalPage> {
  List<RentalRecord> _records = [];

  @override
  void initState() { super.initState(); _refresh(); }

  void _refresh() { setState(() { _records = _s.getRentals(); }); }

  @override
  Widget build(BuildContext context) {
    final borrowed = _records.where((r) => r.status == 'borrowed').length;
    final overdue = _records.where((r) => r.isOverdue).length;
    return _appScaffold(context, '租借管理', Column(children: [
      Container(margin: const EdgeInsets.all(14), padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(color: app.C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: app.C.line)),
        child: Row(children: [
          _statItem('借出中', '$borrowed', app.C.orange),
          _statItem('已归还', '${_records.where((r) => r.status == 'returned').length}', app.C.green),
          if (overdue > 0) _statItem('⚠️逾期', '$overdue', app.C.red),
        ])),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: _actionBtn('➕ 借出设备', app.C.orange, () => _showBorrowDialog())),
      const SizedBox(height: 8),
      Expanded(child: _records.isEmpty
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('📚', style: TextStyle(fontSize: 48)), const SizedBox(height: 8), Text('暂无租借记录\n点击上方借出设备', textAlign: TextAlign.center, style: TextStyle(color: app.C.t2, fontSize: 13))]))
        : ListView(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14), children: _records.map((r) => _buildCard(r)).toList())),
    ]));
  }

  Widget _statItem(String label, String value, Color c) => Expanded(child: Column(children: [Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c)), Text(label, style: TextStyle(fontSize: 10, color: app.C.t2))]));

  Widget _actionBtn(String t, Color c, VoidCallback onTap) => SizedBox(width: double.infinity, child: InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: c.withOpacity(0.3))), child: Center(child: Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c))))));

  Widget _buildCard(RentalRecord r) {
    return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: app.C.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: r.isOverdue ? app.C.red.withOpacity(0.3) : app.C.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: (r.isOverdue ? app.C.red : r.status == 'borrowed' ? app.C.orange : app.C.green).withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text(r.isOverdue ? '⚠️' : r.status == 'borrowed' ? '📤' : '📥', style: const TextStyle(fontSize: 16)))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.deviceName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: app.C.t1)),
            Text('${r.borrower} · ${r.contact}', style: TextStyle(fontSize: 10, color: app.C.t2)),
          ])),
          if (r.status == 'borrowed')
            InkWell(onTap: () => _returnRental(r), child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: app.C.green.withOpacity(0.12), borderRadius: BorderRadius.circular(8)), child: Text('归还', style: TextStyle(fontSize: 11, color: app.C.green, fontWeight: FontWeight.w700)))),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Text('借出: ${r.borrowedAt.toString().substring(0, 10)}', style: TextStyle(fontSize: 10, color: app.C.t3)),
          const SizedBox(width: 12),
          if (r.dueAt != null) Text('应还: ${r.dueAt!.toString().substring(0, 10)}', style: TextStyle(fontSize: 10, color: r.isOverdue ? app.C.red : app.C.t3)),
          const SizedBox(width: 12),
          if (r.deposit != null && r.deposit! > 0) Text('押金${yuan(r.deposit!)}', style: TextStyle(fontSize: 10, color: app.C.t3)),
        ]),
      ]));
  }

  void _showBorrowDialog() {
    final devices = _s.getDevices().where((d) => d.status == 'in_stock').toList();
    if (devices.isEmpty) { toast(context, '暂无可用库存设备'); return; }

    final nameC = TextEditingController();
    final contactC = TextEditingController();
    final depositC = TextEditingController();
    final purposeC = TextEditingController();
    String? selectedId;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
      backgroundColor: app.C.card, title: const Text('借出设备', style: TextStyle(fontSize: 16)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(value: selectedId, items: devices.map((d) => DropdownMenuItem(value: d.id, child: Text('${d.model} ${d.capacity}', style: const TextStyle(fontSize: 12)))).toList(),
          onChanged: (v) => setD(() => selectedId = v), decoration: const InputDecoration(labelText: '选择设备', border: OutlineInputBorder()), style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 10),
        TextField(controller: nameC, decoration: const InputDecoration(labelText: '借用人', border: OutlineInputBorder()), style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 10),
        TextField(controller: contactC, decoration: const InputDecoration(labelText: '联系方式', border: OutlineInputBorder()), style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 10),
        TextField(controller: depositC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '押金(元)', border: OutlineInputBorder()), style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 10),
        TextField(controller: purposeC, decoration: const InputDecoration(labelText: '用途', border: OutlineInputBorder()), style: const TextStyle(fontSize: 13)),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('取消', style: TextStyle(color: app.C.t2))),
        TextButton(onPressed: () async {
          if (selectedId == null) { toast(ctx, '请选择设备'); return; }
          if (nameC.text.isEmpty) { toast(ctx, '请输入借用人'); return; }
          final d = devices.firstWhere((d) => d.id == selectedId);
          final r = RentalRecord(id: _uid(), deviceId: d.id, deviceName: '${d.model} ${d.capacity}',
            borrower: nameC.text, contact: contactC.text, purpose: purposeC.text,
            borrowedAt: DateTime.now(), deposit: ((double.tryParse(depositC.text) ?? 0) * 100).round(),
            createdAt: DateTime.now().toIso8601String());
          await _s.addRental(r);
          Navigator.pop(ctx); _refresh();
        }, child: const Text('借出', style: TextStyle(color: Color(0xFF06B6D4)))),
      ],
    )));
  }

  Future<void> _returnRental(RentalRecord r) async {
    r.status = 'returned';
    r.returnedAt = DateTime.now();
    await _s.updateRental(r);
    _refresh();
    toast(context, '${r.deviceName} 已归还');
  }
}

// ======================================================================
// 5. 机器追踪
// ======================================================================
class DeviceTrackingPage extends StatefulWidget {
  const DeviceTrackingPage({Key? key}) : super(key: key);
  @override
  State<DeviceTrackingPage> createState() => _DeviceTrackingPageState();
}

class _DeviceTrackingPageState extends State<DeviceTrackingPage> {
  final _searchC = TextEditingController();
  List<Device> _results = [];

  @override
  void dispose() { _searchC.dispose(); super.dispose(); }

  void _search() {
    setState(() { _results = _s.searchDevices(_searchC.text); });
  }

  @override
  Widget build(BuildContext context) {
    return _appScaffold(context, '机器追踪', Column(children: [
      Padding(padding: const EdgeInsets.all(14), child: TextField(
        controller: _searchC,
        onChanged: (_) => _search(),
        decoration: InputDecoration(
          hintText: '🔍 搜索序列号/型号/内部ID...',
          hintStyle: TextStyle(color: app.C.t3, fontSize: 13),
          filled: true, fillColor: app.C.card,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          suffixIcon: _searchC.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchC.clear(); setState(() => _results = []); }) : null,
        ), style: TextStyle(fontSize: 14, color: app.C.t1),
      )),
      Expanded(child: _results.isEmpty
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_searchC.text.isEmpty ? '🔍' : '📭', style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 8),
            Text(_searchC.text.isEmpty ? '输入序列号或型号搜索设备' : '未找到匹配设备', style: TextStyle(color: app.C.t2, fontSize: 13)),
          ]))
        : ListView(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14), children: _results.map((d) => _buildDeviceCard(d)).toList())),
    ]));
  }

  Widget _buildDeviceCard(Device d) {
    final alloc = _s.getActiveAllocation(d.id);
    final qc = _s.getQCReportByDevice(d.id);
    return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: app.C.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: app.C.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: app.C.brand2.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: const Center(child: Text('📱', style: TextStyle(fontSize: 16)))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${d.model} ${d.capacity} ${d.color}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: app.C.t1)),
            Text('ID: ${d.id} · 序列号: ${d.serial}', style: TextStyle(fontSize: 10, color: app.C.t3)),
          ])),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _infoTag('状态', d.status == 'in_stock' ? '在库' : d.status == 'sold' ? '已售' : d.status, d.status == 'sold' ? app.C.green : app.C.brand2),
          const SizedBox(width: 6),
          _infoTag('成色', d.condition, app.C.orange),
          const SizedBox(width: 6),
          _infoTag('电池', '${d.batteryHealth}%', app.C.blue),
          if (qc != null) ...[const SizedBox(width: 6), _infoTag('品级', qc.grade, qc.grade == 'A' ? app.C.green : app.C.orange)],
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Text('采购${yuan(d.purchaseCost)} · 库${d.stockDays}天', style: TextStyle(fontSize: 10, color: app.C.t2)),
          const Spacer(),
          if (alloc != null) Text('📍 ${alloc.assignee}', style: TextStyle(fontSize: 10, color: app.C.brand2)),
          if (alloc != null) Text(' · ${alloc.purpose}', style: TextStyle(fontSize: 10, color: app.C.t3)),
        ]),
        if (d.sellPrice > 0) Padding(padding: const EdgeInsets.only(top: 4), child: Row(children: [
          Text('售价${yuan(d.sellPrice)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: app.C.brand2)),
          if (d.sellDate != null) Text(' · ${d.sellDate}', style: TextStyle(fontSize: 10, color: app.C.t3)),
        ])),
      ]));
  }

  Widget _infoTag(String label, String value, Color c) => Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(5)), child: Text('$label: $value', style: TextStyle(fontSize: 9, color: c)));
}

// ======================================================================
// 6. 分期付款管理
// ======================================================================
class InstallmentPage extends StatefulWidget {
  const InstallmentPage({Key? key}) : super(key: key);
  @override
  State<InstallmentPage> createState() => _InstallmentPageState();
}

class _InstallmentPageState extends State<InstallmentPage> {
  List<InstallmentPlan> _plans = [];

  @override
  void initState() { super.initState(); _refresh(); }

  void _refresh() { setState(() { _plans = _s.getInstallmentPlans(); }); }

  @override
  Widget build(BuildContext context) {
    return _appScaffold(context, '分期付款', Column(children: [
      Container(margin: const EdgeInsets.all(14), padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(color: app.C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: app.C.line)),
        child: Row(children: [
          _statItem('进行中', '${_plans.where((p) => p.status == 'active').length}', app.C.orange),
          _statItem('已结清', '${_plans.where((p) => p.status == 'completed').length}', app.C.green),
          _statItem('逾期', '${_plans.where((p) => p.status == 'active').where((p) => p.items.any((i) => i.isOverdue)).length}', app.C.red),
        ])),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: _actionBtn('➕ 创建分期方案', app.C.brand2, () => _showCreateDialog())),
      const SizedBox(height: 8),
      Expanded(child: _plans.isEmpty
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('💳', style: TextStyle(fontSize: 48)), const SizedBox(height: 8), Text('暂无分期记录\n点击上方创建分期方案', textAlign: TextAlign.center, style: TextStyle(color: app.C.t2, fontSize: 13))]))
        : ListView(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14), children: _plans.map((p) => _buildCard(p)).toList())),
    ]));
  }

  Widget _statItem(String label, String value, Color c) => Expanded(child: Column(children: [Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c)), Text(label, style: TextStyle(fontSize: 10, color: app.C.t2))]));

  Widget _actionBtn(String t, Color c, VoidCallback onTap) => SizedBox(width: double.infinity, child: InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: c.withOpacity(0.3))), child: Center(child: Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c))))));

  Widget _buildCard(InstallmentPlan p) {
    final overdue = p.items.where((i) => i.isOverdue).length;
    return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: app.C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: overdue > 0 ? app.C.red.withOpacity(0.3) : app.C.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(p.deviceName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: app.C.t1)),
          const Spacer(),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: (p.status == 'completed' ? app.C.green : overdue > 0 ? app.C.red : app.C.orange).withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
            child: Text(p.status == 'completed' ? '已结清' : overdue > 0 ? '逾期中' : '进行中', style: TextStyle(fontSize: 10, color: p.status == 'completed' ? app.C.green : overdue > 0 ? app.C.red : app.C.orange, fontWeight: FontWeight.w600))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Text('总价${yuan(p.totalAmount)}', style: TextStyle(fontSize: 12, color: app.C.t2)),
          const SizedBox(width: 12),
          Text('首付${yuan(p.downPayment)}', style: TextStyle(fontSize: 12, color: app.C.t2)),
          const SizedBox(width: 12),
          Text('${p.installmentCount}期×${yuan(p.installmentAmount)}/期', style: TextStyle(fontSize: 12, color: app.C.brand2)),
        ]),
        const SizedBox(height: 6),
        Text('买家: ${p.buyer} · ${p.contact}', style: TextStyle(fontSize: 10, color: app.C.t3)),
        const SizedBox(height: 8),
        // 分期进度条
        ...p.items.map((i) => Container(margin: const EdgeInsets.only(bottom: 4), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: i.paid ? app.C.green.withOpacity(0.08) : i.isOverdue ? app.C.red.withOpacity(0.08) : app.C.bg, borderRadius: BorderRadius.circular(6)),
          child: Row(children: [
            Text('第${i.index}期', style: TextStyle(fontSize: 11, color: app.C.t2, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Text(yuan(i.amount), style: TextStyle(fontSize: 11, color: app.C.t1)),
            const Spacer(),
            Text(i.paid ? '✅ ${i.paidAt.toString().substring(0, 10)}' : i.isOverdue ? '⚠️ 逾期' : '待还', style: TextStyle(fontSize: 10, color: i.paid ? app.C.green : i.isOverdue ? app.C.red : app.C.t3)),
            if (!i.paid)
              InkWell(onTap: () => _markPaid(p, i), child: Container(margin: const EdgeInsets.only(left: 8), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: app.C.green.withOpacity(0.12), borderRadius: BorderRadius.circular(5)),
                child: Text('收款', style: TextStyle(fontSize: 10, color: app.C.green, fontWeight: FontWeight.w700)))),
          ]))),
      ]));
  }

  void _showCreateDialog() {
    final devices = _s.getDevices().where((d) => d.status == 'in_stock' || d.status == 'listed').toList();
    final buyerC = TextEditingController();
    final contactC = TextEditingController();
    final totalC = TextEditingController();
    final downC = TextEditingController();
    int periods = 3;
    String? selectedId;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
      backgroundColor: app.C.card, title: const Text('创建分期方案', style: TextStyle(fontSize: 16)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(value: selectedId, items: devices.take(30).map((d) => DropdownMenuItem(value: d.id, child: Text('${d.model} ${d.capacity} ${yuan(d.sellPrice > 0 ? d.sellPrice : d.purchaseCost)}', style: const TextStyle(fontSize: 12)))).toList(),
          onChanged: (v) => setD(() { selectedId = v; if (v != null) { final d = devices.firstWhere((d) => d.id == v); final price = d.sellPrice > 0 ? d.sellPrice : d.purchaseCost; totalC.text = (price / 100).toStringAsFixed(0); }}),
          decoration: const InputDecoration(labelText: '设备', border: OutlineInputBorder()), style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 10),
        TextField(controller: buyerC, decoration: const InputDecoration(labelText: '买家姓名', border: OutlineInputBorder()), style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 10),
        TextField(controller: contactC, decoration: const InputDecoration(labelText: '联系方式', border: OutlineInputBorder()), style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 10),
        TextField(controller: totalC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '总金额(元)', border: OutlineInputBorder()), style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 10),
        TextField(controller: downC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '首付金额(元)', border: OutlineInputBorder()), style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 10),
        Row(children: [Text('分期期数: ', style: TextStyle(fontSize: 13, color: app.C.t2)), Expanded(child: Slider(value: periods.toDouble(), min: 2, max: 12, divisions: 10, label: '$periods期', activeColor: app.C.brand2, onChanged: (v) => setD(() => periods = v.round())))],),
        Center(child: Text('$periods期 × ${totalC.text.isNotEmpty && downC.text.isNotEmpty ? ((double.tryParse(totalC.text) ?? 0) - (double.tryParse(downC.text) ?? 0)) / periods : 0}元/期', style: TextStyle(fontSize: 12, color: app.C.brand2))),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('取消', style: TextStyle(color: app.C.t2))),
        TextButton(onPressed: () async {
          if (selectedId == null) { toast(ctx, '请选择设备'); return; }
          if (buyerC.text.isEmpty) { toast(ctx, '请输入买家姓名'); return; }
          final total = ((double.tryParse(totalC.text) ?? 0) * 100).round();
          final down = ((double.tryParse(downC.text) ?? 0) * 100).round();
          final rest = total - down;
          final perPeriod = rest ~/ periods;
          // 生成明细
          final items = <InstallmentItem>[];
          for (int i = 1; i <= periods; i++) {
            items.add(InstallmentItem(index: i, amount: perPeriod, dueDate: DateTime.now().add(Duration(days: 30 * i))));
          }
          final plan = InstallmentPlan(id: _uid(), deviceId: selectedId!, deviceName: devices.firstWhere((d) => d.id == selectedId!).model,
            buyer: buyerC.text, contact: contactC.text, totalAmount: total, downPayment: down,
            installmentCount: periods, installmentAmount: perPeriod, items: items, createdAt: DateTime.now().toIso8601String());
          await _s.addInstallmentPlan(plan);
          Navigator.pop(ctx); _refresh();
        }, child: const Text('创建', style: TextStyle(color: Color(0xFF06B6D4)))),
      ],
    )));
  }

  Future<void> _markPaid(InstallmentPlan p, InstallmentItem i) async {
    i.paid = true;
    i.paidAt = DateTime.now();
    // 检查是否全部还清
    if (p.items.every((item) => item.paid)) {
      p.status = 'completed';
    }
    await _s.updateInstallmentPlan(p);
    _refresh();
    toast(context, '第${i.index}期已收款');
  }
}

// ======================================================================
// 7. 预付定金管理
// ======================================================================
class DepositPage extends StatefulWidget {
  const DepositPage({Key? key}) : super(key: key);
  @override
  State<DepositPage> createState() => _DepositPageState();
}

class _DepositPageState extends State<DepositPage> {
  List<DepositRecord> _records = [];

  @override
  void initState() { super.initState(); _refresh(); }

  void _refresh() { setState(() { _records = _s.getDeposits(); }); }

  @override
  Widget build(BuildContext context) {
    return _appScaffold(context, '预付定金', Column(children: [
      Container(margin: const EdgeInsets.all(14), padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(color: app.C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: app.C.line)),
        child: Row(children: [
          _statItem('进行中', '${_records.where((d) => d.status == 'active').length}', app.C.orange),
          _statItem('已完成', '${_records.where((d) => d.status == 'completed').length}', app.C.green),
          _statItem('定金总额', yuan(_records.fold<int>(0, (s, d) => s + d.depositAmount)), app.C.brand2),
        ])),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: _actionBtn('➕ 收取定金', app.C.orange, () => _showCreateDialog())),
      const SizedBox(height: 8),
      Expanded(child: _records.isEmpty
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('💰', style: TextStyle(fontSize: 48)), const SizedBox(height: 8), Text('暂无定金记录\n点击上方收取定金', textAlign: TextAlign.center, style: TextStyle(color: app.C.t2, fontSize: 13))]))
        : ListView(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14), children: _records.map((r) => _buildCard(r)).toList())),
    ]));
  }

  Widget _statItem(String label, String value, Color c) => Expanded(child: Column(children: [Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c)), Text(label, style: TextStyle(fontSize: 10, color: app.C.t2))]));

  Widget _actionBtn(String t, Color c, VoidCallback onTap) => SizedBox(width: double.infinity, child: InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: c.withOpacity(0.3))), child: Center(child: Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c))))));

  Widget _buildCard(DepositRecord r) {
    return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: app.C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: app.C.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: (r.status == 'completed' ? app.C.green : app.C.orange).withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text(r.status == 'completed' ? '✅' : '💰', style: const TextStyle(fontSize: 16)))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.deviceName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: app.C.t1)),
            Text('${r.customer} · ${r.contact}', style: TextStyle(fontSize: 10, color: app.C.t2)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: (r.status == 'completed' ? app.C.green : r.status == 'cancelled' ? app.C.red : app.C.orange).withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
            child: Text(r.status == 'completed' ? '已完成' : r.status == 'cancelled' ? '已取消' : r.status == 'refunded' ? '已退款' : '进行中', style: TextStyle(fontSize: 10, color: r.status == 'completed' ? app.C.green : app.C.orange, fontWeight: FontWeight.w600))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Column(children: [Text(yuan(r.depositAmount), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: app.C.brand2)), Text('定金', style: TextStyle(fontSize: 10, color: app.C.t3))]),
          const SizedBox(width: 24),
          Column(children: [Text(yuan(r.remainingAmount), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: app.C.t1)), Text('尾款', style: TextStyle(fontSize: 10, color: app.C.t3))]),
          const SizedBox(width: 24),
          Column(children: [Text(yuan(r.totalPrice), style: TextStyle(fontSize: 14, color: app.C.t2)), Text('总价', style: TextStyle(fontSize: 10, color: app.C.t3))]),
          const Spacer(),
          if (r.status == 'active')
            InkWell(onTap: () => _completeDeposit(r), child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: app.C.green.withOpacity(0.12), borderRadius: BorderRadius.circular(8)), child: Text('收尾款', style: TextStyle(fontSize: 11, color: app.C.green, fontWeight: FontWeight.w700)))),
        ]),
      ]));
  }

  void _showCreateDialog() {
    final devices = _s.getDevices().where((d) => d.status == 'in_stock' || d.status == 'listed').toList();
    final customerC = TextEditingController();
    final contactC = TextEditingController();
    final depositC = TextEditingController();
    final totalC = TextEditingController();
    String? selectedId;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
      backgroundColor: app.C.card, title: const Text('收取定金', style: TextStyle(fontSize: 16)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(value: selectedId, items: devices.take(30).map((d) => DropdownMenuItem(value: d.id, child: Text('${d.model} ${d.capacity}', style: const TextStyle(fontSize: 12)))).toList(),
          onChanged: (v) => setD(() { selectedId = v; if (v != null) { final d = devices.firstWhere((d) => d.id == v); totalC.text = (d.sellPrice > 0 ? d.sellPrice : d.purchaseCost / 100 * 1.2).round().toString(); }}),
          decoration: const InputDecoration(labelText: '设备', border: OutlineInputBorder()), style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 10),
        TextField(controller: customerC, decoration: const InputDecoration(labelText: '客户姓名', border: OutlineInputBorder()), style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 10),
        TextField(controller: contactC, decoration: const InputDecoration(labelText: '联系方式', border: OutlineInputBorder()), style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 10),
        TextField(controller: depositC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '定金(元)', border: OutlineInputBorder()), style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 10),
        TextField(controller: totalC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '总价(元)', border: OutlineInputBorder()), style: const TextStyle(fontSize: 13)),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('取消', style: TextStyle(color: app.C.t2))),
        TextButton(onPressed: () async {
          if (selectedId == null) { toast(ctx, '请选择设备'); return; }
          if (customerC.text.isEmpty) { toast(ctx, '请输入客户姓名'); return; }
          final r = DepositRecord(id: _uid(), deviceId: selectedId!, deviceName: devices.firstWhere((d) => d.id == selectedId).model,
            customer: customerC.text, contact: contactC.text,
            depositAmount: ((double.tryParse(depositC.text) ?? 0) * 100).round(),
            totalPrice: ((double.tryParse(totalC.text) ?? 0) * 100).round(), createdAt: DateTime.now().toIso8601String());
          await _s.addDeposit(r);
          Navigator.pop(ctx); _refresh();
        }, child: const Text('确认', style: TextStyle(color: Color(0xFF06B6D4)))),
      ],
    )));
  }

  Future<void> _completeDeposit(DepositRecord r) async {
    r.status = 'completed';
    await _s.updateDeposit(r);
    _refresh();
    toast(context, '${r.customer} 的定金交易已完成');
  }
}

// ======================================================================
// 8. 库存预警配置
// ======================================================================
class AlertConfigPage extends StatefulWidget {
  const AlertConfigPage({Key? key}) : super(key: key);
  @override
  State<AlertConfigPage> createState() => _AlertConfigPageState();
}

class _AlertConfigPageState extends State<AlertConfigPage> {
  late InventoryAlertConfig _cfg;

  @override
  void initState() { super.initState(); _cfg = _s.getAlertConfig(); }

  @override
  Widget build(BuildContext context) {
    return _appScaffold(context, '库存预警', ListView(padding: const EdgeInsets.all(14), children: [
      // 预警概览卡片
      Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: app.C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: app.C.line)),
        child: Column(children: [
          Row(children: [
            _statusCard('低库存告警', _cfg.enableLowStockAlert),
            const SizedBox(width: 8),
            _statusCard('滞销告警', _cfg.enableStagnantAlert),
          ]),
          const SizedBox(height: 12),
          // 检查预警
          InkWell(onTap: _checkAlerts, child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: app.C.brand2.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text('🔔 立即检查预警', style: TextStyle(fontSize: 14, color: app.C.brand2, fontWeight: FontWeight.w700))))),
        ])),
      const SizedBox(height: 14),
      // 低库存阈值设置
      Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: app.C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: app.C.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('⚡ 低库存阈值', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: app.C.t1)),
          const SizedBox(height: 12),
          Row(children: [
            Text('全局阈值: ${_cfg.lowStockThreshold}台', style: TextStyle(fontSize: 12, color: app.C.t2)),
            const Spacer(),
            _smallBtn('-', () { if (_cfg.lowStockThreshold > 1) setState(() => _cfg.lowStockThreshold--); }),
            Text(' ${_cfg.lowStockThreshold} ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: app.C.t1)),
            _smallBtn('+', () { setState(() => _cfg.lowStockThreshold++); }),
          ]),
          const SizedBox(height: 12),
          Text('滞销天数阈值: ${_cfg.stagnantDaysThreshold}天', style: TextStyle(fontSize: 12, color: app.C.t2)),
          Slider(value: _cfg.stagnantDaysThreshold.toDouble(), min: 7, max: 60, divisions: 53, label: '${_cfg.stagnantDaysThreshold}天', activeColor: app.C.orange, onChanged: (v) => setState(() => _cfg.stagnantDaysThreshold = v.round())),
        ])),
      const SizedBox(height: 14),
      // 型号独立阈值
      Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: app.C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: app.C.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('📱 型号独立阈值', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: app.C.t1)),
          const SizedBox(height: 8),
          ..._cfg.modelThresholds.entries.map((e) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                Expanded(child: Text(e.key, style: TextStyle(fontSize: 12, color: app.C.t1))),
                Text('${e.value}台', style: TextStyle(fontSize: 12, color: app.C.t2)),
                IconButton(icon: Icon(Icons.close, size: 14, color: app.C.t3), onPressed: () => setState(() => _cfg.modelThresholds.remove(e.key))),
              ]));
          }).toList(),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: InkWell(
              onTap: _addModelThreshold,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(color: app.C.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: app.C.line)),
                child: Center(child: Text('+ 添加型号阈值', style: TextStyle(fontSize: 12, color: app.C.brand2))),
              ),
            ),
          ),
        ])),
      const SizedBox(height: 20),
      SizedBox(width: double.infinity, child: ElevatedButton(
        style: ElevatedButton.styleFrom(primary: app.C.brand2, onPrimary: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        onPressed: _save, child: const Text('保存配置', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      )),
      const SizedBox(height: 40),
    ]));
  }

  Widget _statusCard(String title, bool enabled) => Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: (enabled ? app.C.green : app.C.red).withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
    child: Column(children: [Icon(enabled ? Icons.check_circle : Icons.cancel, color: enabled ? app.C.green : app.C.red, size: 22), const SizedBox(height: 4), Text(title, style: TextStyle(fontSize: 11, color: app.C.t2))])));

  Widget _smallBtn(String label, VoidCallback onTap) => GestureDetector(onTap: onTap, child: Container(width: 28, height: 28, decoration: BoxDecoration(color: app.C.bg, borderRadius: BorderRadius.circular(7), border: Border.all(color: app.C.line)), child: Center(child: Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: app.C.t1)))));

  void _addModelThreshold() {
    final models = _s.getDevices().map((d) => d.model).toSet().toList()..sort();
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
      backgroundColor: app.C.card, title: const Text('添加型号阈值', style: TextStyle(fontSize: 16)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(items: models.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 12)))).toList(),
          onChanged: (v) => setD(() => ctrl.text = v ?? ''), decoration: const InputDecoration(labelText: '选择型号', border: OutlineInputBorder()), style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 10),
        TextField(controller: ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '库存阈值(台)', border: OutlineInputBorder()), style: const TextStyle(fontSize: 13)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('取消', style: TextStyle(color: app.C.t2))),
        TextButton(onPressed: () {
          if (ctrl.text.isEmpty) return;
          final parts = ctrl.text.split('\n');
          if (parts.length == 2) {
            setState(() => _cfg.modelThresholds[parts[0]] = int.tryParse(parts[1]) ?? 5);
          } else {
            setState(() => _cfg.modelThresholds[ctrl.text] = 5);
          }
          Navigator.pop(ctx);
        }, child: const Text('添加', style: TextStyle(color: Color(0xFF06B6D4)))),
      ],
    )));
  }

  Future<void> _save() async {
    await _s.saveAlertConfig(_cfg);
    toast(context, '预警配置已保存');
    Navigator.pop(context);
  }

  void _checkAlerts() {
    final alerts = _s.checkAlerts();
    if (alerts.isEmpty) {
      toast(context, '✅ 库存健康，暂无预警');
      return;
    }
    final alertWidgets = alerts.map((a) {
      final isLowStock = a['type'] == 'low_stock';
      final msg = isLowStock
          ? '${a['model']} 库存仅剩 ${a['count']} 台 (阈值 ${a['threshold']} 台)'
          : '${a['model']} 有 ${a['count']} 台超 ${a['days']} 天未售';
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Icon(isLowStock ? Icons.warning_amber : Icons.timer_off, size: 18, color: app.C.orange),
          const SizedBox(width: 8),
          Expanded(child: Text(msg, style: TextStyle(fontSize: 12, color: app.C.t1))),
        ]));
    }).toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: app.C.card,
        title: Text('⚠️ 库存预警 (${alerts.length})', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: app.C.t1)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: alertWidgets)),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('知道了', style: TextStyle(color: app.C.brand2)))],
      ),
    );
  }
}

// ======================================================================
// 9. 六维度统计报表
// ======================================================================
class ReportPage extends StatefulWidget {
  const ReportPage({Key? key}) : super(key: key);
  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  static const _tabs = ['运营', '库存', '质检', '维修', '销售', '采购'];

  @override
  void initState() { super.initState(); _tabCtrl = TabController(length: _tabs.length, vsync: this); }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: app.C.bg,
      appBar: AppBar(
        title: const Text('统计报表', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: app.C.card, elevation: 0.5,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, size: 18), onPressed: () => Navigator.pop(context)),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: app.C.brand2,
          labelColor: app.C.brand2,
          unselectedLabelColor: app.C.t2,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: TabBarView(controller: _tabCtrl, children: [
        _OpsReport(), _StockReport(), _QCReport(), _RepairReport(), _SalesReport(), _PurchaseReport(),
      ]),
    );
  }
}

// ====== 1. 运营报表 ======
class _OpsReport extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = _s.computeStats();
    final daily = _s.getDailyOpsSnapshot();
    final monthly = _s.getMonthlyTrend();
    final yesterdayProfit = _s.getYesterdayProfit();
    final yesterdayOrders = _s.getYesterdayOrderCount();
    final yesterdayGmv = _s.getYesterdayGmv();
    final avgProfit = _s.getAvgProfit();
    final turnoverRate = _s.getCapitalTurnoverRate();

    return ListView(padding: const EdgeInsets.all(14), children: [
      // 今日概览
      _section('📊 今日运营概览', [
        _kpiGrid([
          _kpiItem('今日GMV', yuan(s.gmv), '昨日${yuan(yesterdayGmv)}', s.gmv >= yesterdayGmv ? app.C.green : app.C.red),
          _kpiItem('今日毛利', yuan(s.grossProfit), '昨日${yuan(yesterdayProfit)}', s.grossProfit >= yesterdayProfit ? app.C.green : app.C.red),
          _kpiItem('今日订单', '${s.orderCount}', '昨日$yesterdayOrders', app.C.brand2),
          _kpiItem('平均单台利', yuan(avgProfit), '资金周转${turnoverRate.toStringAsFixed(2)}', app.C.orange),
        ]),
      ]),
      const SizedBox(height: 12),
      // 月度趋势
      _section('📈 近12月趋势', [
        ...monthly.map((m) => _trendRow(m['month'] as String, m['gmv'] as int, m['profit'] as int, m['count'] as int)),
      ]),
      const SizedBox(height: 12),
      // 关键KPI
      _section('🎯 关键指标', [
        _kpiRow('在售库存', '${s.inStockCount} 台', '资金占用 ${yuan(s.capitalOccupied)}'),
        _kpiRow('滞销设备', '${s.stagnantCount} 台', '占比 ${s.inStockCount > 0 ? (s.stagnantCount * 100 / s.inStockCount).toStringAsFixed(0) : 0}%'),
        _kpiRow('待发货', '${s.pendingCount} 单', '在途 ${s.shippedCount} 单'),
        _kpiRow('待质检', '${s.pendingQcCount} 台', '未定价需处理'),
      ]),
      const SizedBox(height: 20),
      Text('数据说明：GMV为成交总额，毛利已扣除售后费用、佣金、物流等成本',
        textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: app.C.t3)),
      const SizedBox(height: 40),
    ]);
  }
}

// ====== 2. 库存报表 ======
class _StockReport extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final devices = _s.getDevices();
    final inStock = devices.where((d) => d.status == 'in_stock' || d.status == 'listed').toList();
    final ageDist = _s.getInventoryAgeDist();
    final turnoverByModel = _s.getTurnoverByModel().take(10).toList();
    final alerts = _s.checkAlerts();
    final modelCount = <String, int>{};
    for (final d in inStock) {
      modelCount[d.model] = (modelCount[d.model] ?? 0) + 1;
    }
    final topModels = modelCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final totalCapital = inStock.fold<int>(0, (s, d) => s + d.purchaseCost);

    return ListView(padding: const EdgeInsets.all(14), children: [
      // KPI
      _section('📦 库存概览', [
        _kpiGrid([
          _kpiItem('在售台数', '${inStock.length}', '资金${yuan(totalCapital)}', app.C.brand2),
          _kpiItem('滞销', '${(ageDist['16-30天'] ?? 0) + (ageDist['30天+'] ?? 0)} 台', '预警${alerts.length}条', app.C.orange),
          _kpiItem('平均库龄', inStock.isEmpty ? '0天' : '${(inStock.fold<int>(0, (s, d) => s + d.stockDays) / inStock.length).round()}天', '', app.C.blue),
          _kpiItem('资金周转率', _s.getCapitalTurnoverRate().toStringAsFixed(2), '', app.C.green),
        ]),
      ]),
      const SizedBox(height: 12),
      // 库存年龄
      _section('⏳ 库存年龄分布', [
        ...ageDist.entries.map((e) {
          final total = ageDist.values.fold<int>(0, (a, b) => a + b);
          final pct = total > 0 ? e.value / total : 0.0;
          return Padding(padding: const EdgeInsets.only(bottom: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(e.key, style: TextStyle(fontSize: 12, color: app.C.t2)),
              Text('${e.value}台', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: app.C.t1)),
            ]),
            const SizedBox(height: 4),
            ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(
              value: pct, backgroundColor: app.C.bg,
              valueColor: AlwaysStoppedAnimation(e.key.contains('30') ? app.C.red : (e.key.contains('16') ? app.C.orange : (e.key.contains('8') ? app.C.brand2 : app.C.green))),
              minHeight: 6)),
          ]));
        }),
      ]),
      const SizedBox(height: 12),
      // 型号排行
      if (topModels.isNotEmpty) _section('📱 型号库存排行', [
        ...topModels.take(10).toList().asMap().entries.map((e) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [
          Container(width: 22, alignment: Alignment.center, child: Text('${e.key + 1}', style: TextStyle(fontSize: 11, color: e.key < 3 ? app.C.brand2 : app.C.t3, fontWeight: FontWeight.w700))),
          const SizedBox(width: 8),
          Expanded(child: Text(e.value.key, style: TextStyle(fontSize: 12, color: app.C.t1, fontWeight: FontWeight.w500))),
          Text('${e.value.value}台', style: TextStyle(fontSize: 12, color: app.C.brand2, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Text(yuan(topModels.firstWhere((tm) => tm.key == e.value.key).value * (devices.where((d) => d.model == e.value.key && (d.status == 'in_stock' || d.status == 'listed')).fold<int>(0, (s, d) => s + d.purchaseCost))),
            style: TextStyle(fontSize: 10, color: app.C.t3)),
        ]))),
      ]),
      const SizedBox(height: 12),
      // 周转排行
      if (turnoverByModel.isNotEmpty) _section('⚡ 周转排行 (快→慢)', [
        ...turnoverByModel.asMap().entries.map((e) {
          final m = e.value;
          final days = m['avgDays'] as int;
          return Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [
            Container(width: 22, alignment: Alignment.center, child: Text('${e.key + 1}', style: TextStyle(fontSize: 11, color: days <= 15 ? app.C.green : app.C.t3, fontWeight: FontWeight.w700))),
            const SizedBox(width: 8),
            Expanded(child: Text(m['model'] as String, style: TextStyle(fontSize: 12, color: app.C.t1))),
            Text('$days天', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: days <= 15 ? app.C.green : (days <= 30 ? app.C.orange : app.C.red))),
          ]));
        }),
      ]),
      const SizedBox(height: 40),
    ]);
  }
}

// ====== 3. 质检报表 ======
class _QCReport extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final qcStats = _s.getQCStats();
    final defects = _s.getQCDefects();
    final reports = _s.getQCReports().take(20).toList();
    final byGrade = qcStats['byGrade'] as Map<String, int>;
    final total = qcStats['total'] as int;

    return ListView(padding: const EdgeInsets.all(14), children: [
      _section('🔍 质检总览', [
        _kpiGrid([
          _kpiItem('总质检', '$total', '通过${qcStats['passed']}', app.C.brand2),
          _kpiItem('通过率', '${((qcStats['passRate'] as double) * 100).toStringAsFixed(0)}%', total > 0 ? 'A品${byGrade['A'] ?? 0}台' : '', app.C.green),
          _kpiItem('需维修', '${(byGrade['C'] ?? 0) + (byGrade['D'] ?? 0)}', 'D品${byGrade['D'] ?? 0}台', app.C.orange),
          _kpiItem('A品率', total > 0 ? '${((byGrade['A'] ?? 0) / total * 100).toStringAsFixed(0)}%' : '0%', '', app.C.blue),
        ]),
      ]),
      const SizedBox(height: 12),
      // 品级分布
      if (total > 0) _section('📊 品级分布', [
        ...['A', 'B', 'C', 'D'].map((g) {
          final cnt = byGrade[g] ?? 0;
          final pct = cnt / total;
          return Padding(padding: const EdgeInsets.only(bottom: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 24, height: 24, decoration: BoxDecoration(color: g == 'A' ? app.C.green : g == 'B' ? app.C.blue : g == 'C' ? app.C.orange : app.C.red, borderRadius: BorderRadius.circular(6)),
                child: Center(child: Text(g, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)))),
              const SizedBox(width: 8),
              Text('$cnt 台', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: app.C.t1)),
              const Spacer(),
              Text('${(pct * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 12, color: app.C.t2)),
            ]),
            const SizedBox(height: 4),
            ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: pct, backgroundColor: app.C.bg,
              valueColor: AlwaysStoppedAnimation(g == 'A' ? app.C.green : g == 'B' ? app.C.blue : g == 'C' ? app.C.orange : app.C.red), minHeight: 6)),
          ]));
        }),
      ]),
      const SizedBox(height: 12),
      // 缺陷分布
      if (defects.isNotEmpty) _section('⚠️ 缺陷分布 TOP 6', [
        ...() {
          final sorted = defects.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
          return sorted.take(6).toList().asMap().entries.map((e) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [
            Container(width: 22, alignment: Alignment.center, child: Text('${e.key + 1}', style: TextStyle(fontSize: 11, color: app.C.t3))),
            const SizedBox(width: 8),
            Expanded(child: Text(e.value.key, style: TextStyle(fontSize: 12, color: app.C.t1))),
            Text('${e.value.value}次', style: TextStyle(fontSize: 12, color: app.C.red, fontWeight: FontWeight.w700)),
          ])));
        }(),
      ]),
      const SizedBox(height: 40),
    ]);
  }
}

// ====== 4. 维修报表 ======
class _RepairReport extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final stats = _s.getRepairStats();
    final repairs = _s.getRepairOrders();
    final byType = stats['byType'] as Map<String, dynamic>;
    final byStatus = stats['byStatus'] as Map<String, int>;
    final typeCountMap = byType['count'] as Map<String, int>;
    final typeCostMap = byType['cost'] as Map<String, int>;
    final total = stats['total'] as int;
    final totalCost = stats['totalCost'] as int;

    return ListView(padding: const EdgeInsets.all(14), children: [
      _section('🔧 维修总览', [
        _kpiGrid([
          _kpiItem('维修工单', '$total', '总额${yuan(totalCost)}', app.C.orange),
          _kpiItem('平均成本', yuan(stats['avgCost'] as int), total > 0 ? '${(total / repairs.length).round()}台' : '', app.C.brand2),
          _kpiItem('完成', '${byStatus['完成'] ?? 0}', '进行中${byStatus['进行中'] ?? 0}', app.C.green),
          _kpiItem('待修', '${byStatus['待修'] ?? 0}', '${total > 0 ? '完成率${((byStatus['完成'] ?? 0) / total * 100).toStringAsFixed(0)}%' : ''}', app.C.orange),
        ]),
      ]),
      const SizedBox(height: 12),
      // 维修类型分布
      if (typeCountMap.isNotEmpty) _section('📊 维修类型分布', [
        ...typeCountMap.entries.map((e) {
          final cost = typeCostMap[e.key] ?? 0;
          final pct = total > 0 ? e.value / total : 0.0;
          return Padding(padding: const EdgeInsets.only(bottom: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(e.key, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: app.C.t1)),
              const Spacer(),
              Text('${e.value}次', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: app.C.brand2)),
              const SizedBox(width: 8),
              Text(yuan(cost), style: TextStyle(fontSize: 11, color: app.C.t3)),
            ]),
            const SizedBox(height: 4),
            ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: pct, backgroundColor: app.C.bg,
              valueColor: const AlwaysStoppedAnimation(app.C.orange), minHeight: 6)),
          ]));
        }),
      ]),
      const SizedBox(height: 12),
      // 状态分布
      if (byStatus.isNotEmpty) _section('📋 维修状态', [
        ...byStatus.entries.map((e) {
          final pct = total > 0 ? e.value / total : 0.0;
          final c = e.key == '完成' ? app.C.green : e.key == '进行中' ? app.C.brand2 : app.C.orange;
          return Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(e.key, style: TextStyle(fontSize: 12, color: app.C.t1)),
            const Spacer(),
            Text('${e.value} (${(pct * 100).toStringAsFixed(0)}%)', style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w600)),
          ]));
        }),
      ]),
      const SizedBox(height: 40),
    ]);
  }
}

// ====== 5. 销售报表 ======
class _SalesReport extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final channelStats = _s.getSalesChannelStats();
    final monthly = _s.getMonthlyTrend();
    final profitByModel = _s.getProfitByModel().take(10).toList();
    final devices = _s.getDevices();
    final sold = devices.where((d) => d.status == 'sold').length;
    final totalRevenue = devices.where((d) => d.status == 'sold').fold<int>(0, (s, d) => s + d.sellPrice);
    final totalProfit = devices.where((d) => d.status == 'sold').fold<int>(0, (s, d) => s + d.netProfit);
    final grossMargin = totalRevenue > 0 ? (totalProfit / totalRevenue * 100) : 0.0;

    return ListView(padding: const EdgeInsets.all(14), children: [
      _section('💰 销售总览', [
        _kpiGrid([
          _kpiItem('累计售出', '$sold 台', '营收${yuan(totalRevenue)}', app.C.brand2),
          _kpiItem('累计毛利', yuan(totalProfit), '毛利率${grossMargin.toStringAsFixed(1)}%', app.C.green),
          _kpiItem('平均售价', sold > 0 ? yuan(totalRevenue ~/ sold) : '¥0', '均利${sold > 0 ? yuan(totalProfit ~/ sold) : "¥0"}', app.C.blue),
          _kpiItem('平均周转', '${_s.getAvgTurnoverDays()}天', '', app.C.orange),
        ]),
      ]),
      const SizedBox(height: 12),
      // 渠道分析
      if (channelStats.isNotEmpty) _section('📊 渠道GMV分析', [
        ...channelStats.map((c) {
          final totalGmv = channelStats.fold<int>(0, (s, e) => s + (e['gmv'] as int));
          final pct = totalGmv > 0 ? (c['gmv'] as int) / totalGmv : 0.0;
          return Padding(padding: const EdgeInsets.only(bottom: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(c['channel'] as String, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: app.C.t1)),
              const Spacer(),
              Text(yuan(c['gmv'] as int), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: app.C.brand2)),
              const SizedBox(width: 8),
              Text('${(pct * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 11, color: app.C.t3)),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              ClipRRect(borderRadius: BorderRadius.circular(3), child: SizedBox(width: MediaQuery.of(context).size.width - 130, child: LinearProgressIndicator(value: pct, backgroundColor: app.C.bg,
                valueColor: const AlwaysStoppedAnimation(app.C.green), minHeight: 6))),
              const SizedBox(width: 8),
              Text('${c['count']}单', style: TextStyle(fontSize: 10, color: app.C.t3)),
            ]),
          ]));
        }),
      ]),
      const SizedBox(height: 12),
      // 月度趋势
      _section('📈 月度销售趋势', [
        ...monthly.map((m) => _trendRow(m['month'] as String, m['gmv'] as int, m['profit'] as int, m['count'] as int)),
      ]),
      const SizedBox(height: 12),
      // 利润排行
      if (profitByModel.isNotEmpty) _section('🏆 型号利润排行', [
        ...profitByModel.asMap().entries.map((e) {
          final m = e.value;
          return Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [
            Container(width: 22, alignment: Alignment.center, child: Text('${e.key + 1}', style: TextStyle(fontSize: 11, color: e.key < 3 ? app.C.brand2 : app.C.t3, fontWeight: FontWeight.w700))),
            const SizedBox(width: 8),
            Expanded(child: Text(m['model'] as String, style: TextStyle(fontSize: 12, color: app.C.t1, fontWeight: FontWeight.w500))),
            Text('${m['count']}台', style: TextStyle(fontSize: 10, color: app.C.t2)),
            const SizedBox(width: 12),
            Text(yuan(m['profit'] as int), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: (m['profit'] as int) >= 0 ? app.C.green : app.C.red)),
          ]));
        }),
      ]),
      const SizedBox(height: 40),
    ]);
  }
}

// ====== 6. 采购分析报表 ======
class _PurchaseReport extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final pos = _s.getPurchaseOrders();
    final channelStats = _s.getPurchaseChannelStats();
    final suppliers = _s.getSupplierStats();
    final totalCost = pos.fold<int>(0, (s, p) => s + p.totalCost);
    final totalReturned = pos.fold<int>(0, (s, p) => s + p.returnedCount);
    final totalAfterSale = pos.fold<int>(0, (s, p) => s + (p.afterSaleAmount ?? 0));

    return ListView(padding: const EdgeInsets.all(14), children: [
      _section('📥 采购总览', [
        _kpiGrid([
          _kpiItem('采购单', '${pos.length}', '总额${yuan(totalCost)}', app.C.brand2),
          _kpiItem('退货', '$totalReturned 件', pos.isEmpty ? '' : '退货率${pos.fold<int>(0, (s, p) => s + p.deviceCount) > 0 ? (totalReturned / pos.fold<int>(0, (s, p) => s + p.deviceCount) * 100).toStringAsFixed(1) : 0}%', app.C.red),
          _kpiItem('售后议价', yuan(totalAfterSale), pos.length > 0 ? '均${yuan(totalAfterSale ~/ (pos.length))}' : '', app.C.orange),
          _kpiItem('平均单额', pos.isEmpty ? '¥0' : yuan(totalCost ~/ pos.length), '', app.C.blue),
        ]),
      ]),
      const SizedBox(height: 12),
      // 采购渠道分析
      if (channelStats.isNotEmpty) _section('🛒 采购渠道分析', [
        ...channelStats.map((c) {
          final totalVal = channelStats.fold<int>(0, (s, e) => s + (e['totalCost'] as int));
          final pct = totalVal > 0 ? (c['totalCost'] as int) / totalVal : 0.0;
          return Padding(padding: const EdgeInsets.only(bottom: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(c['platform'] as String, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: app.C.t1)),
              const Spacer(),
              Text(yuan(c['totalCost'] as int), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: app.C.brand2)),
            ]),
            const SizedBox(height: 4),
            ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: pct, backgroundColor: app.C.bg,
              valueColor: const AlwaysStoppedAnimation(app.C.purple), minHeight: 6)),
            Padding(padding: const EdgeInsets.only(top: 2), child: Row(children: [
              Text('${c['count']}单', style: TextStyle(fontSize: 10, color: app.C.t3)),
              const SizedBox(width: 12),
              Text('退货${c['returned']}件', style: TextStyle(fontSize: 10, color: app.C.red)),
              if ((c['afterSale'] as int) > 0) ...[const SizedBox(width: 12), Text('议价${yuan(c['afterSale'] as int)}', style: TextStyle(fontSize: 10, color: app.C.orange))],
            ])),
          ]));
        }),
      ]),
      const SizedBox(height: 12),
      // 供应商利润分析
      if (suppliers.isNotEmpty) _section('🏭 供应商利润分析', [
        ...suppliers.asMap().entries.map((e) {
          final m = e.value;
          final profitVal = m['profit'] as int;
          final revenue = m['revenue'] as int;
          final margin = revenue > 0 ? profitVal / revenue * 100 : 0.0;
          return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
            Container(width: 22, alignment: Alignment.center, child: Text('${e.key + 1}', style: TextStyle(fontSize: 11, color: e.key < 3 ? app.C.purple : app.C.t3, fontWeight: FontWeight.w700))),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m['channel'] as String, style: TextStyle(fontSize: 12, color: app.C.t1, fontWeight: FontWeight.w600)),
              Text('${m['count']}台 · 利润率${margin.toStringAsFixed(0)}%', style: TextStyle(fontSize: 9, color: app.C.t3)),
            ])),
            Text(yuan(profitVal), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: profitVal >= 0 ? app.C.green : app.C.red)),
          ]));
        }),
      ]),
      const SizedBox(height: 40),
    ]);
  }
}

// ========== 报表通用组件 ==========
Widget _section(String title, List<Widget> children) => Container(
  padding: const EdgeInsets.all(14),
  decoration: BoxDecoration(color: app.C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: app.C.line)),
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: app.C.t1)),
    const SizedBox(height: 12),
    ...children,
  ]));

Widget _kpiGrid(List<Widget> items) => GridView.count(
  shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
  crossAxisCount: 2, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 2.2,
  children: items);

Widget _kpiItem(String label, String value, String sub, Color color) => Container(
  padding: const EdgeInsets.all(10),
  decoration: BoxDecoration(color: color.withOpacity(0.07), borderRadius: BorderRadius.circular(10)),
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
    Text(label, style: TextStyle(fontSize: 9, color: app.C.t3)),
    const SizedBox(height: 2),
    Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
    if (sub.isNotEmpty) ...[const SizedBox(height: 1), Text(sub, style: TextStyle(fontSize: 9, color: app.C.t3))],
  ]));

Widget _kpiRow(String label, String value, String sub) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Row(children: [
    Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: app.C.t1))),
    Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: app.C.brand2)),
    const SizedBox(width: 10),
    Text(sub, style: TextStyle(fontSize: 10, color: app.C.t3)),
  ]));

Widget _trendRow(String month, int gmv, int profit, int count) {
  final maxVal = 500000; // 假设最大50万用于进度条
  return Padding(padding: const EdgeInsets.only(bottom: 6), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      SizedBox(width: 55, child: Text(month.length > 7 ? month.substring(5) : month, style: TextStyle(fontSize: 11, color: app.C.t2))),
      const SizedBox(width: 4),
      Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(
        value: maxVal > 0 ? (gmv / maxVal).clamp(0.0, 1.0) : 0.0,
        backgroundColor: app.C.bg, valueColor: const AlwaysStoppedAnimation(app.C.brand2), minHeight: 5))),
      const SizedBox(width: 6),
      SizedBox(width: 65, child: Text(yuan(gmv), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: app.C.t1))),
      SizedBox(width: 50, child: Text(yuan(profit), style: TextStyle(fontSize: 10, color: profit >= 0 ? app.C.green : app.C.red))),
      SizedBox(width: 25, child: Text('$count单', style: TextStyle(fontSize: 9, color: app.C.t3))),
    ]),
  ]));
}

// ======================================================================
// 10. 仓库管理
// ======================================================================
class WarehousePage extends StatefulWidget {
  const WarehousePage({Key? key}) : super(key: key);
  @override
  State<WarehousePage> createState() => _WarehousePageState();
}

class _WarehousePageState extends State<WarehousePage> {
  List<Warehouse> _warehouses = [];

  @override
  void initState() { super.initState(); _refresh(); }

  void _refresh() { setState(() { _warehouses = _s.getWarehouses(); }); }

  @override
  Widget build(BuildContext context) {
    return _appScaffold(context, '仓库管理', Column(children: [
      Padding(padding: const EdgeInsets.all(14), child: SizedBox(width: double.infinity, child: InkWell(
        onTap: _showAddDialog,
        child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: app.C.brand2.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: app.C.brand2.withOpacity(0.3))),
          child: Center(child: Text('➕ 新增仓库', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: app.C.brand2))),
        ),
      ))),
      Expanded(child: _warehouses.isEmpty
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('🏭', style: TextStyle(fontSize: 48)), const SizedBox(height: 8), Text('暂无仓库，点击上方新增', style: TextStyle(color: app.C.t2, fontSize: 13))]))
        : ListView.builder(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14), itemCount: _warehouses.length, itemBuilder: (_, i) => _buildCard(_warehouses[i]))),
    ]));
  }

  Widget _buildCard(Warehouse w) {
    final deviceCount = _s.getDevices().where((d) => d.status == 'in_stock' || d.status == 'listed').length;
    return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: app.C.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: app.C.line)),
      child: Row(children: [
        Container(width: 42, height: 42, decoration: BoxDecoration(color: app.C.brand2.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: const Center(child: Text('🏭', style: TextStyle(fontSize: 18)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(w.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: app.C.t1)),
          if (w.address.isNotEmpty) Text(w.address, style: TextStyle(fontSize: 11, color: app.C.t2)),
          Row(children: [
            Text('设备 $deviceCount 台', style: TextStyle(fontSize: 10, color: app.C.t3)),
            if (w.contact.isNotEmpty) Text(' · ${w.contact}', style: TextStyle(fontSize: 10, color: app.C.t3)),
          ]),
        ])),
        IconButton(icon: Icon(Icons.edit, size: 16, color: app.C.t3), onPressed: () => _editWarehouse(w)),
      ]));
  }

  void _showAddDialog() {
    final nameC = TextEditingController();
    final addrC = TextEditingController();
    final contactC = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: app.C.card, title: const Text('新增仓库', style: TextStyle(fontSize: 16)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameC, decoration: const InputDecoration(labelText: '仓库名称', border: OutlineInputBorder()), style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 10),
        TextField(controller: addrC, decoration: const InputDecoration(labelText: '地址', border: OutlineInputBorder()), style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 10),
        TextField(controller: contactC, decoration: const InputDecoration(labelText: '联系人', border: OutlineInputBorder()), style: const TextStyle(fontSize: 14)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('取消', style: TextStyle(color: app.C.t2))),
        TextButton(onPressed: () async {
          if (nameC.text.isEmpty) { toast(ctx, '请输入仓库名称'); return; }
          await _s.addWarehouse(Warehouse(id: _uid(), name: nameC.text, address: addrC.text, contact: contactC.text, createdAt: DateTime.now().toIso8601String()));
          Navigator.pop(ctx); _refresh();
        }, child: const Text('保存', style: TextStyle(color: Color(0xFF06B6D4)))),
      ],
    ));
  }

  void _editWarehouse(Warehouse w) async {
    final nameC = TextEditingController(text: w.name);
    final addrC = TextEditingController(text: w.address);
    final contactC = TextEditingController(text: w.contact);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: app.C.card, title: const Text('编辑仓库', style: TextStyle(fontSize: 16)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameC, decoration: const InputDecoration(labelText: '仓库名称', border: OutlineInputBorder()), style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 10),
        TextField(controller: addrC, decoration: const InputDecoration(labelText: '地址', border: OutlineInputBorder()), style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 10),
        TextField(controller: contactC, decoration: const InputDecoration(labelText: '联系人', border: OutlineInputBorder()), style: const TextStyle(fontSize: 14)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('取消', style: TextStyle(color: app.C.t2))),
        TextButton(onPressed: () async {
          w.name = nameC.text; w.address = addrC.text; w.contact = contactC.text;
          await _s.updateWarehouse(w); Navigator.pop(ctx); _refresh();
        }, child: const Text('保存', style: TextStyle(color: Color(0xFF06B6D4)))),
      ],
    ));
  }
}

// ======================================================================
// 11. 调拨管理
// ======================================================================
class TransferPage extends StatefulWidget {
  const TransferPage({Key? key}) : super(key: key);
  @override
  State<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends State<TransferPage> {
  List<WarehouseTransfer> _transfers = [];

  @override
  void initState() { super.initState(); _refresh(); }

  void _refresh() { setState(() { _transfers = _s.getTransfers(); }); }

  @override
  Widget build(BuildContext context) {
    final done = _transfers.where((t) => t.status == 'done').length;
    return _appScaffold(context, '库存调拨', Column(children: [
      Container(margin: const EdgeInsets.all(14), padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(color: app.C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: app.C.line)),
        child: Row(children: [
          Expanded(child: Column(children: [Text('${_transfers.length}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: app.C.brand2)), Text('总调拨', style: TextStyle(fontSize: 10, color: app.C.t2))])),
          Expanded(child: Column(children: [Text('$done', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: app.C.green)), Text('已完成', style: TextStyle(fontSize: 10, color: app.C.t2))])),
          Expanded(child: Column(children: [Text('${_transfers.length - done}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: app.C.orange)), Text('处理中', style: TextStyle(fontSize: 10, color: app.C.t2))])),
        ])),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: SizedBox(width: double.infinity, child: InkWell(
        onTap: _showCreateDialog,
        child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: app.C.brand2.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: app.C.brand2.withOpacity(0.3))),
          child: Center(child: Text('🔄 新建调拨', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: app.C.brand2))),
        ),
      ))),
      const SizedBox(height: 8),
      Expanded(child: _transfers.isEmpty
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('🚚', style: TextStyle(fontSize: 48)), const SizedBox(height: 8), Text('暂无调拨记录\n点击上方新建调拨', textAlign: TextAlign.center, style: TextStyle(color: app.C.t2, fontSize: 13))]))
        : ListView.builder(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14), itemCount: _transfers.length, itemBuilder: (_, i) => _buildCard(_transfers[i]))),
    ]));
  }

  Widget _buildCard(WarehouseTransfer t) {
    return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: app.C.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: app.C.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: (t.status == 'done' ? app.C.green : app.C.orange).withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
            child: Text(t.status == 'done' ? '已完成' : '待处理', style: TextStyle(fontSize: 10, color: t.status == 'done' ? app.C.green : app.C.orange, fontWeight: FontWeight.w600))),
          const Spacer(),
          Text(t.createdAt.substring(0, 10), style: TextStyle(fontSize: 10, color: app.C.t3)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: Column(children: [Text(t.fromWarehouseName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: app.C.t1)), Text('源仓库', style: TextStyle(fontSize: 10, color: app.C.t3))])),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('→', style: TextStyle(fontSize: 20, color: app.C.brand2))),
          Expanded(child: Column(children: [Text(t.toWarehouseName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: app.C.t1)), Text('目标仓库', style: TextStyle(fontSize: 10, color: app.C.t3))])),
        ]),
        const SizedBox(height: 8),
        Text('${t.deviceCount} 台设备', style: TextStyle(fontSize: 12, color: app.C.t2)),
        if (t.operator != null && t.operator!.isNotEmpty) Text('经办人: ${t.operator}', style: TextStyle(fontSize: 10, color: app.C.t3)),
        if (t.status == 'pending')
          Padding(padding: const EdgeInsets.only(top: 8), child: Row(children: [
            InkWell(onTap: () => _completeTransfer(t), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: app.C.green.withOpacity(0.12), borderRadius: BorderRadius.circular(8)), child: Text('确认完成', style: TextStyle(fontSize: 12, color: app.C.green, fontWeight: FontWeight.w700)))),
            const SizedBox(width: 8),
            InkWell(onTap: () => _cancelTransfer(t), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: app.C.red.withOpacity(0.12), borderRadius: BorderRadius.circular(8)), child: Text('取消', style: TextStyle(fontSize: 12, color: app.C.red, fontWeight: FontWeight.w700)))),
          ])),
      ]));
  }

  void _showCreateDialog() {
    final warehouses = _s.getWarehouses();
    if (warehouses.length < 2) { toast(context, '至少需要2个仓库才能调拨'); return; }
    final devices = _s.getDevices().where((d) => d.status == 'in_stock' || d.status == 'listed').toList();
    if (devices.isEmpty) { toast(context, '无可调拨的库存设备'); return; }

    String? fromId, toId;
    final selectedDevices = <String>{};
    final optC = TextEditingController();

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
      backgroundColor: app.C.card, title: const Text('新建调拨', style: TextStyle(fontSize: 16)),
      content: SingleChildScrollView(child: SizedBox(width: 300, child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(value: fromId, items: warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name, style: const TextStyle(fontSize: 12)))).toList(),
          onChanged: (v) => setD(() => fromId = v), decoration: const InputDecoration(labelText: '源仓库', border: OutlineInputBorder()), style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(value: toId, items: warehouses.where((w) => w.id != fromId).map((w) => DropdownMenuItem(value: w.id, child: Text(w.name, style: const TextStyle(fontSize: 12)))).toList(),
          onChanged: (v) => setD(() => toId = v), decoration: const InputDecoration(labelText: '目标仓库', border: OutlineInputBorder()), style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 8),
        Text('选择设备 (${selectedDevices.length})', style: TextStyle(fontSize: 12, color: app.C.t2)),
        SizedBox(height: 120, child: ListView(
          children: devices.take(20).map((d) {
            final sel = selectedDevices.contains(d.id);
            return CheckboxListTile(
              dense: true, value: sel,
              onChanged: (v) { setD(() { if (v == true) selectedDevices.add(d.id); else selectedDevices.remove(d.id); }); },
              title: Text('${d.model} ${d.capacity}', style: const TextStyle(fontSize: 11)),
              subtitle: Text(yuan(d.purchaseCost), style: const TextStyle(fontSize: 9)),
              controlAffinity: ListTileControlAffinity.leading,
            );
          }).toList(),
        )),
        TextField(controller: optC, decoration: const InputDecoration(labelText: '经办人', border: OutlineInputBorder()), style: const TextStyle(fontSize: 13)),
    ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('取消', style: TextStyle(color: app.C.t2))),
        TextButton(onPressed: () async {
          if (fromId == null || toId == null) { toast(ctx, '请选择仓库'); return; }
          if (selectedDevices.isEmpty) { toast(ctx, '请选择要调拨的设备'); return; }
          final fw = warehouses.firstWhere((w) => w.id == fromId);
          final tw = warehouses.firstWhere((w) => w.id == toId);
          final t = WarehouseTransfer(id: _uid(), fromWarehouseId: fromId!, fromWarehouseName: fw.name,
            toWarehouseId: toId!, toWarehouseName: tw.name, deviceIds: selectedDevices.toList(),
            operator: optC.text.isNotEmpty ? optC.text : null, createdAt: DateTime.now().toIso8601String());
          await _s.addTransfer(t); Navigator.pop(ctx); _refresh();
        }, child: const Text('创建', style: TextStyle(color: Color(0xFF06B6D4)))),
      ],
    )));
  }

  void _completeTransfer(WarehouseTransfer t) async {
    t.status = 'done'; await _s.updateTransfer(t); _refresh(); toast(context, '调拨已完成');
  }

  void _cancelTransfer(WarehouseTransfer t) async {
    t.status = 'cancelled'; await _s.updateTransfer(t); _refresh(); toast(context, '调拨已取消');
  }
}

// ======================================================================
// 12. 盘点管理
// ======================================================================
class InventoryCountPage extends StatefulWidget {
  const InventoryCountPage({Key? key}) : super(key: key);
  @override
  State<InventoryCountPage> createState() => _InventoryCountPageState();
}

class _InventoryCountPageState extends State<InventoryCountPage> {
  List<InventoryCount> _counts = [];

  @override
  void initState() { super.initState(); _refresh(); }

  void _refresh() { setState(() { _counts = _s.getInventoryCounts(); }); }

  @override
  Widget build(BuildContext context) {
    return _appScaffold(context, '盘点管理', Column(children: [
      Container(margin: const EdgeInsets.all(14), padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(color: app.C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: app.C.line)),
        child: Row(children: [
          Expanded(child: Column(children: [Text('${_counts.length}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: app.C.brand2)), Text('盘点单', style: TextStyle(fontSize: 10, color: app.C.t2))])),
          Expanded(child: Column(children: [Text('${_counts.where((c) => c.status == 'done').length}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: app.C.green)), Text('已完成', style: TextStyle(fontSize: 10, color: app.C.t2))])),
          Expanded(child: Column(children: [Text('${_counts.fold<int>(0, (s, c) => s + c.diffCount)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: app.C.red)), Text('差异', style: TextStyle(fontSize: 10, color: app.C.t2))])),
        ])),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: SizedBox(width: double.infinity, child: InkWell(
        onTap: _showCreateDialog,
        child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: app.C.orange.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: app.C.orange.withOpacity(0.3))),
          child: Center(child: Text('📋 新建盘点', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: app.C.orange))),
        ),
      ))),
      const SizedBox(height: 8),
      Expanded(child: _counts.isEmpty
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('📋', style: TextStyle(fontSize: 48)), const SizedBox(height: 8), Text('暂无盘点记录\n点击上方新建盘点', textAlign: TextAlign.center, style: TextStyle(color: app.C.t2, fontSize: 13))]))
        : ListView.builder(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14), itemCount: _counts.length, itemBuilder: (_, i) => _buildCard(_counts[i]))),
    ]));
  }

  Widget _buildCard(InventoryCount c) {
    final matchPct = c.totalCount > 0 ? (c.matchedCount / c.totalCount * 100).round() : 0;
    return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: app.C.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: app.C.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: (c.status == 'done' ? app.C.green : app.C.orange).withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
            child: Text(c.status == 'done' ? '已完成' : '草稿', style: TextStyle(fontSize: 10, color: c.status == 'done' ? app.C.green : app.C.orange, fontWeight: FontWeight.w600))),
          const Spacer(),
          Text(c.createdAt.substring(0, 10), style: TextStyle(fontSize: 10, color: app.C.t3)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Text(c.warehouseName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: app.C.t1)),
          const Spacer(),
          Text('${c.matchedCount}/${c.totalCount} 匹配', style: TextStyle(fontSize: 12, color: app.C.t2)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: matchPct / 100.0, backgroundColor: app.C.bg,
          valueColor: AlwaysStoppedAnimation(matchPct >= 95 ? app.C.green : app.C.orange), minHeight: 5)),
        if (c.diffCount > 0) Text('⚠️ ${c.diffCount} 条差异', style: TextStyle(fontSize: 11, color: app.C.red, fontWeight: FontWeight.w600)),
      ]));
  }

  void _showCreateDialog() {
    final warehouses = _s.getWarehouses();
    if (warehouses.isEmpty) { toast(context, '请先创建仓库'); return; }
    String? whId;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
      backgroundColor: app.C.card, title: const Text('新建盘点', style: TextStyle(fontSize: 16)),
      content: DropdownButtonFormField<String>(value: whId, items: warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
        onChanged: (v) => setD(() => whId = v), decoration: const InputDecoration(labelText: '选择仓库', border: OutlineInputBorder()), style: const TextStyle(fontSize: 13)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('取消', style: TextStyle(color: app.C.t2))),
        TextButton(onPressed: () async {
          if (whId == null) { toast(ctx, '请选择仓库'); return; }
          final w = warehouses.firstWhere((w) => w.id == whId);
          final devices = _s.getDevices().where((d) => d.status == 'in_stock' || d.status == 'listed').toList();
          final items = devices.map((d) => InventoryCountItem(deviceId: d.id, deviceName: '${d.model} ${d.capacity}', serial: d.serial)).toList();
          final c = InventoryCount(id: _uid(), warehouseId: whId!, warehouseName: w.name, items: items, createdAt: DateTime.now().toIso8601String());
          await _s.addInventoryCount(c); Navigator.pop(ctx); _refresh();
        }, child: const Text('创建', style: TextStyle(color: Color(0xFF06B6D4)))),
      ],
    )));
  }
}

// ======================================================================
// 13. 其他出入库
// ======================================================================
class OtherInOutPage extends StatefulWidget {
  const OtherInOutPage({Key? key}) : super(key: key);
  @override
  State<OtherInOutPage> createState() => _OtherInOutPageState();
}

class _OtherInOutPageState extends State<OtherInOutPage> {
  List<OtherInOut> _records = [];

  @override
  void initState() { super.initState(); _refresh(); }

  void _refresh() { setState(() { _records = _s.getOtherInOuts(); }); }

  @override
  Widget build(BuildContext context) {
    return _appScaffold(context, '其他出入库', Column(children: [
      Container(margin: const EdgeInsets.all(14), padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(color: app.C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: app.C.line)),
        child: Row(children: [
          Expanded(child: Column(children: [Text('${_records.where((r) => r.type == 'in').length}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: app.C.green)), Text('入库', style: TextStyle(fontSize: 10, color: app.C.t2))])),
          Expanded(child: Column(children: [Text('${_records.where((r) => r.type == 'out').length}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: app.C.red)), Text('出库', style: TextStyle(fontSize: 10, color: app.C.t2))])),
          Expanded(child: Column(children: [Text('${_records.length}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: app.C.brand2)), Text('总计', style: TextStyle(fontSize: 10, color: app.C.t2))])),
        ])),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Row(children: [
        Expanded(child: InkWell(onTap: () => _showCreateDialog('in'), child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: app.C.green.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: app.C.green.withOpacity(0.3))), child: Center(child: Text('📥 入库', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: app.C.green)))))),
        const SizedBox(width: 8),
        Expanded(child: InkWell(onTap: () => _showCreateDialog('out'), child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: app.C.red.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: app.C.red.withOpacity(0.3))), child: Center(child: Text('📤 出库', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: app.C.red)))))),
      ])),
      const SizedBox(height: 8),
      Expanded(child: _records.isEmpty
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('📦', style: TextStyle(fontSize: 48)), const SizedBox(height: 8), Text('暂无记录\n点击上方入库或出库', textAlign: TextAlign.center, style: TextStyle(color: app.C.t2, fontSize: 13))]))
        : ListView.builder(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14), itemCount: _records.length, itemBuilder: (_, i) => _buildCard(_records[i]))),
    ]));
  }

  Widget _buildCard(OtherInOut r) {
    return Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: app.C.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: app.C.line)),
      child: Row(children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: (r.type == 'in' ? app.C.green : app.C.red).withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
          child: Center(child: Text(r.type == 'in' ? '📥' : '📤', style: const TextStyle(fontSize: 16)))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(r.deviceName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: app.C.t1)),
          Text('${r.category} · ${r.type == 'in' ? '入库' : '出库'}${r.quantity}件', style: TextStyle(fontSize: 10, color: app.C.t2)),
          if (r.note != null && r.note!.isNotEmpty) Text(r.note!, style: TextStyle(fontSize: 10, color: app.C.t3)),
        ])),
        if (r.amount != null && r.amount! > 0) Text(yuan(r.amount!), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: r.type == 'in' ? app.C.green : app.C.red)),
      ]));
  }

  void _showCreateDialog(String type) {
    final devices = _s.getDevices().where((d) => d.status == 'in_stock' || d.status == 'listed').toList();
    final catC = TextEditingController();
    final qtyC = TextEditingController(text: '1');
    final amountC = TextEditingController();
    final noteC = TextEditingController();
    String? selectedId;
    String category = type == 'in' ? '赠品' : '报废';

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
      backgroundColor: app.C.card, title: Text('${type == 'in' ? '入' : '出'}库登记', style: const TextStyle(fontSize: 16)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(value: selectedId, items: devices.map((d) => DropdownMenuItem(value: d.id, child: Text('${d.model} ${d.capacity}', style: const TextStyle(fontSize: 12)))).toList(),
          onChanged: (v) => setD(() => selectedId = v), decoration: const InputDecoration(labelText: '设备', border: OutlineInputBorder()), style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(value: category, items: (type == 'in' ? ['赠品','配件','样品','其他'] : ['报废','损耗','赠送','其他']).map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) => setD(() => category = v ?? '其他'), decoration: const InputDecoration(labelText: '类别', border: OutlineInputBorder()), style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 8),
        TextField(controller: qtyC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '数量', border: OutlineInputBorder()), style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 8),
        TextField(controller: amountC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '金额(元)', border: OutlineInputBorder()), style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 8),
        TextField(controller: noteC, decoration: const InputDecoration(labelText: '备注', border: OutlineInputBorder()), style: const TextStyle(fontSize: 13)),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('取消', style: TextStyle(color: app.C.t2))),
        TextButton(onPressed: () async {
          if (selectedId == null) { toast(ctx, '请选择设备'); return; }
          final d = devices.firstWhere((d) => d.id == selectedId);
          final r = OtherInOut(id: _uid(), type: type, category: category, deviceId: selectedId, deviceName: '${d.model} ${d.capacity}',
            quantity: int.tryParse(qtyC.text) ?? 1, amount: ((double.tryParse(amountC.text) ?? 0) * 100).round(),
            note: noteC.text.isNotEmpty ? noteC.text : null, createdAt: DateTime.now().toIso8601String());
          await _s.addOtherInOut(r); Navigator.pop(ctx); _refresh();
        }, child: Text(type == 'in' ? '入库' : '出库', style: const TextStyle(color: Color(0xFF06B6D4)))),
      ],
    )));
  }
}

// ========== 通用 AppScaffold ==========
Widget _appScaffold(BuildContext context, String title, Widget body) {
  return Scaffold(
    backgroundColor: app.C.bg,
    appBar: AppBar(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      backgroundColor: app.C.card,
      elevation: 0.5,
      leading: IconButton(icon: const Icon(Icons.arrow_back_ios, size: 18), onPressed: () => Navigator.pop(context)),
    ),
    body: body,
  );
}
