class ShopStory {
  const ShopStory({
    required this.id,
    required this.shopId,
    required this.mediaPath,
    required this.mediaType,
    required this.caption,
    required this.createdAt,
    required this.expiresAt,
    required this.shopName,
    this.logoUrl,
  });
  final String id, shopId, mediaPath, mediaType, caption, shopName;
  final String? logoUrl;
  final DateTime createdAt, expiresAt;
  bool isLiveAt(DateTime now) =>
      // Creation/expiry are stamped and access-controlled by the server. Allow
      // small device-clock drift so a freshly uploaded story appears at once.
      !createdAt.isAfter(now.add(const Duration(seconds: 30))) &&
      expiresAt.isAfter(now);
  bool get isVideo => mediaType == 'video';
  factory ShopStory.fromJson(Map<String, dynamic> json) {
    final shop = json['shops'] as Map<String, dynamic>? ?? {};
    return ShopStory(
      id: json['id'] as String,
      shopId: json['shop_id'] as String,
      mediaPath: json['media_path'] as String,
      mediaType: json['media_type'] as String,
      caption: json['caption'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      shopName: shop['name'] as String? ?? 'Artisan',
      logoUrl: shop['logo_url'] as String?,
    );
  }
}

/// Stable chronological playback within a maker; unseen makers come first.
List<List<ShopStory>> groupLiveStories(
  List<ShopStory> stories,
  Set<String> seen,
  DateTime now,
) {
  final groups = <String, List<ShopStory>>{};
  for (final story in stories.where((s) => s.isLiveAt(now))) {
    (groups[story.shopId] ??= []).add(story);
  }
  final result = groups.values.toList();
  for (final group in result) {
    group.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }
  result.sort((a, b) {
    final aUnseen = a.any((s) => !seen.contains(s.id));
    final bUnseen = b.any((s) => !seen.contains(s.id));
    if (aUnseen != bUnseen) return aUnseen ? -1 : 1;
    return b.last.createdAt.compareTo(a.last.createdAt);
  });
  return result;
}
