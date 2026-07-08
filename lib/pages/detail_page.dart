import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';
import '../components/index.dart';
import '../utils/utils.dart';
import '../models.dart';
import '../main.dart';
import '../ai_service.dart';
import '../services/device_export_service.dart';
import '../services/xianyu_copy_service.dart';
import 'sell_page.dart';

class DetailPage extends StatefulWidget {
  final Device device;
  const DetailPage({Key? key, required this.device}) : super(key: key);
  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  String? aiPrice;
  bool loading = false;
  bool downloading = false;
  bool savingInfo = false;
  bool regeneratingDescription = false;
  late Device device;
  final _modelCtrl = TextEditingController();
  final _serialCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _networkCtrl = TextEditingController();
  final _conditionCtrl = TextEditingController();
  final _batteryCtrl = TextEditingController();
  final _cycleCtrl = TextEditingController();
  final _accessoriesCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _channelCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _idClean = true;
  String _status = 'in_stock';
  String _cleanSnapshot = '';
  static const _capacityOptions = ['64G', '128G', '256G', '512G', '1TB', '2TB'];
  static const _colorOptions = ['深空灰', '银色', '星光色', '粉色', '紫色', '蓝色'];
  static const _accessoryOptions = [
    '裸机',
    '盒装',
    '原装充电器',
    '妙控键盘',
    'Apple Pencil',
  ];

  @override
  void initState() {
    super.initState();
    device = widget.device;
    _loadEditorsFromDevice();
  }

  @override
  void dispose() {
    for (final controller in [
      _modelCtrl,
      _serialCtrl,
      _capacityCtrl,
      _colorCtrl,
      _networkCtrl,
      _conditionCtrl,
      _batteryCtrl,
      _cycleCtrl,
      _accessoriesCtrl,
      _costCtrl,
      _channelCtrl,
      _dateCtrl,
      _priceCtrl,
      _descCtrl,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _loadEditorsFromDevice() {
    _modelCtrl.text = device.model;
    _serialCtrl.text = device.serial;
    _capacityCtrl.text = device.capacity;
    _colorCtrl.text = device.color;
    _networkCtrl.text = device.network;
    _conditionCtrl.text = device.condition;
    _batteryCtrl.text = '${device.batteryHealth}';
    _cycleCtrl.text = '${device.cycleCount}';
    _accessoriesCtrl.text = device.accessories;
    _costCtrl.text = (device.purchaseCost / 100).round().toString();
    _channelCtrl.text = device.purchaseChannel;
    _dateCtrl.text = device.purchaseDate;
    _priceCtrl.text =
        device.sellPrice > 0 ? (device.sellPrice / 100).round().toString() : '';
    _descCtrl.text = device.description ?? '';
    _idClean = device.idLockClean;
    _status = device.status;
    _markEditorsClean();
  }

  String _snapshotEditors() {
    const sep = '\u001f';
    return [
      _modelCtrl.text.trim(),
      _serialCtrl.text.trim(),
      _capacityCtrl.text.trim(),
      _colorCtrl.text.trim(),
      _networkCtrl.text.trim(),
      _conditionCtrl.text.trim(),
      _batteryCtrl.text.trim(),
      _cycleCtrl.text.trim(),
      _accessoriesCtrl.text.trim(),
      _costCtrl.text.trim(),
      _channelCtrl.text.trim(),
      _dateCtrl.text.trim(),
      _priceCtrl.text.trim(),
      _descCtrl.text.trim(),
      _idClean.toString(),
      _status,
    ].join(sep);
  }

  void _markEditorsClean() {
    _cleanSnapshot = _snapshotEditors();
  }

  bool get _hasUnsavedChanges =>
      _cleanSnapshot.isNotEmpty && _snapshotEditors() != _cleanSnapshot;

  Future<bool> _confirmLeaveIfDirty() async {
    if (!_hasUnsavedChanges) return true;
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: C.bgCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: C.border),
            ),
            title: Text(
              '保存修改？',
              style: TextStyle(
                color: C.t1,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            content: Text(
              '这台设备有未保存的修改，离开前可以先保存，或放弃本次修改。',
              style: TextStyle(color: C.t2, fontSize: 13, height: 1.45),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'discard'),
                child: Text('放弃修改', style: TextStyle(color: C.red)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'cancel'),
                child: Text('继续编辑', style: TextStyle(color: C.t2)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'save'),
                child: Text('保存后离开', style: TextStyle(color: C.cyan)),
              ),
            ],
          ),
    );
    if (action == 'discard') return true;
    if (action == 'save') {
      return _saveInlineInfo(showToast: false);
    }
    return false;
  }

  Future<void> _askAi() async {
    setState(() => loading = true);
    final r = await AiService.priceAdvice(
      model: device.model,
      capacity: device.capacity,
      color: device.color,
      network: device.network,
      condition: device.condition,
      batteryHealth: device.batteryHealth,
      purchaseCost: device.purchaseCost,
      stockDays: device.stockDays,
    );
    setState(() {
      aiPrice = r;
      loading = false;
    });
  }

  int _moneyFen(String raw, int fallback) {
    final clean = raw.replaceAll('¥', '').replaceAll(',', '').trim();
    if (clean.isEmpty) return fallback;
    final value = double.tryParse(clean);
    if (value == null) return fallback;
    return (value * 100).round();
  }

  int _intValue(String raw, int fallback) {
    final clean = raw.trim();
    if (clean.isEmpty) return fallback;
    return int.tryParse(clean) ?? fallback;
  }

  void _setControllerText(TextEditingController controller, String value) {
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    setState(() {});
  }

  Future<void> _pickPurchaseDate() async {
    final firstDate = DateTime(2020);
    final lastDate = DateTime.now().add(const Duration(days: 1));
    DateTime initial;
    try {
      initial = DateTime.parse(_dateCtrl.text.trim());
    } catch (_) {
      initial = DateTime.now();
    }
    if (initial.isBefore(firstDate)) initial = firstDate;
    if (initial.isAfter(lastDate)) initial = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
      builder:
          (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme:
                  C.isLight
                      ? ColorScheme.dark(
                        primary: C.purple,
                        onPrimary: C.hudDark,
                        surface: C.hudDark2,
                        onSurface: C.t1,
                        outline: C.hudLine,
                      )
                      : ColorScheme.dark(
                        primary: C.cyan,
                        onPrimary: Colors.black,
                        surface: C.bgCard,
                        onSurface: C.t1,
                      ),
            ),
            child: child!,
          ),
    );
    if (picked == null) return;
    _setControllerText(_dateCtrl, fmtDate(picked));
  }

  Future<bool> _saveInlineInfo({bool showToast = true}) async {
    if (savingInfo) return false;
    final model = _modelCtrl.text.trim();
    if (model.isEmpty) {
      toast(context, '型号不能为空');
      return false;
    }
    setState(() => savingInfo = true);
    device.model = model;
    device.serial = _serialCtrl.text.trim();
    device.capacity = _capacityCtrl.text.trim();
    device.color = _colorCtrl.text.trim();
    device.network = _networkCtrl.text.trim();
    device.condition = _conditionCtrl.text.trim();
    device.batteryHealth =
        _intValue(
          _batteryCtrl.text,
          device.batteryHealth,
        ).clamp(0, 100).toInt();
    device.cycleCount = _intValue(_cycleCtrl.text, device.cycleCount);
    device.idLockClean = _idClean;
    device.accessories =
        _accessoriesCtrl.text.trim().isEmpty
            ? '裸机'
            : _accessoriesCtrl.text.trim();
    device.purchaseCost = _moneyFen(_costCtrl.text, device.purchaseCost);
    device.purchaseChannel = _channelCtrl.text.trim();
    device.purchaseDate =
        _dateCtrl.text.trim().isEmpty
            ? device.purchaseDate
            : _dateCtrl.text.trim();
    device.sellPrice = _moneyFen(_priceCtrl.text, 0);
    device.status = _status;
    device.description =
        _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim();

    await gStorage.updateDevice(device);
    _markEditorsClean();
    if (!mounted) return true;
    setState(() => savingInfo = false);
    if (showToast) toast(context, '设备信息已保存');
    return true;
  }

  Future<void> _regenerateDescription() async {
    if (regeneratingDescription) return;
    final model = _modelCtrl.text.trim();
    if (model.isEmpty) {
      toast(context, '请先填写型号');
      return;
    }
    setState(() => regeneratingDescription = true);
    final copyReference = XianyuCopyService.buildReferenceContext(
      gStorage,
      model: model,
      condition: _conditionCtrl.text.trim(),
    );
    final desc = await AiService.generateDescription(
      model: model,
      capacity: _capacityCtrl.text.trim(),
      color: _colorCtrl.text.trim(),
      network: _networkCtrl.text.trim(),
      condition: _conditionCtrl.text.trim(),
      batteryHealth: _intValue(_batteryCtrl.text, device.batteryHealth),
      cycleCount: _intValue(_cycleCtrl.text, device.cycleCount),
      idLockClean: _idClean,
      accessories:
          _accessoriesCtrl.text.trim().isEmpty
              ? '裸机'
              : _accessoriesCtrl.text.trim(),
      copywritingReference: copyReference,
      previousDescription: _descCtrl.text,
    );
    if (!mounted) return;
    setState(() => regeneratingDescription = false);
    if (desc.startsWith('AI调用') || desc.startsWith('AI返回')) {
      toast(context, desc);
      return;
    }
    _descCtrl.text = desc;
    await _saveInlineInfo(showToast: false);
    if (!mounted) return;
    toast(context, 'AI描述已重新生成');
  }

  void _genReport() {
    final report = '''【货脉验机报告】

设备：${device.model} ${device.capacity} ${device.color}
序列号：${device.serial}
网络制式：${device.network}

—— 成色鉴定 ——
成色等级：${device.condition}
电池健康度：${device.batteryHealth}%
充电循环次数：${device.cycleCount}次

—— 安全检测 ——
iCloud激活锁：${device.idLockClean ? "无锁 ✓" : "有锁 ✗"}
ID锁状态：${device.idLockClean ? "正常 ✓" : "异常 ✗"}
配件：${device.accessories}

—— 质检结论 ——
${device.idLockClean ? "✅ 该设备各项检测正常，可正常交易" : "⚠️ 该设备存在ID锁风险，建议谨慎"}

检测时间：${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}
报告由「货脉」自动生成''';
    Clipboard.setData(ClipboardData(text: report));
    toast(context, '验机报告已复制到剪贴板，可粘贴发给买家');
  }

  /// 一键下载：描述存剪贴板 + 图片存相册 + 最前面插自制封面图
  /// [openXianyu] 为 true 时下载成功后拉起闲鱼 app
  Future<void> _downloadAll({bool openXianyu = false}) async {
    if (downloading) return;
    setState(() => downloading = true);
    try {
      final result = await DeviceExportService.downloadListing(
        device: device,
        docDir: gDocDir,
        openXianyu: openXianyu,
      );
      if (!mounted) return;
      toast(context, result.message);
    } catch (e) {
      toast(context, '下载失败：$e');
    } finally {
      if (mounted) setState(() => downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImg = device.imagePath != null && device.imagePath!.isNotEmpty;
    final images = hasImg ? device.imagePath!.split(';') : <String>[];
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final canLeave = await _confirmLeaveIfDirty();
        if (!canLeave || !mounted) return;
        Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: C.bgDeep,
        body: SafeArea(
          child: Stack(
            children: [
              ListView(
                children: [
                  Stack(
                    children: [
                      Container(
                        height: 230,
                        color: C.bgCardMuted,
                        child:
                            images.isNotEmpty
                                ? LocalImageThumb(
                                  path: images.first,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: 230,
                                  radius: 0,
                                )
                                : Center(
                                  child: Icon(
                                    Icons.tablet_mac_rounded,
                                    color: C.t3,
                                    size: 64,
                                  ),
                                ),
                      ),
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.32),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.chevron_left_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                            onPressed: () async {
                              final canLeave = await _confirmLeaveIfDirty();
                              if (!canLeave || !mounted) return;
                              Navigator.pop(context);
                            },
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 12,
                        left: 14,
                        child: StatusChip(
                          device.idLockClean ? 'ID无锁' : 'ID异常',
                          device.idLockClean ? C.green : C.red,
                        ),
                      ),
                      if (device.isStagnant)
                        Positioned(
                          bottom: 12,
                          right: 14,
                          child: StatusChip('滞销', C.red),
                        ),
                    ],
                  ),
                  // 多图横向展示
                  if (images.length > 1)
                    SizedBox(
                      height: 80,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: images.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder:
                            (_, i) => LocalImageThumb(
                              path: images[i],
                              width: 70,
                              height: 70,
                              radius: 8,
                            ),
                      ),
                    ),
                  CardBox(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${device.model} ${device.capacity} ${device.color}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: C.t1,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Text(
                              device.sellPrice > 0
                                  ? yuan(device.sellPrice)
                                  : '未定价',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: device.sellPrice > 0 ? C.cyan : C.orange,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '采购${yuan(device.purchaseCost)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: C.t2,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            if (device.status == 'sold')
                              StatusChip(
                                '毛利${yuan(device.netProfit)}',
                                device.netProfit >= 0 ? C.green : C.red,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${device.purchaseChannel} · 库龄${device.stockDays}天 · ${device.serial.isEmpty ? "暂无序列号" : device.serial}',
                          style: TextStyle(fontSize: 11.5, color: C.t2),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _buildInlineInfoCard(),
                  _buildDescriptionCard(),
                  CardBox(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionTitle(
                          'AI定价建议',
                          trailing: AiService.effectiveConfig.model,
                        ),
                        const SizedBox(height: 8),
                        if (aiPrice != null)
                          Text(
                            aiPrice!,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: C.t2,
                              height: 1.8,
                            ),
                          )
                        else
                          Text(
                            '点击下方按钮，调用AI根据型号/成色/电池/采购成本/库存天数给出定价建议',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: C.t3,
                              height: 1.8,
                            ),
                          ),
                        const SizedBox(height: 12),
                        if (loading)
                          Center(child: CircularProgressIndicator(color: C.t3))
                        else
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _askAi,
                              icon: Icon(Icons.auto_awesome_rounded, size: 18),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: C.purple,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                elevation: 0,
                              ),
                              label: const Text(
                                '调用 AI 定价',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // 一键下载：两个并排按钮（纯下载 / 下载并去闲鱼）
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed:
                                downloading
                                    ? null
                                    : () => _downloadAll(openXianyu: false),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: C.bgCard,
                              foregroundColor: C.t1,
                              padding: EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13),
                              ),
                              elevation: 0,
                              side: BorderSide(color: C.border),
                            ),
                            child: const Text(
                              '仅下载',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed:
                                downloading
                                    ? null
                                    : () => _downloadAll(openXianyu: true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: C.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13),
                              ),
                              elevation: 0,
                            ),
                            child:
                                downloading
                                    ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                    : const Text(
                                      '下载并去闲鱼',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (device.status == 'in_stock' || device.status == 'listed')
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                      child: primaryBtn(
                        '售出此设备',
                        () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const SellPage()),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    child: ghostBtn('生成验机报告', _genReport),
                  ),
                  CardBox(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionTitle('全链路追溯'),
                        const SizedBox(height: 12),
                        _tl(
                          '收购入库',
                          '${device.purchaseDate} · 采购${yuan(device.purchaseCost)} · ${device.purchaseChannel}',
                          true,
                        ),
                        _tl(
                          '质检完成',
                          '${device.condition} · 电池${device.batteryHealth}% · ID锁${device.idLockClean ? "无锁 ✓" : "有锁 ✗"}',
                          true,
                        ),
                        if (device.status == 'listed')
                          _tl(
                            '上架待售',
                            '标价${device.sellPrice > 0 ? yuan(device.sellPrice) : "未定"} · 在库${device.stockDays}天${device.isStagnant ? " · 滞销" : ""}',
                            false,
                            last: true,
                          ),
                        if (device.status == 'sold' &&
                            device.repairCost != null &&
                            device.repairCost! > 0)
                          _tl(
                            '翻新维修',
                            '${device.sellDate ?? ""} · 成本${yuan(device.repairCost!)}',
                            false,
                          ),
                        if (device.status == 'sold')
                          _tl(
                            '已售出',
                            '${device.sellDate ?? ""} · ${device.sellChannel ?? ""} · 售价${yuan(device.sellPrice)} · 毛利${yuan(device.netProfit)}',
                            true,
                            last: true,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInlineInfoCard() => CardBox(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('基本信息', icon: Icons.tune_rounded),
        const SizedBox(height: 2),
        _formGroupLabel('设备参数'),
        const SizedBox(height: 9),
        _fieldRow(
          _field(_modelCtrl, '型号', Icons.tablet_mac_rounded),
          _field(_serialCtrl, '序列号', Icons.confirmation_number_outlined),
        ),
        const SizedBox(height: 12),
        _fieldRow(
          _choiceField(
            _capacityCtrl,
            '容量',
            Icons.sd_storage_outlined,
            _capacityOptions,
          ),
          _choiceField(_colorCtrl, '颜色', Icons.palette_outlined, _colorOptions),
        ),
        const SizedBox(height: 12),
        _fieldRow(
          _choiceField(_networkCtrl, '网络', Icons.wifi_rounded, iPadNetworks),
          _choiceField(
            _conditionCtrl,
            '成色',
            Icons.verified_outlined,
            iPadConditions,
          ),
        ),
        const SizedBox(height: 12),
        _fieldRow(
          _field(
            _batteryCtrl,
            '电池健康(%)',
            Icons.battery_5_bar_rounded,
            keyboardType: TextInputType.number,
          ),
          _field(
            _cycleCtrl,
            '循环次数',
            Icons.refresh_rounded,
            keyboardType: TextInputType.number,
          ),
        ),
        const SizedBox(height: 12),
        _fieldRow(
          _choiceField(
            _accessoriesCtrl,
            '配件',
            Icons.inventory_2_outlined,
            _accessoryOptions,
          ),
          _dateField(),
        ),
        const SizedBox(height: 17),
        _softDivider(),
        const SizedBox(height: 13),
        _formGroupLabel('交易信息'),
        const SizedBox(height: 9),
        _choiceField(
          _channelCtrl,
          '采购渠道',
          Icons.storefront_outlined,
          PurchaseChannels,
        ),
        const SizedBox(height: 12),
        _fieldRow(
          _field(
            _costCtrl,
            '采购成本(元)',
            Icons.payments_outlined,
            keyboardType: TextInputType.number,
          ),
          _field(
            _priceCtrl,
            '售价(元)',
            Icons.sell_outlined,
            keyboardType: TextInputType.number,
          ),
        ),
        const SizedBox(height: 15),
        _formGroupLabel('设备状态'),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _idClean = true),
                child: _EditToggle(
                  label: 'ID 无锁',
                  selected: _idClean,
                  color: C.mint,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _idClean = false),
                child: _EditToggle(
                  label: 'ID 异常',
                  selected: !_idClean,
                  color: C.red,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _statusOption('in_stock', '库存', C.mint),
            _statusOption('listed', '在售', C.cyan),
            _statusOption('sold', '已售', C.purple),
            _statusOption('returned', '退回', C.orange),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: savingInfo ? null : () => _saveInlineInfo(),
            icon:
                savingInfo
                    ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: C.primaryButtonFg,
                      ),
                    )
                    : Icon(Icons.save_rounded, size: 18),
            style: FilledButton.styleFrom(
              backgroundColor: C.primaryButtonBg,
              foregroundColor: C.primaryButtonFg,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: C.primaryButtonBorder),
              ),
            ),
            label: Text(
              savingInfo ? '保存中' : '保存修改',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildDescriptionCard() => CardBox(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('商品描述', icon: Icons.notes_rounded),
        AppFormField(
          controller: _descCtrl,
          label: '商品描述',
          icon: Icons.notes_rounded,
          maxLines: 5,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: savingInfo ? null : () => _saveInlineInfo(),
                icon: Icon(Icons.save_outlined, size: 17),
                style: OutlinedButton.styleFrom(
                  foregroundColor: C.t1,
                  side: BorderSide(
                    color:
                        C.isLight
                            ? C.purple.withValues(alpha: 0.28)
                            : Colors.white.withValues(alpha: 0.12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: const StadiumBorder(),
                ),
                label: const Text(
                  '保存描述',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed:
                    regeneratingDescription ? null : _regenerateDescription,
                icon:
                    regeneratingDescription
                        ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: C.isLight ? C.primaryButtonFg : Colors.white,
                          ),
                        )
                        : Icon(Icons.auto_awesome_rounded, size: 17),
                style: FilledButton.styleFrom(
                  backgroundColor: C.isLight ? C.hudDark2 : C.purple,
                  foregroundColor: C.isLight ? C.purple : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: const StadiumBorder(),
                ),
                label: Text(
                  regeneratingDescription ? '生成中' : 'AI重新生成',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _formGroupLabel(String label) => Text(
    label,
    style: TextStyle(color: C.t3, fontSize: 11, fontWeight: FontWeight.w900),
  );

  Widget _softDivider() => Container(
    height: 1,
    color: C.isLight ? C.divider : Colors.white.withValues(alpha: 0.06),
  );

  Widget _fieldShell({
    required String label,
    required IconData icon,
    required Widget child,
    VoidCallback? onTap,
  }) {
    final content = AnimatedContainer(
      duration: C.fast,
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.fromLTRB(11, 8, 10, 8),
      decoration: BoxDecoration(
        color: C.isLight ? C.hudDark2 : const Color(0xB5161B24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: C.isLight ? C.hudLine : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color:
                  C.isLight
                      ? C.purple.withValues(alpha: 0.16)
                      : Colors.white.withValues(alpha: 0.055),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: C.isLight ? C.purple : C.t3, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: C.t3,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 6),
                child,
              ],
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: content,
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    String? hint,
    TextInputType? keyboardType,
  }) => _fieldShell(
    label: label,
    icon: icon,
    child: TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: 1,
      textInputAction: TextInputAction.next,
      style: TextStyle(
        color: C.t1,
        fontSize: 15,
        fontWeight: FontWeight.w900,
        height: 1.1,
      ),
      decoration: InputDecoration(
        isDense: true,
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        hintText: hint ?? '未填写',
        hintStyle: TextStyle(
          color: C.tMuted,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        contentPadding: EdgeInsets.zero,
      ),
    ),
  );

  Widget _choiceField(
    TextEditingController controller,
    String label,
    IconData icon,
    List<String> options,
  ) {
    final values = _optionsWithCurrent(options, controller.text.trim());
    final current = controller.text.trim();
    return _fieldShell(
      label: label,
      icon: icon,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: current.isEmpty ? null : current,
          isExpanded: true,
          isDense: true,
          dropdownColor: C.bgCard,
          menuMaxHeight: 320,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: C.t3),
          hint: Text(
            '未选择',
            style: TextStyle(
              color: C.tMuted,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          style: TextStyle(
            color: C.t1,
            fontSize: 15,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
          items:
              values
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item,
                      child: Text(
                        item,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  )
                  .toList(),
          onChanged: (value) {
            if (value == null) return;
            _setControllerText(controller, value);
          },
        ),
      ),
    );
  }

  List<String> _optionsWithCurrent(List<String> options, String current) {
    final values = [...options];
    if (current.isNotEmpty && !values.contains(current))
      values.insert(0, current);
    return values;
  }

  Widget _dateField() => _fieldShell(
    label: '收购日期',
    icon: Icons.event_outlined,
    onTap: _pickPurchaseDate,
    child: Row(
      children: [
        Expanded(
          child: Text(
            _dateCtrl.text.trim().isEmpty ? '点击选择日期' : _dateCtrl.text.trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _dateCtrl.text.trim().isEmpty ? C.tMuted : C.t1,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
        ),
        Icon(Icons.keyboard_arrow_down_rounded, color: C.t3, size: 20),
      ],
    ),
  );

  Widget _fieldRow(Widget left, Widget right) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 280) {
        return Column(children: [left, const SizedBox(height: 12), right]);
      }
      return Row(
        children: [
          Expanded(child: left),
          const SizedBox(width: 12),
          Expanded(child: right),
        ],
      );
    },
  );

  Widget _statusOption(String value, String label, Color color) => _EditToggle(
    label: label,
    selected: _status == value,
    color: color,
    compact: true,
    onTap: () => setState(() => _status = value),
  );

  Widget _tl(String tt, String td, bool active, {bool last = false}) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Column(
        children: [
          Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: active ? C.cyan : C.t3,
              shape: BoxShape.circle,
              border: Border.all(color: C.bgDeep, width: 2),
            ),
          ),
          if (!last) Container(width: 2, height: 36, color: C.border),
        ],
      ),
      SizedBox(width: 11),
      Expanded(
        child: Padding(
          padding: EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tt,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: C.t1,
                ),
              ),
              SizedBox(height: 2),
              Text(td, style: TextStyle(fontSize: 11, color: C.t2)),
            ],
          ),
        ),
      ),
    ],
  );
}

class _EditToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final bool compact;
  final VoidCallback? onTap;

  const _EditToggle({
    required this.label,
    required this.selected,
    required this.color,
    this.compact = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selectedBg = C.isLight ? C.hudDark : color;
    final idleBg = C.isLight ? C.hudDark2 : const Color(0xB5161B24);
    final selectedBorder = C.isLight ? C.purple.withValues(alpha: 0.58) : color;
    final idleBorder =
        C.isLight ? C.hudLine : Colors.white.withValues(alpha: 0.08);
    final selectedText = C.isLight ? C.purple : Colors.black;
    final body = AnimatedContainer(
      duration: C.fast,
      height: compact ? 38 : 42,
      padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? selectedBg : idleBg,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: selected ? selectedBorder : idleBorder),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: selected ? selectedText : C.t2,
          fontSize: compact ? 12 : 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: body,
      ),
    );
  }
}
