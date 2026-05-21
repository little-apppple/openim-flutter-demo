import 'package:flutter_test/flutter_test.dart';
import 'package:openim/ai_assistant/models/memory_context.dart';

void main() {
  group('MemoryContext', () {
    test('default values are empty strings', () {
      const context = MemoryContext(conversationID: 'conv-1');

      expect(context.conversationID, 'conv-1');
      expect(context.recentMessages, '');
      expect(context.contactProfile, '');
      expect(context.notionLongTermMemory, '');
    });

    group('buildTopicPrompt', () {
      test('contains base instruction text', () {
        const context = MemoryContext(conversationID: 'conv-1');

        final prompt = context.buildTopicPrompt();

        expect(prompt, contains('社交助手'));
        expect(prompt, contains('话题建议'));
        expect(prompt, contains('JSON数组'));
      });

      test('excludes contact info section when contactProfile is empty', () {
        const context = MemoryContext(conversationID: 'conv-1');

        final prompt = context.buildTopicPrompt();

        expect(prompt, isNot(contains('联系人信息')));
      });

      test('includes contact info section when contactProfile is set', () {
        const context = MemoryContext(
          conversationID: 'conv-1',
          contactProfile: '好友备注: 小明',
        );

        final prompt = context.buildTopicPrompt();

        expect(prompt, contains('联系人信息'));
        expect(prompt, contains('好友备注: 小明'));
      });

      test('excludes Notion memory section when notionLongTermMemory is empty', () {
        const context = MemoryContext(conversationID: 'conv-1');

        final prompt = context.buildTopicPrompt();

        expect(prompt, isNot(contains('长期记忆')));
      });

      test('includes Notion memory section when notionLongTermMemory is set', () {
        const context = MemoryContext(
          conversationID: 'conv-1',
          notionLongTermMemory: '小明喜欢打篮球',
        );

        final prompt = context.buildTopicPrompt();

        expect(prompt, contains('长期记忆'));
        expect(prompt, contains('小明喜欢打篮球'));
      });

      test('excludes recent messages section when recentMessages is empty', () {
        const context = MemoryContext(conversationID: 'conv-1');

        final prompt = context.buildTopicPrompt();

        expect(prompt, isNot(contains('近期聊天记录')));
      });

      test('includes recent messages section when recentMessages is set', () {
        const context = MemoryContext(
          conversationID: 'conv-1',
          recentMessages: '小明: 你好\n我: 你好呀',
        );

        final prompt = context.buildTopicPrompt();

        expect(prompt, contains('近期聊天记录'));
        expect(prompt, contains('小明: 你好'));
      });

      test('includes all sections when all fields are set', () {
        const context = MemoryContext(
          conversationID: 'conv-1',
          contactProfile: '好友备注: 小明',
          notionLongTermMemory: '小明喜欢打篮球',
          recentMessages: '小明: 你好',
        );

        final prompt = context.buildTopicPrompt();

        expect(prompt, contains('联系人信息'));
        expect(prompt, contains('长期记忆'));
        expect(prompt, contains('近期聊天记录'));
      });
    });

    group('buildReplyPrompt', () {
      test('contains base instruction text', () {
        const context = MemoryContext(conversationID: 'conv-1');

        final prompt = context.buildReplyPrompt('你好');

        expect(prompt, contains('社交助手'));
        expect(prompt, contains('回复'));
        expect(prompt, contains('JSON数组'));
      });

      test('includes latest message', () {
        const context = MemoryContext(conversationID: 'conv-1');

        final prompt = context.buildReplyPrompt('今天天气怎么样？');

        expect(prompt, contains('最新收到的消息'));
        expect(prompt, contains('今天天气怎么样？'));
      });

      test('includes contact info when set', () {
        const context = MemoryContext(
          conversationID: 'conv-1',
          contactProfile: '好友备注: 小红',
        );

        final prompt = context.buildReplyPrompt('你好');

        expect(prompt, contains('联系人信息'));
        expect(prompt, contains('好友备注: 小红'));
      });

      test('includes Notion memory when set', () {
        const context = MemoryContext(
          conversationID: 'conv-1',
          notionLongTermMemory: '小红在学钢琴',
        );

        final prompt = context.buildReplyPrompt('你好');

        expect(prompt, contains('长期记忆'));
        expect(prompt, contains('小红在学钢琴'));
      });

      test('includes recent messages when set', () {
        const context = MemoryContext(
          conversationID: 'conv-1',
          recentMessages: '小红: 在吗？',
        );

        final prompt = context.buildReplyPrompt('你好');

        expect(prompt, contains('近期聊天记录'));
        expect(prompt, contains('小红: 在吗？'));
      });

      test('topic and reply prompts have different instruction text', () {
        const context = MemoryContext(conversationID: 'conv-1');

        final topicPrompt = context.buildTopicPrompt();
        final replyPrompt = context.buildReplyPrompt('你好');

        expect(topicPrompt, contains('话题'));
        expect(replyPrompt, contains('回复'));
        expect(topicPrompt, isNot(contains('最新收到的消息')));
        expect(replyPrompt, contains('最新收到的消息'));
      });
    });
  });
}
