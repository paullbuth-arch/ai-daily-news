import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/colors.dart';
import '../components/index.dart';
import '../utils/utils.dart';
import '../main.dart';
import '../ai_service.dart';
import '../services/market_price_import_service.dart';

class MarketPricePage extends StatefulWidget {
  const MarketPricePage({Key? key}) : super(key: key);
  @override
  State<MarketPricePage> createState() => _MarketPricePageState();
}

class _MarketPricePageState extends State<MarketPricePage> {
  String? _selectedModel;
  final _priceCtrl = TextEditingController();
  Map<String, Map<String, dynamic>> _allPrices = {};
  List<MarketPriceImportRow> _lastImportedRows = [];
  String _lastImportSource = '';
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _allPrices = gStorage.getAllLatestMarketPrices();
    });
  }

  List<String> get _modelOptions {
    final dbModels = gStorage.getDevices().map((d) => d.model).toSet().toList();
    final marketModels = gStorage.getAllLatestMarketPrices().keys.toList();
    final preset = iPadModels.map((m) => m['name']!).toList();
    final all = <String>[...preset];
    for (final m in [...dbModels, ...marketModels]) {
      if (!all.contains(m)) all.add(m);
    }
    return all;
  }

  void _onModelChanged(String? v) {
    setState(() {
      _selectedModel = v;
      if (v != null) {
        final mp = gStorage.getMarketPrice(v);
        _priceCtrl.text =
            mp != null ? ((mp['price'] as int) / 100).toStringAsFixed(0) : '';
      } else {
        _priceCtrl.clear();
      }
    });
  }

  Future<void> _savePrice() async {
    if (_selectedModel == null) {
      toast(context, '请先选型号');
      return;
    }
    final price = double.tryParse(_priceCtrl.text) ?? 0;
    if (price <= 0) {
      toast(context, '请输入有效批发价');
      return;
    }
    await gStorage.saveMarketPrice(_selectedModel!, (price * 100).round());
    _reload();
    toast(context, '✅ 已保存 ${_selectedModel!} 批发价 $price 元');
  }

  /// 从文件导入（支持 csv / 图片）
  Future<void> _importFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'jpg', 'jpeg', 'png', 'bmp'],
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final path = file.path;
      if (path == null) return;

      final ext = path.split('.').last.toLowerCase();
      if (ext == 'csv') {
        await _importCsv(File(path));
      } else if (['jpg', 'jpeg', 'png', 'bmp'].contains(ext)) {
        await _importImage(File(path));
      } else {
        toast(context, '不支持的文件格式：$ext');
      }
    } catch (e) {
      toast(context, '导入失败：$e');
    }
  }

  /// 解析 CSV：格式 = 型号,批发价(元)
  Future<void> _importCsv(File file) async {
    setState(() => _importing = true);
    try {
      final rows = MarketPriceImportService.parseRows(
        await file.readAsString(),
      );
      for (final row in rows) {
        await gStorage.saveMarketPrice(row.model, row.priceYuan * 100);
      }
      setState(() {
        _lastImportedRows = rows;
        _lastImportSource = 'CSV导入结果';
      });
      _reload();
      toast(context, '✅ 导入完成，共更新 ${rows.length} 条行情');
    } catch (e) {
      toast(context, 'CSV 解析失败：$e');
    } finally {
      setState(() => _importing = false);
    }
  }

  /// 图片调用 AI 识别批发价
  Future<void> _importImage(File file) async {
    setState(() => _importing = true);
    try {
      final bytes = await file.readAsBytes();
      final b64 = base64Encode(bytes);
      final result = await AiService.chatWithImage(
        MarketPriceImportService.imageSystemPrompt,
        b64,
        MarketPriceImportService.imageUserPrompt,
        maxTokens: 8192,
      );
      if (result.startsWith('AI调用') || result.startsWith('AI返回')) {
        toast(context, '❌ $result');
        return;
      }
      final rows = MarketPriceImportService.parseRows(result);
      for (final row in rows) {
        await gStorage.saveMarketPrice(row.model, row.priceYuan * 100);
      }
      setState(() {
        _lastImportedRows = rows;
        _lastImportSource = 'AI图片识别结果';
      });
      _reload();
      toast(context, '✅ AI识别导入完成，共导入 ${rows.length} 条行情');
    } catch (e) {
      toast(context, '图片识别失败：$e');
    } finally {
      setState(() => _importing = false);
    }
  }

  Future<void> _exportLastImportedRows() async {
    if (_lastImportedRows.isEmpty) {
      toast(context, '暂无可导出的识别表格');
      return;
    }
    try {
      final now = DateTime.now();
      final stamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final path = '$gDocDir/market_price_recognition_$stamp.csv';
      await File(path).writeAsString(
        MarketPriceImportService.toCsv(_lastImportedRows),
        encoding: utf8,
      );
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      final origin =
          box == null
              ? const Rect.fromLTWH(0, 0, 1, 1)
              : box.localToGlobal(Offset.zero) & box.size;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path)],
          text: '货脉批发价识别表格',
          sharePositionOrigin: origin,
        ),
      );
    } catch (e) {
      if (mounted) toast(context, '导出失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortedModels = _allPrices.keys.toList()..sort();
    return appScaffold(
      context,
      '今日批发价',
      ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // 手动录入卡
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '手动录入',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: C.t1,
                  ),
                ),
                const SizedBox(height: 10),
                AppDropdownField<String>(
                  value: _selectedModel,
                  hint: '选择型号',
                  options: _modelOptions,
                  labelBuilder: (value) => value,
                  onChanged: _onModelChanged,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: AppFormField(
                        controller: _priceCtrl,
                        keyboardType: TextInputType.number,
                        label: '批发价(元)',
                        icon: Icons.sell_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _savePrice,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: C.cyan,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          '保存',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 导入操作卡
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '批量导入',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: C.t1,
                      ),
                    ),
                    const Spacer(),
                    if (_importing)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: C.t3,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '支持 CSV / 批发价截图。图片会按型号、容量、网络、成色和版本拆成多条行情。',
                  style: TextStyle(fontSize: 11, color: C.t2, height: 1.5),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _importing ? null : _importFromFile,
                        icon: const Icon(Icons.file_upload_outlined, size: 18),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: C.t3,
                          side: const BorderSide(color: C.t3),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        label: const Text(
                          '选择文件导入',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_lastImportedRows.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildRecognitionTable(),
          ],
          // 已记录行情列表
          if (sortedModels.isNotEmpty) ...[
            const SizedBox(height: 12),
            CardBox(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '已记录行情',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: C.t1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...sortedModels.map((model) {
                    final mp = _allPrices[model]!;
                    final price = mp['price'] as int;
                    final date = mp['date'] as String? ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: C.cyan.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                model,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: C.cyan,
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '¥${(price / 100).toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: C.t1,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            date,
                            style: TextStyle(fontSize: 10, color: C.t3),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            'CSV格式示例：\niPad Pro 11 2022,4700\niPad Pro 12.9 2021,4200\niPad Air 5,2300',
            style: TextStyle(fontSize: 10, color: C.t3, height: 1.8),
          ),
        ],
      ),
    );
  }

  Widget _buildRecognitionTable() => CardBox(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _lastImportSource.isEmpty ? '最近识别表格' : _lastImportSource,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: C.t1,
                ),
              ),
            ),
            Text(
              '${_lastImportedRows.length}条',
              style: const TextStyle(
                color: C.t3,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                '这是 AI/CSV 本次解析出的原始表格，可导出核对。下方已记录行情是保存后的结果。',
                style: TextStyle(fontSize: 11, color: C.t2, height: 1.45),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 36,
              child: OutlinedButton.icon(
                onPressed: _exportLastImportedRows,
                icon: const Icon(Icons.ios_share_rounded, size: 16),
                label: const Text('导出CSV'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: C.cyan,
                  side: BorderSide(color: C.cyan.withValues(alpha: 0.45)),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: C.bgDeep,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: C.border),
          ),
          child: Column(
            children: [
              const _RecognitionHeader(),
              ..._lastImportedRows.take(120).map(_RecognitionRow.new),
              if (_lastImportedRows.length > 120)
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    '仅预览前120条，完整内容请导出CSV查看。',
                    style: TextStyle(fontSize: 11, color: C.t3),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _RecognitionHeader extends StatelessWidget {
  const _RecognitionHeader();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: C.bgSurface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
      border: Border(bottom: BorderSide(color: C.border)),
    ),
    child: const Row(
      children: [
        Expanded(
          child: Text(
            '行情名',
            style: TextStyle(
              color: C.t2,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        SizedBox(width: 10),
        SizedBox(
          width: 64,
          child: Text(
            '价格',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: C.t2,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),
  );
}

class _RecognitionRow extends StatelessWidget {
  final MarketPriceImportRow row;

  const _RecognitionRow(this.row);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(color: C.border.withValues(alpha: 0.6)),
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            row.model,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: C.t1,
              fontSize: 11.5,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 64,
          child: Text(
            '¥${row.priceYuan}',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: C.mint,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),
  );
}
