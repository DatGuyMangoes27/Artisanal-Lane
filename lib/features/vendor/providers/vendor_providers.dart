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

final vendorMarketEventsProvider = FutureProvider<List<ShopMarketEvent>>((
  ref,
) async {
  final shop = await ref.watch(vendorShopProvider.future);
  if (shop == null) return [];
  final service = ref.read(supabaseServiceProvider);
  return service.getShopMarketEvents(
    shop.id,
    upcomingOnly: false,
    includeInactive: true,
  );
});

// ── Chat ────────────────────────────────────────────────────────
final vendorThreadsProvider = FutureProvider<List<ChatThread>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  final service = ref.read(supabaseServiceProvider);
  return service.getVendorThreads(userId);
});

final vendorThreadsStreamProvider = StreamProvider<List<ChatThread>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    return Stream.value(const <ChatThread>[]);
  }
  final service = ref.read(supabaseServiceProvider);
  return service.watchVendorThreads(userId);
});

final vendorUnreadThreadsCountProvider = Provider<int>((ref) {
  final streamThreads = ref.watch(vendorThreadsStreamProvider).value;
  final threads = streamThreads ?? ref.watch(vendorThreadsProvider).value ?? [];
  return threads.where((thread) => thread.unreadCount > 0).length;
});

final vendorChatThreadProvider = FutureProvider.family<ChatThread, String>((
  ref,
  threadId,
) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) throw Exception('Not authenticated');
  final service = ref.read(supabaseServiceProvider);
  return service.getThread(threadId, userId);
});

final vendorThreadMessagesProvider =
    StreamProvider.family<List<ChatMessage>, String>((ref, threadId) {
      final service = ref.read(supabaseServiceProvider);
      return service.watchThreadMessages(threadId);
    });

final vendorActiveDisputeProvider =
    FutureProvider.family<DisputeCase?, String>((ref, orderId) async {
      final userId = ref.watch(currentUserIdProvider);
      if (userId == null) return null;
      final service = ref.read(supabaseServiceProvider);
      return service.getActiveDisputeForOrder(orderId, userId);
    });

final vendorActiveDisputeStreamProvider =
    StreamProvider.family<DisputeCase?, String>((ref, orderId) {
      final userId = ref.watch(currentUserIdProvider);
      if (userId == null) return Stream.value(null);
      final service = ref.read(supabaseServiceProvider);
      return service.watchActiveDisputeForOrder(orderId, userId);
    });

final vendorDisputeMessagesProvider =
    StreamProvider.family<List<ChatMessage>, String>((ref, conversationId) {
      final service = ref.read(supabaseServiceProvider);
      return service.watchDisputeMessages(conversationId);
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

final vendorOrdersStreamProvider = StreamProvider<List<Order>>((ref) async* {
  final shop = await ref.watch(vendorShopProvider.future);
  if (shop == null) {
    yield const <Order>[];
    return;
  }
  final service = ref.read(supabaseServiceProvider);
  yield* service.watchShopOrders(shop.id);
});

final vendorOrderDetailProvider = FutureProvider.family<Order, String>((
  ref,
  orderId,
) async {
  final service = ref.read(supabaseServiceProvider);
  return service.getOrder(orderId);
});

final vendorOrderDetailStreamProvider = StreamProvider.family<Order, String>((
  ref,
  orderId,
) {
  final service = ref.read(supabaseServiceProvider);
  return service.watchOrder(orderId);
});

// ── Vendor Earnings ─────────────────────────────────────────────
final vendorEarningsProvider = FutureProvider<Map<String, double>>((ref) async {
  final shop = await ref.watch(vendorShopProvider.future);
  if (shop == null) {
    return {'totalSales': 0, 'held': 0, 'released': 0, 'fees': 0};
  }
  final service = ref.read(supabaseServiceProvider);
  return service.getShopEarnings(shop.id);
});

final vendorPayoutProfileProvider = FutureProvider<VendorPayoutProfile?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  final service = ref.read(supabaseServiceProvider);
  return service.getVendorPayoutProfile(userId);
});

final vendorPayoutProfileStreamProvider =
    StreamProvider<VendorPayoutProfile?>((ref) {
      final userId = ref.watch(currentUserIdProvider);
      if (userId == null) {
        return Stream.value(null);
      }
      final service = ref.read(supabaseServiceProvider);
      return service.watchVendorPayoutProfile(userId);
    });

// ── Vendor Application ──────────────────────────────────────────
final vendorApplicationProvider = FutureProvider<VendorApplication?>((
  ref,
) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  final service = ref.read(supabaseServiceProvider);
  return service.getVendorApplication(userId);
});

final vendorApplicationStreamProvider = StreamProvider<VendorApplication?>((
  ref,
) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    return Stream.value(null);
  }
  final service = ref.read(supabaseServiceProvider);
  return service.watchVendorApplication(userId);
});

// ── Vendor Posts ────────────────────────────────────────────────
final vendorPostsProvider = FutureProvider<List<ShopPost>>((ref) async {
  final shop = await ref.watch(vendorShopProvider.future);
  if (shop == null) return [];
  final service = ref.read(supabaseServiceProvider);
  return service.getShopPosts(shop.id);
});

final vendorStationeryRequestsProvider =
    FutureProvider<List<StationeryRequest>>((ref) async {
      final userId = ref.watch(currentUserIdProvider);
      if (userId == null) return [];
      final service = ref.read(supabaseServiceProvider);
      return service.getVendorStationeryRequests(userId);
    });

final vendorStationeryRequestsStreamProvider =
    StreamProvider<List<StationeryRequest>>((ref) {
      final userId = ref.watch(currentUserIdProvider);
      if (userId == null) {
        return Stream.value(const <StationeryRequest>[]);
      }
      final service = ref.read(supabaseServiceProvider);
      return service.watchVendorStationeryRequests(userId);
    });

// ── Categories (for product form) ──────────────────────────────
final vendorCategoriesProvider = FutureProvider<List<Category>>((ref) async {
  final service = ref.read(supabaseServiceProvider);
  return service.getCategories();
});

// ── Subcategories (for product form, keyed by categoryId) ─────
final vendorSubcategoriesProvider =
    FutureProvider.family<List<Subcategory>, String>((ref, categoryId) async {
      final service = ref.read(supabaseServiceProvider);
      return service.getSubcategories(categoryId);
    });
