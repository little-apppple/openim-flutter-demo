import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  SecureStorage._();

  static const _instance = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static Future<void> write(String key, String value) async {
    await _instance.write(key: key, value: value);
  }

  static Future<String?> read(String key) async {
    return await _instance.read(key: key);
  }

  static Future<void> delete(String key) async {
    await _instance.delete(key: key);
  }

  static const llmApiKey = 'ai_llm_api_key';
  static const notionToken = 'ai_notion_token';
}
