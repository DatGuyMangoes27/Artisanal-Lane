import '../../../models/order.dart';
import '../../../models/product.dart';
import 'discover_taste.dart';
import 'discovery_preferences.dart';

/// Where loved/saved-but-not-bought pieces are placed in the Shop "For you"
/// list as reminders: never first (that slot is the editorial pick), then
/// one in every three near the top.
const shopForYouReminderSlots = <int>[1, 4, 7, 10, 13, 16];

/// Order statuses where the buyer has not (or no longer) bought the piece,
/// so it can still be shown as a reminder.
const _notBoughtStatuses = {
  'pending',
  'awaiting_payment',
  'payment_failed',
  'cancelled',
  'expired',
};

/// Product ids from [orders] the buyer has actually paid for.
Set<String> purchasedProductIds(Iterable<Order> orders) => {
  for (final order in orders)
    if (!_notBoughtStatuses.contains(order.status))
      for (final item in order.items ?? const <OrderItem>[])
        if (item.productId.isNotEmpty) item.productId,
};

/// Ranks the Shop tab's default "For you" view with the same signals as
/// Discover, so what the buyer chose and swiped there is reinforced here:
///
/// * Pieces they loved on Discover or saved, and haven't bought, are the
///   "most likely to catch attention": they're surfaced near the top at
///   [shopForYouReminderSlots] (strongest match first) as a reminder.
/// * Everything else (within their Discover budget, minus pieces they
///   marked "Not for me") is ordered by their Discover categories, then by
///   the categories, makers and tags of what they loved/saved (and away
///   from what they skipped), then featured, then newest.
///
/// Only real catalogue pieces in [products] are returned; nothing is added.
List<Product> rankShopForYou({
  required List<Product> products,
  required DiscoveryPreferences preferences,
  Iterable<Product> savedProducts = const [],
  Set<String> savedProductIds = const {},
  Set<String> purchasedProductIds = const {},
}) {
  final saved = {...savedProductIds, for (final p in savedProducts) p.id};
  final taste = discoverTasteFor(
    products,
    preferences,
    savedProducts: savedProducts,
    savedProductIds: saved,
  );
  final scores = <String, double>{};
  double score(Product product) => scores.putIfAbsent(product.id, () {
    var value = product.isFeatured ? 1.0 : 0.0;
    if (preferences.categoryIds.contains(product.categoryId)) value += 6;
    return value + taste.scoreOf(product);
  });
  int byScore(Product a, Product b) {
    final compared = score(b).compareTo(score(a));
    if (compared != 0) return compared;
    final byDate = b.createdAt.compareTo(a.createdAt);
    return byDate != 0 ? byDate : a.id.compareTo(b.id);
  }

  bool interested(Product p) =>
      preferences.likedProductIds.contains(p.id) || saved.contains(p.id);
  final reminders = [
    for (final product in products)
      if (interested(product) &&
          !purchasedProductIds.contains(product.id) &&
          product.isAvailableForPurchase)
        product,
  ]..sort(byScore);
  final reminderIds = {for (final p in reminders) p.id};
  final rest = [
    for (final product in products)
      if (!reminderIds.contains(product.id) &&
          !preferences.skippedProductIds.contains(product.id) &&
          // Loved pieces only appear as reminders; once bought they step
          // aside rather than keep topping the list.
          !preferences.likedProductIds.contains(product.id) &&
          (preferences.maxBudget == null ||
              product.price <= preferences.maxBudget!))
        product,
  ]..sort(byScore);

  final result = <Product>[];
  var nextReminder = 0;
  var nextRest = 0;
  while (nextReminder < reminders.length || nextRest < rest.length) {
    final slot = result.length;
    final wantsReminder =
        nextReminder < reminders.length &&
        (nextRest >= rest.length ||
            (shopForYouReminderSlots.contains(slot) &&
                nextReminder < shopForYouReminderSlots.length));
    if (wantsReminder) {
      result.add(reminders[nextReminder++]);
    } else if (nextRest < rest.length) {
      // Reminders beyond the top slots slot back in by score.
      if (nextReminder >= shopForYouReminderSlots.length &&
          nextReminder < reminders.length &&
          byScore(reminders[nextReminder], rest[nextRest]) <= 0) {
        result.add(reminders[nextReminder++]);
      } else {
        result.add(rest[nextRest++]);
      }
    }
  }
  return result;
}
