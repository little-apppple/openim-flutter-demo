import 'package:flutter_test/flutter_test.dart';
import 'package:openim/ai_assistant/models/notion_config.dart';

void main() {
  group('NotionConfig', () {
    test('default values are empty strings', () {
      const config = NotionConfig();

      expect(config.integrationToken, '');
      expect(config.rootPageId, '');
    });

    test('isConfigured returns false when integrationToken is empty', () {
      const config = NotionConfig(
        integrationToken: '',
        rootPageId: 'page-123',
      );

      expect(config.isConfigured, isFalse);
    });

    test('isConfigured returns false when rootPageId is empty', () {
      const config = NotionConfig(
        integrationToken: 'secret-token',
        rootPageId: '',
      );

      expect(config.isConfigured, isFalse);
    });

    test('isConfigured returns true when both fields are set', () {
      const config = NotionConfig(
        integrationToken: 'secret-token',
        rootPageId: 'page-123',
      );

      expect(config.isConfigured, isTrue);
    });

    test('copyWith updates specified fields', () {
      const config = NotionConfig(
        integrationToken: 'old-token',
        rootPageId: 'old-page',
      );

      final updated = config.copyWith(integrationToken: 'new-token');

      expect(updated.integrationToken, 'new-token');
      expect(updated.rootPageId, 'old-page');
    });

    test('copyWith preserves values when no arguments given', () {
      const config = NotionConfig(
        integrationToken: 'token',
        rootPageId: 'page',
      );

      final copied = config.copyWith();

      expect(copied.integrationToken, config.integrationToken);
      expect(copied.rootPageId, config.rootPageId);
    });

    test('toNonSensitiveJson excludes integrationToken', () {
      const config = NotionConfig(
        integrationToken: 'secret-token',
        rootPageId: 'page-123',
      );

      final json = config.toNonSensitiveJson();

      expect(json.containsKey('rootPageId'), isTrue);
      expect(json.containsKey('integrationToken'), isFalse);
      expect(json['rootPageId'], 'page-123');
    });

    test('toNonSensitiveJson only contains rootPageId', () {
      const config = NotionConfig(
        integrationToken: 'secret',
        rootPageId: 'abc',
      );

      final json = config.toNonSensitiveJson();

      expect(json.keys.length, 1);
      expect(json.keys.first, 'rootPageId');
    });
  });
}
