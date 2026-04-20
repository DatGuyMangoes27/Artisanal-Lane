/// Kinds of chat threads supported by the platform.
///
/// * `buyerVendor` — the default buyer<->vendor chat.
/// * `adminVendor` — the Artisan Lane admin team messaging the shop.
enum ChatThreadKind {
  buyerVendor,
  adminVendor;

  static ChatThreadKind fromRaw(String? raw) {
    switch (raw) {
      case 'admin_vendor':
        return ChatThreadKind.adminVendor;
      case 'buyer_vendor':
      default:
        return ChatThreadKind.buyerVendor;
    }
  }

  bool get isAdminVendor => this == ChatThreadKind.adminVendor;
}

class ChatThread {
  final String id;
  final String shopId;
  final String buyerId;
  final String vendorId;
  final ChatThreadKind kind;
  final String? lastMessagePreview;
  final String lastMessageType;
  final String? lastMessageSenderId;
  final DateTime? lastMessageAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastReadAt;
  final String? lastReadMessageId;
  final int unreadCount;

  final String? shopName;
  final String? shopLogoUrl;
  final String? buyerDisplayName;
  final String? buyerAvatarUrl;
  final String? vendorDisplayName;
  final String? vendorAvatarUrl;

  const ChatThread({
    required this.id,
    required this.shopId,
    required this.buyerId,
    required this.vendorId,
    this.kind = ChatThreadKind.buyerVendor,
    this.lastMessagePreview,
    this.lastMessageType = 'text',
    this.lastMessageSenderId,
    this.lastMessageAt,
    required this.createdAt,
    required this.updatedAt,
    this.lastReadAt,
    this.lastReadMessageId,
    this.unreadCount = 0,
    this.shopName,
    this.shopLogoUrl,
    this.buyerDisplayName,
    this.buyerAvatarUrl,
    this.vendorDisplayName,
    this.vendorAvatarUrl,
  });

  factory ChatThread.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
    int unreadCount = 0,
  }) {
    final shopData = json['shops'] as Map<String, dynamic>?;
    final buyerData = json['buyer'] as Map<String, dynamic>?;
    final vendorData = json['vendor'] as Map<String, dynamic>?;
    final reads = (json['chat_thread_reads'] as List?)
        ?.map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();

    Map<String, dynamic>? currentRead;
    if (currentUserId != null && reads != null) {
      for (final entry in reads) {
        if (entry['participant_id'] == currentUserId) {
          currentRead = entry;
          break;
        }
      }
    }

    return ChatThread(
      id: json['id'] as String,
      shopId: json['shop_id'] as String,
      buyerId: json['buyer_id'] as String,
      vendorId: json['vendor_id'] as String,
      kind: ChatThreadKind.fromRaw(json['kind'] as String?),
      lastMessagePreview: json['last_message_preview'] as String?,
      lastMessageType: json['last_message_type'] as String? ?? 'text',
      lastMessageSenderId: json['last_message_sender_id'] as String?,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      lastReadAt: currentRead?['last_read_at'] != null
          ? DateTime.parse(currentRead!['last_read_at'] as String)
          : null,
      lastReadMessageId: currentRead?['last_read_message_id'] as String?,
      unreadCount: unreadCount,
      shopName: shopData?['name'] as String?,
      shopLogoUrl: shopData?['logo_url'] as String?,
      buyerDisplayName: buyerData?['display_name'] as String?,
      buyerAvatarUrl: buyerData?['avatar_url'] as String?,
      vendorDisplayName: vendorData?['display_name'] as String?,
      vendorAvatarUrl: vendorData?['avatar_url'] as String?,
    );
  }

  ChatThread copyWith({
    String? id,
    String? shopId,
    String? buyerId,
    String? vendorId,
    ChatThreadKind? kind,
    String? lastMessagePreview,
    String? lastMessageType,
    String? lastMessageSenderId,
    DateTime? lastMessageAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastReadAt,
    String? lastReadMessageId,
    int? unreadCount,
    String? shopName,
    String? shopLogoUrl,
    String? buyerDisplayName,
    String? buyerAvatarUrl,
    String? vendorDisplayName,
    String? vendorAvatarUrl,
  }) {
    return ChatThread(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      buyerId: buyerId ?? this.buyerId,
      vendorId: vendorId ?? this.vendorId,
      kind: kind ?? this.kind,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      lastMessageType: lastMessageType ?? this.lastMessageType,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      lastReadMessageId: lastReadMessageId ?? this.lastReadMessageId,
      unreadCount: unreadCount ?? this.unreadCount,
      shopName: shopName ?? this.shopName,
      shopLogoUrl: shopLogoUrl ?? this.shopLogoUrl,
      buyerDisplayName: buyerDisplayName ?? this.buyerDisplayName,
      buyerAvatarUrl: buyerAvatarUrl ?? this.buyerAvatarUrl,
      vendorDisplayName: vendorDisplayName ?? this.vendorDisplayName,
      vendorAvatarUrl: vendorAvatarUrl ?? this.vendorAvatarUrl,
    );
  }

  String get previewText {
    if (lastMessagePreview != null && lastMessagePreview!.trim().isNotEmpty) {
      return lastMessagePreview!;
    }
    return lastMessageType == 'attachment' ? 'Attachment' : 'Start the conversation';
  }
}
