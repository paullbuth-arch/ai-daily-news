import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../components/index.dart';
import '../theme/colors.dart';
import '../utils/utils.dart';
import '../models.dart';
import '../main.dart';
import '../services/device_export_service.dart';
import '../services/ecommerce_material_import_service.dart';
import 'ai_report_page.dart';
import 'market_price_page.dart';
import 'sell_page.dart';
import 'stagnant_list_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  Stats stats = Stats();
  List<Device> stagnant = [];
  List<DailyStat> daily = [];
  List<DailyStat> weekly = [];
  Map<String, int> channelGmv = {};

  @override
  void initState() {
    super.initState();
    refresh();
  }

  void refresh() {
    setState(() {
      stats = gStorage.computeStats();
      stagnant = gStorage.getDevices().where((d) => d.isStagnant).toList();
      daily = gStorage.getDailyStats(days: 7);
      weekly = gStorage.getCurrentMonthWeeklyStats();
      channelGmv = gStorage.getChannelGmv();
    });
  }

  @override
  Widget build(BuildContext context) {
    final margin = stats.gmv > 0 ? stats.grossProfit / stats.gmv * 100 : 0.0;
    return PageScaffold(
      title: const Text(
        '货脉',
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w900,
          color: C.t1,
        ),
      ),
      subtitle: Text(
        '今日 ${stats.orderCount} 单 · 在售 ${stats.inStockCount} 台 · ${fmtDate(DateTime.now())}',
        style: const TextStyle(
          fontSize: 12,
          color: C.t2,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeroPhoneCard(
            stats: stats,
            margin: margin,
            onSearch: null,
            onTune: null,
            onScan: _openLinkMaterialImport,
            onPrice: () => _push(const MarketPricePage()),
            onSell: () => _push(const SellPage()),
          ),
          const SizedBox(height: 14),
          _AttentionStrip(
            stats: stats,
            stagnant: stagnant,
            onStagnantTap: () => _push(const StagnantListPage()),
          ),
          const SizedBox(height: 14),
          _TrendPanel(daily: daily, weekly: weekly),
          const SizedBox(height: 14),
          if (channelGmv.isNotEmpty) _ChannelPanel(channelGmv: channelGmv),
          const SizedBox(height: 14),
          _AiPanel(onTap: () => _push(const AiReportPage())),
        ],
      ),
    );
  }

  void _push(Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    ).then((_) => refresh());
  }

  void _openLinkMaterialImport() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _LinkMaterialImportPage()),
    );
  }
}

class _HeroPhoneCard extends StatelessWidget {
  final Stats stats;
  final double margin;
  final VoidCallback? onSearch;
  final VoidCallback? onTune;
  final VoidCallback onScan;
  final VoidCallback onPrice;
  final VoidCallback onSell;

  const _HeroPhoneCard({
    required this.stats,
    required this.margin,
    required this.onSearch,
    required this.onTune,
    required this.onScan,
    required this.onPrice,
    required this.onSell,
  });

  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: EdgeInsets.zero,
    radius: 30,
    borderColor: Colors.white.withValues(alpha: 0.16),
    color: const Color(0xEE080A10),
    child: Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: _HeroTexturePainter())),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _CircleTool(icon: Icons.search_rounded, onTap: onSearch),
                  const Spacer(),
                  Container(
                    width: 84,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  const Spacer(),
                  _CircleTool(icon: Icons.tune_rounded, onTap: onTune),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                '今日经营舱',
                style: TextStyle(
                  fontSize: 13,
                  color: C.t2,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: Text(
                  yuan(stats.gmv),
                  style: const TextStyle(
                    fontSize: 46,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    color: C.t1,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '今日毛利 ${yuan(stats.grossProfit)} · 毛利率 ${margin.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 12,
                  color: C.t2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder:
                    (context, box) => Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: (box.maxWidth - 10) / 2,
                          child: _MiniMetric(
                            label: '今日订单',
                            value: '${stats.orderCount}',
                            tint: C.purple,
                          ),
                        ),
                        SizedBox(
                          width: (box.maxWidth - 10) / 2,
                          child: _MiniMetric(
                            label: '在售设备',
                            value: '${stats.inStockCount}',
                            tint: C.cyan,
                          ),
                        ),
                        SizedBox(
                          width: box.maxWidth,
                          child: _MiniMetric(
                            label: '资金占用',
                            value: yuan(stats.capitalOccupied),
                            tint: C.mint,
                          ),
                        ),
                      ],
                    ),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, box) {
                  final half = (box.maxWidth - 10) / 2;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: half,
                        child: _PastelPill(
                          label: '链接下载',
                          sub: '图片入相册 · 文案进剪贴板',
                          icon: Icons.link_rounded,
                          color: C.cyan,
                          onTap: onScan,
                        ),
                      ),
                      SizedBox(
                        width: half,
                        child: _PastelPill(
                          label: '批发价',
                          sub: '行情参考',
                          icon: Icons.query_stats_rounded,
                          color: C.mint,
                          onTap: onPrice,
                        ),
                      ),
                      SizedBox(
                        width: box.maxWidth,
                        child: _PastelPill(
                          label: '售出设备',
                          sub: '生成订单并计算利润',
                          icon: Icons.point_of_sale_outlined,
                          color: C.purple,
                          onTap: onSell,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _HeroTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final topGlow =
        Paint()
          ..shader = RadialGradient(
            colors: [C.cyan.withValues(alpha: 0.28), Colors.transparent],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.18, 0),
              radius: size.width * 0.95,
            ),
          );
    canvas.drawRect(Offset.zero & size, topGlow);

    final band =
        Paint()
          ..shader = LinearGradient(
            colors: [Colors.white.withValues(alpha: 0.08), Colors.transparent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(Offset.zero & size);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          -20,
          size.height * 0.34,
          size.width + 40,
          size.height * 0.46,
        ),
        const Radius.circular(36),
      ),
      band,
    );

    final linePaint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.055)
          ..strokeWidth = 1;
    for (double y = size.height * 0.68; y < size.height - 16; y += 16) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CircleTool extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _CircleTool({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Icon(icon, color: C.t1, size: 21),
      ),
    ),
  );
}

class _LinkMaterialImportPage extends StatelessWidget {
  const _LinkMaterialImportPage();

  @override
  Widget build(BuildContext context) => appScaffold(
    context,
    '链接素材下载',
    ListView(
      padding: EdgeInsets.fromLTRB(
        AppLayout.pageHorizontal(context),
        4,
        AppLayout.pageHorizontal(context),
        AppLayout.scrollBottomPadding(context),
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: const [
        _LinkMaterialIntro(),
        SizedBox(height: 14),
        _LinkMaterialImportSheet(),
      ],
    ),
  );
}

class _LinkMaterialIntro extends StatelessWidget {
  const _LinkMaterialIntro();

  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: const EdgeInsets.all(14),
    radius: 14,
    color: C.bgCardMuted,
    borderColor: C.border,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Icon(Icons.download_for_offline_rounded, color: C.cyan, size: 22),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            '复制商品链接或分享口令后解析，图片保存到相册，文案复制到剪贴板。',
            style: TextStyle(
              color: C.t2,
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _LinkMaterialImportSheet extends StatefulWidget {
  const _LinkMaterialImportSheet();

  @override
  State<_LinkMaterialImportSheet> createState() =>
      _LinkMaterialImportSheetState();
}

class _LinkMaterialImportSheetState extends State<_LinkMaterialImportSheet> {
  static const int _maxImages = 80;

  final _linkCtrl = TextEditingController();
  bool _busy = false;
  EcommerceMaterialImportResult? _result;
  int? _savedImageCount;
  int? _savedVideoCount;
  bool _copiedText = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pasteFromClipboard(silent: true);
    });
  }

  @override
  void dispose() {
    _linkCtrl.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard({bool silent = false}) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (!mounted) return;
    if (text.isEmpty) {
      if (!silent) toast(context, '剪贴板里没有可用文本');
      return;
    }
    setState(() => _linkCtrl.text = text);
    if (!silent) toast(context, '已读取剪贴板');
  }

  void _clearInput() {
    setState(() {
      _linkCtrl.clear();
      _result = null;
      _savedImageCount = null;
      _savedVideoCount = null;
      _copiedText = false;
      _saveError = null;
    });
    toast(context, '已清空输入内容');
  }

  Future<void> _importMaterial() async {
    final raw = _linkCtrl.text.trim();
    if (raw.isEmpty) {
      toast(context, '请先复制或粘贴商品链接');
      return;
    }

    setState(() {
      _busy = true;
      _saveError = null;
    });

    try {
      final result = await EcommerceMaterialImportService.importFromText(
        raw,
        docDir: gDocDir,
        maxImages: _maxImages,
      );

      final copyText = result.copyText.trim();
      final copiedText = copyText.isNotEmpty;
      if (copiedText) {
        await Clipboard.setData(ClipboardData(text: copyText));
      }

      var savedImages = 0;
      var savedVideos = 0;
      String? saveError;
      final imagePaths = result.images.map((image) => image.savedPath).toList();
      if (imagePaths.isNotEmpty) {
        try {
          savedImages = await DeviceExportService.saveImagesToGallery(
            paths: imagePaths,
            albumName: '货脉链接素材',
          );
        } catch (e) {
          saveError = _friendlyError(e);
        }
      }
      final videoPaths = result.videos.map((video) => video.savedPath).toList();
      if (videoPaths.isNotEmpty) {
        try {
          savedVideos = await DeviceExportService.saveVideosToGallery(
            paths: videoPaths,
            albumName: '货脉链接素材',
          );
        } catch (e) {
          final message = _friendlyError(e);
          saveError = saveError == null ? message : '$saveError；$message';
        }
      }

      if (!mounted) return;
      setState(() {
        _result = result;
        _savedImageCount = savedImages;
        _savedVideoCount = savedVideos;
        _copiedText = copiedText;
        _saveError = saveError;
      });

      final parts = <String>[];
      if (savedImages > 0) parts.add('已保存$savedImages张图到相册');
      if (savedVideos > 0) parts.add('已保存$savedVideos个视频到相册');
      if (copiedText) parts.add('文案已复制');
      if (parts.isEmpty) parts.add('已解析链接，但没有拿到可保存素材');
      if (saveError != null) {
        toast(context, '解析成功，相册保存失败：$saveError');
      } else {
        toast(context, parts.join('，'));
      }
    } catch (e) {
      if (!mounted) return;
      toast(context, '解析下载失败：${_friendlyError(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyError(Object error) => error
      .toString()
      .replaceFirst(RegExp(r'^FormatException:\s*'), '')
      .replaceFirst(RegExp(r'^HttpException:\s*'), '')
      .replaceFirst(RegExp(r'^PlatformException\([^,]+,\s*'), '')
      .replaceFirst(RegExp(r',\s*null,\s*null\)$'), '');

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppFormField(
        controller: _linkCtrl,
        label: '商品链接或分享口令',
        hint: '支持闲鱼、小红书，以及可公开访问的商品页',
        icon: Icons.link_rounded,
        keyboardType: TextInputType.multiline,
        maxLines: 4,
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _clearInput,
              icon: const Icon(Icons.clear_rounded, size: 17),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              label: const Text('清空内容'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed: _busy ? null : _importMaterial,
              icon:
                  _busy
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                      : const Icon(Icons.download_rounded, size: 17),
              style: FilledButton.styleFrom(
                backgroundColor: C.cyan,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              label: Text(_busy ? '解析中' : '解析下载'),
            ),
          ),
        ],
      ),
      if (_result != null) ...[
        const SizedBox(height: 14),
        _LinkImportResultCard(
          result: _result!,
          savedImageCount: _savedImageCount ?? 0,
          savedVideoCount: _savedVideoCount ?? 0,
          copiedText: _copiedText,
          saveError: _saveError,
        ),
      ],
    ],
  );
}

class _LinkImportResultCard extends StatelessWidget {
  final EcommerceMaterialImportResult result;
  final int savedImageCount;
  final int savedVideoCount;
  final bool copiedText;
  final String? saveError;

  const _LinkImportResultCard({
    required this.result,
    required this.savedImageCount,
    required this.savedVideoCount,
    required this.copiedText,
    this.saveError,
  });

  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: const EdgeInsets.all(12),
    radius: 14,
    color: const Color(0xEA0B1018),
    borderColor: C.border,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ImportBadge(
              icon: Icons.storefront_outlined,
              label: result.platform,
              color: C.cyan,
            ),
            _ImportBadge(
              icon: Icons.photo_library_outlined,
              label: '图片 $savedImageCount/${result.images.length}',
              color: C.mint,
            ),
            if (result.videos.isNotEmpty || result.candidateVideoCount > 0)
              _ImportBadge(
                icon: Icons.play_circle_outline_rounded,
                label:
                    '视频 $savedVideoCount/${result.videos.isNotEmpty ? result.videos.length : result.candidateVideoCount}',
                color: C.orange,
              ),
            _ImportBadge(
              icon:
                  copiedText
                      ? Icons.content_copy_rounded
                      : Icons.text_snippet_outlined,
              label: copiedText ? '文案已复制' : '未提取到文案',
              color: copiedText ? C.purple : C.orange,
            ),
          ],
        ),
        if (result.title.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            result.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: C.t1,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              height: 1.35,
            ),
          ),
        ],
        if (result.images.isNotEmpty || result.videos.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount:
                  (result.images.length + result.videos.length) > 12
                      ? 12
                      : result.images.length + result.videos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index >= result.images.length) {
                  final video = result.videos[index - result.images.length];
                  return _VideoPreviewTile(path: video.savedPath);
                }
                final image = result.images[index];
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(image.savedPath),
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    errorBuilder:
                        (_, __, ___) => Container(
                          width: 72,
                          height: 72,
                          color: C.bgCard,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            color: C.t3,
                          ),
                        ),
                  ),
                );
              },
            ),
          ),
        ],
        if (saveError != null) ...[
          const SizedBox(height: 9),
          _ImportNote(icon: Icons.error_outline_rounded, text: saveError!),
        ],
        ...result.warnings
            .take(2)
            .map(
              (warning) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _ImportNote(
                  icon: Icons.info_outline_rounded,
                  text: warning,
                ),
              ),
            ),
      ],
    ),
  );
}

class _VideoPreviewTile extends StatelessWidget {
  final String path;

  const _VideoPreviewTile({required this.path});

  @override
  Widget build(BuildContext context) {
    final name = path.split(Platform.pathSeparator).last;
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: C.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: C.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.play_circle_fill_rounded, color: C.orange, size: 26),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: C.t3,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _ImportBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: color.withValues(alpha: 0.28)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _ImportNote extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ImportNote({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 15, color: C.t3),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: C.t3,
            fontSize: 11,
            height: 1.35,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color tint;

  const _MiniMetric({
    required this.label,
    required this.value,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: C.t3,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        FittedBox(
          alignment: Alignment.centerLeft,
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 18,
              color: tint,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),
  );
}

class _PastelPill extends StatelessWidget {
  final String label;
  final String sub;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _PastelPill({
    required this.label,
    required this.sub,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 11, 10, 11),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.black.withValues(alpha: 0.50),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 19),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _AttentionStrip extends StatelessWidget {
  final Stats stats;
  final List<Device> stagnant;
  final VoidCallback onStagnantTap;

  const _AttentionStrip({
    required this.stats,
    required this.stagnant,
    required this.onStagnantTap,
  });

  @override
  Widget build(BuildContext context) {
    final devices =
        gStorage
            .getDevices()
            .where((d) => d.status == 'in_stock' || d.status == 'listed')
            .toList();
    final priced = devices.where((d) => d.sellPrice > 0).toList();
    final estimatedProfit = priced.fold<int>(0, (sum, d) {
      final cost = d.purchaseCost + (d.repairCost ?? 0);
      final profit = d.sellPrice - cost;
      return profit > 0 ? sum + profit : sum;
    });
    final avgStockDays =
        devices.isEmpty
            ? 0
            : (devices.fold<int>(0, (sum, d) => sum + d.stockDays) /
                    devices.length)
                .round();
    final agingCount = stagnant.length;

    return Row(
      children: [
        Expanded(
          child: _AlertTile(
            icon: Icons.account_balance_wallet_outlined,
            title: '库存资金',
            value: yuan(stats.capitalOccupied),
            subtitle: '${devices.length} 台在库/在售',
            color: C.cyan,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _AlertTile(
            icon: Icons.trending_up_rounded,
            title: '预估毛利',
            value: yuan(estimatedProfit),
            subtitle: '${priced.length} 台已定价',
            color: C.mint,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _AlertTile(
            icon: Icons.schedule_rounded,
            title: '平均库龄',
            value: '${avgStockDays}天',
            subtitle: agingCount > 0 ? '$agingCount 台超过15天' : '周转正常',
            color: agingCount > 0 ? C.orange : C.blue,
            onTap: onStagnantTap,
          ),
        ),
      ],
    );
  }
}

class _AlertTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String? subtitle;
  final Color color;
  final VoidCallback? onTap;

  const _AlertTile({
    required this.icon,
    required this.title,
    required this.value,
    this.subtitle,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: const EdgeInsets.all(12),
    radius: 18,
    onTap: onTap,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 19),
        const SizedBox(height: 10),
        FittedBox(
          alignment: Alignment.centerLeft,
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 21,
              color: C.t1,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            color: C.t2,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              color: C.t3,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    ),
  );
}

class _TrendPanel extends StatefulWidget {
  final List<DailyStat> daily;
  final List<DailyStat> weekly;

  const _TrendPanel({required this.daily, required this.weekly});

  @override
  State<_TrendPanel> createState() => _TrendPanelState();
}

class _TrendPanelState extends State<_TrendPanel> {
  bool weeklyMode = false;

  @override
  Widget build(BuildContext context) {
    final source = weeklyMode ? widget.weekly : widget.daily;
    final data = source.map((d) => d.profit.toDouble()).toList();
    final labels =
        source
            .map((d) => d.date.length > 5 ? d.date.substring(5) : d.date)
            .toList();
    final total = source.fold<int>(0, (sum, d) => sum + d.profit);
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.timeline_rounded,
                  color: C.cyan,
                  size: 16,
                ),
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  '毛利时间线',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: C.t1,
                  ),
                ),
              ),
              _TrendToggle(
                weeklyMode: weeklyMode,
                onChanged: (value) => setState(() => weeklyMode = value),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              StatusChip(
                weeklyMode ? '本月 ${yuan(total)}' : '7日 ${yuan(total)}',
                C.cyan,
              ),
              const SizedBox(width: 8),
              Text(
                weeklyMode ? '按月内自然周聚合' : '最近 7 天净利',
                style: const TextStyle(
                  color: C.t3,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 150,
            child: CustomPaint(
              painter: LineChartPainter(
                data,
                labels,
                lineColor: C.cyan,
                showPointLabels: true,
              ),
              size: Size.infinite,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendToggle extends StatelessWidget {
  final bool weeklyMode;
  final ValueChanged<bool> onChanged;

  const _TrendToggle({required this.weeklyMode, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _item('日', !weeklyMode, () => onChanged(false)),
        _item('周', weeklyMode, () => onChanged(true)),
      ],
    ),
  );

  Widget _item(String label, bool selected, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: C.fast,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? C.cyan : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.black : C.t2,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
}

class _ChannelPanel extends StatelessWidget {
  final Map<String, int> channelGmv;

  const _ChannelPanel({required this.channelGmv});

  @override
  Widget build(BuildContext context) {
    final total = channelGmv.values.fold<int>(0, (a, b) => a + b);
    final colors = [C.cyan, C.purple, C.mint, C.orange, C.blue];
    final entries = channelGmv.entries.toList();
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('渠道占比', icon: Icons.donut_large_rounded),
          const SizedBox(height: 4),
          ...entries.asMap().entries.map((e) {
            final color = colors[e.key % colors.length];
            final value = e.value.value;
            final pct = total == 0 ? 0.0 : value / total;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.storefront_outlined,
                      color: color,
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                e.value.key,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: C.t1,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Text(
                              '${(pct * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(
                                color: C.t2,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 7,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.07,
                            ),
                            valueColor: AlwaysStoppedAnimation(color),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _AiPanel extends StatelessWidget {
  final VoidCallback onTap;

  const _AiPanel({required this.onTap});

  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: const EdgeInsets.all(16),
    radius: 22,
    color: C.purple.withValues(alpha: 0.16),
    borderColor: C.purple.withValues(alpha: 0.24),
    onTap: onTap,
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: C.purple,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: Colors.black,
            size: 23,
          ),
        ),
        const SizedBox(width: 13),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI 经营日报',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: C.t1,
                ),
              ),
              SizedBox(height: 3),
              Text(
                '汇总库存、订单和利润，生成今日判断',
                style: TextStyle(
                  fontSize: 12,
                  color: C.t2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: C.t2),
      ],
    ),
  );
}
