enum AiSuggestionType { topic, reply }

class AiSuggestion {
  final AiSuggestionType type;
  final String text;

  const AiSuggestion({
    required this.type,
    required this.text,
  });
}
