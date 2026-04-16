import '../../../models/chat_message.dart';

List<ChatMessage> buildDisplayedChatMessages({
  required List<ChatMessage> streamedMessages,
  List<ChatMessage> localMessages = const [],
}) {
  final byId = <String, ChatMessage>{
    for (final message in localMessages) message.id: message,
  };

  for (final message in streamedMessages) {
    byId[message.id] = message;
  }

  final merged = byId.values.toList()
    ..sort((a, b) {
      final createdAtComparison = a.createdAt.compareTo(b.createdAt);
      if (createdAtComparison != 0) {
        return createdAtComparison;
      }
      return a.id.compareTo(b.id);
    });

  return merged;
}
