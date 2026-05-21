enum AiSuggestionType { topic, reply }

class AiSuggestion {
  final AiSuggestionType type;
  final String text;

  const AiSuggestion({
    required this.type,
    required this.text,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiSuggestion && type == other.type && text == other.text;

  @override
  int get hashCode => Object.hash(type, text);
}
