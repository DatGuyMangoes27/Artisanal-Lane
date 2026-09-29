/// Post formats a maker can publish.
enum PostFormat { photo, video, carousel, tutorial, poll }

PostFormat parsePostFormat(Object? value) => PostFormat.values.firstWhere(
  (format) => format.name == value,
  orElse: () => PostFormat.photo,
);

class ShopPost {
  /// Columns every post query should select so cards can show maker details.
  static const select = '*, shops(name, logo_url, is_verified, location, slug)';

  final String id;
  final String shopId;
  final String caption;
  final List<String> mediaUrls;
  final List<String> productIds;
  final bool isPublished;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Maker settings.
  final bool commentsEnabled;
  final bool hideLikeCount;
  final DateTime? scheduledFor;
  final PostFormat format;

  /// One caption per media item for tutorial posts (may be shorter than media).
  final List<String> stepCaptions;

  /// When the post went (or goes) live: the schedule, else creation time.
  final DateTime publishedAt;

  // Joined shop data
  final String? shopName;
  final String? shopLogoUrl;
  final bool shopIsVerified;
  final String? shopLocation;
  final String? shopHandle;

  const ShopPost({
    required this.id,
    required this.shopId,
    required this.caption,
    this.mediaUrls = const [],
    this.productIds = const [],
    this.isPublished = true,
    required this.createdAt,
    required this.updatedAt,
    this.commentsEnabled = true,
    this.hideLikeCount = false,
    this.scheduledFor,
    this.format = PostFormat.photo,
    this.stepCaptions = const [],
    DateTime? publishedAt,
    this.shopName,
    this.shopLogoUrl,
    this.shopIsVerified = false,
    this.shopLocation,
    this.shopHandle,
  }) : publishedAt = publishedAt ?? scheduledFor ?? createdAt;

  factory ShopPost.fromJson(Map<String, dynamic> json) {
    List<String> strings(dynamic values) {
      if (values is List) return values.map((e) => e.toString()).toList();
      return [];
    }

    DateTime? date(dynamic value) =>
        value is String ? DateTime.tryParse(value) : null;

    final shopData = json['shops'] as Map<String, dynamic>?;
    final createdAt = DateTime.parse(json['created_at'] as String);
    final scheduledFor = date(json['scheduled_for']);

    return ShopPost(
      id: json['id'] as String,
      shopId: json['shop_id'] as String,
      caption: json['caption'] as String? ?? '',
      mediaUrls: strings(json['media_urls']),
      productIds: (json['product_ids'] as List? ?? [])
          .whereType<String>()
          .toList(),
      isPublished: json['is_published'] as bool? ?? true,
      createdAt: createdAt,
      updatedAt: DateTime.parse(json['updated_at'] as String),
      commentsEnabled: json['comments_enabled'] as bool? ?? true,
      hideLikeCount: json['hide_like_count'] as bool? ?? false,
      scheduledFor: scheduledFor,
      format: parsePostFormat(json['format']),
      stepCaptions: strings(json['step_captions']),
      publishedAt: date(json['published_at']) ?? scheduledFor ?? createdAt,
      shopName: shopData?['name'] as String?,
      shopLogoUrl: shopData?['logo_url'] as String?,
      shopIsVerified: shopData?['is_verified'] as bool? ?? false,
      shopLocation: shopData?['location'] as String?,
      shopHandle: shopData?['slug'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'shop_id': shopId,
    'caption': caption,
    'media_urls': mediaUrls,
    'product_ids': productIds,
    'is_published': isPublished,
    'comments_enabled': commentsEnabled,
    'hide_like_count': hideLikeCount,
    'scheduled_for': scheduledFor?.toUtc().toIso8601String(),
    'format': format.name,
    'step_captions': stepCaptions,
  };

  /// Scheduled for later and not yet visible to the public.
  bool get isScheduled =>
      scheduledFor != null && scheduledFor!.isAfter(DateTime.now());

  String get primaryImage => mediaUrls.isNotEmpty
      ? mediaUrls.first
      : 'https://images.unsplash.com/photo-1565193566173-7a0ee3dbe261?w=400&h=400&fit=crop';

  /// Returns a human-friendly relative time string
  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(publishedAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }
}
