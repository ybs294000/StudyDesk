class AiChatMessage {
  const AiChatMessage({
    required this.role,
    required this.content,
    this.preview,
    this.errorMessage,
  });

  final AiChatRole role;
  final String content;
  final AiGeneratedPreview? preview;
  final String? errorMessage;

  bool get isUser => role == AiChatRole.user;

  AiChatMessage copyWith({
    AiChatRole? role,
    String? content,
    Object? preview = _aiChatSentinel,
    Object? errorMessage = _aiChatSentinel,
  }) {
    return AiChatMessage(
      role: role ?? this.role,
      content: content ?? this.content,
      preview: identical(preview, _aiChatSentinel)
          ? this.preview
          : preview as AiGeneratedPreview?,
      errorMessage: identical(errorMessage, _aiChatSentinel)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

enum AiChatRole {
  user,
  assistant,
}

class AiGeneratedPreview {
  const AiGeneratedPreview({
    required this.kind,
    required this.rawPayload,
    required this.title,
    required this.itemCount,
    required this.summary,
  });

  final String kind;
  final String rawPayload;
  final String title;
  final int itemCount;
  final String summary;
}

const _aiChatSentinel = Object();
