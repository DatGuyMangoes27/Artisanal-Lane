import 'package:artisanal_lane/features/buyer/utils/discovery_preferences.dart';
import 'package:artisanal_lane/models/product.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 22);
  Product product({
    required String id,
    required String categoryId,
    required double price,
    List<String> tags = const [],
  }) => Product(
    id: id,
    shopId: 'shop',
    categoryId: categoryId,
    title: id,
    price: price,
    stockQty: 1,
    tags: tags,
    createdAt: now,
    updatedAt: now,
  );

  test('preferences use isolated keys for each signed-in buyer', () {
    expect(
      discoveryPreferencesKey('buyer-a'),
      isNot(discoveryPreferencesKey('buyer-b')),
    );
    expect(discoveryPreferencesKey(null), contains('guest'));
  });

  test('ranking honours budget, boosts by liked similarity, and never '
      'resurfaces already-reviewed items', () {
    final products = [
      product(id: 'liked', categoryId: 'home', price: 300, tags: ['wood']),
      product(id: 'match', categoryId: 'home', price: 350, tags: ['wood']),
      product(id: 'skip', categoryId: 'home', price: 200),
      product(id: 'over-budget', categoryId: 'jewellery', price: 900),
    ];
    final ranked = rankDiscoverProducts(
      products,
      const DiscoveryPreferences(
        categoryIds: {'home'},
        maxBudget: 500,
        likedProductIds: {'liked'},
        skippedProductIds: {'skip'},
      ),
    );

    // Already-decided items (loved AND skipped) never reappear; only the
    // still-undecided, in-budget match remains, boosted by its similarity
    // to the loved item.
    expect(ranked.map((item) => item.id), ['match']);
  });
}
