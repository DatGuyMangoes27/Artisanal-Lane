import 'package:artisanal_lane/features/buyer/screens/creator_shop_screen.dart';
import 'package:artisanal_lane/models/product.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Product _product(
  String id, {
  required double price,
  double? compareAtPrice,
  String? categoryId,
  DateTime? createdAt,
}) => Product(
  id: id,
  shopId: 'shop-$id',
  categoryId: categoryId,
  title: 'Product $id',
  price: price,
  compareAtPrice: compareAtPrice,
  createdAt: createdAt ?? DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

void main() {
  group('applyShopSortAndFilters', () {
    final products = [
      _product('a', price: 300, categoryId: 'ceramics'),
      _product(
        'b',
        price: 900,
        compareAtPrice: 1200,
        categoryId: 'textiles',
        createdAt: DateTime(2026, 3, 1),
      ),
      _product('c', price: 150, categoryId: 'ceramics'),
    ];

    test('recommended keeps the original order', () {
      final result = applyShopSortAndFilters(products);
      expect(result.map((p) => p.id), ['a', 'b', 'c']);
    });

    test('sorts by price ascending and descending', () {
      expect(
        applyShopSortAndFilters(
          products,
          sort: ShopSortOption.priceLowHigh,
        ).map((p) => p.id),
        ['c', 'a', 'b'],
      );
      expect(
        applyShopSortAndFilters(
          products,
          sort: ShopSortOption.priceHighLow,
        ).map((p) => p.id),
        ['b', 'a', 'c'],
      );
    });

    test('sorts by newest first', () {
      expect(
        applyShopSortAndFilters(products, sort: ShopSortOption.newest).first.id,
        'b',
      );
    });

    test('filters to on-sale items only', () {
      expect(
        applyShopSortAndFilters(products, onSaleOnly: true).map((p) => p.id),
        ['b'],
      );
    });

    test('filters by selected categories', () {
      expect(
        applyShopSortAndFilters(
          products,
          categoryIds: {'ceramics'},
        ).map((p) => p.id),
        ['a', 'c'],
      );
    });

    test('filters by price range', () {
      expect(
        applyShopSortAndFilters(
          products,
          priceRange: const RangeValues(100, 500),
        ).map((p) => p.id),
        ['a', 'c'],
      );
    });

    test('combines filters and sort', () {
      expect(
        applyShopSortAndFilters(
          products,
          sort: ShopSortOption.priceLowHigh,
          categoryIds: {'ceramics'},
        ).map((p) => p.id),
        ['c', 'a'],
      );
    });
  });
}
