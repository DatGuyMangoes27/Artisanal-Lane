class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String notificationType;
  final Map<String, dynamic> data;
  final DateTime? readAt;
  final DateTime? dismissedAt;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.notificationType,
    this.data = const {},
    this.readAt,
    this.dismissedAt,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];

    return AppNotification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String? ?? 'Notification',
      body: json['body'] as String? ?? '',
      notificationType: json['notification_type'] as String? ?? 'general',
      data: rawData is Map ? Map<String, dynamic>.from(rawData) : const {},
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
      dismissedAt: json['dismissed_at'] != null
          ? DateTime.parse(json['dismissed_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  bool get isUnread => readAt == null;

  /// Cleared by the user; hidden from the list and the unread badge.
  bool get isDismissed => dismissedAt != null;

  AppNotification copyWith({DateTime? readAt, DateTime? dismissedAt}) {
    return AppNotification(
      id: id,
      userId: userId,
      title: title,
      body: body,
      notificationType: notificationType,
      data: data,
      readAt: readAt ?? this.readAt,
      dismissedAt: dismissedAt ?? this.dismissedAt,
      createdAt: createdAt,
    );
  }
}
