List<String> productZoomImages({
  required List<String> displayImages,
  required String fallbackImage,
}) {
  if (displayImages.isNotEmpty) {
    return displayImages;
  }

  return [fallbackImage];
}
