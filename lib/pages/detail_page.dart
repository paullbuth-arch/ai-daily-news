import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';
import '../components/index.dart';
import '../utils/utils.dart';
import '../storage.dart';
import '../models.dart';
import '../main.dart';
import '../ai_service.dart';
import 'scan_page.dart';
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
  late Device device;
  final GlobalKey _coverKey = GlobalKey();
  static const _galleryChannel = MethodChannel('ipad_boss_app/gallery');

  @override
  void initState() {
    super.initState();
    device = widget.device;
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

  void _adjustPrice() async {
    final ctrl = TextEditingController(
      text:
          device.sellPrice > 0
              ? (device.sellPrice / 100).toStringAsFixed(0)
              : '',
    );
    final result = await showDialog<int>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: C.card,
            title: Text('售价微调', style: TextStyle(color: C.t1, fontSize: 16)),
            content: TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: TextStyle(color: C.t1),
              decoration: InputDecoration(
                labelText: '新售价(元)',
                labelStyle: TextStyle(color: C.t2),
                filled: true,
                fillColor: C.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: C.line),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('取消', style: TextStyle(color: C.t2)),
              ),
              TextButton(
                onPressed: () {
                  final v = (double.tryParse(ctrl.text) ?? 0) * 100;
                  Navigator.pop(ctx, v.toInt());
                },
                child: Text('确定', style: TextStyle(color: C.brand2)),
              ),
            ],
          ),
    );
    if (result == null) return;
    if (result <= 0) {
      toast(context, '售价需大于0');
      return;
    }
    device.sellPrice = result;
    if (device.status == 'in_stock') device.status = 'listed';
    await gStorage.updateDevice(device);
    setState(() {});
    toast(context, '售价已调整为${yuan(result)}');
  }

  void _genReport() {
    final report = '''【机掌柜验机报告】

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
报告由「机掌柜」自动生成''';
    Clipboard.setData(ClipboardData(text: report));
    toast(context, '验机报告已复制到剪贴板，可粘贴发给买家');
  }

  /// 一键下载：描述存剪贴板 + 图片存相册 + 最前面插自制封面图
  /// [openXianyu] 为 true 时下载成功后拉起闲鱼 app
  Future<void> _downloadAll({bool openXianyu = false}) async {
    if (downloading) return;
    setState(() => downloading = true);
    try {
      // 1. 截取自制封面图（RepaintBoundary 渲染的设备信息卡）
      String? coverPath;
      final ctx = _coverKey.currentContext;
      if (ctx != null) {
        final boundary = ctx.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2.5);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          final coverFile = File(
            '$gDocDir/cover_${device.id}_${DateTime.now().millisecondsSinceEpoch}.png',
          );
          await coverFile.writeAsBytes(byteData.buffer.asUint8List());
          coverPath = coverFile.path;
        }
      }

      // 2. 组装图片列表：封面图在最前 + 设备实拍图
      final images = <String>[];
      if (coverPath != null) images.add(coverPath);
      if (device.imagePath != null && device.imagePath!.isNotEmpty) {
        images.addAll(
          device.imagePath!
              .split(';')
              .where((s) => s.isNotEmpty && File(s).existsSync()),
        );
      }

      // 3. 商品描述复制到剪贴板
      final desc = (device.description ?? '').trim();
      if (desc.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: desc));
      }

      // 4. 调用原生通道把图片保存到手机相册
      if (images.isEmpty) {
        toast(context, desc.isNotEmpty ? '✅ 描述已复制到剪贴板（暂无图片）' : '暂无可下载的图片与描述');
        return;
      }
      final result = await _galleryChannel.invokeMethod('saveImagesToGallery', {
        'paths': images,
        'albumName': '机掌柜',
      });
      final saved = (result is Map) ? (result['saved'] as int? ?? 0) : 0;
      final msg = StringBuffer('✅ 已保存${saved}张图到相册');
      if (desc.isNotEmpty) msg.write('，描述已复制到剪贴板');
      toast(context, msg.toString());

      // 5. 按需拉起闲鱼
      if (openXianyu) {
        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;
        await _openXianyu();
      }
    } catch (e) {
      toast(context, '下载失败：$e');
    } finally {
      if (mounted) setState(() => downloading = false);
    }
  }

  /// 拉起闲鱼 app（已安装则直接打开，未安装提示去应用商店）
  Future<void> _openXianyu() async {
    try {
      final result = await _galleryChannel.invokeMethod('openXianyu');
      if (result is Map && result['success'] == true) {
        toast(context, '已打开闲鱼，去发布商品吧');
      } else {
        // 闲鱼未安装，提示用户
        toast(context, '未检测到闲鱼，请先安装闲鱼 app');
      }
    } catch (e) {
      toast(context, '拉起闲鱼失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImg = device.imagePath != null && device.imagePath!.isNotEmpty;
    final images = hasImg ? device.imagePath!.split(';') : <String>[];
    final hasDesc =
        device.description != null && device.description!.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              children: [
                Stack(
                  children: [
                    Container(
                      height: 230,
                      color: C.cardMuted,
                      child:
                          images.isNotEmpty
                              ? Image.file(
                                File(images.first),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 230,
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
                          color: Colors.black.withOpacity(0.32),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.chevron_left_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                          onPressed: () => Navigator.pop(context),
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
                      const Positioned(
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
                          (_, i) => ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(images[i]),
                              width: 70,
                              height: 70,
                              fit: BoxFit.cover,
                            ),
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
                              color: device.sellPrice > 0 ? C.brand : C.orange,
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 9,
                    crossAxisSpacing: 9,
                    childAspectRatio: 3.2,
                    children: [
                      _a('型号', device.model),
                      _a('容量/颜色', '${device.capacity} ${device.color}'),
                      _a('网络', device.network),
                      _a('成色', device.condition),
                      _a('电池健康', '${device.batteryHealth}%'),
                      _a('循环次数', '${device.cycleCount}次'),
                      _a(
                        'ID锁检测',
                        device.idLockClean ? '✓ 无锁' : '✗ 有锁',
                        vc: device.idLockClean ? C.green : C.red,
                      ),
                      _a(
                        '在库天数',
                        '${device.stockDays}天${device.isStagnant ? "(滞销)" : ""}',
                      ),
                    ],
                  ),
                ),
                // 商品描述（AI生成，三行高度可滑动，不占太多篇幅）
                CardBox(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle('商品描述', trailing: 'AI生成'),
                      const SizedBox(height: 8),
                      Container(
                        height: 66, // 约三行高度
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: C.bg,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: C.line),
                        ),
                        child:
                            hasDesc
                                ? SingleChildScrollView(
                                  child: SelectableText(
                                    device.description!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: C.t2,
                                      height: 1.5,
                                    ),
                                  ),
                                )
                                : Center(
                                  child: Text(
                                    '暂无AI描述（入库时未生成）',
                                    style: TextStyle(fontSize: 12, color: C.t3),
                                  ),
                                ),
                      ),
                    ],
                  ),
                ),
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
                        const Center(
                          child: CircularProgressIndicator(color: C.brand2),
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _askAi,
                            icon: const Icon(
                              Icons.auto_awesome_rounded,
                              size: 18,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: C.purple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
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
                            backgroundColor: C.card,
                            foregroundColor: C.t1,
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
                            ),
                            elevation: 0,
                            side: BorderSide(color: C.line),
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
                if (device.status == 'in_stock' || device.status == 'listed')
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                    child: ghostBtn('售价微调', _adjustPrice),
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
            // 屏幕外的自制封面图（用于一键下载时截图，置顶相册防止闲鱼错乱）
            Positioned(
              left: -10000,
              top: 0,
              child: RepaintBoundary(key: _coverKey, child: _buildCoverImage()),
            ),
          ],
        ),
      ),
    );
  }

  /// 自制封面图：包含设备核心信息，下载时截图置顶相册
  Widget _buildCoverImage() {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 360,
        height: 480,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E293B), Color(0xFF0B0F1A)],
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: C.selected,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.tablet_mac_rounded,
                    color: C.brand,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  '机掌柜',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: C.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    device.idLockClean ? 'ID无锁' : 'ID有锁',
                    style: TextStyle(
                      color: device.idLockClean ? C.green : C.red,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              device.model,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              '${device.capacity} · ${device.color} · ${device.network}',
              style: const TextStyle(
                color: C.brand2,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            _coverRow('成色', device.condition),
            _coverRow('电池健康', '${device.batteryHealth}%'),
            _coverRow('充电循环', '${device.cycleCount}次'),
            _coverRow('序列号', device.serial),
            const Spacer(),
            Container(
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: C.line),
              ),
              child: Row(
                children: [
                  Text('售价', style: TextStyle(color: C.t2, fontSize: 13)),
                  const Spacer(),
                  Text(
                    device.sellPrice > 0 ? yuan(device.sellPrice) : '未定价',
                    style: const TextStyle(
                      color: C.brand2,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: Text(
                '${device.purchaseDate} · 实拍图见后续',
                style: TextStyle(color: C.t3, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coverRow(String k, String v) => Padding(
    padding: EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(k, style: TextStyle(color: C.t2, fontSize: 13)),
        ),
        Expanded(
          child: Text(
            v,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
  Widget _a(String l, String v, {Color? vc}) => Container(
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: C.cardMuted,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: C.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          l,
          style: TextStyle(
            fontSize: 10,
            color: C.t2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          v,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: vc ?? C.t1,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
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
              color: active ? C.brand : C.t3,
              shape: BoxShape.circle,
              border: Border.all(color: C.bg, width: 2),
            ),
          ),
          if (!last) Container(width: 2, height: 36, color: C.line),
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
