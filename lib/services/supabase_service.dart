import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';
import '../models/models.dart';

class SupabaseService {
  final SupabaseClient _client;

  static const _pendingRequestedRoleKey = 'pending_auth_requested_role';
  static const _pendingDisplayNameKey = 'pending_auth_display_name';

  SupabaseService(this._client);

  Future<void> savePendingAuthIntent({
    required String requestedRole,
    String? displayName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingRequestedRoleKey, requestedRole);

    final trimmedName = displayName?.trim();
    if (trimmedName == null || trimmedName.isEmpty) {
      await prefs.remove(_pendingDisplayNameKey);
    } else {
      await prefs.setString(_pendingDisplayNameKey, trimmedName);
    }
  }

  Future<void> clearPendingAuthIntent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingRequestedRoleKey);
    await prefs.remove(_pendingDisplayNameKey);
  }

  Future<Map<String, String>?> _consumePendingAuthIntent() async {
    final prefs = await SharedPreferences.getInstance();
    final requestedRole = prefs.getString(_pendingRequestedRoleKey);
    final displayName = prefs.getString(_pendingDisplayNameKey);

    await prefs.remove(_pendingRequestedRoleKey);
    await prefs.remove(_pendingDisplayNameKey);

    if (requestedRole == null && displayName == null) {
      return null;
    }

    return {
      if (requestedRole != null) 'requested_role': requestedRole,
      if (displayName != null) 'display_name': displayName,
    };
  }

  Future<AuthResponse> signInWithGoogleNative({
    String? requestedRole,
    String? displayName,
  }) async {
    final normalizedRole = requestedRole == 'vendor' ? 'vendor' : 'buyer';
    final trimmedDisplayName = displayName?.trim();
    final webClientId = AppConstants.googleWebClientId.trim();
    final iosClientId = AppConstants.googleIosClientId.trim();

    if (webClientId.isEmpty) {
      throw Exception(
        'GOOGLE_WEB_CLIENT_ID is not configured. Add it to your Dart defines before using native Google sign-in.',
      );
    }

    if (requestedRole != null || (trimmedDisplayName?.isNotEmpty ?? false)) {
      await savePendingAuthIntent(
        requestedRole: normalizedRole,
        displayName: trimmedDisplayName,
      );
    }

    try {
      final signIn = GoogleSignIn.instance;
      await signIn.initialize(
        serverClientId: webClientId,
        clientId: Platform.isIOS ? iosClientId : null,
      );

      final googleAccount = await signIn.authenticate();
      final googleAuthentication = googleAccount.authentication;
      final idToken = googleAuthentication.idToken;

      if (idToken == null) {
        throw Exception('Google sign-in did not return an ID token.');
      }

      return _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
    } catch (error) {
      if (requestedRole != null || (trimmedDisplayName?.isNotEmpty ?? false)) {
        await clearPendingAuthIntent();
      }
      rethrow;
    }
  }

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

    await _client.storage
        .from('product-images')
        .upload(
          storagePath,
          imageFile,
          fileOptions: FileOptions(contentType: _mimeType(ext)),
        );

    return _client.storage.from('product-images').getPublicUrl(storagePath);
  }

  Future<String> uploadShopImage(
    String userId,
    File imageFile, {
    String folder = 'general',
  }) async {
    final ext = imageFile.path.split('.').last.toLowerCase();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final storagePath = '$userId/$folder/$fileName';

    await _client.storage
        .from('shop-assets')
        .upload(
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
        .eq('is_featured', true)
        .order('featured_at', ascending: false)
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
        .select(
          '*, shops(name, logo_url, slug, bio, location), categories(name)',
        )
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

  Future<Shop?> getSpotlightShop() async {
    final data = await _client
        .from('shops')
        .select()
        .eq('is_active', true)
        .eq('is_spotlight', true)
        .maybeSingle();

    if (data == null) {
      return null;
    }

    return Shop.fromJson(data);
  }

  Future<Shop> getShop(String id) async {
    final data = await _client.from('shops').select().eq('id', id).single();
    return Shop.fromJson(data);
  }

  Future<List<ShopMarketEvent>> getShopMarketEvents(
    String shopId, {
    bool upcomingOnly = true,
    bool includeInactive = false,
  }) async {
    var query = _client
        .from('shop_market_events')
        .select()
        .eq('shop_id', shopId);

    if (!includeInactive) {
      query = query.eq('is_active', true);
    }

    if (upcomingOnly) {
      final today = DateTime.now().toIso8601String().split('T').first;
      query = query.gte('event_date', today);
    }

    final data = await query
        .order('event_date', ascending: true)
        .order('created_at', ascending: true);

    return (data as List)
        .map((e) => ShopMarketEvent.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> replaceShopMarketEvents(
    String shopId,
    List<ShopMarketEvent> events,
  ) async {
    await _client.from('shop_market_events').delete().eq('shop_id', shopId);

    if (events.isEmpty) {
      return;
    }

    await _client
        .from('shop_market_events')
        .insert(events.map((event) => event.toInsertJson(shopId)).toList());
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
    String shopId,
    List<ShippingOption> options,
  ) async {
    await _client
        .from('shops')
        .update({'shipping_options': options.map((o) => o.toJson()).toList()})
        .eq('id', shopId);
  }

  Future<void> setShopOfflineMode(
    String shopId, {
    required bool isOffline,
    DateTime? backToWorkDate,
  }) async {
    await _client
        .from('shops')
        .update({
          'is_offline': isOffline,
          'back_to_work_date': isOffline && backToWorkDate != null
              ? backToWorkDate.toIso8601String().split('T').first
              : null,
        })
        .eq('id', shopId);
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

  Future<List<StationeryRequest>> getVendorStationeryRequests(
    String vendorId,
  ) async {
    final data = await _client
        .from('stationery_requests')
        .select()
        .eq('vendor_id', vendorId)
        .order('created_at', ascending: false);

    return (data as List).map((e) => StationeryRequest.fromJson(e)).toList();
  }

  Stream<List<StationeryRequest>> watchVendorStationeryRequests(
    String vendorId,
  ) {
    return _client
        .from('stationery_requests')
        .stream(primaryKey: ['id'])
        .eq('vendor_id', vendorId)
        .order('created_at')
        .asyncMap((_) => getVendorStationeryRequests(vendorId));
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
        .select(
          'product_id, products(*, shops(name, logo_url), categories(name))',
        )
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
    await _client.from('favourites').upsert({
      'user_id': userId,
      'product_id': productId,
    });
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

  Future<void> addToCart(
    String userId,
    String productId, {
    int quantity = 1,
  }) async {
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

  Stream<List<Order>> watchOrders(String userId) {
    return _client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('buyer_id', userId)
        .order('created_at', ascending: false)
        .asyncMap((_) => getOrders(userId));
  }

  Stream<Order> watchOrder(String orderId) {
    return _client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('id', orderId)
        .limit(1)
        .asyncMap((_) => getOrder(orderId));
  }

  // ── Shop Follows ─────────────────────────────────────────────
  Future<void> followShop(String userId, String shopId) async {
    await _client.from('shop_follows').upsert({
      'user_id': userId,
      'shop_id': shopId,
    });
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
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();
    return Profile.fromJson(data);
  }

  Future<void> updateProfile(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    await _client.from('profiles').update(updates).eq('id', userId);
  }

  Future<Profile?> syncCurrentUserProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final pendingIntent = await _consumePendingAuthIntent();

    final existingProfile = await _client
        .from('profiles')
        .select('role, phone, avatar_url')
        .eq('id', user.id)
        .maybeSingle();

    final currentMetadata = Map<String, dynamic>.from(user.userMetadata ?? {});
    final requestedRole =
        pendingIntent?['requested_role'] ??
        currentMetadata['requested_role'] as String? ??
        'buyer';
    final pendingDisplayName = pendingIntent?['display_name']?.trim();
    final metadataDisplayName =
        currentMetadata['display_name'] ??
        currentMetadata['full_name'] ??
        currentMetadata['name'];

    final updatedMetadata = <String, dynamic>{...currentMetadata};
    var shouldUpdateMetadata = false;

    if (updatedMetadata['requested_role'] != requestedRole) {
      updatedMetadata['requested_role'] = requestedRole;
      shouldUpdateMetadata = true;
    }

    if (pendingDisplayName != null &&
        pendingDisplayName.isNotEmpty &&
        (updatedMetadata['display_name'] as String?)?.trim().isEmpty != false) {
      updatedMetadata['display_name'] = pendingDisplayName;
      shouldUpdateMetadata = true;
    }

    if (shouldUpdateMetadata) {
      await _client.auth.updateUser(UserAttributes(data: updatedMetadata));
    }

    final effectiveUser = _client.auth.currentUser ?? user;

    final profileData = {
      'id': effectiveUser.id,
      'role': existingProfile?['role'] as String? ?? 'buyer',
      'display_name':
          (pendingDisplayName ??
                  metadataDisplayName ??
                  effectiveUser.email?.split('@').first)
              as String?,
      'email': effectiveUser.email,
      'phone': existingProfile?['phone'] as String?,
      'avatar_url':
          (existingProfile?['avatar_url'] ??
                  effectiveUser.userMetadata?['avatar_url'] ??
                  effectiveUser.userMetadata?['picture'])
              as String?,
    };

    await _client.from('profiles').upsert(profileData);
    return getProfile(effectiveUser.id);
  }

  Future<String> getPostAuthRoute({Profile? profile}) async {
    final currentUser = _client.auth.currentUser;
    final currentProfile =
        profile ??
        (currentUser == null ? null : await getProfile(currentUser.id));

    if (currentProfile?.isVendor == true) {
      return '/vendor';
    }

    final requestedRole =
        currentUser?.userMetadata?['requested_role'] as String? ?? 'buyer';

    if (requestedRole == 'vendor') {
      return '/vendor/onboarding';
    }

    return '/home';
  }

  // ── Order Creation ─────────────────────────────────────────────
  Future<CheckoutSession> createCheckout({
    required Map<String, dynamic> shippingAddress,
    required String shippingMethod,
    required double shippingCost,
    bool isGift = false,
    String? giftRecipient,
    String? giftMessage,
  }) async {
    final response = await _client.functions.invoke(
      'create-checkout',
      body: {
        'shippingAddress': shippingAddress,
        'shippingMethod': shippingMethod,
        'shippingCost': shippingCost,
        'isGift': isGift,
        'giftRecipient': giftRecipient,
        'giftMessage': giftMessage,
      },
    );

    return CheckoutSession.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
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
    await _client.functions.invoke(
      'release-escrow',
      body: {'orderId': orderId},
    );
  }

  Future<void> createDispute(
    String orderId,
    String raisedBy,
    String reason,
  ) async {
    await _client.functions.invoke(
      'open-dispute',
      body: {'orderId': orderId, 'raisedBy': raisedBy, 'reason': reason},
    );
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

  Future<void> saveAddresses(
    String userId,
    List<Map<String, dynamic>> addresses,
  ) async {
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

  Future<Product> createProduct(
    String shopId,
    Map<String, dynamic> data,
  ) async {
    final row = await _client
        .from('products')
        .insert({'shop_id': shopId, ...data})
        .select('*, categories(name)')
        .single();
    return Product.fromJson(row);
  }

  Future<void> updateProduct(
    String productId,
    Map<String, dynamic> updates,
  ) async {
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

  Stream<List<Order>> watchShopOrders(String shopId) {
    return _client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('shop_id', shopId)
        .order('created_at', ascending: false)
        .asyncMap((_) => getShopOrders(shopId));
  }

  Future<void> updateOrderStatus(
    String orderId,
    String status, {
    String? trackingNumber,
  }) async {
    if (status == 'shipped') {
      await _client.functions.invoke(
        'mark-order-shipped',
        body: {'orderId': orderId, 'trackingNumber': trackingNumber},
      );
      return;
    }

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

  Stream<VendorApplication?> watchVendorApplication(String userId) {
    return _client
        .from('vendor_applications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .limit(1)
        .asyncMap((_) => getVendorApplication(userId));
  }

  Future<VendorApplication> submitVendorApplication({
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
    throw Exception(
      'Vendor accounts are provisioned by an admin after approval.',
    );
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

  Future<void> updateShopPost(
    String postId,
    Map<String, dynamic> updates,
  ) async {
    await _client.from('shop_posts').update(updates).eq('id', postId);
  }

  Future<void> deleteShopPost(String postId) async {
    await _client.from('shop_posts').delete().eq('id', postId);
  }
}
