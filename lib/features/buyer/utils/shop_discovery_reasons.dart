import '../../../models/product.dart';

/// Computes the short "Because you liked …" line shown on a Shop tile in the
/// For You view. Pure and transparent: it only looks at the buyer's saved
/// taste categories (from Discover) and a small set of reference products
/// (liked/favourited pieces) already loaded by the caller — no extra
/// network calls happen here.
///
/// Returns null when there's nothing meaningful to say, so callers can fall
/// back to showing no reason line.
String? shopForYouReason({
  required Product product,
  required Set<String> likedCategoryIds,
  required List<Product> referenceProducts,
  Set<String> lovedProductIds = const {},
  Set<String> savedProductIds = const {},
}) {
  // Reminders of the buyer's own picks (see `rankShopForYou`).
  if (lovedProductIds.contains(product.id)) return 'You loved this';
  if (savedProductIds.contains(product.id)) return 'You saved this';

  final categoryName = product.categoryName?.trim();
  if (categoryName == null || categoryName.isEmpty) return null;
  if (product.categoryId == null) return null;

  if (likedCategoryIds.contains(product.categoryId)) {
    return 'Because you liked $categoryName';
  }

  for (final reference in referenceProducts) {
    if (reference.id == product.id) continue;
    if (reference.categoryId != null &&
        reference.categoryId == product.categoryId) {
      return 'Because you liked $categoryName';
    }
  }

  for (final reference in referenceProducts) {
    if (reference.id == product.id) continue;
    final sharedTag = product.tags
        .where((tag) => tag.trim().isNotEmpty && reference.tags.contains(tag))
        .firstOrNull;
    if (sharedTag != null) {
      return 'Because you liked $sharedTag pieces';
    }
  }

  return null;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
