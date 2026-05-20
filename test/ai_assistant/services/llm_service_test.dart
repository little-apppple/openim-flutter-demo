import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openim/ai_assistant/models/llm_config.dart';
import 'package:openim/ai_assistant/models/memory_context.dart';
import 'package:openim/ai_assistant/services/llm_service.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio mockDio;
  late LLMService service;

  const testConfig = LlmConfig(
    vendor: 'openai',
    apiKey: 'sk-test-key',
    apiBaseUrl: 'https://api.openai.com/v1',
    modelName: 'gpt-4o-mini',
  );

  const testContext = MemoryContext(
    conversationID: 'conv-1',
    recentMessages: 'Alice: 你好\nBob: 你好呀',
    contactProfile: '好友备注: Alice',
  );

  setUp(() {
    mockDio = MockDio();
    service = LLMService(dio: mockDio);
  });

  Response _successResponse(Map<String, dynamic> data) {
    return Response(
      data: data,
      statusCode: 200,
      requestOptions: RequestOptions(path: ''),
    );
  }

  Response _errorResponse(int statusCode) {
    return Response(
      statusCode: statusCode,
      requestOptions: RequestOptions(path: ''),
    );
  }

  group('LLMService', () {
    group('generateTopicSuggestions', () {
      test('returns parsed suggestions on successful response', () async {
        final responseData = {
          'choices': [
            {
              'message': {
                'content': '["聊聊旅行", "分享音乐", "讨论美食"]',
              },
            },
          ],
        };

        when(() => mockDio.post(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
            )).thenAnswer((_) async => _successResponse(responseData));

        final results = await service.generateTopicSuggestions(
          config: testConfig,
          context: testContext,
        );

        expect(results, ['聊聊旅行', '分享音乐', '讨论美食']);
      });

      test('returns empty list when API returns null content', () async {
        final responseData = {
          'choices': [
            {'message': {'content': null}},
          ],
        };

        when(() => mockDio.post(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
            )).thenAnswer((_) async => _successResponse(responseData));

        final results = await service.generateTopicSuggestions(
          config: testConfig,
          context: testContext,
        );

        expect(results, isEmpty);
      });

      test('returns empty list when API returns empty choices', () async {
        final responseData = {'choices': <dynamic>[]};

        when(() => mockDio.post(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
            )).thenAnswer((_) async => _successResponse(responseData));

        final results = await service.generateTopicSuggestions(
          config: testConfig,
          context: testContext,
        );

        expect(results, isEmpty);
      });

      test('returns empty list on DioException', () async {
        when(() => mockDio.post(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
            )).thenThrow(DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.connectionTimeout,
        ));

        final results = await service.generateTopicSuggestions(
          config: testConfig,
          context: testContext,
        );

        expect(results, isEmpty);
      });
    });

    group('generateReplySuggestions', () {
      test('returns parsed reply suggestions on successful response', () async {
        final responseData = {
          'choices': [
            {
              'message': {
                'content': '["好的！", "没问题", "收到"]',
              },
            },
          ],
        };

        when(() => mockDio.post(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
            )).thenAnswer((_) async => _successResponse(responseData));

        final results = await service.generateReplySuggestions(
          config: testConfig,
          context: testContext,
          latestMessage: '你好',
        );

        expect(results, ['好的！', '没问题', '收到']);
      });

      test('returns empty list on network error', () async {
        when(() => mockDio.post(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
            )).thenThrow(DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.connectionError,
        ));

        final results = await service.generateReplySuggestions(
          config: testConfig,
          context: testContext,
          latestMessage: '你好',
        );

        expect(results, isEmpty);
      });
    });

    group('testConnection', () {
      test('returns true on successful connection', () async {
        final responseData = {
          'choices': [
            {'message': {'content': 'Hi'}},
          ],
        };

        when(() => mockDio.post(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
            )).thenAnswer((_) async => _successResponse(responseData));

        final result = await service.testConnection(testConfig);

        expect(result, isTrue);
      });

      test('returns false on connection failure', () async {
        when(() => mockDio.post(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
            )).thenThrow(DioException(
          requestOptions: RequestOptions(path: ''),
        ));

        final result = await service.testConnection(testConfig);

        expect(result, isFalse);
      });

      test('returns false when response has no choices', () async {
        final responseData = {'choices': <dynamic>[]};

        when(() => mockDio.post(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
            )).thenAnswer((_) async => _successResponse(responseData));

        final result = await service.testConnection(testConfig);

        expect(result, isFalse);
      });
    });

    group('request headers', () {
      test('sends Authorization header for non-Azure vendors', () async {
        when(() => mockDio.post(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
            )).thenAnswer((_) async => _successResponse({
          'choices': [
            {'message': {'content': '["test"]'}},
          ],
        }));

        await service.generateTopicSuggestions(
          config: testConfig,
          context: testContext,
        );

        final captured = verify(() => mockDio.post(
              any(),
              data: any(named: 'data'),
              options: captureAny(named: 'options'),
            )).captured;

        final options = captured.first as Options;
        expect(options.headers?['Authorization'], 'Bearer sk-test-key');
        expect(options.headers?.containsKey('api-key'), isFalse);
      });

      test('sends api-key header for Azure vendor', () async {
        const azureConfig = LlmConfig(
          vendor: 'azure',
          apiKey: 'azure-key-123',
          apiBaseUrl: 'https://my-resource.openai.azure.com',
          modelName: 'my-deployment',
        );

        when(() => mockDio.post(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
            )).thenAnswer((_) async => _successResponse({
          'choices': [
            {'message': {'content': '["test"]'}},
          ],
        }));

        await service.generateTopicSuggestions(
          config: azureConfig,
          context: testContext,
        );

        final captured = verify(() => mockDio.post(
              any(),
              data: any(named: 'data'),
              options: captureAny(named: 'options'),
            )).captured;

        final options = captured.first as Options;
        expect(options.headers?.containsKey('Authorization'), isFalse);
        expect(options.headers?['api-key'], 'azure-key-123');
      });
    });

    group('response parsing', () {
      test('parses valid JSON array response', () async {
        final responseData = {
          'choices': [
            {
              'message': {
                'content': '["话题1", "话题2", "话题3"]',
              },
            },
          ],
        };

        when(() => mockDio.post(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
            )).thenAnswer((_) async => _successResponse(responseData));

        final results = await service.generateTopicSuggestions(
          config: testConfig,
          context: testContext,
        );

        expect(results.length, 3);
        expect(results, ['话题1', '话题2', '话题3']);
      });

      test('falls back to regex extraction when JSON parsing fails', () async {
        final responseData = {
          'choices': [
            {
              'message': {
                'content': '这里是一些建议："去公园散步" 和 "看一部电影"',
              },
            },
          ],
        };

        when(() => mockDio.post(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
            )).thenAnswer((_) async => _successResponse(responseData));

        final results = await service.generateTopicSuggestions(
          config: testConfig,
          context: testContext,
        );

        expect(results, isNotEmpty);
        expect(results, contains('去公园散步'));
        expect(results, contains('看一部电影'));
      });

      test('returns empty list for completely unparseable response', () async {
        final responseData = {
          'choices': [
            {
              'message': {
                'content': 'no suggestions available',
              },
            },
          ],
        };

        when(() => mockDio.post(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
            )).thenAnswer((_) async => _successResponse(responseData));

        final results = await service.generateTopicSuggestions(
          config: testConfig,
          context: testContext,
        );

        expect(results, isEmpty);
      });

      test('handles non-200 status code as null response', () async {
        when(() => mockDio.post(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
            )).thenAnswer((_) async => _errorResponse(401));

        final results = await service.generateTopicSuggestions(
          config: testConfig,
          context: testContext,
        );

        expect(results, isEmpty);
      });
    });
  });
}
