import 'package:artisanal_lane/features/buyer/screens/creator_shop_screen.dart';
import 'package:artisanal_lane/features/buyer/utils/discovery_preferences.dart';
import 'package:artisanal_lane/features/buyer/utils/shop_discovery_reasons.dart';
import 'package:artisanal_lane/features/buyer/utils/shop_for_you_ranking.dart';
import 'package:artisanal_lane/models/order.dart';
import 'package:artisanal_lane/models/product.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 1);
  Product product(
    String id, {
    String categoryId = 'home',
    String shopId = 'maker',
    double price = 300,
    int stock = 1,
    int ageDays = 0,
  }) => Product(
    id: id,
    shopId: shopId,
    categoryId: categoryId,
    categoryName: categoryId,
    title: id,
    price: price,
    stockQty: stock,
    createdAt: now.subtract(Duration(days: ageDays)),
    updatedAt: now,
  );

  List<String> ids(Iterable<Product> products) => [
    for (final p in products) p.id,
  ];

  final catalogue = [
    product('new-1', ageDays: 0),
    product('new-2', ageDays: 1),
    product('new-3', ageDays: 2),
    product('new-4', ageDays: 3),
    product('kids-1', categoryId: 'kids', ageDays: 6),
    product('kids-2', categoryId: 'kids', ageDays: 7),
    product(
      'loved',
      categoryId: 'jewellery',
      shopId: 'silversmith',
      ageDays: 20,
    ),
    product('saved', categoryId: 'art', ageDays: 21),
    product(
      'bought',
      categoryId: 'jewellery',
      shopId: 'silversmith',
      ageDays: 22,
    ),
    product('ring', categoryId: 'jewellery', ageDays: 8),
    product('by-silversmith', shopId: 'silversmith', ageDays: 9),
    product('skipped', ageDays: 0),
    product('pricey', categoryId: 'kids', price: 2000),
  ];
  const preferences = DiscoveryPreferences(
    categoryIds: {'kids'},
    maxBudget: 1000,
    likedProductIds: {'loved', 'bought'},
    skippedProductIds: {'skipped'},
  );

  List<Product> rank({Set<String> bought = const {'bought'}}) => rankShopForYou(
    products: catalogue,
    preferences: preferences,
    savedProductIds: const {'saved'},
    purchasedProductIds: bought,
  );

  test('Discover categories and swipe signals lead, with loved/saved '
      'pieces surfaced near the top as reminders', () {
    final ranked = ids(rank());
    expect(ranked.take(6), [
      'kids-1', // chosen Discover category, editorial slot stays a match
      'loved', // reminder: loved on Discover, not bought
      'kids-2',
      'ring', // loved category
      'saved', // reminder: saved, not bought
      'by-silversmith', // loved maker
    ]);
    // Not-for-me and over-budget pieces stay out, as before.
    expect(ranked, isNot(contains('skipped')));
    expect(ranked, isNot(contains('pricey')));
    // Bought pieces aren't nagged about.
    expect(ranked, isNot(contains('bought')));
  });

  test('only real catalogue products are returned, never extras', () {
    final ranked = rankShopForYou(
      products: [product('a')],
      preferences: const DiscoveryPreferences(likedProductIds: {'elsewhere'}),
      savedProducts: [product('not-in-catalogue')],
    );
    expect(ids(ranked), ['a']);
  });

  test('For you uses it; a specific filter keeps its current behaviour', () {
    final forYou = filterCreatorShopProducts(
      products: catalogue,
      query: '',
      filter: CreatorShopFilter.forYou,
      preferences: preferences,
      savedProductIds: const {'saved'},
      purchasedProductIds: const {'bought'},
    );
    expect(ids(forYou), ids(rank()));

    final newDrops = filterCreatorShopProducts(
      products: catalogue,
      query: '',
      filter: CreatorShopFilter.newDrops,
      preferences: preferences,
      savedProductIds: const {'saved'},
    );
    expect(newDrops, hasLength(catalogue.length));
    expect(newDrops.first.createdAt, now);

    final all = filterCreatorShopProducts(
      products: catalogue,
      query: '',
      filter: CreatorShopFilter.allPieces,
      preferences: preferences,
      savedProductIds: const {'saved'},
    );
    expect(ids(all), ids(catalogue));
  });

  test('purchased ids only count paid orders', () {
    OrderItem item(String productId) => OrderItem(
      id: 'i-$productId',
      orderId: 'o',
      productId: productId,
      quantity: 1,
      unitPrice: 100,
      createdAt: now,
    );
    Order order(String status, String productId) => Order(
      id: 'o-$productId',
      buyerId: 'buyer',
      shopId: 'shop',
      status: status,
      total: 100,
      createdAt: now,
      updatedAt: now,
      items: [item(productId)],
    );
    expect(
      purchasedProductIds([
        order('paid', 'a'),
        order('delivered', 'b'),
        order('awaiting_payment', 'c'),
        order('cancelled', 'd'),
      ]),
      {'a', 'b'},
    );
  });

  test('reminder tiles say why they are there', () {
    expect(
      shopForYouReason(
        product: product('loved'),
        likedCategoryIds: const {},
        referenceProducts: const [],
        lovedProductIds: const {'loved'},
      ),
      'You loved this',
    );
    expect(
      shopForYouReason(
        product: product('saved'),
        likedCategoryIds: const {},
        referenceProducts: const [],
        savedProductIds: const {'saved'},
      ),
      'You saved this',
    );
  });
}
