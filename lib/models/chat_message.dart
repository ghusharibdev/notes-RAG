enum MessageRole { user, assistant }

class Citation {
  final String documentName;
  final int page;
  final String passage;

  const Citation({
    required this.documentName,
    required this.page,
    required this.passage,
  });
}

class ChatMessage {
  final String id;
  final MessageRole role;
  final String content;
  final List<Citation> citations;
  final DateTime timestamp;
  final bool isStreaming;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.citations = const [],
    required this.timestamp,
    this.isStreaming = false,
  });

  ChatMessage copyWith({
    String? content,
    List<Citation>? citations,
    bool? isStreaming,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      citations: citations ?? this.citations,
      timestamp: timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}
