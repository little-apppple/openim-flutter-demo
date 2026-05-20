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

    test('different suggestions with same values are equal when const', () {
      const suggestion1 = AiSuggestion(type: AiSuggestionType.topic, text: 'hello');
      const suggestion2 = AiSuggestion(type: AiSuggestionType.topic, text: 'hello');

      expect(suggestion1.type, suggestion2.type);
      expect(suggestion1.text, suggestion2.text);
    });

    test('suggestions with different types are not equal', () {
      const topicSuggestion = AiSuggestion(type: AiSuggestionType.topic, text: 'hello');
      const replySuggestion = AiSuggestion(type: AiSuggestionType.reply, text: 'hello');

      expect(topicSuggestion.type == replySuggestion.type, isFalse);
    });
  });
}
