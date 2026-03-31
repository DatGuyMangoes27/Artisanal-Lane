import 'chat_attachment.dart';

class ChatMessage {
  final String id;
  final String threadId;
  final String senderId;
  final String? body;
  final String messageType;
  final ChatAttachment? attachment;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.threadId,
    required this.senderId,
    this.body,
    required this.messageType,
    this.attachment,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final hasAttachment =
        json['attachment_name'] != null ||
        json['attachment_path'] != null ||
        json['attachment_url'] != null;

    return ChatMessage(
      id: json['id'] as String,
      threadId: json['thread_id'] as String,
      senderId: json['sender_id'] as String,
      body: (json['body'] as String?)?.trim().isEmpty == true
          ? null
          : json['body'] as String?,
      messageType: json['message_type'] as String? ?? 'text',
      attachment: hasAttachment ? ChatAttachment.fromJson(json) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'thread_id': threadId,
        'sender_id': senderId,
        'body': body,
        'message_type': messageType,
        'created_at': createdAt.toIso8601String(),
        ...?attachment?.toJson(),
      };

  ChatMessage copyWith({
    String? id,
    String? threadId,
    String? senderId,
    String? body,
    String? messageType,
    ChatAttachment? attachment,
    DateTime? createdAt,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      threadId: threadId ?? this.threadId,
      senderId: senderId ?? this.senderId,
      body: body ?? this.body,
      messageType: messageType ?? this.messageType,
      attachment: attachment ?? this.attachment,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get hasText => body != null && body!.trim().isNotEmpty;
  bool get hasAttachment => attachment != null;

  bool isSentBy(String userId) => senderId == userId;
}
