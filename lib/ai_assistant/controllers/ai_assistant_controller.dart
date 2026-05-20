import 'dart:async';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import '../models/ai_suggestion.dart';
import '../models/llm_config.dart';
import '../models/memory_context.dart';
import '../models/notion_config.dart';
import '../services/llm_service.dart';
import '../services/notion_service.dart';
import '../utils/secure_storage.dart';

class AIAssistantController extends GetxController {
  final _llmService = LLMService();
  final _notionService = NotionService();

  final aiEnabled = false.obs;
  final llmConfig = const LlmConfig().obs;
  final notionConfig = const NotionConfig().obs;
  final topicEnabled = true.obs;
  final replyEnabled = true.obs;
  final notionSyncEnabled = true.obs;
  final llmConnected = false.obs;
  final notionConnected = false.obs;

  final suggestions = <AiSuggestion>[].obs;
  final isLoadingSuggestions = false.obs;
  final lastSyncTime = ''.obs;

  final _notionMemoryCache = <String, String>{};
  final _syncQueue = <Map<String, dynamic>>[];
  final _enqueuedMsgIDs = <String>{};
  final _inFlightConversationIDs = <String>{};
  Timer? _syncTimer;

  Worker? _syncEnabledWorker;

  @override
  void onInit() {
    super.onInit();
    _loadConfig();
    _startSyncTimer();
    _setupConfigListeners();
  }

  void _setupConfigListeners() {
    _syncEnabledWorker = ever(notionSyncEnabled, (enabled) {
      if (enabled && _canSyncNotion) {
        _startSyncTimer();
      } else {
        _stopSyncTimer();
      }
    });
  }

  void _stopSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  @override
  void onClose() {
    _syncEnabledWorker?.dispose();
    _stopSyncTimer();
    super.onClose();
  }

  Future<void> _loadConfig() async {
    aiEnabled.value = DataSp.getAIEnabled();

    final llmMap = DataSp.getAILlmConfig();
    if (llmMap != null) {
      final savedConfig = LlmConfig.fromJson(llmMap.cast());
      final apiKey = await SecureStorage.read(SecureStorage.llmApiKey) ?? '';
      llmConfig.value = savedConfig.copyWith(apiKey: apiKey);
    }

    final notionMap = DataSp.getAINotionConfig();
    if (notionMap != null) {
      final token = await SecureStorage.read(SecureStorage.notionToken) ?? '';
      final rootPageId = notionMap['rootPageId'] as String? ?? '';
      notionConfig.value = NotionConfig(integrationToken: token, rootPageId: rootPageId);
    }

    topicEnabled.value = DataSp.getAITopicEnabled();
    replyEnabled.value = DataSp.getAIReplyEnabled();
    notionSyncEnabled.value = DataSp.getAINotionSyncEnabled();
    lastSyncTime.value = DataSp.getAILastSyncTime() ?? '';
  }

  Future<void> saveLlmConfig(LlmConfig config) async {
    await SecureStorage.write(SecureStorage.llmApiKey, config.apiKey);
    DataSp.putAILlmConfig(config.toJson());
    llmConfig.value = config;
  }

  Future<void> saveNotionConfig(NotionConfig config) async {
    await SecureStorage.write(SecureStorage.notionToken, config.integrationToken);
    DataSp.putAINotionConfig(config.toNonSensitiveJson());
    notionConfig.value = config;
  }

  void setAIEnabled(bool enabled) {
    aiEnabled.value = enabled;
    DataSp.putAIEnabled(enabled);
    if (!enabled) {
      suggestions.clear();
      isLoadingSuggestions.value = false;
    }
  }

  void setTopicEnabled(bool enabled) {
    topicEnabled.value = enabled;
    DataSp.putAITopicEnabled(enabled);
  }

  void setReplyEnabled(bool enabled) {
    replyEnabled.value = enabled;
    DataSp.putAIReplyEnabled(enabled);
  }

  void setNotionSyncEnabled(bool enabled) {
    notionSyncEnabled.value = enabled;
    DataSp.putAINotionSyncEnabled(enabled);
  }

  Future<bool> testLlmConnection() async {
    if (!llmConfig.value.isConfigured) return false;
    final result = await _llmService.testConnection(llmConfig.value);
    llmConnected.value = result;
    return result;
  }

  Future<bool> testNotionConnection() async {
    if (!notionConfig.value.isConfigured) return false;
    final result = await _notionService.testConnection(notionConfig.value);
    notionConnected.value = result;
    return result;
  }

  bool get _canGenerateSuggestions =>
      aiEnabled.value && llmConfig.value.isConfigured;

  bool get _canSyncNotion =>
      aiEnabled.value && notionSyncEnabled.value && notionConfig.value.isConfigured;

  Future<void> generateTopicSuggestions(ConversationInfo conversationInfo) async {
    final conversationID = conversationInfo.conversationID;
    if (!_canGenerateSuggestions || !topicEnabled.value) return;
    if (_inFlightConversationIDs.contains(conversationID)) return;
    _inFlightConversationIDs.add(conversationID);

    isLoadingSuggestions.value = true;
    suggestions.clear();

    try {
      final context = await _buildMemoryContext(conversationInfo);
      final results = await _llmService.generateTopicSuggestions(
        config: llmConfig.value,
        context: context,
      );
      suggestions.assignAll(
        results.map((text) => AiSuggestion(type: AiSuggestionType.topic, text: text)),
      );
    } catch (e) {
      Logger.print('generateTopicSuggestions failed: $e');
    } finally {
      isLoadingSuggestions.value = false;
      _inFlightConversationIDs.remove(conversationID);
    }
  }

  Future<void> generateReplySuggestions(ConversationInfo conversationInfo, Message newMessage) async {
    final conversationID = conversationInfo.conversationID;
    if (!_canGenerateSuggestions || !replyEnabled.value) return;
    if (_inFlightConversationIDs.contains(conversationID)) return;
    _inFlightConversationIDs.add(conversationID);

    isLoadingSuggestions.value = true;
    suggestions.clear();

    try {
      final context = await _buildMemoryContext(conversationInfo);
      final latestText = newMessage.textElem?.content ?? '';
      final results = await _llmService.generateReplySuggestions(
        config: llmConfig.value,
        context: context,
        latestMessage: latestText,
      );
      suggestions.assignAll(
        results.map((text) => AiSuggestion(type: AiSuggestionType.reply, text: text)),
      );
    } catch (e) {
      Logger.print('generateReplySuggestions failed: $e');
    } finally {
      isLoadingSuggestions.value = false;
      _inFlightConversationIDs.remove(conversationID);
    }
  }

  void clearSuggestions() {
    suggestions.clear();
    isLoadingSuggestions.value = false;
  }

  Future<MemoryContext> _buildMemoryContext(ConversationInfo conversationInfo) async {
    final conversationID = conversationInfo.conversationID;
    String recentMessages = '';
    String contactProfile = '';
    String notionMemory = '';

    try {
      final result = await OpenIM.iMManager.messageManager.getAdvancedHistoryMessageList(
        conversationID: conversationID,
        count: 20,
      );
      final messages = result.messageList ?? [];
      final buffer = StringBuffer();
      for (final msg in messages) {
        if (msg.contentType == MessageType.text) {
          final sender = msg.senderNickname ?? '';
          final content = msg.textElem?.content ?? '';
          buffer.writeln('$sender: $content');
        }
      }
      recentMessages = buffer.toString();
    } catch (e) {
      Logger.print('Failed to fetch recent messages: $e');
    }

    try {
      final buffer = StringBuffer();
      buffer.writeln('会话名称: ${conversationInfo.showName ?? ''}');
      if (conversationInfo.userID != null && conversationInfo.userID!.isNotEmpty) {
        try {
          final friends = await OpenIM.iMManager.friendshipManager.getFriendsInfo(
            userIDList: [conversationInfo.userID!],
          );
          final friend = friends.firstOrNull;
          if (friend != null) {
            buffer.writeln('好友备注: ${friend.remark ?? ''}');
          }
        } catch (_) {}
      }
      contactProfile = buffer.toString();
    } catch (e) {
      Logger.print('Failed to fetch contact profile: $e');
    }

    if (_canSyncNotion) {
      notionMemory = _notionMemoryCache[conversationID] ?? '';
      if (notionMemory.isEmpty) {
        try {
          final pageName = _buildPageName(conversationID);
          final pageId = await _notionService.findChildPageByName(
            config: notionConfig.value,
            pageName: pageName,
          );
          if (pageId != null) {
            notionMemory = await _notionService.readPageContent(
              config: notionConfig.value,
              pageId: pageId,
            );
            _notionMemoryCache[conversationID] = notionMemory;
          }
        } catch (e) {
          Logger.print('Failed to read Notion memory: $e');
        }
      }
    }

    return MemoryContext(
      conversationID: conversationID,
      recentMessages: recentMessages,
      contactProfile: contactProfile,
      notionLongTermMemory: notionMemory,
    );
  }

  String _buildPageName(String conversationID) {
    return conversationID.replaceAll('_', '-');
  }

  void enqueueMessageForSync({
    required String conversationID,
    required String clientMsgID,
    required String senderNickname,
    required String content,
    required int sendTime,
  }) {
    if (!_canSyncNotion) return;
    if (_enqueuedMsgIDs.contains(clientMsgID)) return;
    _enqueuedMsgIDs.add(clientMsgID);
    _syncQueue.add({
      'conversationID': conversationID,
      'clientMsgID': clientMsgID,
      'senderNickname': senderNickname,
      'content': content,
      'sendTime': sendTime,
    });
    if (_syncQueue.length >= 20) {
      _flushSyncQueue();
    }
  }

  void _startSyncTimer() {
    _stopSyncTimer();
    if (!_canSyncNotion) return;
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_syncQueue.isNotEmpty) {
        _flushSyncQueue();
      }
    });
  }

  Future<void> _flushSyncQueue() async {
    if (_syncQueue.isEmpty || !_canSyncNotion) return;

    final batch = List<Map<String, dynamic>>.from(_syncQueue);
    _syncQueue.clear();
    final batchedMsgIDs = batch.map((item) => item['clientMsgID'] as String).toSet();

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final item in batch) {
      final convID = item['conversationID'] as String;
      grouped.putIfAbsent(convID, () => []).add(item);
    }

    final failedMessages = <Map<String, dynamic>>[];

    for (final entry in grouped.entries) {
      try {
        final pageName = _buildPageName(entry.key);
        final pageId = await _notionService.withRetry(() => _notionService.getOrCreateChildPage(
              config: notionConfig.value,
              pageName: pageName,
            ));

        final byDate = <String, List<String>>{};
        for (final msg in entry.value) {
          final date = DateTime.fromMillisecondsSinceEpoch(msg['sendTime'] as int);
          final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          final timeStr = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
          final line = '[$timeStr] ${msg['senderNickname']}: ${msg['content']}';
          byDate.putIfAbsent(dateStr, () => []).add(line);
        }

        for (final dateEntry in byDate.entries) {
          await _notionService.withRetry(() => _notionService.appendMessagesToPage(
                config: notionConfig.value,
                pageId: pageId,
                dateHeader: dateEntry.key,
                messageLines: dateEntry.value,
              ));
        }

        lastSyncTime.value = DateTime.now().toIso8601String();
        DataSp.putAILastSyncTime(lastSyncTime.value);
      } catch (e) {
        Logger.print('Notion sync flush failed for ${entry.key}: $e');
        failedMessages.addAll(entry.value);
      }
    }

    if (failedMessages.isNotEmpty) {
      _syncQueue.insertAll(0, failedMessages);
    } else {
      _enqueuedMsgIDs.removeAll(batchedMsgIDs);
    }
  }

  void clearNotionMemoryCache(String conversationID) {
    _notionMemoryCache.remove(conversationID);
  }
}
