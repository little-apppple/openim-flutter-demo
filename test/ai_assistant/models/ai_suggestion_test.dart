import 'package:flutter_test/flutter_test.dart';
import 'package:openim/ai_assistant/models/ai_suggestion.dart';

void main() {
  group('AiSuggestionType', () {
    test('has topic and reply values', () {
      expect(AiSuggestionType.values, contains(AiSuggestionType.topic));
      expect(AiSuggestionType.values, contains(AiSuggestionType.reply));
      expect(AiSuggestionType.values.length, 2);
    });
  });

  group('AiSuggestion', () {
    test('creates topic suggestion with correct type and text', () {
      const suggestion = AiSuggestion(
        type: AiSuggestionType.topic,
        text: '聊聊最近的电影',
      );

      expect(suggestion.type, AiSuggestionType.topic);
      expect(suggestion.text, '聊聊最近的电影');
    });

    test('creates reply suggestion with correct type and text', () {
      const suggestion = AiSuggestion(
        type: AiSuggestionType.reply,
        text: '好的，没问题！',
      );

      expect(suggestion.type, AiSuggestionType.reply);
      expect(suggestion.text, '好的，没问题！');
    });

    test('equal suggestions have same hashCode', () {
      const suggestion1 = AiSuggestion(type: AiSuggestionType.topic, text: 'hello');
      const suggestion2 = AiSuggestion(type: AiSuggestionType.topic, text: 'hello');

      expect(suggestion1, equals(suggestion2));
      expect(suggestion1.hashCode, equals(suggestion2.hashCode));
    });

    test('suggestions with different types are not equal', () {
      const topicSuggestion = AiSuggestion(type: AiSuggestionType.topic, text: 'hello');
      const replySuggestion = AiSuggestion(type: AiSuggestionType.reply, text: 'hello');

      expect(topicSuggestion, isNot(equals(replySuggestion)));
    });

    test('suggestions with different text are not equal', () {
      const suggestion1 = AiSuggestion(type: AiSuggestionType.topic, text: 'hello');
      const suggestion2 = AiSuggestion(type: AiSuggestionType.topic, text: 'world');

      expect(suggestion1, isNot(equals(suggestion2)));
    });

    test('is not equal to non-AiSuggestion object', () {
      const suggestion = AiSuggestion(type: AiSuggestionType.topic, text: 'hello');

      expect(suggestion == 'hello', isFalse);
      expect(suggestion == 42, isFalse);
    });

    test('is equal to itself', () {
      const suggestion = AiSuggestion(type: AiSuggestionType.topic, text: 'hello');

      expect(suggestion == suggestion, isTrue);
    });
  });
}
