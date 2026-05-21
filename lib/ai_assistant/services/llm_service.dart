import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:openim_common/openim_common.dart';
import '../models/llm_config.dart';
import '../models/memory_context.dart';

class LLMService {
  final Dio _dio;

  LLMService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
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
