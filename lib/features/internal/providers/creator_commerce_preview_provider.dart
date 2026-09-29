import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../concepts/creator_commerce/creator_commerce_mockup_app.dart';
import '../../../models/product.dart';
import '../../../models/shop.dart';
import '../../../models/shop_post.dart';
import '../../auth/providers/auth_providers.dart';

/// Loads the internal concept from the same Supabase services used by the
/// production buyer and vendor experiences. Each source fails independently so
/// a post-policy issue cannot hide an otherwise healthy live catalogue.
final creatorCommerceCatalogProvider = FutureProvider<CreatorCommerceCatalog>((
  ref,
) async {
  final service = ref.read(supabaseServiceProvider);
  final userId = ref.watch(currentUserIdProvider);

  var liveSources = 0;
  var failedSources = 0;
  var products = const <Product>[];
  var shops = const <Shop>[];
  var posts = const <ShopPost>[];
  var followingPosts = const <ShopPost>[];
  var vendorProducts = const <Product>[];
  Shop? vendorShop;

  try {
    products = await service.getProducts(limit: 30);
    liveSources++;
  } catch (_) {
    failedSources++;
  }

  try {
    shops = await service.getShops();
    liveSources++;
  } catch (_) {
    failedSources++;
  }

  if (shops.isNotEmpty) {
    final postResults = await Future.wait(
      shops.take(8).map((shop) async {
        try {
          return await service.getShopPosts(shop.id, limit: 3);
        } catch (_) {
          return null;
        }
      }),
    );
    final successfulResults = postResults.whereType<List<ShopPost>>();
    if (successfulResults.isNotEmpty) {
      posts = successfulResults.expand((entries) => entries).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      liveSources++;
    } else {
      failedSources++;
    }
  }

  if (userId != null) {
    try {
      followingPosts = await service.getFollowingFeed(userId, limit: 20);
      liveSources++;
    } catch (_) {
      failedSources++;
    }

    try {
      vendorShop = await service.getVendorShop(userId);
      if (vendorShop != null) {
        vendorProducts = await service.getVendorProducts(vendorShop.id);
      }
      liveSources++;
    } catch (_) {
      failedSources++;
    }
  }

  return CreatorCommerceCatalog(
    products: products,
    shops: shops,
    posts: posts,
    followingPosts: followingPosts,
    vendorProducts: vendorProducts,
    vendorShop: vendorShop,
    liveSources: liveSources,
    failedSources: failedSources,
  );
});
