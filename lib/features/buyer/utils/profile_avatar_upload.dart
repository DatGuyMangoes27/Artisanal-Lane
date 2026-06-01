String profileAvatarStoragePath({
  required String userId,
  required String originalPath,
  required int timestampMillis,
}) {
  final normalizedExtension = originalPath.split('.').last.toLowerCase();
  final extension = normalizedExtension == originalPath.toLowerCase()
      ? 'jpg'
      : normalizedExtension;
  return '$userId/avatar-$timestampMillis.$extension';
}
