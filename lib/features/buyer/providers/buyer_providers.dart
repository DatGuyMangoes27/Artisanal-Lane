import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/models.dart';
import '../../auth/providers/auth_providers.dart';
import '../utils/product_visibility.dart';

// Re-export core providers so existing imports still work
export '../../auth/providers/auth_providers.dart'
    show supabaseClientProvider, supabaseServiceProvider, currentUserIdProvider;

// ── Gift Options (in-memory, cleared after order) ───────────────
class GiftOptions {
  final bool isGift;
  final String recipient;
  final String message;

  const GiftOptions({
    this.isGift = false,
    this.recipient = '',
    this.message = '',
  });

  GiftOptions copyWith({bool? isGift, String? recipient, String? message}) =>
      GiftOptions(
        isGift: isGift ?? this.isGift,
        recipient: recipient ?? this.recipient,
        message: message ?? this.message,
      );
}

class GiftOptionsNotifier extends Notifier<GiftOptions> {
  @override
  GiftOptions build() => const GiftOptions();

  void update(GiftOptions options) => state = options;
  void reset() => state = const GiftOptions();
}

final giftOptionsProvider = NotifierProvider<GiftOptionsNotifier, GiftOptions>(
  GiftOptionsNotifier.new,
);

// ── Recent Searches (persisted locally) ─────────────────────────
const _kRecentSearchesKey = 'recent_searches';

class RecentSearchesNotifier extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_kRecentSearchesKey) ?? [];
  }

  Future<void> add(String term) async {
    final current = state.value ?? [];
    final updated = <String>[
      term,
      ...current.where((s) => s != term),
    ].take(10).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kRecentSearchesKey, updated);
    state = AsyncData(updated);
  }

  Future<void> remove(String term) async {
    final current = state.value ?? [];
    final updated = current.where((s) => s != term).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kRecentSearchesKey, updated);
    state = AsyncData(updated);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRecentSearchesKey);
    state = const AsyncData([]);
  }
}

final recentSearchesProvider =
    AsyncNotifierProvider<RecentSearchesNotifier, List<String>>(
      RecentSearchesNotifier.new,
    );

// ── Trending Searches (live from Supabase) ──────────────────────
final trendingSearchesProvider = StreamProvider<List<String>>((ref) {
  final service = ref.read(supabaseServiceProvider);
  return service.watchTrendingSearches();
});

// ── Categories ──────────────────────────────────────────────────
final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final service = ref.read(supabaseServiceProvider);
  return service.getCategories();
});

// ── Subcategories ───────────────────────────────────────────────
final subcategoriesProvider = FutureProvider.family<List<Subcategory>, String>((
  ref,
  categoryId,
) async {
  // "Shop all" browsing passes an empty categoryId — no subcategories apply.
  if (categoryId.isEmpty) return const <Subcategory>[];
  final service = ref.read(supabaseServiceProvider);
  return service.getSubcategories(categoryId);
});

// ── Chat ────────────────────────────────────────────────────────
final buyerThreadsProvider = FutureProvider<List<ChatThread>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  final service = ref.read(supabaseServiceProvider);
  return service.getBuyerThreads(userId);
});

final buyerThreadsStreamProvider = StreamProvider<List<ChatThread>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    return Stream.value(const <ChatThread>[]);
  }
  final service = ref.read(supabaseServiceProvider);
  return service.watchBuyerThreads(userId);
});

final buyerUnreadThreadsCountProvider = Provider<int>((ref) {
  final streamThreads = ref.watch(buyerThreadsStreamProvider).value;
  final threads = streamThreads ?? ref.watch(buyerThreadsProvider).value ?? [];
  return threads.where((thread) => thread.unreadCount > 0).length;
});

final notificationsStreamProvider = StreamProvider<List<AppNotification>>((
  ref,
) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(const <AppNotification>[]);
  final service = ref.read(supabaseServiceProvider);
  return service.watchNotifications(userId);
});

final buyerChatThreadProvider = FutureProvider.family<ChatThread, String>((
  ref,
  threadId,
) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) throw Exception('Not authenticated');
  final service = ref.read(supabaseServiceProvider);
  return service.getThread(threadId, userId);
});

final buyerThreadMessagesProvider =
    StreamProvider.family<List<ChatMessage>, String>((ref, threadId) {
      final service = ref.read(supabaseServiceProvider);
      return service.watchThreadMessages(threadId);
    });

final buyerActiveDisputeProvider = FutureProvider.family<DisputeCase?, String>((
  ref,
  orderId,
) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  final service = ref.read(supabaseServiceProvider);
  return service.getActiveDisputeForOrder(orderId, userId);
});

final buyerActiveDisputeStreamProvider =
    StreamProvider.family<DisputeCase?, String>((ref, orderId) {
      final userId = ref.watch(currentUserIdProvider);
      if (userId == null) return Stream.value(null);
      final service = ref.read(supabaseServiceProvider);
      return service.watchActiveDisputeForOrder(orderId, userId);
    });

final buyerDisputeMessagesProvider =
    StreamProvider.family<List<ChatMessage>, String>((ref, conversationId) {
      final service = ref.read(supabaseServiceProvider);
      return service.watchDisputeMessages(conversationId);
    });

// ── Products ────────────────────────────────────────────────────
final featuredProductsProvider = FutureProvider<List<Product>>((ref) async {
  final service = ref.read(supabaseServiceProvider);
  return service.getFeaturedProducts(limit: 10);
});

final curatedCollectionProductsProvider = FutureProvider<List<Product>>((
  ref,
) async {
  final service = ref.read(supabaseServiceProvider);
  return service.getAllProducts(featured: true, sortBy: 'featured_at');
});

final onSaleProductsProvider = FutureProvider<List<Product>>((ref) async {
  final service = ref.read(supabaseServiceProvider);
  return service.getOnSaleProducts(limit: 10);
});

final freshArrivalsProvider = FutureProvider<List<Product>>((ref) async {
  final service = ref.read(supabaseServiceProvider);
  return service.getProducts(limit: 10);
});

/// Filter parameters for category product browsing.
class CategoryProductFilter {
  final String categoryId;
  final String? subcategoryId;
  final List<String> tags;
  final bool onSale;
  final bool featured;
  final String sortBy;
  final bool ascending;

  const CategoryProductFilter({
    required this.categoryId,
    this.subcategoryId,
    this.tags = const [],
    this.onSale = false,
    this.featured = false,
    this.sortBy = 'created_at',
    this.ascending = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryProductFilter &&
          other.categoryId == categoryId &&
          other.subcategoryId == subcategoryId &&
          _listEq(other.tags, tags) &&
          other.onSale == onSale &&
          other.featured == featured &&
          other.sortBy == sortBy &&
          other.ascending == ascending;

  @override
  int get hashCode => Object.hash(
    categoryId,
    subcategoryId,
    Object.hashAll(tags),
    onSale,
    featured,
    sortBy,
    ascending,
  );

  static bool _listEq(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

final categoryProductsProvider =
    FutureProvider.family<List<Product>, CategoryProductFilter>((
      ref,
      filter,
    ) async {
      final service = ref.read(supabaseServiceProvider);
      return service.getAllProducts(
        // An empty categoryId means "shop all": no category filter.
        categoryId: filter.categoryId.isEmpty ? null : filter.categoryId,
        subcategoryId: filter.subcategoryId,
        tags: filter.tags.isNotEmpty ? filter.tags : null,
        onSale: filter.onSale ? true : null,
        featured: filter.featured ? true : null,
        sortBy: filter.sortBy,
        ascending: filter.ascending,
      );
    });

final shopProductsProvider = FutureProvider.family<List<Product>, String>((
  ref,
  shopId,
) async {
  final service = ref.read(supabaseServiceProvider);
  return service.getAllProducts(shopId: shopId);
});

final productDetailProvider = FutureProvider.family<Product, String>((
  ref,
  productId,
) async {
  final service = ref.read(supabaseServiceProvider);
  final product = await service.getProduct(productId, buyerVisibleOnly: true);
  if (!isBuyerVisibleProduct(product)) {
    throw StateError('This product is no longer available.');
  }
  return product;
});

final searchProductsProvider = FutureProvider.family<List<Product>, String>((
  ref,
  query,
) async {
  final service = ref.read(supabaseServiceProvider);
  return service.getProducts(search: query);
});

// ── Shops ───────────────────────────────────────────────────────
final shopShippingOptionsProvider =
    FutureProvider.family<List<ShippingOption>, String>((ref, shopId) async {
      final service = ref.read(supabaseServiceProvider);
      return service.getShopShippingOptions(shopId);
    });

final shopsProvider = FutureProvider<List<Shop>>((ref) async {
  final service = ref.read(supabaseServiceProvider);
  return service.getShops();
});

final spotlightShopsProvider = FutureProvider<List<Shop>>((ref) async {
  final service = ref.read(supabaseServiceProvider);
  return service.getSpotlightShops();
});

final shopDetailProvider = FutureProvider.family<Shop, String>((
  ref,
  shopId,
) async {
  final service = ref.read(supabaseServiceProvider);
  return service.getShop(shopId);
});

final shopMarketEventsProvider =
    FutureProvider.family<List<ShopMarketEvent>, String>((ref, shopId) async {
      final service = ref.read(supabaseServiceProvider);
      return service.getShopMarketEvents(shopId);
    });

final shopReviewsProvider = FutureProvider.family<List<ShopReview>, String>((
  ref,
  shopId,
) async {
  final service = ref.read(supabaseServiceProvider);
  return service.getShopReviews(shopId);
});

final shopReviewSummaryProvider = FutureProvider.family<ReviewSummary, String>((
  ref,
  shopId,
) async {
  final service = ref.read(supabaseServiceProvider);
  return service.getShopReviewSummary(shopId);
});

final canReviewShopProvider = FutureProvider.family<bool, String>((
  ref,
  shopId,
) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return false;
  final service = ref.read(supabaseServiceProvider);
  return service.canReviewShop(shopId, userId);
});

final productReviewsProvider =
    FutureProvider.family<List<ProductReview>, String>((ref, productId) async {
      final service = ref.read(supabaseServiceProvider);
      return service.getProductReviews(productId);
    });

final productReviewSummaryProvider =
    FutureProvider.family<ReviewSummary, String>((ref, productId) async {
      final service = ref.read(supabaseServiceProvider);
      return service.getProductReviewSummary(productId);
    });

final canReviewProductProvider = FutureProvider.family<bool, String>((
  ref,
  productId,
) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return false;
  final service = ref.read(supabaseServiceProvider);
  return service.canReviewProduct(productId, userId);
});

// ── Favourites ──────────────────────────────────────────────────
final favouriteProductsProvider = FutureProvider<List<Product>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  final service = ref.read(supabaseServiceProvider);
  return service.getFavourites(userId);
});

final favouriteIdsProvider = FutureProvider<List<String>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  final service = ref.read(supabaseServiceProvider);
  return service.getFavouriteProductIds(userId);
});

final favouriteIdsStreamProvider = StreamProvider<List<String>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(const <String>[]);
  final service = ref.read(supabaseServiceProvider);
  return service.watchFavouriteProductIds(userId);
});

List<String> resolveFavouriteIds({
  List<String>? liveIds,
  List<String>? loadedIds,
}) {
  return liveIds ?? loadedIds ?? const <String>[];
}

final currentFavouriteIdsProvider = Provider<List<String>>((ref) {
  final liveIds = ref.watch(favouriteIdsStreamProvider).value;
  final loadedIds = ref.watch(favouriteIdsProvider).value;
  return resolveFavouriteIds(liveIds: liveIds, loadedIds: loadedIds);
});

// ── Cart ────────────────────────────────────────────────────────
final cartItemsProvider = FutureProvider<List<CartItem>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  final service = ref.read(supabaseServiceProvider);
  return service.getCartItems(userId);
});

// ── Orders ──────────────────────────────────────────────────────
final ordersProvider = FutureProvider<List<Order>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  final service = ref.read(supabaseServiceProvider);
  return service.getOrders(userId);
});

final ordersStreamProvider = StreamProvider<List<Order>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(const <Order>[]);
  final service = ref.read(supabaseServiceProvider);
  return service.watchOrders(userId);
});

final buyerDisputedOrdersProvider = Provider<List<Order>>((ref) {
  final streamOrders = ref.watch(ordersStreamProvider).value;
  final orders =
      streamOrders ?? ref.watch(ordersProvider).value ?? const <Order>[];
  return orders.where((order) => order.status == 'disputed').toList();
});

final orderDetailProvider = FutureProvider.family<Order, String>((
  ref,
  orderId,
) async {
  final service = ref.read(supabaseServiceProvider);
  return service.getOrder(orderId);
});

final orderDetailStreamProvider = StreamProvider.family<Order, String>((
  ref,
  orderId,
) {
  final service = ref.read(supabaseServiceProvider);
  return service.watchOrder(orderId);
});

// ── Shop Follows ────────────────────────────────────────────────
final followedShopIdsProvider = FutureProvider<List<String>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  final service = ref.read(supabaseServiceProvider);
  return service.getFollowedShopIds(userId);
});

final isFollowingProvider = FutureProvider.family<bool, String>((
  ref,
  shopId,
) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return false;
  final service = ref.read(supabaseServiceProvider);
  return service.isFollowing(userId, shopId);
});

final followerCountProvider = FutureProvider.family<int, String>((
  ref,
  shopId,
) async {
  final service = ref.read(supabaseServiceProvider);
  return service.getFollowerCount(shopId);
});

// ── Shop Posts ──────────────────────────────────────────────────
final shopPostsProvider = FutureProvider.family<List<ShopPost>, String>((
  ref,
  shopId,
) async {
  final service = ref.read(supabaseServiceProvider);
  return service.getShopPosts(shopId);
});

final followingFeedProvider = FutureProvider<List<ShopPost>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  final service = ref.read(supabaseServiceProvider);
  return service.getFollowingFeed(userId);
});

// ── Profile ─────────────────────────────────────────────────────
final profileProvider = FutureProvider<Profile>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) throw Exception('Not authenticated');
  final service = ref.read(supabaseServiceProvider);
  return service.getProfile(userId);
});
