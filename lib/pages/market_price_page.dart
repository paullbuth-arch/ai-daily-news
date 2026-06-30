import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/colors.dart';
import '../components/index.dart';
import '../utils/utils.dart';
import '../storage.dart';
import '../models.dart';
import '../main.dart';
import '../ai_service.dart';

class MarketPricePage extends StatefulWidget {
  const MarketPricePage({Key? key}) : super(key: key);
  @override
  State<MarketPricePage> createState() => _MarketPricePageState();
}

class _MarketPricePageState extends State<MarketPricePage> {
  String? _selectedModel;
  final _priceCtrl = TextEditingController();
  Map<String, Map<String, dynamic>> _allPrices = {};
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
    final preset = iPadModels.map((m) => m['name']!).toList();
    final all = <String>[...preset];
    for (final m in dbModels) {
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
      final lines = await file.readAsLines();
      int imported = 0;
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
        final parts = trimmed.split(',');
        if (parts.length < 2) continue;
        final model = parts[0].trim();
        final price = double.tryParse(parts[1].trim());
        if (model.isEmpty || price == null || price <= 0) continue;
        await gStorage.saveMarketPrice(model, (price * 100).round());
        imported++;
      }
      _reload();
      toast(context, '✅ 导入完成，共更新 $imported 个型号');
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
        '你是一个华强北iPad批发价识别专家。用户会上传一张批发价表格截图（含型号和价格），'
            '请把识别到的型号和批发价（元）以CSV格式逐行输出：型号,价格\n'
            '例如：iPad Pro 11 2022,4700\n'
            '如果某个价格看不清填0。不要返回其他文字。',
        b64,
        '请识别这张图片中的所有iPad型号和批发价格。',
        maxTokens: 4096,
      );
      if (result.startsWith('AI调用') || result.startsWith('AI返回')) {
        toast(context, '❌ $result');
        return;
      }
      // 解析 AI 返回的 CSV 格式
      int imported = 0;
      for (final line in result.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
        final parts = trimmed.split(',');
        if (parts.length < 2) continue;
        final model = parts[0].trim();
        final price = double.tryParse(parts[1].trim());
        if (model.isEmpty || price == null || price <= 0) continue;
        await gStorage.saveMarketPrice(model, (price * 100).round());
        imported++;
      }
      _reload();
      toast(context, '✅ AI识别导入完成，共导入 $imported 个型号');
    } catch (e) {
      toast(context, '图片识别失败：$e');
    } finally {
      setState(() => _importing = false);
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
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: C.bgDeep,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: C.border),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedModel,
                    isExpanded: true,
                    underline: const SizedBox(),
                    dropdownColor: C.bgCard,
                    hint: Text(
                      '选择型号',
                      style: TextStyle(color: C.t3, fontSize: 14),
                    ),
                    style: TextStyle(color: C.t1, fontSize: 14),
                    items:
                        _modelOptions
                            .map(
                              (m) => DropdownMenuItem(
                                value: m,
                                child: Text(
                                  m,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            )
                            .toList(),
                    onChanged: _onModelChanged,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _priceCtrl,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: C.t1, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: '批发价(元)',
                          labelStyle: TextStyle(color: C.t2, fontSize: 12),
                          filled: true,
                          fillColor: C.bgDeep,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: C.border),
                          ),
                        ),
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
                  '支持 CSV 表格 / 批发价截图(图片→AI识别)，格式：型号,价格',
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
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: C.cyan.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              model,
                              style: const TextStyle(
                                fontSize: 11,
                                color: C.cyan,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Spacer(),
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
}
