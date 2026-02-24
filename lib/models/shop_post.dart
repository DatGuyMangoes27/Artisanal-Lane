class ShopPost {
  final String id;
  final String shopId;
  final String caption;
  final List<String> mediaUrls;
  final bool isPublished;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined shop data
  final String? shopName;
  final String? shopLogoUrl;

  const ShopPost({
    required this.id,
    required this.shopId,
    required this.caption,
    this.mediaUrls = const [],
    this.isPublished = true,
    required this.createdAt,
    required this.updatedAt,
    this.shopName,
    this.shopLogoUrl,
  });

  factory ShopPost.fromJson(Map<String, dynamic> json) {
    List<String> parseMediaUrls(dynamic urls) {
      if (urls == null) return [];
      if (urls is List) return urls.map((e) => e.toString()).toList();
      return [];
    }

    final shopData = json['shops'] as Map<String, dynamic>?;

    return ShopPost(
      id: json['id'] as String,
      shopId: json['shop_id'] as String,
      caption: json['caption'] as String? ?? '',
      mediaUrls: parseMediaUrls(json['media_urls']),
      isPublished: json['is_published'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      shopName: shopData?['name'] as String?,
      shopLogoUrl: shopData?['logo_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'shop_id': shopId,
        'caption': caption,
        'media_urls': mediaUrls,
        'is_published': isPublished,
      };

  String get primaryImage =>
      mediaUrls.isNotEmpty
          ? mediaUrls.first
          : 'https://images.unsplash.com/photo-1565193566173-7a0ee3dbe261?w=400&h=400&fit=crop';

  /// Returns a human-friendly relative time string
  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }
}
