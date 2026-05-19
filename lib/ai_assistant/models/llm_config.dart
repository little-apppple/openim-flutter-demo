class LlmConfig {
  final String vendor;
  final String apiKey;
  final String apiBaseUrl;
  final String modelName;
  final int maxTokens;
  final double temperature;

  const LlmConfig({
    this.vendor = 'openai',
    this.apiKey = '',
    this.apiBaseUrl = 'https://api.openai.com/v1',
    this.modelName = 'gpt-4o-mini',
    this.maxTokens = 2048,
    this.temperature = 0.7,
  });

  LlmConfig copyWith({
    String? vendor,
    String? apiKey,
    String? apiBaseUrl,
    String? modelName,
    int? maxTokens,
    double? temperature,
  }) {
    return LlmConfig(
      vendor: vendor ?? this.vendor,
      apiKey: apiKey ?? this.apiKey,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      modelName: modelName ?? this.modelName,
      maxTokens: maxTokens ?? this.maxTokens,
      temperature: temperature ?? this.temperature,
    );
  }

  bool get isConfigured => apiKey.isNotEmpty && apiBaseUrl.isNotEmpty && modelName.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'vendor': vendor,
        'apiBaseUrl': apiBaseUrl,
        'modelName': modelName,
        'maxTokens': maxTokens,
        'temperature': temperature,
      };

  factory LlmConfig.fromJson(Map<String, dynamic> json) => LlmConfig(
        vendor: json['vendor'] ?? 'openai',
        apiBaseUrl: json['apiBaseUrl'] ?? 'https://api.openai.com/v1',
        modelName: json['modelName'] ?? 'gpt-4o-mini',
        maxTokens: json['maxTokens'] ?? 2048,
        temperature: (json['temperature'] ?? 0.7).toDouble(),
      );
}

class LlmVendorPreset {
  static const openai = LlmConfig(
    vendor: 'openai',
    apiBaseUrl: 'https://api.openai.com/v1',
    modelName: 'gpt-4o-mini',
  );

  static const azure = LlmConfig(
    vendor: 'azure',
    apiBaseUrl: '',
    modelName: '',
  );

  static const qwen = LlmConfig(
    vendor: 'qwen',
    apiBaseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    modelName: 'qwen-plus',
  );

  static const zhipu = LlmConfig(
    vendor: 'zhipu',
    apiBaseUrl: 'https://open.bigmodel.cn/api/paas/v4',
    modelName: 'glm-4-flash',
  );

  static const deepseek = LlmConfig(
    vendor: 'deepseek',
    apiBaseUrl: 'https://api.deepseek.com/v1',
    modelName: 'deepseek-chat',
  );

  static const custom = LlmConfig(
    vendor: 'custom',
    apiBaseUrl: '',
    modelName: '',
  );

  static const List<MapEntry<String, LlmConfig>> all = [
    MapEntry('OpenAI', openai),
    MapEntry('Azure OpenAI', azure),
    MapEntry('通义千问', qwen),
    MapEntry('智谱 AI', zhipu),
    MapEntry('DeepSeek', deepseek),
    MapEntry('自定义', custom),
  ];

  static LlmConfig getByName(String vendor) {
    switch (vendor) {
      case 'openai':
        return openai;
      case 'azure':
        return azure;
      case 'qwen':
        return qwen;
      case 'zhipu':
        return zhipu;
      case 'deepseek':
        return deepseek;
      case 'custom':
        return custom;
      default:
        return openai;
    }
  }
}
