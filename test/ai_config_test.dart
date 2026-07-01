import 'package:flutter_test/flutter_test.dart';
import 'package:ipad_boss_app/ai_service.dart';

void main() {
  group('AiConfig', () {
    test('defaultConfig 含 BigModel GLM 默认配置', () {
      final d = AiConfig.defaultConfig();
      expect(d.providerName, 'GLM (智谱)');
      expect(
        d.baseUrl,
        'https://open.bigmodel.cn/api/paas/v4/chat/completions',
      );
      expect(d.apiKey, isNotEmpty);
      expect(d.model, 'GLM-4-Flash-250414');
      expect(d.protocol, 'openai');
      expect(kDefaultAiVisionModel, 'GLM-4.1V-Thinking-Flash');
    });

    test('fromMap(null) 回退默认值', () {
      expect(AiConfig.fromMap(null).baseUrl, AiConfig.defaultConfig().baseUrl);
      expect(AiConfig.fromMap(null).apiKey, AiConfig.defaultConfig().apiKey);
      expect(AiConfig.fromMap(null).model, AiConfig.defaultConfig().model);
    });

    test('fromMap 部分字段空时 effective 回退', () {
      final c = AiConfig.fromMap({
        'baseUrl': '',
        'apiKey': 'sk-x',
        'model': '',
        'protocol': '',
      });
      final e = c.effective;
      expect(e.baseUrl, AiConfig.defaultConfig().baseUrl); // 空回退
      expect(e.apiKey, 'sk-x'); // 非空保留
      expect(e.model, AiConfig.defaultConfig().model); // 空回退
      expect(e.protocol, 'openai'); // 空回退默认
    });

    test('fromMap 全字段非空时 effective 全保留', () {
      final c = AiConfig(
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'sk-new',
        model: 'gpt-4',
        protocol: 'openai',
      );
      final e = c.effective;
      expect(e.baseUrl, 'https://api.openai.com/v1');
      expect(e.apiKey, 'sk-new');
      expect(e.model, 'gpt-4');
      expect(e.protocol, 'openai');
    });

    test('toMap/fromMap 往返一致', () {
      final c = AiConfig(
        baseUrl: 'b',
        apiKey: 'k',
        model: 'm',
        protocol: 'anthropic',
      );
      final restored = AiConfig.fromMap(c.toMap());
      expect(restored.baseUrl, 'b');
      expect(restored.apiKey, 'k');
      expect(restored.model, 'm');
      expect(restored.protocol, 'anthropic');
    });

    test('isConfigured 正确判断', () {
      expect(
        AiConfig(baseUrl: 'b', apiKey: 'k', model: 'm').isConfigured,
        true,
      );
      expect(
        AiConfig(baseUrl: '', apiKey: 'k', model: 'm').isConfigured,
        false,
      );
      expect(
        AiConfig(baseUrl: 'b', apiKey: '', model: 'm').isConfigured,
        false,
      );
    });
  });

  group('AiService 配置持有', () {
    test('setConfig/getConfig 持有生效', () {
      AiService.setConfig(AiConfig(model: 'test-model'));
      expect(AiService.config.model, 'test-model');
    });

    test('effectiveConfig 空字段回退默认', () {
      AiService.setConfig(AiConfig(model: 'test-model'));
      expect(AiService.effectiveConfig.apiKey, AiConfig.defaultConfig().apiKey);
      expect(
        AiService.effectiveConfig.baseUrl,
        AiConfig.defaultConfig().baseUrl,
      );
      expect(AiService.effectiveConfig.model, 'test-model'); // 非空保留
    });

    test('setConfig(defaultConfig) 完整恢复', () {
      AiService.setConfig(AiConfig(model: 'temp'));
      AiService.setConfig(AiConfig.defaultConfig());
      expect(AiService.effectiveConfig.model, 'GLM-4-Flash-250414');
      expect(
        AiService.effectiveConfig.baseUrl,
        'https://open.bigmodel.cn/api/paas/v4/chat/completions',
      );
    });
  });
}
