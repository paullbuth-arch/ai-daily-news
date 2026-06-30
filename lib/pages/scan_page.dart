import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/colors.dart';
import '../components/index.dart';
import '../utils/utils.dart';
import '../storage.dart';
import '../models.dart';
import '../ai_service.dart';
import '../serial_decoder.dart';
import '../main.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({Key? key}) : super(key: key);
  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  // 基本信息
  final _serialCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  String selectedModel = '';
  String selectedCapacity = '';
  String selectedColor = '';
  String selectedNetwork = 'WiFi';
  String selectedCondition = '95新';
  String selectedChannel = '华强北同行';
  bool isCustomChannel = false;
  final _customChannelCtrl = TextEditingController();

  // ID锁检测
  bool iCloudLock = false, actLock = false, mdm = false, configLock = false;
  Map<String, dynamic>? idCheck;

  // 多图上传（最多12张）
  List<String> imagePaths = [];

  // "关于本机"截图AI识别
  String? aboutThisDeviceImagePath;
  bool aiRecognizing = false;
  Map<String, String>? aiRecognizedInfo;

  // 保存
  bool saving = false;

  // 步骤指引：当前步骤 0=基本信息 1=实拍图 2=确认入库
  int currentStep = 0;

  void _checkIdLock() {
    final c = IdLockChecker.check(
      iCloudLocked: iCloudLock,
      activationLocked: actLock,
      mdmSupervised: mdm,
      configLock: configLock,
    );
    setState(() {
      idCheck = c;
    });
  }

  /// 拍"关于本机"截图，AI识别序列号
  Future<void> _pickAboutThisDevice() async {
    try {
      final picker = ImagePicker();
      final x = await picker.pickImage(source: ImageSource.camera);
      if (x != null) {
        final now = DateTime.now();
        final dest = '$gDocDir/about_${now.millisecondsSinceEpoch}.jpg';
        await File(x.path).copy(dest);
        setState(() {
          aboutThisDeviceImagePath = dest;
          aiRecognizing = true;
        });

        // 读取图片转为base64
        final bytes = await File(dest).readAsBytes();
        final base64 = base64Encode(bytes);

        // 调用AI识别
        final info = await AiService.recognizeAboutThisDevice(base64);
        setState(() {
          aiRecognizing = false;
          aiRecognizedInfo = info;
          // 自动填入识别结果
          if (info['serial'] != '未知' && info['serial']!.isNotEmpty) {
            _serialCtrl.text = info['serial']!;
          }
          if (info['model'] != '未知' && info['model']!.isNotEmpty) {
            selectedModel = info['model']!;
          }
          if (info['capacity'] != '未知' && info['capacity']!.isNotEmpty) {
            selectedCapacity = info['capacity']!;
          }
          if (info['color'] != '未知' && info['color']!.isNotEmpty) {
            selectedColor = info['color']!;
          }
          if (info['network'] != '未知' && info['network']!.isNotEmpty) {
            selectedNetwork = info['network']!;
          }
          if (info['batteryHealth'] != '未知' &&
              info['batteryHealth']!.isNotEmpty) {
            // batteryHealth 保留但不直接用字段，后面存入Device
          }
        });
        toast(context, '✅ AI已识别设备信息');
      }
    } catch (e) {
      setState(() {
        aiRecognizing = false;
      });
      toast(context, 'AI识别失败：$e');
    }
  }

  /// 添加实拍图（原图，不压缩）
  Future<void> _addImage(bool fromCamera) async {
    if (imagePaths.length >= 12) {
      toast(context, '最多上传12张图片');
      return;
    }
    try {
      final picker = ImagePicker();
      final x = await picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      );
      if (x != null) {
        final now = DateTime.now();
        final dest =
            '$gDocDir/dev_${now.millisecondsSinceEpoch}_${imagePaths.length}.jpg';
        // 原图拷贝，不做压缩
        await File(x.path).copy(dest);
        setState(() {
          imagePaths.add(dest);
        });
        toast(context, '已添加第${imagePaths.length}张图片');
      }
    } catch (e) {
      toast(context, '选图失败：$e');
    }
  }

  /// 多选图片（从相册批量选择）
  Future<void> _addMultipleImages() async {
    final remaining = 12 - imagePaths.length;
    if (remaining <= 0) {
      toast(context, '最多上传12张图片');
      return;
    }
    try {
      final picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage();
      if (images.isNotEmpty) {
        int added = 0;
        for (final x in images) {
          if (imagePaths.length >= 12) break;
          final now = DateTime.now();
          final dest =
              '$gDocDir/dev_${now.millisecondsSinceEpoch}_${imagePaths.length + added}.jpg';
          await File(x.path).copy(dest);
          imagePaths.add(dest);
          added++;
        }
        setState(() {});
        toast(context, '已添加${added}张图片，共${imagePaths.length}张');
      }
    } catch (e) {
      toast(context, '批量选图失败：$e');
    }
  }

  /// 删除某张图
  void _removeImage(int index) {
    setState(() {
      imagePaths.removeAt(index);
    });
  }

  Future<void> _save() async {
    // 校验
    if (selectedModel.isEmpty) {
      toast(context, '请选择iPad型号');
      return;
    }
    if (selectedCapacity.isEmpty) {
      toast(context, '请选择容量');
      return;
    }
    if (_costCtrl.text.isEmpty || (double.tryParse(_costCtrl.text) ?? 0) <= 0) {
      toast(context, '请输入采购成本');
      return;
    }

    setState(() => saving = true);
    final now = DateTime.now();
    final cost = (double.tryParse(_costCtrl.text) ?? 0) * 100;
    final channel = isCustomChannel ? _customChannelCtrl.text : selectedChannel;
    final serial = _serialCtrl.text.trim().toUpperCase();

    // 如果有"关于本机"识别的电池信息
    int batteryHealth = 100;
    int cycleCount = 0;
    if (aiRecognizedInfo != null) {
      if (aiRecognizedInfo!['batteryHealth'] != '未知') {
        batteryHealth =
            int.tryParse(
              aiRecognizedInfo!['batteryHealth']!.replaceAll('%', ''),
            ) ??
            100;
      }
      if (aiRecognizedInfo!['cycleCount'] != '未知') {
        cycleCount = int.tryParse(aiRecognizedInfo!['cycleCount']!) ?? 0;
      }
    }

    // 序列号解码（如果有）
    final idClean = idCheck != null ? idCheck!['clean'] as bool : true;

    // 商品描述：优先复用同型号历史描述，无历史或用户选重新生成时调 AI
    String? description;
    // 查找同型号的历史描述
    final historyList =
        gStorage
            .getDevices()
            .where(
              (d) =>
                  d.model == selectedModel &&
                  d.description != null &&
                  d.description!.isNotEmpty,
            )
            .map((d) => d.description)
            .toList();
    final historyDesc = historyList.isNotEmpty ? historyList.last : null;
    // 有历史描述时弹窗让用户选
    if (historyDesc != null && mounted) {
      final choice = await showDialog<String>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              backgroundColor: C.card,
              title: Text('商品描述', style: TextStyle(color: C.t1, fontSize: 16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '同型号有历史描述可用',
                    style: TextStyle(color: C.t2, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: C.bg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: C.line),
                    ),
                    child: Text(
                      historyDesc,
                      style: TextStyle(fontSize: 11, color: C.t2, height: 1.6),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'ai'),
                  child: const Text(
                    '重新AI生成',
                    style: TextStyle(color: C.purple),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'reuse'),
                  child: const Text('复用历史', style: TextStyle(color: C.brand2)),
                ),
              ],
            ),
      );
      if (choice == 'reuse') {
        description = historyDesc;
      }
    }
    // 需要AI生成时
    if (description == null) {
      try {
        description = await AiService.generateDescription(
          model: selectedModel,
          capacity: selectedCapacity,
          color: selectedColor.isEmpty ? '未知' : selectedColor,
          network: selectedNetwork,
          condition: selectedCondition,
          batteryHealth: batteryHealth,
          cycleCount: cycleCount,
          idLockClean: idClean,
          accessories: '裸机',
        );
        if (description.startsWith('AI调用') || description.startsWith('AI返回')) {
          description = null;
        }
      } catch (_) {
        description = null;
      }
    }

    final d = Device(
      id: 'd${now.millisecondsSinceEpoch}',
      serial: serial.isEmpty ? '未填写' : serial,
      model: selectedModel,
      capacity: selectedCapacity,
      color: selectedColor.isEmpty ? '未知' : selectedColor,
      network: selectedNetwork,
      condition: selectedCondition,
      batteryHealth: batteryHealth,
      cycleCount: cycleCount,
      idLockClean: idClean,
      accessories: '裸机',
      purchaseCost: cost.toInt(),
      purchaseChannel: channel,
      purchaseDate: fmtDate(now),
      sellPrice: calcAutoPrice(cost.toInt()),
      status: 'listed',
      imagePath: imagePaths.isNotEmpty ? imagePaths.join(';') : null,
      description: description,
      createdAt: now.toIso8601String(),
    );
    await gStorage.addDevice(d);
    setState(() => saving = false);
    toast(
      context,
      description != null
          ? '✅ 已入库并自动定价${yuan(d.sellPrice)}：${d.model}（AI描述已生成）'
          : '✅ 已入库并自动定价${yuan(d.sellPrice)}：${d.model}',
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => appScaffold(
    context,
    '扫码收货',
    Stepper(
      type: StepperType.vertical,
      currentStep: currentStep,
      onStepContinue: () {
        if (currentStep < 2) setState(() => currentStep++);
      },
      onStepCancel: () {
        if (currentStep > 0) setState(() => currentStep--);
      },
      controlsBuilder:
          (context, details) => Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                if (currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: details.onStepCancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: C.t2,
                        side: BorderSide(color: C.line),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                      child: Text('上一步', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                if (currentStep > 0) const SizedBox(width: 10),
                if (currentStep < 2)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: details.onStepContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: C.brand2,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                      child: const Text('下一步', style: TextStyle(fontSize: 13)),
                    ),
                  ),
              ],
            ),
          ),
      steps: [
        // 步骤1：基本信息
        Step(
          title: Text(
            '基本信息',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: C.t1,
            ),
          ),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // "关于本机"拍照识别
              CardBox(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '关于本机 · AI识别',
                      style: TextStyle(fontSize: 12, color: C.t2),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '拍一张"设置→关于本机"页面截图，AI自动识别序列号和型号',
                      style: TextStyle(fontSize: 10, color: C.t3),
                    ),
                    const SizedBox(height: 8),
                    if (aboutThisDeviceImagePath != null)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: Image.file(
                              File(aboutThisDeviceImagePath!),
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: GestureDetector(
                              onTap:
                                  () => setState(() {
                                    aboutThisDeviceImagePath = null;
                                    aiRecognizedInfo = null;
                                  }),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                          if (aiRecognizing)
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: C.brand2,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'AI识别中...',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _pickAboutThisDevice,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: C.purple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            '拍关于本机让AI识别',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    if (aiRecognizedInfo != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: C.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(color: C.green.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'AI识别结果',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: C.green,
                                ),
                              ),
                              const SizedBox(height: 6),
                              ...aiRecognizedInfo!.entries
                                  .where(
                                    (e) => e.key != '_raw' && e.value != '未知',
                                  )
                                  .map(
                                    (e) => Padding(
                                      padding: EdgeInsets.only(bottom: 3),
                                      child: Text(
                                        '${e.key}: ${e.value}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: C.t2,
                                        ),
                                      ),
                                    ),
                                  ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),

              // 序列号手动输入/修正
              CardBox(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '序列号（可手动修正）',
                      style: TextStyle(fontSize: 12, color: C.t2),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _serialCtrl,
                      style: TextStyle(color: C.t1, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: '输入或AI识别后自动填入',
                        hintStyle: TextStyle(color: C.t3),
                        filled: true,
                        fillColor: C.bg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: C.line),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: C.brand2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),

              // iPad型号选择
              CardBox(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('型号', style: TextStyle(fontSize: 12, color: C.t2)),
                    const SizedBox(height: 6),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: C.bg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: C.line),
                      ),
                      child: DropdownButton<String>(
                        value: selectedModel.isEmpty ? null : selectedModel,
                        hint: Text(
                          '选择iPad型号',
                          style: TextStyle(color: C.t3, fontSize: 13),
                        ),
                        isExpanded: true,
                        underline: const SizedBox(),
                        dropdownColor: C.card,
                        style: TextStyle(color: C.t1, fontSize: 13),
                        items:
                            iPadModels
                                .map(
                                  (m) => DropdownMenuItem(
                                    value: m['name'],
                                    child: Text(
                                      m['name']!,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged:
                            (v) => setState(() => selectedModel = v ?? ''),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),

              // 容量+颜色+网络 一行
              CardBox(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '容量',
                                style: TextStyle(fontSize: 11, color: C.t2),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: C.bg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: C.line),
                                ),
                                child: DropdownButton<String>(
                                  value:
                                      selectedCapacity.isEmpty
                                          ? null
                                          : selectedCapacity,
                                  hint: Text(
                                    '容量',
                                    style: TextStyle(color: C.t3, fontSize: 12),
                                  ),
                                  isExpanded: true,
                                  underline: const SizedBox(),
                                  dropdownColor: C.card,
                                  style: TextStyle(color: C.t1, fontSize: 12),
                                  items:
                                      iPadCapacities
                                          .map(
                                            (c) => DropdownMenuItem(
                                              value: c,
                                              child: Text(
                                                c,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                  onChanged:
                                      (v) => setState(
                                        () => selectedCapacity = v ?? '',
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '颜色',
                                style: TextStyle(fontSize: 11, color: C.t2),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: C.bg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: C.line),
                                ),
                                child: DropdownButton<String>(
                                  value:
                                      selectedColor.isEmpty
                                          ? null
                                          : selectedColor,
                                  hint: Text(
                                    '颜色',
                                    style: TextStyle(color: C.t3, fontSize: 12),
                                  ),
                                  isExpanded: true,
                                  underline: const SizedBox(),
                                  dropdownColor: C.card,
                                  style: TextStyle(color: C.t1, fontSize: 12),
                                  items:
                                      iPadColors
                                          .map(
                                            (c) => DropdownMenuItem(
                                              value: c,
                                              child: Text(
                                                c,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                  onChanged:
                                      (v) => setState(
                                        () => selectedColor = v ?? '',
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '网络',
                                style: TextStyle(fontSize: 11, color: C.t2),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: C.bg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: C.line),
                                ),
                                child: DropdownButton<String>(
                                  value: selectedNetwork,
                                  isExpanded: true,
                                  underline: const SizedBox(),
                                  dropdownColor: C.card,
                                  style: TextStyle(color: C.t1, fontSize: 12),
                                  items:
                                      iPadNetworks
                                          .map(
                                            (n) => DropdownMenuItem(
                                              value: n,
                                              child: Text(
                                                n,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                  onChanged:
                                      (v) => setState(
                                        () => selectedNetwork = v ?? '',
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),

              // 成色选择
              CardBox(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('成色', style: TextStyle(fontSize: 12, color: C.t2)),
                    const SizedBox(height: 6),
                    Wrap(
                      children:
                          iPadConditions
                              .map(
                                (c) => Padding(
                                  padding: const EdgeInsets.only(
                                    right: 6,
                                    bottom: 4,
                                  ),
                                  child: ChoiceChip(
                                    label: Text(
                                      c,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    selected: selectedCondition == c,
                                    selectedColor: C.brand,
                                    onSelected:
                                        (_) => setState(
                                          () => selectedCondition = c,
                                        ),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),

              // 采购成本 + 渠道
              CardBox(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _costCtrl,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: C.t1, fontSize: 14),
                            decoration: InputDecoration(
                              labelText: '采购成本(元)',
                              labelStyle: TextStyle(color: C.t2),
                              filled: true,
                              fillColor: C.bg,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: C.line),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text('采购渠道', style: TextStyle(fontSize: 12, color: C.t2)),
                    const SizedBox(height: 6),
                    Wrap(
                      children:
                          PurchaseChannels.map(
                            (c) => Padding(
                              padding: const EdgeInsets.only(
                                right: 6,
                                bottom: 4,
                              ),
                              child: ChoiceChip(
                                label: Text(
                                  c,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                selected:
                                    !isCustomChannel && selectedChannel == c,
                                selectedColor: C.brand,
                                onSelected:
                                    (_) => setState(() {
                                      selectedChannel = c;
                                      isCustomChannel = false;
                                    }),
                              ),
                            ),
                          ).toList(),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 6, bottom: 4),
                      child: ChoiceChip(
                        label: const Text(
                          '自定义',
                          style: TextStyle(fontSize: 11),
                        ),
                        selected: isCustomChannel,
                        selectedColor: C.brand,
                        onSelected:
                            (_) => setState(() {
                              isCustomChannel = true;
                            }),
                      ),
                    ),
                    if (isCustomChannel)
                      TextField(
                        controller: _customChannelCtrl,
                        style: TextStyle(color: C.t1, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: '输入渠道名称',
                          labelStyle: TextStyle(color: C.t2),
                          filled: true,
                          fillColor: C.bg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: C.line),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),

              // ID锁安全检测
              CardBox(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ID锁安全检测',
                      style: TextStyle(fontSize: 12, color: C.t2),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      children: [
                        _lockCheck(
                          'iCloud锁',
                          iCloudLock,
                          (v) => setState(() => iCloudLock = v),
                        ),
                        _lockCheck(
                          '激活锁',
                          actLock,
                          (v) => setState(() => actLock = v),
                        ),
                        _lockCheck(
                          'MDM监管',
                          mdm,
                          (v) => setState(() => mdm = v),
                        ),
                        _lockCheck(
                          '配置锁',
                          configLock,
                          (v) => setState(() => configLock = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    primaryBtn('检测ID锁', _checkIdLock),
                    if (idCheck != null && !(idCheck!['clean'] as bool))
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: C.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: C.red.withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            const Text('⚠️', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${idCheck!["risk"]}：${(idCheck!["issues"] as List).join("、")}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFFCA5A5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (idCheck != null && idCheck!['clean'] as bool)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: C.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: C.green.withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            const Text('✓', style: TextStyle(color: C.green)),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'ID锁检测通过：无iCloud锁、无激活锁、非监管机',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6EE7B7),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          isActive: true,
        ),

        // 步骤2：实拍图
        Step(
          title: Text(
            '实拍图（最多12张）',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: C.t1,
            ),
          ),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CardBox(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '设备实拍',
                          style: TextStyle(fontSize: 12, color: C.t2),
                        ),
                        const Spacer(),
                        Text(
                          '${imagePaths.length}/12张',
                          style: TextStyle(fontSize: 11, color: C.t3),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // 已选图片横向展示
                    if (imagePaths.isNotEmpty)
                      SizedBox(
                        height: 100,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: imagePaths.length + 1,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            if (i == imagePaths.length) {
                              // 添加按钮
                              return GestureDetector(
                                onTap: () => _addImage(false),
                                child: Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    color: C.bg,
                                    borderRadius: BorderRadius.circular(11),
                                    border: Border.all(color: C.line),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.add_photo_alternate,
                                      color: C.t3,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              );
                            }
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(11),
                                  child: Image.file(
                                    File(imagePaths[i]),
                                    width: 90,
                                    height: 90,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () => _removeImage(i),
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 4,
                                  left: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '#${i + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      )
                    else
                      Container(
                        height: 90,
                        decoration: BoxDecoration(
                          color: C.bg,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: C.line),
                        ),
                        child: Center(
                          child: Text(
                            '未上传实拍图',
                            style: TextStyle(color: C.t3, fontSize: 12),
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _addMultipleImages(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: C.card,
                              foregroundColor: C.t1,
                              padding: EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              '相册多选',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _addImage(false),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: C.card,
                              foregroundColor: C.t1,
                              padding: EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              '相册单选',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _addImage(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: C.brand2,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              '拍照',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          isActive: true,
        ),

        // 步骤3：确认入库
        Step(
          title: Text(
            '确认入库',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: C.t1,
            ),
          ),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CardBox(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '入库信息确认',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: C.t1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (selectedModel.isNotEmpty) _kv('型号', selectedModel),
                    if (selectedCapacity.isNotEmpty)
                      _kv(
                        '容量/颜色/网络',
                        '$selectedCapacity $selectedColor $selectedNetwork',
                      ),
                    if (_serialCtrl.text.isNotEmpty)
                      _kv('序列号', _serialCtrl.text),
                    _kv('成色', selectedCondition),
                    _kv('采购成本', '${_costCtrl.text}元'),
                    _kv(
                      '采购渠道',
                      isCustomChannel
                          ? _customChannelCtrl.text
                          : selectedChannel,
                    ),
                    if (idCheck != null)
                      _kv(
                        'ID锁',
                        idCheck!['clean'] as bool
                            ? '✓ 安全'
                            : '✗ ${idCheck!["risk"]}',
                      ),
                    _kv('实拍图', '${imagePaths.length}张'),
                    const SizedBox(height: 14),
                    saving
                        ? const Center(
                          child: CircularProgressIndicator(color: C.brand2),
                        )
                        : primaryBtn('确认入库', _save),
                  ],
                ),
              ),
            ],
          ),
          isActive: true,
        ),
      ],
    ),
  );

  Widget _lockCheck(String label, bool val, ValueChanged<bool> onChanged) =>
      Padding(
        padding: EdgeInsets.only(right: 8, bottom: 6),
        child: FilterChip(
          label: Text(
            label,
            style: TextStyle(fontSize: 11, color: val ? Colors.white : C.t2),
          ),
          selected: val,
          selectedColor: C.red,
          onSelected: onChanged,
        ),
      );
  Widget _kv(String k, String v) => Padding(
    padding: EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(k, style: TextStyle(fontSize: 12, color: C.t2)),
        ),
        Expanded(
          child: Text(
            v,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: C.t1,
            ),
          ),
        ),
      ],
    ),
  );
}
