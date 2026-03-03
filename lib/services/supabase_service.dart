import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

class SupabaseService {
  final SupabaseClient _client;

  SupabaseService(this._client);

  // ── Storage ─────────────────────────────────────────────────
  static String _mimeType(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      default:
        return 'image/jpeg';
    }
  }

  Future<String> uploadProductImage(String userId, File imageFile) async {
    final ext = imageFile.path.split('.').last.toLowerCase();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final storagePath = '$userId/$fileName';

    await _client.storage.from('product-images').upload(
          storagePath,
          imageFile,
          fileOptions: FileOptions(contentType: _mimeType(ext)),
        );

    return _client.storage.from('product-images').getPublicUrl(storagePath);
  }

  Future<String> uploadShopImage(String userId, File imageFile, {String folder = 'general'}) async {
    final ext = imageFile.path.split('.').last.toLowerCase();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final storagePath = '$userId/$folder/$fileName';

    await _client.storage.from('shop-assets').upload(
          storagePath,
          imageFile,
          fileOptions: FileOptions(contentType: _mimeType(ext)),
        );

    return _client.storage.from('shop-assets').getPublicUrl(storagePath);
  }

  // ── Categories ────────────────────────────────────────────────
  Future<List<Category>> getCategories() async {
    final data = await _client
        .from('categories')
        .select()
        .order('sort_order', ascending: true);
    return (data as List).map((e) => Category.fromJson(e)).toList();
  }

  Future<List<String>> getTrendingSearches() async {
    final data = await _client
        .from('trending_searches')
        .select('term')
        .eq('is_active', true)
        .order('sort_order', ascending: true);
    return (data as List).map((e) => e['term'] as String).toList();
  }

  // ── Products ──────────────────────────────────────────────────
  Future<List<Product>> getProducts({
    String? categoryId,
    String? shopId,
    String? search,
    String sortBy = 'created_at',
    bool ascending = false,
    int limit = 20,
    int offset = 0,
  }) async {
    var query = _client
        .from('products')
        .select('*, shops(name, logo_url), categories(name)')
        .eq('is_published', true);

    if (categoryId != null) {
      query = query.eq('category_id', categoryId);
    }
    if (shopId != null) {
      query = query.eq('shop_id', shopId);
    }
    if (search != null && search.isNotEmpty) {
      query = query.ilike('title', '%$search%');
    }

    final data = await query
        .order(sortBy, ascending: ascending)
        .range(offset, offset + limit - 1);

    return (data as List).map((e) => Product.fromJson(e)).toList();
  }

  Future<List<Product>> getFeaturedProducts({int limit = 10}) async {
    final data = await _client
        .from('products')
        .select('*, shops(name, logo_url), categories(name)')
        .eq('is_published', true)
        .order('created_at', ascending: false)
        .limit(limit);
    return (data as List).map((e) => Product.fromJson(e)).toList();
  }

  Future<List<Product>> getOnSaleProducts({int limit = 10}) async {
    final data = await _client
        .from('products')
        .select('*, shops(name, logo_url), categories(name)')
        .eq('is_published', true)
        .not('compare_at_price', 'is', null)
        .order('created_at', ascending: false)
        .limit(limit);
    return (data as List).map((e) => Product.fromJson(e)).toList();
  }

  Future<Product> getProduct(String id) async {
    final data = await _client
        .from('products')
        .select('*, shops(name, logo_url, slug, bio, location), categories(name)')
        .eq('id', id)
        .single();
    return Product.fromJson(data);
  }

  // ── Shops ─────────────────────────────────────────────────────
  Future<List<Shop>> getShops() async {
    final data = await _client
        .from('shops')
        .select()
        .eq('is_active', true)
        .order('name', ascending: true);
    return (data as List).map((e) => Shop.fromJson(e)).toList();
  }

  Future<Shop> getShop(String id) async {
    final data =
        await _client.from('shops').select().eq('id', id).single();
    return Shop.fromJson(data);
  }

  Future<List<ShippingOption>> getShopShippingOptions(String shopId) async {
    final data = await _client
        .from('shops')
        .select('shipping_options')
        .eq('id', shopId)
        .single();
    return ShippingOption.listFromJson(data['shipping_options']);
  }

  Future<void> updateShopShippingOptions(
      String shopId, List<ShippingOption> options) async {
    await _client.from('shops').update({
      'shipping_options': options.map((o) => o.toJson()).toList(),
    }).eq('id', shopId);
  }

  Future<void> setShopOfflineMode(
    String shopId, {
    required bool isOffline,
    DateTime? backToWorkDate,
  }) async {
    await _client.from('shops').update({
      'is_offline': isOffline,
      'back_to_work_date': isOffline && backToWorkDate != null
          ? backToWorkDate.toIso8601String().split('T').first
          : null,
    }).eq('id', shopId);
  }

  // ── Stationery Requests ───────────────────────────────────────
  Future<void> submitStationeryRequest({
    required String shopId,
    required String vendorId,
    required List<Map<String, dynamic>> items,
    String? notes,
    String? deliveryAddress,
  }) async {
    await _client.from('stationery_requests').insert({
      'shop_id': shopId,
      'vendor_id': vendorId,
      'items': items,
      'notes': notes,
      'delivery_address': deliveryAddress,
    });
  }

  Future<void> submitSupportTicket({
    required String userId,
    String? shopId,
    required String subject,
    required String message,
  }) async {
    await _client.from('support_tickets').insert({
      'user_id': userId,
      'shop_id': shopId,
      'subject': subject,
      'message': message,
    });
  }

  // ── Favourites ────────────────────────────────────────────────
  Future<List<Product>> getFavourites(String userId) async {
    final data = await _client
        .from('favourites')
        .select('product_id, products(*, shops(name, logo_url), categories(name))')
        .eq('user_id', userId);
    return (data as List)
        .map((e) => Product.fromJson(e['products'] as Map<String, dynamic>))
        .toList();
  }

  Future<List<String>> getFavouriteProductIds(String userId) async {
    final data = await _client
        .from('favourites')
        .select('product_id')
        .eq('user_id', userId);
    return (data as List).map((e) => e['product_id'] as String).toList();
  }

  Future<void> addFavourite(String userId, String productId) async {
    await _client
        .from('favourites')
        .upsert({'user_id': userId, 'product_id': productId});
  }

  Future<void> removeFavourite(String userId, String productId) async {
    await _client
        .from('favourites')
        .delete()
        .eq('user_id', userId)
        .eq('product_id', productId);
  }

  // ── Cart ──────────────────────────────────────────────────────
  Future<List<CartItem>> getCartItems(String userId) async {
    // Get or create cart
    var cartData = await _client
        .from('carts')
        .select('id')
        .eq('user_id', userId)
        .maybeSingle();

    cartData ??= await _client
        .from('carts')
        .insert({'user_id': userId})
        .select('id')
        .single();

    final cartId = cartData['id'] as String;

    // Remove items that are older than kCartExpiryHours
    final expiryCutoff = DateTime.now()
        .toUtc()
        .subtract(const Duration(hours: kCartExpiryHours))
        .toIso8601String();
    await _client
        .from('cart_items')
        .delete()
        .eq('cart_id', cartId)
        .lt('created_at', expiryCutoff);

    final items = await _client
        .from('cart_items')
        .select('*, products(*, shops(name, logo_url), categories(name))')
        .eq('cart_id', cartId);

    return (items as List).map((e) => CartItem.fromJson(e)).toList();
  }

  Future<void> addToCart(String userId, String productId, {int quantity = 1}) async {
    var cartData = await _client
        .from('carts')
        .select('id')
        .eq('user_id', userId)
        .maybeSingle();

    cartData ??= await _client
        .from('carts')
        .insert({'user_id': userId})
        .select('id')
        .single();

    final cartId = cartData['id'] as String;

    final existing = await _client
        .from('cart_items')
        .select('id, quantity')
        .eq('cart_id', cartId)
        .eq('product_id', productId)
        .maybeSingle();

    if (existing != null) {
      final newQty = (existing['quantity'] as int) + quantity;
      await _client
          .from('cart_items')
          .update({'quantity': newQty})
          .eq('id', existing['id'] as String);
    } else {
      await _client.from('cart_items').insert({
        'cart_id': cartId,
        'product_id': productId,
        'quantity': quantity,
      });
    }
  }

  Future<void> updateCartItemQuantity(String cartItemId, int quantity) async {
    await _client
        .from('cart_items')
        .update({'quantity': quantity})
        .eq('id', cartItemId);
  }

  Future<void> removeCartItem(String cartItemId) async {
    await _client.from('cart_items').delete().eq('id', cartItemId);
  }

  // ── Orders ────────────────────────────────────────────────────
  Future<List<Order>> getOrders(String userId) async {
    final data = await _client
        .from('orders')
        .select('*, shops(name), order_items(*, products(title, images))')
        .eq('buyer_id', userId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => Order.fromJson(e)).toList();
  }

  Future<Order> getOrder(String id) async {
    final data = await _client
        .from('orders')
        .select('*, shops(name), order_items(*, products(title, images))')
        .eq('id', id)
        .single();
    return Order.fromJson(data);
  }

  // ── Shop Follows ─────────────────────────────────────────────
  Future<void> followShop(String userId, String shopId) async {
    await _client
        .from('shop_follows')
        .upsert({'user_id': userId, 'shop_id': shopId});
  }

  Future<void> unfollowShop(String userId, String shopId) async {
    await _client
        .from('shop_follows')
        .delete()
        .eq('user_id', userId)
        .eq('shop_id', shopId);
  }

  Future<List<String>> getFollowedShopIds(String userId) async {
    final data = await _client
        .from('shop_follows')
        .select('shop_id')
        .eq('user_id', userId);
    return (data as List).map((e) => e['shop_id'] as String).toList();
  }

  Future<bool> isFollowing(String userId, String shopId) async {
    final data = await _client
        .from('shop_follows')
        .select('id')
        .eq('user_id', userId)
        .eq('shop_id', shopId)
        .maybeSingle();
    return data != null;
  }

  Future<int> getFollowerCount(String shopId) async {
    final data = await _client
        .from('shop_follows')
        .select('id')
        .eq('shop_id', shopId);
    return (data as List).length;
  }

  // ── Shop Posts ──────────────────────────────────────────────
  Future<List<ShopPost>> getShopPosts(
    String shopId, {
    int limit = 20,
    int offset = 0,
  }) async {
    final data = await _client
        .from('shop_posts')
        .select('*, shops(name, logo_url)')
        .eq('shop_id', shopId)
        .eq('is_published', true)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return (data as List).map((e) => ShopPost.fromJson(e)).toList();
  }

  Future<List<ShopPost>> getFollowingFeed(
    String userId, {
    int limit = 20,
    int offset = 0,
  }) async {
    // First get followed shop IDs
    final followedIds = await getFollowedShopIds(userId);
    if (followedIds.isEmpty) return [];

    final data = await _client
        .from('shop_posts')
        .select('*, shops(name, logo_url)')
        .inFilter('shop_id', followedIds)
        .eq('is_published', true)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return (data as List).map((e) => ShopPost.fromJson(e)).toList();
  }

  // ── Profile ───────────────────────────────────────────────────
  Future<Profile> getProfile(String userId) async {
    final data =
        await _client.from('profiles').select().eq('id', userId).single();
    return Profile.fromJson(data);
  }

  Future<void> updateProfile(String userId, Map<String, dynamic> updates) async {
    await _client.from('profiles').update(updates).eq('id', userId);
  }

  // ── Order Creation ─────────────────────────────────────────────
  Future<Order> createOrder({
    required String userId,
    required String shopId,
    required List<CartItem> items,
    required Map<String, dynamic> shippingAddress,
    required String shippingMethod,
    required double shippingCost,
    bool isGift = false,
    String? giftRecipient,
    String? giftMessage,
  }) async {
    final subtotal = items.fold<double>(
      0,
      (sum, item) => sum + (item.product?.price ?? 0) * item.quantity,
    );

    final orderData = await _client
        .from('orders')
        .insert({
          'buyer_id': userId,
          'shop_id': shopId,
          'status': 'paid',
          'total': subtotal,
          'shipping_cost': shippingCost,
          'shipping_method': shippingMethod,
          'shipping_address': shippingAddress,
          'is_gift': isGift,
          if (isGift && giftRecipient != null && giftRecipient.isNotEmpty)
            'gift_recipient': giftRecipient,
          if (isGift && giftMessage != null && giftMessage.isNotEmpty)
            'gift_message': giftMessage,
        })
        .select()
        .single();

    final orderId = orderData['id'] as String;

    for (final item in items) {
      await _client.from('order_items').insert({
        'order_id': orderId,
        'product_id': item.productId,
        'quantity': item.quantity,
        'unit_price': item.product?.price ?? 0,
      });
    }

    await _client.from('escrow_transactions').insert({
      'order_id': orderId,
      'amount': subtotal + shippingCost,
      'platform_fee': (subtotal + shippingCost) * 0.05,
      'status': 'held',
    });

    return getOrder(orderId);
  }

  Future<void> clearCart(String userId) async {
    final cartData = await _client
        .from('carts')
        .select('id')
        .eq('user_id', userId)
        .maybeSingle();

    if (cartData != null) {
      await _client
          .from('cart_items')
          .delete()
          .eq('cart_id', cartData['id'] as String);
    }
  }

  Future<void> confirmReceipt(String orderId) async {
    await _client
        .from('orders')
        .update({'status': 'completed'})
        .eq('id', orderId);

    await _client
        .from('escrow_transactions')
        .update({'status': 'released', 'released_at': DateTime.now().toIso8601String()})
        .eq('order_id', orderId);
  }

  Future<void> createDispute(String orderId, String raisedBy, String reason) async {
    await _client.from('disputes').insert({
      'order_id': orderId,
      'raised_by': raisedBy,
      'reason': reason,
      'status': 'open',
    });

    await _client
        .from('orders')
        .update({'status': 'disputed'})
        .eq('id', orderId);
  }

  // ── Addresses ──────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getSavedAddresses(String userId) async {
    final data = await _client
        .from('profiles')
        .select('shipping_addresses')
        .eq('id', userId)
        .single();
    final addresses = data['shipping_addresses'];
    if (addresses == null) return [];
    return (addresses as List).cast<Map<String, dynamic>>();
  }

  Future<void> saveAddresses(String userId, List<Map<String, dynamic>> addresses) async {
    await _client
        .from('profiles')
        .update({'shipping_addresses': addresses})
        .eq('id', userId);
  }

  // ══════════════════════════════════════════════════════════════
  //  VENDOR SERVICE METHODS
  // ══════════════════════════════════════════════════════════════

  // ── Vendor Shop ─────────────────────────────────────────────
  Future<Shop?> getVendorShop(String vendorId) async {
    final data = await _client
        .from('shops')
        .select()
        .eq('vendor_id', vendorId)
        .maybeSingle();
    if (data == null) return null;
    return Shop.fromJson(data);
  }

  Future<void> updateShop(String shopId, Map<String, dynamic> updates) async {
    await _client.from('shops').update(updates).eq('id', shopId);
  }

  // ── Vendor Products ─────────────────────────────────────────
  Future<List<Product>> getVendorProducts(String shopId) async {
    final data = await _client
        .from('products')
        .select('*, categories(name)')
        .eq('shop_id', shopId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => Product.fromJson(e)).toList();
  }

  Future<Product> createProduct(String shopId, Map<String, dynamic> data) async {
    final row = await _client
        .from('products')
        .insert({
          'shop_id': shopId,
          ...data,
        })
        .select('*, categories(name)')
        .single();
    return Product.fromJson(row);
  }

  Future<void> updateProduct(String productId, Map<String, dynamic> updates) async {
    await _client.from('products').update(updates).eq('id', productId);
  }

  Future<void> deleteProduct(String productId) async {
    await _client.from('products').delete().eq('id', productId);
  }

  // ── Vendor Orders ───────────────────────────────────────────
  Future<List<Order>> getShopOrders(String shopId) async {
    final data = await _client
        .from('orders')
        .select('*, order_items(*, products(title, images))')
        .eq('shop_id', shopId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => Order.fromJson(e)).toList();
  }

  Future<void> updateOrderStatus(
    String orderId,
    String status, {
    String? trackingNumber,
  }) async {
    final updates = <String, dynamic>{'status': status};
    if (trackingNumber != null) {
      updates['tracking_number'] = trackingNumber;
    }
    await _client.from('orders').update(updates).eq('id', orderId);
  }

  // ── Vendor Earnings ─────────────────────────────────────────
  Future<Map<String, double>> getShopEarnings(String shopId) async {
    final orders = await _client
        .from('orders')
        .select('id, total, shipping_cost')
        .eq('shop_id', shopId);

    if ((orders as List).isEmpty) {
      return {'totalSales': 0, 'held': 0, 'released': 0, 'fees': 0};
    }

    final orderIds = (orders).map((o) => o['id'] as String).toList();

    final escrowData = await _client
        .from('escrow_transactions')
        .select()
        .inFilter('order_id', orderIds);

    double held = 0;
    double released = 0;
    double fees = 0;
    double totalSales = 0;

    for (final e in escrowData as List) {
      final amount = (e['amount'] as num).toDouble();
      final fee = (e['platform_fee'] as num?)?.toDouble() ?? 0;
      fees += fee;
      totalSales += amount;
      if (e['status'] == 'held') held += amount;
      if (e['status'] == 'released') released += (amount - fee);
    }

    return {
      'totalSales': totalSales,
      'held': held,
      'released': released,
      'fees': fees,
    };
  }

  // ── Vendor Application ──────────────────────────────────────
  Future<VendorApplication?> getVendorApplication(String userId) async {
    final data = await _client
        .from('vendor_applications')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (data == null) return null;
    return VendorApplication.fromJson(data);
  }

  Future<VendorApplication> submitVendorApplication({
    required String userId,
    required String businessName,
    required String inviteCode,
    String? motivation,
    String? portfolioUrl,
    String? location,
    String? deliveryInfo,
    String? turnaroundTime,
  }) async {
    // Validate invite code
    final codeData = await _client
        .from('invite_codes')
        .select()
        .eq('code', inviteCode)
        .eq('is_used', false)
        .maybeSingle();

    if (codeData == null) {
      throw Exception('Invalid or already used invite code');
    }

    // Mark code as used
    await _client.from('invite_codes').update({
      'is_used': true,
      'used_by': userId,
      'used_at': DateTime.now().toIso8601String(),
    }).eq('id', codeData['id'] as String);

    // Create application
    final appData = await _client
        .from('vendor_applications')
        .insert({
          'user_id': userId,
          'business_name': businessName,
          'motivation': motivation,
          'portfolio_url': portfolioUrl,
          'location': location,
          'invite_code': inviteCode,
          'delivery_info': deliveryInfo,
          'turnaround_time': turnaroundTime,
          'status': 'pending',
        })
        .select()
        .single();

    return VendorApplication.fromJson(appData);
  }

  Future<VendorApplication> submitVendorOnboarding({
    required String userId,
    required String businessName,
    String? motivation,
    String? portfolioUrl,
    String? location,
    String? deliveryInfo,
    String? turnaroundTime,
  }) async {
    final appData = await _client
        .from('vendor_applications')
        .insert({
          'user_id': userId,
          'business_name': businessName,
          'motivation': motivation,
          'portfolio_url': portfolioUrl,
          'location': location,
          'delivery_info': deliveryInfo,
          'turnaround_time': turnaroundTime,
          'status': 'pending',
        })
        .select()
        .single();

    return VendorApplication.fromJson(appData);
  }

  Future<void> activateVendorAccount({
    required String userId,
    required String businessName,
    String? location,
  }) async {
    await _client.from('profiles').update({
      'role': 'vendor',
    }).eq('id', userId);

    final existing = await _client
        .from('shops')
        .select('id')
        .eq('vendor_id', userId)
        .maybeSingle();

    if (existing != null) return;

    final slug = businessName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final uniqueSlug = '$slug-${DateTime.now().millisecondsSinceEpoch}';

    await _client.from('shops').insert({
      'vendor_id': userId,
      'name': businessName,
      'slug': uniqueSlug,
      'bio': 'Welcome to $businessName!',
      if (location != null) 'location': location,
    });
  }

  // ── Shop Posts (Vendor) ─────────────────────────────────────
  Future<ShopPost> createShopPost(
    String shopId, {
    required String caption,
    List<String> mediaUrls = const [],
  }) async {
    final data = await _client
        .from('shop_posts')
        .insert({
          'shop_id': shopId,
          'caption': caption,
          'media_urls': mediaUrls,
          'is_published': true,
        })
        .select('*, shops(name, logo_url)')
        .single();
    return ShopPost.fromJson(data);
  }

  Future<void> updateShopPost(String postId, Map<String, dynamic> updates) async {
    await _client.from('shop_posts').update(updates).eq('id', postId);
  }

  Future<void> deleteShopPost(String postId) async {
    await _client.from('shop_posts').delete().eq('id', postId);
  }
}
