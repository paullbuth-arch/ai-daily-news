import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../components/index.dart';
import '../utils/utils.dart';
import '../storage.dart';
import '../main.dart';
import '../ai_service.dart';

class AiConfigPage extends StatefulWidget {
  const AiConfigPage({Key? key}) : super(key: key);
  @override
  State<AiConfigPage> createState() => _AiConfigPageState();
}

class _AiConfigPageState extends State<AiConfigPage> {
  int _providerIndex = 0;
  late TextEditingController _apiKeyCtrl;
  late TextEditingController _modelCtrl;
  bool _obscureKey = true;
  bool _testing = false;
  bool _saving = false;
  bool _fetchingModels = false;
  List<ModelInfo>? _fetchedModels;
  String? _fetchError;

  List<ModelProvider> get _providers => kModelProviders;
  ModelProvider get _selectedProvider => _providers[_providerIndex];

  ModelInfo? get _bestModel =>
      (_fetchedModels != null && _fetchedModels!.isNotEmpty)
          ? _fetchedModels!.first
          : null;

  String get _effectiveModelName =>
      _modelCtrl.text.trim().isNotEmpty
          ? _modelCtrl.text.trim()
          : (_bestModel?.label ?? '（等待 API 获取）');

  @override
  void initState() {
    super.initState();
    final c = AiService.effectiveConfig;
    _apiKeyCtrl = TextEditingController(text: c.apiKey);
    _modelCtrl = TextEditingController(text: c.model);
    if (c.providerName.isNotEmpty) {
      for (int i = 0; i < _providers.length; i++) {
        if (_providers[i].name == c.providerName) {
          _providerIndex = i;
          break;
        }
      }
    }
    if (_apiKeyCtrl.text.isNotEmpty) {
      _doFetchModels();
    }
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  Future<void> _doFetchModels() async {
    final apiKey = _apiKeyCtrl.text.trim();
    if (apiKey.isEmpty) return;
    setState(() {
      _fetchingModels = true;
      _fetchError = null;
    });
    final models = await fetchModels(_selectedProvider.modelsUrl, apiKey);
    if (!mounted) return;
    setState(() {
      _fetchedModels = models;
      _fetchingModels = false;
      if (models == null) _fetchError = '无法获取模型列表，请检查 API Key 是否正确';
    });
  }

  void _onProviderChanged(int? v) {
    if (v == null) return;
    setState(() {
      _providerIndex = v;
      _fetchedModels = null;
      _fetchError = null;
    });
    if (_apiKeyCtrl.text.trim().isNotEmpty) {
      _doFetchModels();
    }
  }

  AiConfig _buildConfig() {
    final modelName = _modelCtrl.text.trim();
    final finalModel =
        modelName.isNotEmpty ? modelName : (_bestModel?.label ?? '');
    return AiConfig(
      providerName: _selectedProvider.name,
      baseUrl: _selectedProvider.baseUrl,
      apiKey: _apiKeyCtrl.text.trim(),
      model: finalModel,
    );
  }

  @override
  Widget build(BuildContext context) {
    return appScaffold(
      context,
      'AI 配置',
      ListView(
        padding: const EdgeInsets.all(14),
        children: [
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('模型提供商', style: TextStyle(fontSize: 13, color: C.t2)),
                const SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: C.bgDeep,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: C.border),
                  ),
                  child: DropdownButton<int>(
                    value: _providerIndex,
                    isExpanded: true,
                    underline: const SizedBox(),
                    dropdownColor: C.bgCard,
                    style: TextStyle(color: C.t1, fontSize: 14),
                    items: List.generate(
                      _providers.length,
                      (i) => DropdownMenuItem(
                        value: i,
                        child: Text(
                          _providers[i].name,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                    onChanged: _onProviderChanged,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'API Token（密钥）',
                  style: TextStyle(fontSize: 13, color: C.t2),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _apiKeyCtrl,
                  obscureText: _obscureKey,
                  style: TextStyle(color: C.t1, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '输入你的 API 密钥',
                    hintStyle: TextStyle(color: C.t3, fontSize: 12),
                    filled: true,
                    fillColor: C.bgDeep,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: C.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: C.t3),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureKey ? Icons.visibility_off : Icons.visibility,
                        color: C.t3,
                        size: 18,
                      ),
                      onPressed:
                          () => setState(() => _obscureKey = !_obscureKey),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '填完密钥后自动拉取该厂商可用模型',
                      style: TextStyle(fontSize: 10, color: C.t3),
                    ),
                    const Spacer(),
                    if (_apiKeyCtrl.text.trim().isNotEmpty && !_fetchingModels)
                      GestureDetector(
                        onTap: _doFetchModels,
                        child: Text(
                          '刷新模型列表',
                          style: TextStyle(fontSize: 10, color: C.t3),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_fetchingModels)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: CardBox(
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: C.t3,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '正在从 ${_selectedProvider.name} 拉取最新模型...',
                      style: TextStyle(fontSize: 12, color: C.t2),
                    ),
                  ],
                ),
              ),
            ),
          if (_fetchError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: CardBox(
                child: Row(
                  children: [
                    Text('⚠️', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _fetchError!,
                        style: TextStyle(fontSize: 12, color: C.red),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '模型名称（可选）',
                      style: TextStyle(fontSize: 13, color: C.t2),
                    ),
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: C.t3.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '留空=自动选最佳',
                        style: TextStyle(fontSize: 9, color: C.t3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _bestModel != null
                      ? '留空则自动使用最强模型：${_bestModel!.label}（评分 ${_bestModel!.score}）'
                      : '请先填写 API Key 并等待模型列表加载',
                  style: TextStyle(fontSize: 10, color: C.t3),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _modelCtrl,
                  style: TextStyle(color: C.t1, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '留空自动选择',
                    hintStyle: TextStyle(color: C.t3, fontSize: 12),
                    filled: true,
                    fillColor: C.bgDeep,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: C.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: C.t3),
                    ),
                  ),
                ),
                if (_fetchedModels != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'API 拉取结果（按性能评分降序）：',
                    style: TextStyle(fontSize: 9, color: C.t3),
                  ),
                  const SizedBox(height: 4),
                  ..._fetchedModels!
                      .take(10)
                      .map(
                        (m) => Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color:
                                      m.score == _bestModel?.score
                                          ? C.green
                                          : C.t3,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                m.label,
                                style: TextStyle(
                                  fontSize: 10,
                                  color:
                                      m.score == _bestModel?.score
                                          ? C.green
                                          : C.t2,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '评分 ${m.score}',
                                style: TextStyle(fontSize: 9, color: C.t3),
                              ),
                            ],
                          ),
                        ),
                      ),
                  if (_fetchedModels!.length > 10)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '...还有 ${_fetchedModels!.length - 10} 个模型',
                        style: TextStyle(fontSize: 9, color: C.t3),
                      ),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          CardBox(
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _bestModel != null ? C.green : C.t3,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_selectedProvider.name} · ${_effectiveModelName}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: C.t1,
                        ),
                      ),
                      Text(
                        'API 动态获取 · 端点：${_selectedProvider.baseUrl}',
                        style: TextStyle(fontSize: 9, color: C.t3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_testing)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(color: C.t3),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _testConnection,
                style: OutlinedButton.styleFrom(
                  foregroundColor: C.t3,
                  side: const BorderSide(color: C.t3),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                child: const Text(
                  '测试连接',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          const SizedBox(height: 10),
          if (_saving)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(color: C.t3),
              ),
            )
          else
            primaryBtn('保存配置', _save),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ghostBtn('↩️ 恢复默认', _resetDefault),
          ),
          const SizedBox(height: 16),
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '说明',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: C.t1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '\u2022 \u9009\u62e9\u63d0\u4f9b\u5546 \u2192 \u586b\u5199 API Key \u2192 \u81ea\u52a8\u62c9\u53d6\u53ef\u7528\u6a21\u578b\n\u2022 \u6a21\u578b\u540d\u7559\u7a7a = \u81ea\u52a8\u4f7f\u7528\u8bc4\u5206\u6700\u9ad8\u7684\u6700\u5f3a\u6a21\u578b\uff08\u4fdd\u5b58\u65f6\u81ea\u52a8\u586b\u5165\uff09\n\u2022 \u65e0\u9884\u8bbe\u786c\u7f16\u7801\uff0c\u5168\u90e8\u4ece\u5382\u5546 API \u52a8\u6001\u83b7\u53d6',
                  style: TextStyle(fontSize: 11, color: C.t2, height: 1.8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _testConnection() async {
    final cfg = _buildConfig();
    if (cfg.model.isEmpty) {
      toast(context, '请先等待模型列表加载完成');
      return;
    }
    AiService.setConfig(cfg);
    setState(() => _testing = true);
    final err = await AiService.testConnection();
    if (!mounted) return;
    setState(() => _testing = false);
    toast(context, err == null ? '✅ 连接成功（模型：${cfg.model}）' : '❌ $err');
  }

  void _save() async {
    final cfg = _buildConfig();
    if (cfg.model.isEmpty) {
      toast(context, '无法保存：模型列表未加载完成');
      return;
    }
    if (cfg.apiKey.isEmpty) {
      toast(context, '请填写 API 密钥');
      return;
    }
    setState(() => _saving = true);
    final settings = gStorage.getSettings();
    settings['aiConfig'] = cfg.toMap();
    await gStorage.saveSettings(settings);
    AiService.setConfig(cfg);
    if (!mounted) return;
    setState(() => _saving = false);
    toast(context, '✅ 已保存：${cfg.providerName} · ${cfg.model}');
    Navigator.pop(context);
  }

  void _resetDefault() {
    final c = AiConfig.defaultConfig();
    setState(() {
      _providerIndex = 0;
      _apiKeyCtrl.text = c.apiKey;
      _modelCtrl.text = c.model;
      _fetchedModels = null;
      _fetchError = null;
    });
    _doFetchModels();
  }
}
