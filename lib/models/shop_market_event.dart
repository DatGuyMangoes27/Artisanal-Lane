class ShopMarketEvent {
  final String id;
  final String shopId;
  final String marketName;
  final String location;
  final DateTime eventDate;
  final String? timeLabel;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ShopMarketEvent({
    required this.id,
    required this.shopId,
    required this.marketName,
    required this.location,
    required this.eventDate,
    this.timeLabel,
    this.notes,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ShopMarketEvent.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return ShopMarketEvent(
      id: json['id'] as String,
      shopId: json['shop_id'] as String,
      marketName: json['market_name'] as String,
      location: json['location'] as String,
      eventDate: DateTime.parse(json['event_date'] as String),
      timeLabel: json['time_label'] as String?,
      notes: json['notes'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : now,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : now,
    );
  }

  ShopMarketEvent copyWith({
    String? id,
    String? shopId,
    String? marketName,
    String? location,
    DateTime? eventDate,
    String? timeLabel,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ShopMarketEvent(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      marketName: marketName ?? this.marketName,
      location: location ?? this.location,
      eventDate: eventDate ?? this.eventDate,
      timeLabel: timeLabel ?? this.timeLabel,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toInsertJson(String shopId) => {
    'shop_id': shopId,
    'market_name': marketName,
    'location': location,
    'event_date': eventDate.toIso8601String().split('T').first,
    'time_label': _emptyToNull(timeLabel),
    'notes': _emptyToNull(notes),
    'is_active': isActive,
  };

  static String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
