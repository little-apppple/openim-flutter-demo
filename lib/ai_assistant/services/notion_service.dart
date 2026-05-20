import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:openim_common/openim_common.dart';
import '../models/notion_config.dart';

class NotionService {
  static const _baseUrl = 'https://api.notion.com/v1';
  static const _notionVersion = '2022-06-28';

  final Dio _dio;

  NotionService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
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

  Future<T> withRetry<T>(Future<T> Function() fn, {int maxRetries = 5}) async {
    const baseDelays = [1, 2, 5, 10, 30];
    for (var i = 0; i <= maxRetries; i++) {
      try {
        return await fn();
      } on DioException catch (e) {
        if (e.response?.statusCode == 429) {
          if (i >= maxRetries) rethrow;
          final retryAfter = int.tryParse(e.response?.headers.value('retry-after') ?? '');
          final delay = retryAfter != null 
              ? Duration(seconds: retryAfter)
              : Duration(seconds: baseDelays[i < baseDelays.length ? i : baseDelays.length - 1]);
          Logger.print('Notion rate limited, retrying ${i + 1}/$maxRetries after ${delay.inSeconds}s');
          await Future.delayed(delay);
        } else if (i >= maxRetries) {
          rethrow;
        } else {
          Logger.print('Notion retry ${i + 1}/$maxRetries after ${baseDelays[i]}s');
          await Future.delayed(Duration(seconds: baseDelays[i < baseDelays.length ? i : baseDelays.length - 1]));
        }
      } catch (e) {
        if (i >= maxRetries) rethrow;
        Logger.print('Notion retry ${i + 1}/$maxRetries after ${baseDelays[i < baseDelays.length ? i : baseDelays.length - 1]}s');
        await Future.delayed(Duration(seconds: baseDelays[i < baseDelays.length ? i : baseDelays.length - 1]));
      }
    }
    throw Exception('Max retries exceeded');
  }
}
