# AI Native IM 客户端改造 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 对 openim-flutter-demo 客户端进行 AI Native 改造，实现大模型辅助社交建议 + Notion 聊天记录同步与长时记忆增强。

**Architecture:** 新增全局 `AIAssistantController`（GetX 单例），持有 `LLMService` 和 `NotionService`。ChatLogic 通过 GetX find 依赖 AI 控制器获取建议。AI 建议以悬浮卡片形式展示在输入框上方。配置通过 AI 设置页管理，敏感信息加密存储。

**Tech Stack:** Flutter/Dart, GetX (状态管理+路由), dio (HTTP), flutter_secure_storage (加密存储), OpenAI Chat Completions 兼容 API, Notion API v1

---

## 文件结构

### 新增文件

| 文件 | 职责 |
|------|------|
| `lib/ai_assistant/models/llm_config.dart` | LLM 配置数据模型，含供应商预设常量 |
| `lib/ai_assistant/models/notion_config.dart` | Notion 配置数据模型 |
| `lib/ai_assistant/models/memory_context.dart` | 记忆上下文模型，组装 LLM prompt 用 |
| `lib/ai_assistant/models/ai_suggestion.dart` | AI 建议结果模型（话题/回复） |
| `lib/ai_assistant/services/llm_service.dart` | 大模型调用封装，OpenAI 兼容格式 |
| `lib/ai_assistant/services/notion_service.dart` | Notion API 封装，读写 Page |
| `lib/ai_assistant/controllers/ai_assistant_controller.dart` | 全局 AI 控制器，编排所有 AI 能力 |
| `lib/ai_assistant/widgets/ai_suggestion_bar.dart` | 输入框上方悬浮建议卡片组件 |
| `lib/pages/ai_settings/ai_settings_binding.dart` | AI 设置页 GetX Binding |
| `lib/pages/ai_settings/ai_settings_logic.dart` | AI 设置页逻辑 |
| `lib/pages/ai_settings/ai_settings_view.dart` | AI 设置页 UI |
| `lib/ai_assistant/utils/secure_storage.dart` | flutter_secure_storage 封装工具类 |

### 修改文件

| 文件 | 修改内容 |
|------|----------|
| `pubspec.yaml` | 新增 flutter_secure_storage 依赖 |
| `lib/app.dart` | InitBinding 注册 AIAssistantController |
| `lib/routes/app_routes.dart` | 新增 aiSettings 路由常量 |
| `lib/routes/app_pages.dart` | 新增 aiSettings 路由页面映射 |
| `openim_common/lib/src/utils/data_sp.dart` | 新增 AI 相关非敏感配置存取方法 |
| `lib/pages/chat/chat_logic.dart` | 集成 AI 建议（话题+回复）触发逻辑 |
| `lib/pages/chat/chat_view.dart` | 插入 AiSuggestionBar 组件 |
| `lib/pages/mine/mine_view.dart` | 新增 AI 助手菜单项 |
| `lib/pages/mine/mine_logic.dart` | 新增跳转 AI 设置页方法 |

---

### Task 1: 添加 flutter_secure_storage 依赖

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: 在 pubspec.yaml 中添加依赖**

在 `dependencies:` 下 `flutter_openim_sdk:` 之前添加：

```yaml
  flutter_secure_storage: ^9.2.4
```

- [ ] **Step 2: 运行 flutter pub get**

Run: `cd /workspace && flutter pub get`
Expected: 依赖安装成功，无报错

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add flutter_secure_storage dependency"
```

---

### Task 2: 创建数据模型

**Files:**
- Create: `lib/ai_assistant/models/llm_config.dart`
- Create: `lib/ai_assistant/models/notion_config.dart`
- Create: `lib/ai_assistant/models/memory_context.dart`
- Create: `lib/ai_assistant/models/ai_suggestion.dart`

- [ ] **Step 1: 创建 LlmConfig 模型**

```dart
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
```

- [ ] **Step 2: 创建 NotionConfig 模型**

```dart
class NotionConfig {
  final String integrationToken;
  final String rootPageId;

  const NotionConfig({
    this.integrationToken = '',
    this.rootPageId = '',
  });

  NotionConfig copyWith({
    String? integrationToken,
    String? rootPageId,
  }) {
    return NotionConfig(
      integrationToken: integrationToken ?? this.integrationToken,
      rootPageId: rootPageId ?? this.rootPageId,
    );
  }

  bool get isConfigured => integrationToken.isNotEmpty && rootPageId.isNotEmpty;

  Map<String, dynamic> toNonSensitiveJson() => {
        'rootPageId': rootPageId,
      };
}
```

- [ ] **Step 3: 创建 MemoryContext 模型**

```dart
class MemoryContext {
  final String conversationID;
  final String recentMessages;
  final String contactProfile;
  final String notionLongTermMemory;

  const MemoryContext({
    required this.conversationID,
    this.recentMessages = '',
    this.contactProfile = '',
    this.notionLongTermMemory = '',
  });

  String buildTopicPrompt() {
    final buffer = StringBuffer();
    buffer.write('你是一个社交助手，帮助用户在即时通讯中找到合适的话题。');
    buffer.write('请根据以下上下文信息，生成3到5个适合当前对话的话题建议。');
    buffer.write('只输出JSON数组格式，例如：["话题1","话题2","话题3"]');
    buffer.write('不要输出任何其他内容。\n\n');
    if (contactProfile.isNotEmpty) {
      buffer.write('联系人信息：\n$contactProfile\n\n');
    }
    if (notionLongTermMemory.isNotEmpty) {
      buffer.write('长期记忆（来自Notion笔记）：\n$notionLongTermMemory\n\n');
    }
    if (recentMessages.isNotEmpty) {
      buffer.write('近期聊天记录：\n$recentMessages\n\n');
    }
    return buffer.toString();
  }

  String buildReplyPrompt(String latestMessage) {
    final buffer = StringBuffer();
    buffer.write('你是一个社交助手，帮助用户在即时通讯中生成合适的回复。');
    buffer.write('请根据以下上下文信息，生成3个适合回复最新消息的建议。');
    buffer.write('只输出JSON数组格式，例如：["回复1","回复2","回复3"]');
    buffer.write('不要输出任何其他内容。\n\n');
    if (contactProfile.isNotEmpty) {
      buffer.write('联系人信息：\n$contactProfile\n\n');
    }
    if (notionLongTermMemory.isNotEmpty) {
      buffer.write('长期记忆（来自Notion笔记）：\n$notionLongTermMemory\n\n');
    }
    if (recentMessages.isNotEmpty) {
      buffer.write('近期聊天记录：\n$recentMessages\n\n');
    }
    buffer.write('最新收到的消息：$latestMessage\n');
    return buffer.toString();
  }
}
```

- [ ] **Step 4: 创建 AiSuggestion 模型**

```dart
enum AiSuggestionType { topic, reply }

class AiSuggestion {
  final AiSuggestionType type;
  final String text;

  const AiSuggestion({
    required this.type,
    required this.text,
  });
}
```

- [ ] **Step 5: Commit**

```bash
git add lib/ai_assistant/models/
git commit -m "feat: add AI assistant data models"
```

---

### Task 3: 创建 SecureStorage 工具类

**Files:**
- Create: `lib/ai_assistant/utils/secure_storage.dart`

- [ ] **Step 1: 创建 SecureStorage 封装**

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  SecureStorage._();

  static const _instance = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static Future<void> write(String key, String value) async {
    await _instance.write(key: key, value: value);
  }

  static Future<String?> read(String key) async {
    return await _instance.read(key: key);
  }

  static Future<void> delete(String key) async {
    await _instance.delete(key: key);
  }

  static const llmApiKey = 'ai_llm_api_key';
  static const notionToken = 'ai_notion_token';
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/ai_assistant/utils/
git commit -m "feat: add SecureStorage utility for encrypted config"
```

---

### Task 4: 扩展 DataSp 添加 AI 配置存取方法

**Files:**
- Modify: `openim_common/lib/src/utils/data_sp.dart`

- [ ] **Step 1: 在 DataSp 类中新增 AI 相关常量和存取方法**

在 `DataSp` 类的常量声明区域（`_meetingInProgress` 之后）添加：

```dart
  static const _aiEnabled = 'ai_enabled';
  static const _aiLlmConfig = 'ai_llm_config';
  static const _aiNotionConfig = 'ai_notion_config_non_sensitive';
  static const _aiTopicEnabled = '%s_ai_topic_enabled';
  static const _aiReplyEnabled = '%s_ai_reply_enabled';
  static const _aiNotionSyncEnabled = '%s_ai_notion_sync_enabled';
  static const _aiLastSyncTime = 'ai_last_sync_time';
```

在类末尾（`removeMeetingInProgress` 方法之后）添加：

```dart
  static Future<bool>? putAIEnabled(bool enabled) {
    return SpUtil().putBool(_aiEnabled, defaultValue: enabled);
  }

  static bool getAIEnabled() {
    return SpUtil().getBool(_aiEnabled, defValue: false) ?? false;
  }

  static Future<bool>? putAILlmConfig(Map<String, dynamic> config) {
    return SpUtil().putObject(_aiLlmConfig, config);
  }

  static Map? getAILlmConfig() {
    return SpUtil().getObject(_aiLlmConfig);
  }

  static Future<bool>? putAINotionConfig(Map<String, dynamic> config) {
    return SpUtil().putObject(_aiNotionConfig, config);
  }

  static Map? getAINotionConfig() {
    return SpUtil().getObject(_aiNotionConfig);
  }

  static Future<bool>? putAITopicEnabled(bool enabled) {
    return SpUtil().putBool(getKey(_aiTopicEnabled), defaultValue: enabled);
  }

  static bool getAITopicEnabled() {
    return SpUtil().getBool(getKey(_aiTopicEnabled), defValue: true) ?? true;
  }

  static Future<bool>? putAIReplyEnabled(bool enabled) {
    return SpUtil().putBool(getKey(_aiReplyEnabled), defaultValue: enabled);
  }

  static bool getAIReplyEnabled() {
    return SpUtil().getBool(getKey(_aiReplyEnabled), defValue: true) ?? true;
  }

  static Future<bool>? putAINotionSyncEnabled(bool enabled) {
    return SpUtil().putBool(getKey(_aiNotionSyncEnabled), defaultValue: enabled);
  }

  static bool getAINotionSyncEnabled() {
    return SpUtil().getBool(getKey(_aiNotionSyncEnabled), defValue: true) ?? true;
  }

  static Future<bool>? putAILastSyncTime(String time) {
    return SpUtil().putString(_aiLastSyncTime, time);
  }

  static String? getAILastSyncTime() {
    return SpUtil().getString(_aiLastSyncTime);
  }
```

- [ ] **Step 2: Commit**

```bash
git add openim_common/lib/src/utils/data_sp.dart
git commit -m "feat: extend DataSp with AI config storage methods"
```

---

### Task 5: 创建 LLM Service

**Files:**
- Create: `lib/ai_assistant/services/llm_service.dart`

- [ ] **Step 1: 创建 LLMService**

```dart
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:openim_common/openim_common.dart';
import '../models/llm_config.dart';
import '../models/memory_context.dart';

class LLMService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  Future<List<String>> generateTopicSuggestions({
    required LlmConfig config,
    required MemoryContext context,
  }) async {
    final prompt = context.buildTopicPrompt();
    return _callLLM(config, prompt);
  }

  Future<List<String>> generateReplySuggestions({
    required LlmConfig config,
    required MemoryContext context,
    required String latestMessage,
  }) async {
    final prompt = context.buildReplyPrompt(latestMessage);
    return _callLLM(config, prompt);
  }

  Future<bool> testConnection(LlmConfig config) async {
    try {
      final response = await _sendRequest(
        config: config,
        messages: [
          {'role': 'user', 'content': 'Hi'},
        ],
        maxTokens: 5,
      );
      return response != null;
    } catch (e) {
      Logger.print('LLM connection test failed: $e');
      return false;
    }
  }

  Future<List<String>> _callLLM(LlmConfig config, String prompt) async {
    try {
      final response = await _sendRequest(
        config: config,
        messages: [
          {'role': 'system', 'content': prompt},
          {'role': 'user', 'content': '请生成建议'},
        ],
        maxTokens: config.maxTokens,
      );

      if (response == null) return [];

      return _parseSuggestions(response);
    } catch (e) {
      Logger.print('LLM call failed: $e');
      return [];
    }
  }

  Future<String?> _sendRequest({
    required LlmConfig config,
    required List<Map<String, String>> messages,
    required int maxTokens,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${config.apiKey}',
    };

    if (config.vendor == 'azure') {
      headers['api-key'] = config.apiKey;
      headers.remove('Authorization');
    }

    final body = {
      'model': config.modelName,
      'messages': messages,
      'max_tokens': maxTokens,
      'temperature': config.temperature,
    };

    final url = '${config.apiBaseUrl}/chat/completions';

    final response = await _dio.post(
      url,
      data: jsonEncode(body),
      options: Options(headers: headers),
    );

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      final choices = data['choices'] as List<dynamic>;
      if (choices.isNotEmpty) {
        return choices[0]['message']['content'] as String?;
      }
    }
    return null;
  }

  List<String> _parseSuggestions(String content) {
    try {
      final trimmed = content.trim();
      final decoded = jsonDecode(trimmed);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
      return [];
    } catch (_) {
      final regex = RegExp(r'"([^"]+)"');
      final matches = regex.allMatches(content);
      if (matches.isNotEmpty) {
        return matches.map((m) => m.group(1)!).toList();
      }
      return [];
    }
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/ai_assistant/services/llm_service.dart
git commit -m "feat: add LLM service with OpenAI-compatible API support"
```

---

### Task 6: 创建 Notion Service

**Files:**
- Create: `lib/ai_assistant/services/notion_service.dart`

- [ ] **Step 1: 创建 NotionService**

```dart
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:openim_common/openim_common.dart';
import '../models/notion_config.dart';

class NotionService {
  static const _baseUrl = 'https://api.notion.com/v1';
  static const _notionVersion = '2022-06-28';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  Future<bool> testConnection(NotionConfig config) async {
    try {
      await _get(config, '/pages/${config.rootPageId}');
      return true;
    } catch (e) {
      Logger.print('Notion connection test failed: $e');
      return false;
    }
  }

  Future<String?> findChildPageByName({
    required NotionConfig config,
    required String pageName,
  }) async {
    try {
      final response = await _post(
        config,
        '/search',
        body: {
          'query': pageName,
          'filter': {
            'property': 'object',
            'value': 'page',
          },
        },
      );

      final results = response['results'] as List<dynamic>;
      for (final page in results) {
        final pageId = page['id'] as String;
        final parent = page['parent'];
        if (parent != null && parent['page_id'] == config.rootPageId) {
          return pageId;
        }
      }
      return null;
    } catch (e) {
      Logger.print('Notion findChildPageByName failed: $e');
      return null;
    }
  }

  Future<String> createChildPage({
    required NotionConfig config,
    required String pageName,
  }) async {
    final response = await _post(
      config,
      '/pages',
      body: {
        'parent': {'page_id': config.rootPageId},
        'properties': {
          'title': [
            {
              'text': {'content': pageName},
            },
          ],
        },
      },
    );
    return response['id'] as String;
  }

  Future<String> getOrCreateChildPage({
    required NotionConfig config,
    required String pageName,
  }) async {
    final existingId = await findChildPageByName(config: config, pageName: pageName);
    if (existingId != null) return existingId;
    return await createChildPage(config: config, pageName: pageName);
  }

  Future<void> appendMessagesToPage({
    required NotionConfig config,
    required String pageId,
    required String dateHeader,
    required List<String> messageLines,
  }) async {
    final children = <Map<String, dynamic>>[];

    children.add({
      'object': 'block',
      'type': 'heading_2',
      'heading_2': {
        'rich_text': [
          {'type': 'text', 'text': {'content': dateHeader}},
        ],
      },
    });

    for (final line in messageLines) {
      children.add({
        'object': 'block',
        'type': 'paragraph',
        'paragraph': {
          'rich_text': [
            {'type': 'text', 'text': {'content': line}},
          ],
        },
      });
    }

    await _patch(
      config,
      '/blocks/$pageId/children',
      body: {'children': children},
    );
  }

  Future<String> readPageContent({
    required NotionConfig config,
    required String pageId,
  }) async {
    try {
      final response = await _get(config, '/blocks/$pageId/children?page_size=100');
      final results = response['results'] as List<dynamic>;
      final buffer = StringBuffer();

      for (final block in results) {
        final type = block['type'] as String;
        final richText = block[type]?['rich_text'] as List<dynamic>?;
        if (richText != null) {
          for (final text in richText) {
            buffer.writeln(text['plain_text'] ?? '');
          }
        }
      }
      return buffer.toString();
    } catch (e) {
      Logger.print('Notion readPageContent failed: $e');
      return '';
    }
  }

  Future<dynamic> _get(NotionConfig config, String path) async {
    final response = await _dio.get(
      '$_baseUrl$path',
      options: Options(headers: _headers(config)),
    );
    return response.data;
  }

  Future<dynamic> _post(NotionConfig config, String path, {required Map<String, dynamic> body}) async {
    final response = await _dio.post(
      '$_baseUrl$path',
      data: jsonEncode(body),
      options: Options(headers: _headers(config)),
    );
    return response.data;
  }

  Future<dynamic> _patch(NotionConfig config, String path, {required Map<String, dynamic> body}) async {
    final response = await _dio.patch(
      '$_baseUrl$path',
      data: jsonEncode(body),
      options: Options(headers: _headers(config)),
    );
    return response.data;
  }

  Map<String, String> _headers(NotionConfig config) => {
        'Authorization': 'Bearer ${config.integrationToken}',
        'Notion-Version': _notionVersion,
        'Content-Type': 'application/json',
      };

  Future<T> withRetry<T>(Future<T> Function() fn, {int maxRetries = 3}) async {
    final delays = [5, 15, 30];
    for (var i = 0; i <= maxRetries; i++) {
      try {
        return await fn();
      } catch (e) {
        if (i >= maxRetries) rethrow;
        Logger.print('Notion retry ${i + 1}/$maxRetries after ${delays[i]}s');
        await Future.delayed(Duration(seconds: delays[i]));
      }
    }
    throw Exception('Not reached');
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/ai_assistant/services/notion_service.dart
git commit -m "feat: add Notion service for chat sync and memory read"
```

---

### Task 7: 创建 AIAssistantController

**Files:**
- Create: `lib/ai_assistant/controllers/ai_assistant_controller.dart`

- [ ] **Step 1: 创建 AIAssistantController**

```dart
import 'dart:async';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import '../models/ai_suggestion.dart';
import '../models/llm_config.dart';
import '../models/memory_context.dart';
import '../models/notion_config.dart';
import '../services/llm_service.dart';
import '../services/notion_service.dart';
import '../utils/secure_storage.dart';

class AIAssistantController extends GetxController {
  final _llmService = LLMService();
  final _notionService = NotionService();

  final aiEnabled = false.obs;
  final llmConfig = const LlmConfig().obs;
  final notionConfig = const NotionConfig().obs;
  final topicEnabled = true.obs;
  final replyEnabled = true.obs;
  final notionSyncEnabled = true.obs;
  final llmConnected = false.obs;
  final notionConnected = false.obs;

  final suggestions = <AiSuggestion>[].obs;
  final isLoadingSuggestions = false.obs;
  final lastSyncTime = ''.obs;

  final _notionMemoryCache = <String, String>{};
  final _syncQueue = <Map<String, dynamic>>[];
  Timer? _syncTimer;
  String? _inFlightConversationID;

  @override
  void onInit() {
    super.onInit();
    _loadConfig();
    _startSyncTimer();
  }

  @override
  void onClose() {
    _syncTimer?.cancel();
    super.onClose();
  }

  Future<void> _loadConfig() async {
    aiEnabled.value = DataSp.getAIEnabled();

    final llmMap = DataSp.getAILlmConfig();
    if (llmMap != null) {
      final savedConfig = LlmConfig.fromJson(llmMap.cast());
      final apiKey = await SecureStorage.read(SecureStorage.llmApiKey) ?? '';
      llmConfig.value = savedConfig.copyWith(apiKey: apiKey);
    }

    final notionMap = DataSp.getAINotionConfig();
    if (notionMap != null) {
      final token = await SecureStorage.read(SecureStorage.notionToken) ?? '';
      final rootPageId = notionMap['rootPageId'] as String? ?? '';
      notionConfig.value = NotionConfig(integrationToken: token, rootPageId: rootPageId);
    }

    topicEnabled.value = DataSp.getAITopicEnabled();
    replyEnabled.value = DataSp.getAIReplyEnabled();
    notionSyncEnabled.value = DataSp.getAINotionSyncEnabled();
    lastSyncTime.value = DataSp.getAILastSyncTime() ?? '';
  }

  Future<void> saveLlmConfig(LlmConfig config) async {
    await SecureStorage.write(SecureStorage.llmApiKey, config.apiKey);
    DataSp.putAILlmConfig(config.toJson());
    llmConfig.value = config;
  }

  Future<void> saveNotionConfig(NotionConfig config) async {
    await SecureStorage.write(SecureStorage.notionToken, config.integrationToken);
    DataSp.putAINotionConfig(config.toNonSensitiveJson());
    notionConfig.value = config;
  }

  void setAIEnabled(bool enabled) {
    aiEnabled.value = enabled;
    DataSp.putAIEnabled(enabled);
    if (!enabled) {
      suggestions.clear();
      isLoadingSuggestions.value = false;
    }
  }

  void setTopicEnabled(bool enabled) {
    topicEnabled.value = enabled;
    DataSp.putAITopicEnabled(enabled);
  }

  void setReplyEnabled(bool enabled) {
    replyEnabled.value = enabled;
    DataSp.putAIReplyEnabled(enabled);
  }

  void setNotionSyncEnabled(bool enabled) {
    notionSyncEnabled.value = enabled;
    DataSp.putAINotionSyncEnabled(enabled);
  }

  Future<bool> testLlmConnection() async {
    if (!llmConfig.value.isConfigured) return false;
    final result = await _llmService.testConnection(llmConfig.value);
    llmConnected.value = result;
    return result;
  }

  Future<bool> testNotionConnection() async {
    if (!notionConfig.value.isConfigured) return false;
    final result = await _notionService.testConnection(notionConfig.value);
    notionConnected.value = result;
    return result;
  }

  bool get _canGenerateSuggestions =>
      aiEnabled.value && llmConfig.value.isConfigured;

  bool get _canSyncNotion =>
      aiEnabled.value && notionSyncEnabled.value && notionConfig.value.isConfigured;

  Future<void> generateTopicSuggestions(String conversationID) async {
    if (!_canGenerateSuggestions || !topicEnabled.value) return;
    if (_inFlightConversationID == conversationID) return;
    _inFlightConversationID = conversationID;

    isLoadingSuggestions.value = true;
    suggestions.clear();

    try {
      final context = await _buildMemoryContext(conversationID);
      final results = await _llmService.generateTopicSuggestions(
        config: llmConfig.value,
        context: context,
      );
      suggestions.assignAll(
        results.map((text) => AiSuggestion(type: AiSuggestionType.topic, text: text)),
      );
    } catch (e) {
      Logger.print('generateTopicSuggestions failed: $e');
    } finally {
      isLoadingSuggestions.value = false;
      _inFlightConversationID = null;
    }
  }

  Future<void> generateReplySuggestions(String conversationID, Message newMessage) async {
    if (!_canGenerateSuggestions || !replyEnabled.value) return;
    if (_inFlightConversationID == conversationID) return;
    _inFlightConversationID = conversationID;

    isLoadingSuggestions.value = true;
    suggestions.clear();

    try {
      final context = await _buildMemoryContext(conversationID);
      final latestText = newMessage.textElem?.content ?? '';
      final results = await _llmService.generateReplySuggestions(
        config: llmConfig.value,
        context: context,
        latestMessage: latestText,
      );
      suggestions.assignAll(
        results.map((text) => AiSuggestion(type: AiSuggestionType.reply, text: text)),
      );
    } catch (e) {
      Logger.print('generateReplySuggestions failed: $e');
    } finally {
      isLoadingSuggestions.value = false;
      _inFlightConversationID = null;
    }
  }

  void clearSuggestions() {
    suggestions.clear();
    isLoadingSuggestions.value = false;
  }

  Future<MemoryContext> _buildMemoryContext(String conversationID) async {
    String recentMessages = '';
    String contactProfile = '';
    String notionMemory = '';

    try {
      final result = await OpenIM.iMManager.messageManager.getAdvancedHistoryMessageList(
        conversationID: conversationID,
        count: 20,
      );
      final messages = result.messageList ?? [];
      final buffer = StringBuffer();
      for (final msg in messages) {
        if (msg.contentType == MessageType.text) {
          final sender = msg.senderNickname ?? '';
          final content = msg.textElem?.content ?? '';
          buffer.writeln('$sender: $content');
        }
      }
      recentMessages = buffer.toString();
    } catch (e) {
      Logger.print('Failed to fetch recent messages: $e');
    }

    try {
      final convList = await OpenIM.iMManager.conversationManager.getConversationListSplit(
        offset: 0,
        count: 100,
      );
      final conv = convList.firstWhereOrNull((c) => c.conversationID == conversationID);
      if (conv != null) {
        final buffer = StringBuffer();
        buffer.writeln('会话名称: ${conv.showName ?? ''}');
        if (conv.userID != null && conv.userID!.isNotEmpty) {
          try {
            final friends = await OpenIM.iMManager.friendshipManager.getFriendsInfo(
              userIDList: [conv.userID!],
            );
            final friend = friends.firstOrNull;
            if (friend != null) {
              buffer.writeln('好友备注: ${friend.remark ?? ''}');
            }
          } catch (_) {}
        }
        contactProfile = buffer.toString();
      }
    } catch (e) {
      Logger.print('Failed to fetch contact profile: $e');
    }

    if (_canSyncNotion) {
      notionMemory = _notionMemoryCache[conversationID] ?? '';
      if (notionMemory.isEmpty) {
        try {
          final pageName = _buildPageName(conversationID);
          final pageId = await _notionService.findChildPageByName(
            config: notionConfig.value,
            pageName: pageName,
          );
          if (pageId != null) {
            notionMemory = await _notionService.readPageContent(
              config: notionConfig.value,
              pageId: pageId,
            );
            _notionMemoryCache[conversationID] = notionMemory;
          }
        } catch (e) {
          Logger.print('Failed to read Notion memory: $e');
        }
      }
    }

    return MemoryContext(
      conversationID: conversationID,
      recentMessages: recentMessages,
      contactProfile: contactProfile,
      notionLongTermMemory: notionMemory,
    );
  }

  String _buildPageName(String conversationID) {
    return conversationID.replaceAll('_', '-');
  }

  void enqueueMessageForSync({
    required String conversationID,
    required String clientMsgID,
    required String senderNickname,
    required String content,
    required int sendTime,
  }) {
    if (!_canSyncNotion) return;
    _syncQueue.add({
      'conversationID': conversationID,
      'clientMsgID': clientMsgID,
      'senderNickname': senderNickname,
      'content': content,
      'sendTime': sendTime,
    });
    if (_syncQueue.length >= 20) {
      _flushSyncQueue();
    }
  }

  void _startSyncTimer() {
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_syncQueue.isNotEmpty) {
        _flushSyncQueue();
      }
    });
  }

  Future<void> _flushSyncQueue() async {
    if (_syncQueue.isEmpty || !_canSyncNotion) return;

    final batch = List<Map<String, dynamic>>.from(_syncQueue);
    _syncQueue.clear();

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final item in batch) {
      final convID = item['conversationID'] as String;
      grouped.putIfAbsent(convID, () => []).add(item);
    }

    for (final entry in grouped.entries) {
      try {
        final pageName = _buildPageName(entry.key);
        final pageId = await _notionService.withRetry(() => _notionService.getOrCreateChildPage(
              config: notionConfig.value,
              pageName: pageName,
            ));

        final byDate = <String, List<String>>{};
        for (final msg in entry.value) {
          final date = DateTime.fromMillisecondsSinceEpoch(msg['sendTime'] as int);
          final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          final timeStr = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
          final line = '[$timeStr] ${msg['senderNickname']}: ${msg['content']}';
          byDate.putIfAbsent(dateStr, () => []).add(line);
        }

        for (final dateEntry in byDate.entries) {
          await _notionService.withRetry(() => _notionService.appendMessagesToPage(
                config: notionConfig.value,
                pageId: pageId,
                dateHeader: dateEntry.key,
                messageLines: dateEntry.value,
              ));
        }

        lastSyncTime.value = DateTime.now().toIso8601String();
        DataSp.putAILastSyncTime(lastSyncTime.value);
      } catch (e) {
        Logger.print('Notion sync flush failed for ${entry.key}: $e');
      }
    }
  }

  void clearNotionMemoryCache(String conversationID) {
    _notionMemoryCache.remove(conversationID);
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/ai_assistant/controllers/
git commit -m "feat: add AIAssistantController with suggestion generation and Notion sync"
```

---

### Task 8: 创建 AiSuggestionBar 组件

**Files:**
- Create: `lib/ai_assistant/widgets/ai_suggestion_bar.dart`

- [ ] **Step 1: 创建 AiSuggestionBar**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import '../controllers/ai_assistant_controller.dart';
import '../models/ai_suggestion.dart';

class AiSuggestionBar extends StatelessWidget {
  final TextEditingController? inputController;

  const AiSuggestionBar({super.key, this.inputController});

  @override
  Widget build(BuildContext context) {
    final aiLogic = Get.find<AIAssistantController>();

    return Obx(() {
      final suggestions = aiLogic.suggestions;
      final isLoading = aiLogic.isLoadingSuggestions.value;

      if (!isLoading && suggestions.isEmpty) return const SizedBox.shrink();

      return Container(
        constraints: BoxConstraints(minHeight: 44.h),
        color: Styles.c_F0F2F6,
        padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 8.w),
        child: isLoading
            ? _buildShimmer()
            : Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: suggestions.map((s) => _buildSuggestionChip(s)).toList(),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => aiLogic.clearSuggestions(),
                    child: Padding(
                      padding: EdgeInsets.only(left: 8.w),
                      child: Icon(Icons.close, size: 18.w, color: Styles.c_8E9AB0),
                    ),
                  ),
                ],
              ),
      );
    });
  }

  Widget _buildSuggestionChip(AiSuggestion suggestion) {
    final icon = suggestion.type == AiSuggestionType.topic ? '💡' : '💬';
    return GestureDetector(
      onTap: () {
        final aiLogic = Get.find<AIAssistantController>();
        if (inputController != null) {
          inputController!.text = suggestion.text;
        }
        aiLogic.clearSuggestions();
      },
      child: Container(
        margin: EdgeInsets.only(right: 8.w),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: Styles.c_FFFFFF,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: Styles.c_E8EAEF, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: TextStyle(fontSize: 14.sp)),
            4.horizontalSpace,
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 200.w),
              child: Text(
                suggestion.text,
                style: Styles.ts_0C1C33_14sp,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return Row(
      children: List.generate(
        3,
        (_) => Container(
          margin: EdgeInsets.only(right: 8.w),
          width: 120.w,
          height: 32.h,
          decoration: BoxDecoration(
            color: Styles.c_FFFFFF,
            borderRadius: BorderRadius.circular(16.r),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/ai_assistant/widgets/
git commit -m "feat: add AiSuggestionBar widget"
```

---

### Task 9: 创建 AI 设置页

**Files:**
- Create: `lib/pages/ai_settings/ai_settings_binding.dart`
- Create: `lib/pages/ai_settings/ai_settings_logic.dart`
- Create: `lib/pages/ai_settings/ai_settings_view.dart`

- [ ] **Step 1: 创建 Binding**

```dart
import 'package:get/get.dart';

class AiSettingsBinding extends Bindings {
  @override
  void dependencies() {}
}
```

- [ ] **Step 2: 创建 Logic**

```dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import '../../ai_assistant/controllers/ai_assistant_controller.dart';
import '../../ai_assistant/models/llm_config.dart';
import '../../ai_assistant/models/notion_config.dart';

class AiSettingsLogic extends GetxController {
  final aiLogic = Get.find<AIAssistantController>();

  final vendorList = LlmVendorPreset.all;
  final selectedVendorIndex = 0.obs;

  final apiKeyCtrl = TextEditingController();
  final apiBaseUrlCtrl = TextEditingController();
  final modelNameCtrl = TextEditingController();
  final maxTokensCtrl = TextEditingController(text: '2048');
  final temperatureCtrl = TextEditingController(text: '0.7');

  final notionTokenCtrl = TextEditingController();
  final notionRootPageIdCtrl = TextEditingController();

  final isTestingLlm = false.obs;
  final isTestingNotion = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadCurrentConfig();
  }

  void _loadCurrentConfig() {
    final config = aiLogic.llmConfig.value;
    final vendorIndex = vendorList.indexWhere((e) => e.value.vendor == config.vendor);
    selectedVendorIndex.value = vendorIndex >= 0 ? vendorIndex : 0;

    apiKeyCtrl.text = config.apiKey;
    apiBaseUrlCtrl.text = config.apiBaseUrl;
    modelNameCtrl.text = config.modelName;
    maxTokensCtrl.text = config.maxTokens.toString();
    temperatureCtrl.text = config.temperature.toString();

    final nConfig = aiLogic.notionConfig.value;
    notionTokenCtrl.text = nConfig.integrationToken;
    notionRootPageIdCtrl.text = nConfig.rootPageId;
  }

  void onVendorChanged(int index) {
    selectedVendorIndex.value = index;
    final preset = vendorList[index].value;
    apiBaseUrlCtrl.text = preset.apiBaseUrl;
    modelNameCtrl.text = preset.modelName;
  }

  Future<void> saveLlmConfig() async {
    final config = LlmConfig(
      vendor: vendorList[selectedVendorIndex.value].value.vendor,
      apiKey: apiKeyCtrl.text.trim(),
      apiBaseUrl: apiBaseUrlCtrl.text.trim(),
      modelName: modelNameCtrl.text.trim(),
      maxTokens: int.tryParse(maxTokensCtrl.text.trim()) ?? 2048,
      temperature: double.tryParse(temperatureCtrl.text.trim()) ?? 0.7,
    );
    await aiLogic.saveLlmConfig(config);
  }

  Future<void> saveNotionConfig() async {
    final config = NotionConfig(
      integrationToken: notionTokenCtrl.text.trim(),
      rootPageId: notionRootPageIdCtrl.text.trim(),
    );
    await aiLogic.saveNotionConfig(config);
  }

  Future<void> testLlmConnection() async {
    isTestingLlm.value = true;
    await saveLlmConfig();
    await aiLogic.testLlmConnection();
    isTestingLlm.value = false;
  }

  Future<void> testNotionConnection() async {
    isTestingNotion.value = true;
    await saveNotionConfig();
    await aiLogic.testNotionConnection();
    isTestingNotion.value = false;
  }

  @override
  void onClose() {
    apiKeyCtrl.dispose();
    apiBaseUrlCtrl.dispose();
    modelNameCtrl.dispose();
    maxTokensCtrl.dispose();
    temperatureCtrl.dispose();
    notionTokenCtrl.dispose();
    notionRootPageIdCtrl.dispose();
    super.onClose();
  }
}
```

- [ ] **Step 3: 创建 View**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import '../../ai_assistant/controllers/ai_assistant_controller.dart';
import 'ai_settings_logic.dart';

class AiSettingsPage extends StatelessWidget {
  final logic = Get.put(AiSettingsLogic());
  final aiLogic = Get.find<AIAssistantController>();

  AiSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Styles.c_F8F9FA,
      appBar: TitleBar(title: 'AI 助手'),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMasterSwitch(),
            10.verticalSpace,
            Obx(() => Opacity(
                  opacity: aiLogic.aiEnabled.value ? 1.0 : 0.4,
                  child: AbsorbPointer(
                    absorbing: !aiLogic.aiEnabled.value,
                    child: Column(
                      children: [
                        _buildLlmSection(),
                        10.verticalSpace,
                        _buildNotionSection(),
                        10.verticalSpace,
                        _buildAdvancedSection(),
                      ],
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildMasterSwitch() => Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: Styles.c_FFFFFF,
          borderRadius: BorderRadius.circular(6.r),
        ),
        child: Row(
          children: [
            Expanded(child: '启用 AI 助手'.toText..style = Styles.ts_0C1C33_17sp_medium),
            Obx(() => Switch(
                  value: aiLogic.aiEnabled.value,
                  onChanged: (v) => aiLogic.setAIEnabled(v),
                )),
          ],
        ),
      );

  Widget _buildSectionTitle(String title) => Padding(
        padding: EdgeInsets.only(left: 16.w, bottom: 8.h),
        child: title.toText..style = Styles.ts_8E9AB0_14sp,
      );

  Widget _buildLlmSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('大模型配置'),
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16.w),
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            decoration: BoxDecoration(
              color: Styles.c_FFFFFF,
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Column(
              children: [
                _buildDropdownField(
                  label: '供应商',
                  child: Obx(() => DropdownButton<int>(
                        value: logic.selectedVendorIndex.value,
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: logic.vendorList
                            .asMap()
                            .entries
                            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value.key)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) logic.onVendorChanged(v);
                        },
                      )),
                ),
                _buildTextField(label: 'API Key', controller: logic.apiKeyCtrl, obscure: true),
                _buildTextField(label: 'API Base URL', controller: logic.apiBaseUrlCtrl),
                _buildTextField(label: '模型名称', controller: logic.modelNameCtrl),
                _buildTextField(label: 'Max Tokens', controller: logic.maxTokensCtrl, keyboardType: TextInputType.number),
                _buildTextField(label: 'Temperature', controller: logic.temperatureCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                _buildTestButton(
                  isTesting: logic.isTestingLlm,
                  onTest: logic.testLlmConnection,
                  status: aiLogic.llmConnected,
                ),
              ],
            ),
          ),
        ],
      );

  Widget _buildNotionSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Notion 配置'),
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16.w),
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            decoration: BoxDecoration(
              color: Styles.c_FFFFFF,
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Column(
              children: [
                _buildTextField(label: 'Integration Token', controller: logic.notionTokenCtrl, obscure: true),
                _buildTextField(label: '根页面 ID', controller: logic.notionRootPageIdCtrl),
                _buildTestButton(
                  isTesting: logic.isTestingNotion,
                  onTest: logic.testNotionConnection,
                  status: aiLogic.notionConnected,
                ),
                Obx(() => Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                      child: '上次同步: ${aiLogic.lastSyncTime.value.isEmpty ? "未同步" : aiLogic.lastSyncTime.value}'
                          .toText..style = Styles.ts_8E9AB0_12sp,
                    )),
              ],
            ),
          ),
        ],
      );

  Widget _buildAdvancedSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('高级设置'),
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16.w),
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            decoration: BoxDecoration(
              color: Styles.c_FFFFFF,
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Column(
              children: [
                _buildSwitchRow('话题建议', aiLogic.topicEnabled, aiLogic.setTopicEnabled),
                _buildSwitchRow('回复建议', aiLogic.replyEnabled, aiLogic.setReplyEnabled),
                _buildSwitchRow('聊天记录同步', aiLogic.notionSyncEnabled, aiLogic.setNotionSyncEnabled),
              ],
            ),
          ),
        ],
      );

  Widget _buildSwitchRow(String label, RxBool value, Function(bool) onChanged) => Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Row(
          children: [
            Expanded(child: label.toText..style = Styles.ts_0C1C33_17sp),
            Obx(() => Switch(value: value.value, onChanged: onChanged)),
          ],
        ),
      );

  Widget _buildDropdownField({required String label, required Widget child}) => Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Row(
          children: [
            SizedBox(width: 100.w, child: label.toText..style = Styles.ts_8E9AB0_14sp),
            Expanded(child: child),
          ],
        ),
      );

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool obscure = false,
    TextInputType? keyboardType,
  }) =>
      Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Row(
          children: [
            SizedBox(width: 100.w, child: label.toText..style = Styles.ts_8E9AB0_14sp),
            Expanded(
              child: TextField(
                controller: controller,
                obscureText: obscure,
                keyboardType: keyboardType,
                style: Styles.ts_0C1C33_14sp,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(4.r)),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildTestButton({
    required RxBool isTesting,
    required VoidCallback onTest,
    required RxBool status,
  }) =>
      Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Row(
          children: [
            Obx(() => ElevatedButton(
                  onPressed: isTesting.value ? null : onTest,
                  child: isTesting.value
                      ? SizedBox(width: 16.w, height: 16.h, child: const CircularProgressIndicator(strokeWidth: 2))
                      : '测试连接'.toText..style = Styles.ts_FFFFFF_14sp,
                )),
            12.horizontalSpace,
            Obx(() => Icon(
                  status.value ? Icons.check_circle : Icons.cancel,
                  color: status.value ? Colors.green : Colors.grey,
                  size: 20.w,
                )),
          ],
        ),
      );
}
```

- [ ] **Step 4: Commit**

```bash
git add lib/pages/ai_settings/
git commit -m "feat: add AI settings page"
```

---

### Task 10: 注册路由和 InitBinding

**Files:**
- Modify: `lib/routes/app_routes.dart`
- Modify: `lib/routes/app_pages.dart`
- Modify: `lib/app.dart`

- [ ] **Step 1: 在 app_routes.dart 添加路由常量**

在 `AppRoutes` 类中 `resetPassword` 之后添加：

```dart
  static const aiSettings = '/ai_settings';
```

- [ ] **Step 2: 在 app_pages.dart 添加路由页面映射**

先读取 `app_pages.dart` 确认当前结构，然后在 `routes` 列表中添加：

```dart
    GetPage(
      name: AppRoutes.aiSettings,
      page: () => AiSettingsPage(),
      binding: AiSettingsBinding(),
    ),
```

并在文件顶部添加 import：

```dart
import 'package:openim/pages/ai_settings/ai_settings_binding.dart';
import 'package:openim/pages/ai_settings/ai_settings_view.dart';
```

- [ ] **Step 3: 在 app.dart 的 InitBinding 中注册 AIAssistantController**

在 `InitBinding.dependencies()` 方法中，`Get.put<CacheController>(CacheController());` 之后添加：

```dart
    Get.put<AIAssistantController>(AIAssistantController());
```

并在文件顶部添加 import：

```dart
import 'package:openim/ai_assistant/controllers/ai_assistant_controller.dart';
```

- [ ] **Step 4: Commit**

```bash
git add lib/routes/ lib/app.dart
git commit -m "feat: register AI routes and AIAssistantController in InitBinding"
```

---

### Task 11: 集成 MinePage — 添加 AI 助手入口

**Files:**
- Modify: `lib/pages/mine/mine_view.dart`
- Modify: `lib/pages/mine/mine_logic.dart`

- [ ] **Step 1: 在 mine_logic.dart 添加跳转方法**

读取 `mine_logic.dart`，在类中添加方法：

```dart
  void openAiSettings() => AppNavigator.startAiSettings();
```

- [ ] **Step 2: 在 mine_view.dart 添加 AI 助手菜单项**

在"我的信息"菜单项之后、"账号设置"菜单项之前，添加：

```dart
            _buildItemView(
              icon: ImageRes.myInfo,
              label: 'AI 助手',
              onTap: logic.openAiSettings,
            ),
```

注意：此处 `icon` 暂时复用 `ImageRes.myInfo` 图标，后续可替换为 AI 专属图标。

- [ ] **Step 3: Commit**

```bash
git add lib/pages/mine/
git commit -m "feat: add AI assistant entry in MinePage"
```

---

### Task 12: 集成 ChatLogic — AI 建议触发

**Files:**
- Modify: `lib/pages/chat/chat_logic.dart`

- [ ] **Step 1: 在 ChatLogic 中添加 AI 集成代码**

在 `ChatLogic` 类的成员变量区域（`final _pageSize = 40;` 之后）添加：

```dart
  final aiLogic = Get.find<AIAssistantController>();
  Timer? _topicDebounce;
  Timer? _replyDebounce;
```

在 `onInit()` 方法中，`super.onInit()` 调用之前添加：

```dart
    _topicDebounce = Timer(const Duration(milliseconds: 1500), () {
      aiLogic.generateTopicSuggestions(conversationInfo.conversationID);
    });
```

在 `onRecvNewMessage` 回调的 `if (isCurrentChat(message))` 分支内，`_isReceivedMessageWhenSyncing = true;` 之后添加：

```dart
        _replyDebounce?.cancel();
        _replyDebounce = Timer(const Duration(seconds: 2), () {
          aiLogic.generateReplySuggestions(conversationInfo.conversationID, message);
        });
```

在 `onClose()` 方法中，`_debounce?.cancel();` 之后添加：

```dart
    _topicDebounce?.cancel();
    _replyDebounce?.cancel();
    aiLogic.clearSuggestions();
```

在文件顶部添加 import：

```dart
import 'package:openim/ai_assistant/controllers/ai_assistant_controller.dart';
```

- [ ] **Step 2: Commit**

```bash
git add lib/pages/chat/chat_logic.dart
git commit -m "feat: integrate AI suggestion triggers in ChatLogic"
```

---

### Task 13: 集成 ChatPage — 插入 AiSuggestionBar

**Files:**
- Modify: `lib/pages/chat/chat_view.dart`

- [ ] **Step 1: 在 ChatPage 的 build 方法中插入 AiSuggestionBar**

在 `WaterMarkBgView` 的 `bottomView` 参数中，将 `ChatInputBox` 和 `AiSuggestionBar` 组合。修改 `bottomView` 参数：

将原来的：
```dart
bottomView: ChatInputBox(
  forceCloseToolboxSub: logic.forceCloseToolbox,
  controller: logic.inputCtrl,
  focusNode: logic.focusNode,
  isNotInGroup: logic.isInvalidGroup,
  directionalText: logic.directionalText(),
  onCloseDirectional: logic.onClearDirectional,
  onSend: (v) => logic.sendTextMsg(),
  toolbox: ChatToolBox(
    onTapAlbum: logic.onTapAlbum,
    onTapCall: logic.isGroupChat ? null : logic.call,
  ),
  voiceRecordBar: const SizedBox(),
),
```

替换为：
```dart
bottomView: Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    AiSuggestionBar(inputController: logic.inputCtrl),
    ChatInputBox(
      forceCloseToolboxSub: logic.forceCloseToolbox,
      controller: logic.inputCtrl,
      focusNode: logic.focusNode,
      isNotInGroup: logic.isInvalidGroup,
      directionalText: logic.directionalText(),
      onCloseDirectional: logic.onClearDirectional,
      onSend: (v) => logic.sendTextMsg(),
      toolbox: ChatToolBox(
        onTapAlbum: logic.onTapAlbum,
        onTapCall: logic.isGroupChat ? null : logic.call,
      ),
      voiceRecordBar: const SizedBox(),
    ),
  ],
),
```

在文件顶部添加 import：

```dart
import 'package:openim/ai_assistant/widgets/ai_suggestion_bar.dart';
```

- [ ] **Step 2: Commit**

```bash
git add lib/pages/chat/chat_view.dart
git commit -m "feat: integrate AiSuggestionBar into ChatPage"
```

---

### Task 14: 集成消息发送时 Notion 同步入队

**Files:**
- Modify: `lib/pages/chat/chat_logic.dart`

- [ ] **Step 1: 在 _sendMessage 成功回调中添加 Notion 同步入队**

在 `_sendSucceeded` 方法中，`sendStatusSub.addSafely(...)` 之后添加：

```dart
    aiLogic.enqueueMessageForSync(
      conversationID: conversationInfo.conversationID,
      clientMsgID: newMsg.clientMsgID ?? '',
      senderNickname: OpenIM.iMManager.userInfo.nickname ?? '',
      content: newMsg.textElem?.content ?? '',
      sendTime: newMsg.sendTime ?? DateTime.now().millisecondsSinceEpoch,
    );
```

同样在 `onRecvNewMessage` 回调中，`messageList.add(message)` 之后添加：

```dart
        aiLogic.enqueueMessageForSync(
          conversationID: conversationInfo.conversationID,
          clientMsgID: message.clientMsgID ?? '',
          senderNickname: message.senderNickname ?? '',
          content: message.textElem?.content ?? '',
          sendTime: message.sendTime ?? DateTime.now().millisecondsSinceEpoch,
        );
```

- [ ] **Step 2: Commit**

```bash
git add lib/pages/chat/chat_logic.dart
git commit -m "feat: enqueue messages for Notion sync on send and receive"
```

---

### Task 15: 添加 AppNavigator 跳转方法

**Files:**
- Modify: `lib/routes/app_navigator.dart`

- [ ] **Step 1: 在 AppNavigator 类中添加 AI 设置页跳转方法**

读取 `app_navigator.dart` 确认现有方法模式，然后添加：

```dart
  static startAiSettings() => Get.toNamed(AppRoutes.aiSettings);
```

- [ ] **Step 2: Commit**

```bash
git add lib/routes/app_navigator.dart
git commit -m "feat: add AI settings navigation method"
```

---

### Task 16: 验证编译通过

**Files:**
- None (verification only)

- [ ] **Step 1: 运行 flutter analyze 检查静态分析**

Run: `cd /workspace && flutter analyze`
Expected: 无 error（warning 可接受）

- [ ] **Step 2: 修复任何编译错误（如有）**

根据 `flutter analyze` 输出修复问题。

- [ ] **Step 3: Commit 修复（如有）**

```bash
git add -A
git commit -m "fix: resolve compilation errors"
```
