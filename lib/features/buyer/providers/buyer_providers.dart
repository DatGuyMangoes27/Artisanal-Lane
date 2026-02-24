import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/models.dart';
import '../../auth/providers/auth_providers.dart';

// Re-export core providers so existing imports still work
export '../../auth/providers/auth_providers.dart'
    show supabaseClientProvider, supabaseServiceProvider, currentUserIdProvider;

// ── Categories ──────────────────────────────────────────────────
final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final service = ref.read(supabaseServiceProvider);
  return service.getCategories();
});

// ── Products ────────────────────────────────────────────────────
final featuredProductsProvider = FutureProvider<List<Product>>((ref) async {
  final service = ref.read(supabaseServiceProvider);
  return service.getFeaturedProducts(limit: 10);
});

final onSaleProductsProvider = FutureProvider<List<Product>>((ref) async {
  final service = ref.read(supabaseServiceProvider);
  return service.getOnSaleProducts(limit: 10);
});

final categoryProductsProvider =
    FutureProvider.family<List<Product>, String>((ref, categoryId) async {
  final service = ref.read(supabaseServiceProvider);
  return service.getProducts(categoryId: categoryId);
});

final shopProductsProvider =
    FutureProvider.family<List<Product>, String>((ref, shopId) async {
  final service = ref.read(supabaseServiceProvider);
  return service.getProducts(shopId: shopId);
});

final productDetailProvider =
    FutureProvider.family<Product, String>((ref, productId) async {
  final service = ref.read(supabaseServiceProvider);
  return service.getProduct(productId);
});

final searchProductsProvider =
    FutureProvider.family<List<Product>, String>((ref, query) async {
  final service = ref.read(supabaseServiceProvider);
  return service.getProducts(search: query);
});

// ── Shops ───────────────────────────────────────────────────────
final shopsProvider = FutureProvider<List<Shop>>((ref) async {
  final service = ref.read(supabaseServiceProvider);
  return service.getShops();
});

final shopDetailProvider =
    FutureProvider.family<Shop, String>((ref, shopId) async {
  final service = ref.read(supabaseServiceProvider);
  return service.getShop(shopId);
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

final orderDetailProvider =
    FutureProvider.family<Order, String>((ref, orderId) async {
  final service = ref.read(supabaseServiceProvider);
  return service.getOrder(orderId);
});

// ── Shop Follows ────────────────────────────────────────────────
final followedShopIdsProvider = FutureProvider<List<String>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  final service = ref.read(supabaseServiceProvider);
  return service.getFollowedShopIds(userId);
});

final isFollowingProvider =
    FutureProvider.family<bool, String>((ref, shopId) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return false;
  final service = ref.read(supabaseServiceProvider);
  return service.isFollowing(userId, shopId);
});

final followerCountProvider =
    FutureProvider.family<int, String>((ref, shopId) async {
  final service = ref.read(supabaseServiceProvider);
  return service.getFollowerCount(shopId);
});

// ── Shop Posts ──────────────────────────────────────────────────
final shopPostsProvider =
    FutureProvider.family<List<ShopPost>, String>((ref, shopId) async {
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
