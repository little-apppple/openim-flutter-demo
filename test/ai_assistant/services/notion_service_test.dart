import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openim/ai_assistant/models/notion_config.dart';
import 'package:openim/ai_assistant/services/notion_service.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio mockDio;
  late NotionService service;

  const testConfig = NotionConfig(
    integrationToken: 'secret-test-token',
    rootPageId: 'root-page-123',
  );

  setUp(() {
    mockDio = MockDio();
    service = NotionService(dio: mockDio);
  });

  Response _successResponse(dynamic data) {
    return Response(
      data: data,
      statusCode: 200,
      requestOptions: RequestOptions(path: ''),
    );
  }

  group('NotionService', () {
    group('testConnection', () {
      test('returns true when root page is accessible', () async {
        when(() => mockDio.get(
              any(),
              options: any(named: 'options'),
            )).thenAnswer((_) async => _successResponse({}));

        final result = await service.testConnection(testConfig);

        expect(result, isTrue);
      });

      test('returns false when API call fails', () async {
        when(() => mockDio.get(
              any(),
              options: any(named: 'options'),
            )).thenThrow(DioException(
          requestOptions: RequestOptions(path: ''),
          response: Response(
            statusCode: 401,
            requestOptions: RequestOptions(path: ''),
          ),
        ));

        final result = await service.testConnection(testConfig);

        expect(result, isFalse);
      });
    });

    group('findChildPageByName', () {
      test('returns page ID when child page is found under root', () async {
        final responseData = {
          'results': [
            {
              'id': 'child-page-456',
              'parent': {'page_id': 'root-page-123'},
            },
          ],
        };

        when(() => mockDio.post(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
            )).thenAnswer((_) async => _successResponse(responseData));

        final result = await service.findChildPageByName(
          config: testConfig,
          pageName: 'Test Page',
        );

        expect(result, 'child-page-456');
      });

      test('returns null when no child page matches root parent', () async {
        final responseData = {
          'results': [
            {
              'id': 'other-page-789',
              'parent': {'page_id': 'different-root'},
            },
          ],
        };

        when(() => mockDio.post(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
            )).thenAnswer((_) async => _successResponse(responseData));

        final result = await service.findChildPageByName(
          config: testConfig,
          pageName: 'Test Page',
        );

        expect(result, isNull);
      });

      test('returns null when results are empty', () async {
        final responseData = {'results': <dynamic>[]};

        when(() => mockDio.post(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
            )).thenAnswer((_) async => _successResponse(responseData));

        final result = await service.findChildPageByName(
          config: testConfig,
          pageName: 'Test Page',
        );

        expect(result, isNull);
      });

      test('returns null on API error', () async {
        when(() => mockDio.post(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
            )).thenThrow(DioException(requestOptions: RequestOptions(path: '')));

        final result = await service.findChildPageByName(
          config: testConfig,
          pageName: 'Test Page',
        );

        expect(result, isNull);
      });
    });

    group('createChildPage', () {
      test('returns created page ID', () async {
        final responseData = {'id': 'new-page-999'};

        when(() => mockDio.post(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
            )).thenAnswer((_) async => _successResponse(responseData));

        final result = await service.createChildPage(
          config: testConfig,
          pageName: 'New Page',
        );

        expect(result, 'new-page-999');
      });

      test('sends correct parent and title in request body', () async {
        when(() => mockDio.post(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
            )).thenAnswer((_) async => _successResponse({'id': 'new-page'}));

        await service.createChildPage(
          config: testConfig,
          pageName: 'Chat with Alice',
        );

        final captured = verify(() => mockDio.post(
              any(),
              data: captureAny(named: 'data'),
              options: any(named: 'options'),
            )).captured;

        final body = jsonDecode(captured.first as String) as Map<String, dynamic>;
        expect(body['parent'], {'page_id': 'root-page-123'});
        final titleBlocks = (body['properties']['title'] as List).first as Map;
        expect(titleBlocks['text']['content'], 'Chat with Alice');
      });
    });

    group('getOrCreateChildPage', () {
      test('returns existing page ID when found', () async {
        final searchResponse = {
          'results': [
            {
              'id': 'existing-page',
              'parent': {'page_id': 'root-page-123'},
            },
          ],
        };

        when(() => mockDio.post(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
            )).thenAnswer((_) async => _successResponse(searchResponse));

        final result = await service.getOrCreateChildPage(
          config: testConfig,
          pageName: 'Existing Page',
        );

        expect(result, 'existing-page');
      });

      test('creates new page when not found', () async {
        final searchResponse = {'results': <dynamic>[]};
        final createResponse = {'id': 'brand-new-page'};

        when(() => mockDio.post(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
            )).thenAnswer((invocation) async {
              final data = invocation.namedArguments[#data] as String?;
              final decoded = data != null ? jsonDecode(data) : null;
              if (decoded is Map && decoded.containsKey('query')) {
                return _successResponse(searchResponse);
              }
              return _successResponse(createResponse);
            });

        final result = await service.getOrCreateChildPage(
          config: testConfig,
          pageName: 'New Page',
        );

        expect(result, 'brand-new-page');
      });
    });

    group('appendMessagesToPage', () {
      test('sends heading and paragraph blocks', () async {
        when(() => mockDio.patch(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
            )).thenAnswer((_) async => _successResponse({}));

        await service.appendMessagesToPage(
          config: testConfig,
          pageId: 'page-123',
          dateHeader: '2026-05-19',
          messageLines: ['[14:30] Alice: 你好', '[14:31] Bob: 你好呀'],
        );

        final captured = verify(() => mockDio.patch(
              any(),
              data: captureAny(named: 'data'),
              options: any(named: 'options'),
            )).captured;

        final body = jsonDecode(captured.first as String) as Map<String, dynamic>;
        final children = body['children'] as List;

        expect(children.length, 3);
        expect(children[0]['type'], 'heading_2');
        expect(children[1]['type'], 'paragraph');
        expect(children[2]['type'], 'paragraph');
      });
    });

    group('readPageContent', () {
      test('extracts plain text from page blocks', () async {
        final responseData = {
          'results': [
            {
              'type': 'heading_2',
              'heading_2': {
                'rich_text': [
                  {'plain_text': '2026-05-19'},
                ],
              },
            },
            {
              'type': 'paragraph',
              'paragraph': {
                'rich_text': [
                  {'plain_text': '[14:30] Alice: 你好'},
                ],
              },
            },
          ],
        };

        when(() => mockDio.get(
              any(),
              options: any(named: 'options'),
            )).thenAnswer((_) async => _successResponse(responseData));

        final result = await service.readPageContent(
          config: testConfig,
          pageId: 'page-123',
        );

        expect(result, contains('2026-05-19'));
        expect(result, contains('[14:30] Alice: 你好'));
      });

      test('returns empty string on API error', () async {
        when(() => mockDio.get(
              any(),
              options: any(named: 'options'),
            )).thenThrow(DioException(requestOptions: RequestOptions(path: '')));

        final result = await service.readPageContent(
          config: testConfig,
          pageId: 'page-123',
        );

        expect(result, '');
      });

      test('handles blocks without rich_text gracefully', () async {
        final responseData = {
          'results': [
            {
              'type': 'unsupported',
              'unsupported': {},
            },
          ],
        };

        when(() => mockDio.get(
              any(),
              options: any(named: 'options'),
            )).thenAnswer((_) async => _successResponse(responseData));

        final result = await service.readPageContent(
          config: testConfig,
          pageId: 'page-123',
        );

        expect(result, isNotEmpty);
      });
    });

    group('withRetry', () {
      test('returns result on first successful call', () async {
        final result = await service.withRetry(() async => 'success');

        expect(result, 'success');
      });

      test('retries on DioException and succeeds on second attempt', () async {
        var attemptCount = 0;

        final result = await service.withRetry(() async {
          attemptCount++;
          if (attemptCount == 1) {
            throw DioException(requestOptions: RequestOptions(path: ''));
          }
          return 'recovered';
        }, maxRetries: 3);

        expect(result, 'recovered');
        expect(attemptCount, 2);
      });

      test('throws after max retries exceeded', () async {
        expect(
          () => service.withRetry(
            () async => throw DioException(requestOptions: RequestOptions(path: '')),
            maxRetries: 1,
          ),
          throwsA(isA<DioException>()),
        );
      });

      test('handles rate limiting with 429 status code', () async {
        var attemptCount = 0;

        final result = await service.withRetry(() async {
          attemptCount++;
          if (attemptCount == 1) {
            throw DioException(
              requestOptions: RequestOptions(path: ''),
              response: Response(
                statusCode: 429,
                requestOptions: RequestOptions(path: ''),
              ),
            );
          }
          return 'ok';
        }, maxRetries: 3);

        expect(result, 'ok');
        expect(attemptCount, 2);
      });

      test('rethrows non-DioException after max retries', () async {
        expect(
          () => service.withRetry(
            () async => throw Exception('unexpected'),
            maxRetries: 1,
          ),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('request headers', () {
      test('sends correct Notion headers', () async {
        when(() => mockDio.get(
              any(),
              options: any(named: 'options'),
            )).thenAnswer((_) async => _successResponse({}));

        await service.testConnection(testConfig);

        final captured = verify(() => mockDio.get(
              any(),
              options: captureAny(named: 'options'),
            )).captured;

        final options = captured.first as Options;
        expect(options.headers?['Authorization'], 'Bearer secret-test-token');
        expect(options.headers?['Notion-Version'], '2022-06-28');
        expect(options.headers?['Content-Type'], 'application/json');
      });
    });
  });
}
