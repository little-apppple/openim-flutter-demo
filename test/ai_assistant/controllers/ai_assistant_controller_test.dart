import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openim/ai_assistant/controllers/ai_assistant_controller.dart';
import 'package:openim/ai_assistant/models/ai_suggestion.dart';
import 'package:openim/ai_assistant/models/llm_config.dart';
import 'package:openim/ai_assistant/models/memory_context.dart';
import 'package:openim/ai_assistant/models/notion_config.dart';
import 'package:openim/ai_assistant/services/llm_service.dart';
import 'package:openim/ai_assistant/services/notion_service.dart';

class MockLLMService extends Mock implements LLMService {}

class MockNotionService extends Mock implements NotionService {}

void main() {
  late MockLLMService mockLlmService;
  late MockNotionService mockNotionService;
  late AIAssistantController controller;

  setUpAll(() {
    registerFallbackValue(const LlmConfig());
    registerFallbackValue(const NotionConfig());
    registerFallbackValue(const MemoryContext(conversationID: ''));
  });

  setUp(() {
    mockLlmService = MockLLMService();
    mockNotionService = MockNotionService();
    controller = AIAssistantController(
      llmService: mockLlmService,
      notionService: mockNotionService,
      skipLoadConfig: true,
    );
    controller.onInit();
  });

  tearDown(() {
    controller.onClose();
  });

  group('AIAssistantController', () {
    group('initial state', () {
      test('aiEnabled defaults to false', () {
        expect(controller.aiEnabled.value, isFalse);
      });

      test('llmConfig defaults to empty LlmConfig', () {
        expect(controller.llmConfig.value.apiKey, '');
        expect(controller.llmConfig.value.isConfigured, isFalse);
      });

      test('notionConfig defaults to empty NotionConfig', () {
        expect(controller.notionConfig.value.integrationToken, '');
        expect(controller.notionConfig.value.isConfigured, isFalse);
      });

      test('topicEnabled defaults to true', () {
        expect(controller.topicEnabled.value, isTrue);
      });

      test('replyEnabled defaults to true', () {
        expect(controller.replyEnabled.value, isTrue);
      });

      test('notionSyncEnabled defaults to true', () {
        expect(controller.notionSyncEnabled.value, isTrue);
      });

      test('suggestions defaults to empty', () {
        expect(controller.suggestions, isEmpty);
      });

      test('isLoadingSuggestions defaults to false', () {
        expect(controller.isLoadingSuggestions.value, isFalse);
      });

      test('suggestionError defaults to empty', () {
        expect(controller.suggestionError.value, '');
      });

      test('llmConnected defaults to false', () {
        expect(controller.llmConnected.value, isFalse);
      });

      test('notionConnected defaults to false', () {
        expect(controller.notionConnected.value, isFalse);
      });
    });

    group('setAIEnabled', () {
      test('does not enable AI when LLM is not configured', () {
        controller.llmConfig.value = const LlmConfig();

        controller.setAIEnabled(true);

        expect(controller.aiEnabled.value, isFalse);
      });

      test('enables AI when LLM is configured', () {
        controller.llmConfig.value = const LlmConfig(
          apiKey: 'sk-test',
          apiBaseUrl: 'https://api.openai.com/v1',
          modelName: 'gpt-4o-mini',
        );

        controller.setAIEnabled(true);

        expect(controller.aiEnabled.value, isTrue);
      });

      test('disables AI and clears suggestions and error', () {
        controller.llmConfig.value = const LlmConfig(
          apiKey: 'sk-test',
          apiBaseUrl: 'https://api.openai.com/v1',
          modelName: 'gpt-4o-mini',
        );
        controller.setAIEnabled(true);
        controller.suggestions.add(
          const AiSuggestion(type: AiSuggestionType.topic, text: 'test'),
        );
        controller.isLoadingSuggestions.value = true;
        controller.suggestionError.value = 'some error';

        controller.setAIEnabled(false);

        expect(controller.aiEnabled.value, isFalse);
        expect(controller.suggestions, isEmpty);
        expect(controller.isLoadingSuggestions.value, isFalse);
        expect(controller.suggestionError.value, '');
      });
    });

    group('setTopicEnabled', () {
      test('toggles topic suggestions on', () {
        controller.setTopicEnabled(true);
        expect(controller.topicEnabled.value, isTrue);
      });

      test('toggles topic suggestions off', () {
        controller.setTopicEnabled(false);
        expect(controller.topicEnabled.value, isFalse);
      });
    });

    group('setReplyEnabled', () {
      test('toggles reply suggestions on', () {
        controller.setReplyEnabled(true);
        expect(controller.replyEnabled.value, isTrue);
      });

      test('toggles reply suggestions off', () {
        controller.setReplyEnabled(false);
        expect(controller.replyEnabled.value, isFalse);
      });
    });

    group('setNotionSyncEnabled', () {
      test('toggles Notion sync on', () {
        controller.setNotionSyncEnabled(true);
        expect(controller.notionSyncEnabled.value, isTrue);
      });

      test('toggles Notion sync off', () {
        controller.setNotionSyncEnabled(false);
        expect(controller.notionSyncEnabled.value, isFalse);
      });
    });

    group('clearSuggestions', () {
      test('clears suggestions list, loading state and error', () {
        controller.suggestions.addAll([
          const AiSuggestion(type: AiSuggestionType.topic, text: 'topic1'),
          const AiSuggestion(type: AiSuggestionType.reply, text: 'reply1'),
        ]);
        controller.isLoadingSuggestions.value = true;
        controller.suggestionError.value = 'some error';

        controller.clearSuggestions();

        expect(controller.suggestions, isEmpty);
        expect(controller.isLoadingSuggestions.value, isFalse);
        expect(controller.suggestionError.value, '');
      });
    });

    group('testLlmConnection', () {
      test('returns false when LLM is not configured', () async {
        controller.llmConfig.value = const LlmConfig();

        final result = await controller.testLlmConnection();

        expect(result, isFalse);
        verifyNever(() => mockLlmService.testConnection(any()));
      });

      test('returns true and updates llmConnected on success', () async {
        controller.llmConfig.value = const LlmConfig(
          apiKey: 'sk-test',
          apiBaseUrl: 'https://api.openai.com/v1',
          modelName: 'gpt-4o-mini',
        );
        when(() => mockLlmService.testConnection(any())).thenAnswer((_) async => true);

        final result = await controller.testLlmConnection();

        expect(result, isTrue);
        expect(controller.llmConnected.value, isTrue);
      });

      test('returns false and updates llmConnected on failure', () async {
        controller.llmConfig.value = const LlmConfig(
          apiKey: 'sk-test',
          apiBaseUrl: 'https://api.openai.com/v1',
          modelName: 'gpt-4o-mini',
        );
        when(() => mockLlmService.testConnection(any())).thenAnswer((_) async => false);

        final result = await controller.testLlmConnection();

        expect(result, isFalse);
        expect(controller.llmConnected.value, isFalse);
      });
    });

    group('testNotionConnection', () {
      test('returns false when Notion is not configured', () async {
        controller.notionConfig.value = const NotionConfig();

        final result = await controller.testNotionConnection();

        expect(result, isFalse);
        verifyNever(() => mockNotionService.testConnection(any()));
      });

      test('returns true and updates notionConnected on success', () async {
        controller.notionConfig.value = const NotionConfig(
          integrationToken: 'token',
          rootPageId: 'page-123',
        );
        when(() => mockNotionService.testConnection(any())).thenAnswer((_) async => true);

        final result = await controller.testNotionConnection();

        expect(result, isTrue);
        expect(controller.notionConnected.value, isTrue);
      });

      test('returns false and updates notionConnected on failure', () async {
        controller.notionConfig.value = const NotionConfig(
          integrationToken: 'token',
          rootPageId: 'page-123',
        );
        when(() => mockNotionService.testConnection(any())).thenAnswer((_) async => false);

        final result = await controller.testNotionConnection();

        expect(result, isFalse);
        expect(controller.notionConnected.value, isFalse);
      });
    });

    group('enqueueMessageForSync', () {
      test('does not enqueue when Notion sync is not possible', () {
        controller.enqueueMessageForSync(
          conversationID: 'conv-1',
          clientMsgID: 'msg-1',
          senderNickname: 'Alice',
          content: 'Hello',
          sendTime: 1000,
        );

        expect(controller.syncQueueLength, 0);
      });

      test('enqueues message when Notion sync is enabled and configured', () {
        controller.aiEnabled.value = true;
        controller.notionSyncEnabled.value = true;
        controller.notionConfig.value = const NotionConfig(
          integrationToken: 'token',
          rootPageId: 'page-123',
        );

        controller.enqueueMessageForSync(
          conversationID: 'conv-1',
          clientMsgID: 'msg-1',
          senderNickname: 'Alice',
          content: 'Hello',
          sendTime: 1000,
        );

        expect(controller.syncQueueLength, 1);
      });

      test('does not enqueue duplicate messages', () {
        controller.aiEnabled.value = true;
        controller.notionSyncEnabled.value = true;
        controller.notionConfig.value = const NotionConfig(
          integrationToken: 'token',
          rootPageId: 'page-123',
        );

        controller.enqueueMessageForSync(
          conversationID: 'conv-1',
          clientMsgID: 'msg-1',
          senderNickname: 'Alice',
          content: 'Hello',
          sendTime: 1000,
        );
        controller.enqueueMessageForSync(
          conversationID: 'conv-1',
          clientMsgID: 'msg-1',
          senderNickname: 'Alice',
          content: 'Hello',
          sendTime: 1000,
        );

        expect(controller.syncQueueLength, 1);
      });

      test('does not enqueue messages with empty content', () {
        controller.aiEnabled.value = true;
        controller.notionSyncEnabled.value = true;
        controller.notionConfig.value = const NotionConfig(
          integrationToken: 'token',
          rootPageId: 'page-123',
        );

        controller.enqueueMessageForSync(
          conversationID: 'conv-1',
          clientMsgID: 'msg-1',
          senderNickname: 'Alice',
          content: '',
          sendTime: 1000,
        );

        expect(controller.syncQueueLength, 0);
      });

      test('does not enqueue messages with whitespace-only content', () {
        controller.aiEnabled.value = true;
        controller.notionSyncEnabled.value = true;
        controller.notionConfig.value = const NotionConfig(
          integrationToken: 'token',
          rootPageId: 'page-123',
        );

        controller.enqueueMessageForSync(
          conversationID: 'conv-1',
          clientMsgID: 'msg-1',
          senderNickname: 'Alice',
          content: '   ',
          sendTime: 1000,
        );

        expect(controller.syncQueueLength, 0);
      });

      test('enqueues different messages separately', () {
        controller.aiEnabled.value = true;
        controller.notionSyncEnabled.value = true;
        controller.notionConfig.value = const NotionConfig(
          integrationToken: 'token',
          rootPageId: 'page-123',
        );

        controller.enqueueMessageForSync(
          conversationID: 'conv-1',
          clientMsgID: 'msg-1',
          senderNickname: 'Alice',
          content: 'Hello',
          sendTime: 1000,
        );
        controller.enqueueMessageForSync(
          conversationID: 'conv-1',
          clientMsgID: 'msg-2',
          senderNickname: 'Bob',
          content: 'Hi',
          sendTime: 2000,
        );

        expect(controller.syncQueueLength, 2);
      });
    });

    group('clearNotionMemoryCache', () {
      test('clears cached memory for specified conversation', () {
        controller.aiEnabled.value = true;
        controller.notionSyncEnabled.value = true;
        controller.notionConfig.value = const NotionConfig(
          integrationToken: 'token',
          rootPageId: 'page-123',
        );

        controller.preloadNotionMemory('conv-1', 'cached content for conv-1');
        controller.preloadNotionMemory('conv-2', 'cached content for conv-2');

        controller.clearNotionMemoryCache('conv-1');

        expect(controller.getNotionMemory('conv-1'), isNull);
        expect(controller.getNotionMemory('conv-2'), 'cached content for conv-2');
      });
    });

    group('feature gating', () {
      test('does not generate suggestions when AI is disabled', () async {
        controller.aiEnabled.value = false;
        controller.llmConfig.value = const LlmConfig(
          apiKey: 'sk-test',
          apiBaseUrl: 'https://api.openai.com/v1',
          modelName: 'gpt-4o-mini',
        );

        controller.clearSuggestions();

        expect(controller.suggestions, isEmpty);
        verifyNever(() => mockLlmService.generateTopicSuggestions(
              config: any(named: 'config'),
              context: any(named: 'context'),
            ));
      });

      test('does not generate suggestions when LLM is not configured', () async {
        controller.aiEnabled.value = true;
        controller.llmConfig.value = const LlmConfig();

        controller.clearSuggestions();

        expect(controller.suggestions, isEmpty);
      });
    });

    group('saveLlmConfig', () {
      test('updates llmConfig value', () async {
        final newConfig = LlmConfig(
          vendor: 'qwen',
          apiKey: 'new-key',
          apiBaseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
          modelName: 'qwen-plus',
        );

        await controller.saveLlmConfig(newConfig);

        expect(controller.llmConfig.value.vendor, 'qwen');
        expect(controller.llmConfig.value.apiKey, 'new-key');
        expect(controller.llmConfig.value.apiBaseUrl, 'https://dashscope.aliyuncs.com/compatible-mode/v1');
        expect(controller.llmConfig.value.modelName, 'qwen-plus');
      });
    });

    group('saveNotionConfig', () {
      test('updates notionConfig value', () async {
        final newConfig = NotionConfig(
          integrationToken: 'new-token',
          rootPageId: 'new-page',
        );

        await controller.saveNotionConfig(newConfig);

        expect(controller.notionConfig.value.integrationToken, 'new-token');
        expect(controller.notionConfig.value.rootPageId, 'new-page');
      });
    });
  });
}
