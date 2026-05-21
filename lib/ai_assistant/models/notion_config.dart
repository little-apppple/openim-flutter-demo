class NotionConfig {
  final String integrationToken;
  final String rootPageId;

  const NotionConfig({
    this.integrationToken = '',
    this.rootPageId = '',
  });

  NotionConfig copyWith({
    String? integrationToken,
    String? rootPageId,
  }) {
    return NotionConfig(
      integrationToken: integrationToken ?? this.integrationToken,
      rootPageId: rootPageId ?? this.rootPageId,
    );
  }

  bool get isConfigured => integrationToken.isNotEmpty && rootPageId.isNotEmpty;

  Map<String, dynamic> toNonSensitiveJson() => {
        'rootPageId': rootPageId,
      };
}
