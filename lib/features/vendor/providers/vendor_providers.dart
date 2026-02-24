import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/models.dart';
import '../../auth/providers/auth_providers.dart';

// ── Vendor Shop ─────────────────────────────────────────────────
final vendorShopProvider = FutureProvider<Shop?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) throw Exception('Not authenticated');
  final service = ref.read(supabaseServiceProvider);
  return service.getVendorShop(userId);
});

// ── Vendor Products ─────────────────────────────────────────────
final vendorProductsProvider = FutureProvider<List<Product>>((ref) async {
  final shop = await ref.watch(vendorShopProvider.future);
  if (shop == null) return [];
  final service = ref.read(supabaseServiceProvider);
  return service.getVendorProducts(shop.id);
});

// ── Vendor Orders ───────────────────────────────────────────────
final vendorOrdersProvider = FutureProvider<List<Order>>((ref) async {
  final shop = await ref.watch(vendorShopProvider.future);
  if (shop == null) return [];
  final service = ref.read(supabaseServiceProvider);
  return service.getShopOrders(shop.id);
});

final vendorOrderDetailProvider =
    FutureProvider.family<Order, String>((ref, orderId) async {
  final service = ref.read(supabaseServiceProvider);
  return service.getOrder(orderId);
});

// ── Vendor Earnings ─────────────────────────────────────────────
final vendorEarningsProvider = FutureProvider<Map<String, double>>((ref) async {
  final shop = await ref.watch(vendorShopProvider.future);
  if (shop == null) return {'totalSales': 0, 'held': 0, 'released': 0, 'fees': 0};
  final service = ref.read(supabaseServiceProvider);
  return service.getShopEarnings(shop.id);
});

// ── Vendor Application ──────────────────────────────────────────
final vendorApplicationProvider =
    FutureProvider<VendorApplication?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  final service = ref.read(supabaseServiceProvider);
  return service.getVendorApplication(userId);
});

// ── Vendor Posts ────────────────────────────────────────────────
final vendorPostsProvider = FutureProvider<List<ShopPost>>((ref) async {
  final shop = await ref.watch(vendorShopProvider.future);
  if (shop == null) return [];
  final service = ref.read(supabaseServiceProvider);
  return service.getShopPosts(shop.id);
});

// ── Categories (for product form) ──────────────────────────────
final vendorCategoriesProvider = FutureProvider<List<Category>>((ref) async {
  final service = ref.read(supabaseServiceProvider);
  return service.getCategories();
});
