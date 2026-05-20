import 'package:flutter_test/flutter_test.dart';
import 'package:openim/ai_assistant/models/llm_config.dart';

void main() {
  group('LlmConfig', () {
    test('default values are set correctly', () {
      const config = LlmConfig();

      expect(config.vendor, 'openai');
      expect(config.apiKey, '');
      expect(config.apiBaseUrl, 'https://api.openai.com/v1');
      expect(config.modelName, 'gpt-4o-mini');
      expect(config.maxTokens, 2048);
      expect(config.temperature, 0.7);
    });

    test('isConfigured returns false when apiKey is empty', () {
      const config = LlmConfig(
        apiKey: '',
        apiBaseUrl: 'https://api.openai.com/v1',
        modelName: 'gpt-4o-mini',
      );

      expect(config.isConfigured, isFalse);
    });

    test('isConfigured returns false when apiBaseUrl is empty', () {
      const config = LlmConfig(
        apiKey: 'sk-test',
        apiBaseUrl: '',
        modelName: 'gpt-4o-mini',
      );

      expect(config.isConfigured, isFalse);
    });

    test('isConfigured returns false when modelName is empty', () {
      const config = LlmConfig(
        apiKey: 'sk-test',
        apiBaseUrl: 'https://api.openai.com/v1',
        modelName: '',
      );

      expect(config.isConfigured, isFalse);
    });

    test('isConfigured returns true when all required fields are set', () {
      const config = LlmConfig(
        apiKey: 'sk-test',
        apiBaseUrl: 'https://api.openai.com/v1',
        modelName: 'gpt-4o-mini',
      );

      expect(config.isConfigured, isTrue);
    });

    test('copyWith returns new instance with updated values', () {
      const config = LlmConfig();

      final updated = config.copyWith(
        apiKey: 'sk-new',
        modelName: 'gpt-4o',
        temperature: 0.5,
      );

      expect(updated.apiKey, 'sk-new');
      expect(updated.modelName, 'gpt-4o');
      expect(updated.temperature, 0.5);
      expect(updated.vendor, 'openai');
      expect(updated.apiBaseUrl, 'https://api.openai.com/v1');
      expect(updated.maxTokens, 2048);
    });

    test('copyWith preserves original values when no arguments given', () {
      const config = LlmConfig(
        vendor: 'qwen',
        apiKey: 'sk-test',
        apiBaseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
        modelName: 'qwen-plus',
        maxTokens: 4096,
        temperature: 0.8,
      );

      final copied = config.copyWith();

      expect(copied.vendor, config.vendor);
      expect(copied.apiKey, config.apiKey);
      expect(copied.apiBaseUrl, config.apiBaseUrl);
      expect(copied.modelName, config.modelName);
      expect(copied.maxTokens, config.maxTokens);
      expect(copied.temperature, config.temperature);
    });

    test('toJson excludes apiKey from output', () {
      const config = LlmConfig(
        apiKey: 'sk-secret-key',
        apiBaseUrl: 'https://api.openai.com/v1',
        modelName: 'gpt-4o-mini',
      );

      final json = config.toJson();

      expect(json.containsKey('apiKey'), isFalse);
      expect(json['vendor'], 'openai');
      expect(json['apiBaseUrl'], 'https://api.openai.com/v1');
      expect(json['modelName'], 'gpt-4o-mini');
      expect(json['maxTokens'], 2048);
      expect(json['temperature'], 0.7);
    });

    test('fromJson creates config with provided values', () {
      final json = {
        'vendor': 'qwen',
        'apiBaseUrl': 'https://dashscope.aliyuncs.com/compatible-mode/v1',
        'modelName': 'qwen-plus',
        'maxTokens': 4096,
        'temperature': 0.8,
      };

      final config = LlmConfig.fromJson(json);

      expect(config.vendor, 'qwen');
      expect(config.apiBaseUrl, 'https://dashscope.aliyuncs.com/compatible-mode/v1');
      expect(config.modelName, 'qwen-plus');
      expect(config.maxTokens, 4096);
      expect(config.temperature, 0.8);
      expect(config.apiKey, '');
    });

    test('fromJson uses defaults for missing values', () {
      final json = <String, dynamic>{};

      final config = LlmConfig.fromJson(json);

      expect(config.vendor, 'openai');
      expect(config.apiBaseUrl, 'https://api.openai.com/v1');
      expect(config.modelName, 'gpt-4o-mini');
      expect(config.maxTokens, 2048);
      expect(config.temperature, 0.7);
    });

    test('fromJson handles integer temperature by converting to double', () {
      final json = {
        'temperature': 1,
      };

      final config = LlmConfig.fromJson(json);

      expect(config.temperature, 1.0);
      expect(config.temperature, isA<double>());
    });

    test('round-trip toJson then fromJson preserves non-sensitive values', () {
      const config = LlmConfig(
        vendor: 'deepseek',
        apiBaseUrl: 'https://api.deepseek.com/v1',
        modelName: 'deepseek-chat',
        maxTokens: 1024,
        temperature: 0.3,
      );

      final json = config.toJson();
      final restored = LlmConfig.fromJson(json);

      expect(restored.vendor, config.vendor);
      expect(restored.apiBaseUrl, config.apiBaseUrl);
      expect(restored.modelName, config.modelName);
      expect(restored.maxTokens, config.maxTokens);
      expect(restored.temperature, config.temperature);
    });
  });

  group('LlmVendorPreset', () {
    test('all contains 6 vendor presets', () {
      expect(LlmVendorPreset.all.length, 6);
    });

    test('openai preset has correct defaults', () {
      expect(LlmVendorPreset.openai.vendor, 'openai');
      expect(LlmVendorPreset.openai.apiBaseUrl, 'https://api.openai.com/v1');
      expect(LlmVendorPreset.openai.modelName, 'gpt-4o-mini');
    });

    test('azure preset has empty url and model', () {
      expect(LlmVendorPreset.azure.vendor, 'azure');
      expect(LlmVendorPreset.azure.apiBaseUrl, '');
      expect(LlmVendorPreset.azure.modelName, '');
    });

    test('qwen preset has correct defaults', () {
      expect(LlmVendorPreset.qwen.vendor, 'qwen');
      expect(LlmVendorPreset.qwen.apiBaseUrl, 'https://dashscope.aliyuncs.com/compatible-mode/v1');
      expect(LlmVendorPreset.qwen.modelName, 'qwen-plus');
    });

    test('zhipu preset has correct defaults', () {
      expect(LlmVendorPreset.zhipu.vendor, 'zhipu');
      expect(LlmVendorPreset.zhipu.apiBaseUrl, 'https://open.bigmodel.cn/api/paas/v4');
      expect(LlmVendorPreset.zhipu.modelName, 'glm-4-flash');
    });

    test('deepseek preset has correct defaults', () {
      expect(LlmVendorPreset.deepseek.vendor, 'deepseek');
      expect(LlmVendorPreset.deepseek.apiBaseUrl, 'https://api.deepseek.com/v1');
      expect(LlmVendorPreset.deepseek.modelName, 'deepseek-chat');
    });

    test('custom preset has empty url and model', () {
      expect(LlmVendorPreset.custom.vendor, 'custom');
      expect(LlmVendorPreset.custom.apiBaseUrl, '');
      expect(LlmVendorPreset.custom.modelName, '');
    });

    test('getByName returns correct preset for known vendors', () {
      expect(LlmVendorPreset.getByName('openai').vendor, 'openai');
      expect(LlmVendorPreset.getByName('azure').vendor, 'azure');
      expect(LlmVendorPreset.getByName('qwen').vendor, 'qwen');
      expect(LlmVendorPreset.getByName('zhipu').vendor, 'zhipu');
      expect(LlmVendorPreset.getByName('deepseek').vendor, 'deepseek');
      expect(LlmVendorPreset.getByName('custom').vendor, 'custom');
    });

    test('getByName returns openai for unknown vendor', () {
      expect(LlmVendorPreset.getByName('unknown').vendor, 'openai');
    });

    test('all presets have unique vendor names', () {
      final vendors = LlmVendorPreset.all.map((e) => e.config.vendor).toList();
      expect(vendors.toSet().length, vendors.length);
    });
  });
}
