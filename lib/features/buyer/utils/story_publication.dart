/// One immutable publication identity for upload and database retries.
class StoryPublication {
  final String id, shopId, mediaPath, mediaType, caption;
  const StoryPublication({
    required this.id,
    required this.shopId,
    required this.mediaPath,
    required this.mediaType,
    required this.caption,
  });
  Map<String, dynamic> get row => {
    'id': id,
    'shop_id': shopId,
    'media_path': mediaPath,
    'media_type': mediaType,
    'caption': caption,
  };

  void verify(Map<String, dynamic> saved) {
    for (final entry in row.entries) {
      if (saved[entry.key] != entry.value) {
        throw StateError(
          'This story request no longer matches the saved story.',
        );
      }
    }
  }

  /// Lookup first: a lost commit response must not upload or publish twice.
  Future<void> ensurePublished({
    required Future<Map<String, dynamic>?> Function() find,
    required Future<void> Function() upload,
    required Future<void> Function(Map<String, dynamic>) insert,
  }) async {
    final existing = await find();
    if (existing != null) {
      verify(existing);
      return;
    }
    await upload();
    await insert(row);
    final saved = await find();
    if (saved == null) {
      throw StateError('Publishing has not been confirmed yet.');
    }
    verify(saved);
  }
}
