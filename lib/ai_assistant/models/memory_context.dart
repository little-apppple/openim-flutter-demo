class MemoryContext {
  final String conversationID;
  final String recentMessages;
  final String contactProfile;
  final String notionLongTermMemory;

  const MemoryContext({
    required this.conversationID,
    this.recentMessages = '',
    this.contactProfile = '',
    this.notionLongTermMemory = '',
  });

  String buildTopicPrompt() {
    final buffer = StringBuffer();
    buffer.write('你是一个社交助手，帮助用户在即时通讯中找到合适的话题。');
    buffer.write('请根据以下上下文信息，生成3到5个适合当前对话的话题建议。');
    buffer.write('只输出JSON数组格式，例如：["话题1","话题2","话题3"]');
    buffer.write('不要输出任何其他内容。\n\n');
    if (contactProfile.isNotEmpty) {
      buffer.write('联系人信息：\n$contactProfile\n\n');
    }
    if (notionLongTermMemory.isNotEmpty) {
      buffer.write('长期记忆（来自Notion笔记）：\n$notionLongTermMemory\n\n');
    }
    if (recentMessages.isNotEmpty) {
      buffer.write('近期聊天记录：\n$recentMessages\n\n');
    }
    return buffer.toString();
  }

  String buildReplyPrompt(String latestMessage) {
    final buffer = StringBuffer();
    buffer.write('你是一个社交助手，帮助用户在即时通讯中生成合适的回复。');
    buffer.write('请根据以下上下文信息，生成3个适合回复最新消息的建议。');
    buffer.write('只输出JSON数组格式，例如：["回复1","回复2","回复3"]');
    buffer.write('不要输出任何其他内容。\n\n');
    if (contactProfile.isNotEmpty) {
      buffer.write('联系人信息：\n$contactProfile\n\n');
    }
    if (notionLongTermMemory.isNotEmpty) {
      buffer.write('长期记忆（来自Notion笔记）：\n$notionLongTermMemory\n\n');
    }
    if (recentMessages.isNotEmpty) {
      buffer.write('近期聊天记录：\n$recentMessages\n\n');
    }
    buffer.write('最新收到的消息：$latestMessage\n');
    return buffer.toString();
  }
}
