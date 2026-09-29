import 'package:artisanal_lane/features/buyer/utils/shop_discovery_gift.dart';
import 'package:artisanal_lane/models/product.dart';
import 'package:flutter_test/flutter_test.dart';

Product _product(
  String id, {
  required double price,
  String? categoryId,
  String? categoryName,
  String title = '',
  List<String> tags = const [],
  int stockQty = 5,
  bool shopIsVerified = false,
  bool isPublished = true,
  DateTime? createdAt,
}) => Product(
  id: id,
  shopId: 'shop-$id',
  categoryId: categoryId,
  categoryName: categoryName,
  title: title,
  price: price,
  stockQty: stockQty,
  tags: tags,
  isPublished: isPublished,
  shopIsVerified: shopIsVerified,
  createdAt: createdAt ?? DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

void main() {
  group('GiftBudget.matches', () {
    test('filters by band', () {
      expect(GiftBudget.under250.matches(249), isTrue);
      expect(GiftBudget.under250.matches(250), isFalse);
      expect(GiftBudget.between250And500.matches(250), isTrue);
      expect(GiftBudget.between250And500.matches(500), isTrue);
      expect(GiftBudget.between250And500.matches(501), isFalse);
      expect(GiftBudget.between500And1000.matches(500), isFalse);
      expect(GiftBudget.between500And1000.matches(1000), isTrue);
      expect(GiftBudget.any.matches(999999), isTrue);
    });
  });

  group('giftAffinityScore', () {
    test('counts recipient and occasion keyword hits', () {
      final product = _product(
        'a',
        price: 100,
        title: 'Leather wallet',
        tags: const ['birthday'],
      );
      final score = giftAffinityScore(
        product: product,
        recipient: GiftRecipient.him,
        occasion: GiftOccasion.birthday,
      );
      // "leather" + "wallet" (title) + "birthday" (tag).
      expect(score, 3);
    });

    test('anyone/just because keyword sets contribute nothing', () {
      final product = _product('a', price: 100, title: 'Ceramic mug');
      final score = giftAffinityScore(
        product: product,
        recipient: GiftRecipient.anyone,
        occasion: GiftOccasion.justBecause,
      );
      expect(score, 0);
    });
  });

  group('rankGiftConciergeProducts', () {
    test('filters out-of-budget products', () {
      final products = [
        _product('cheap', price: 100),
        _product('pricey', price: 900),
      ];
      final result = rankGiftConciergeProducts(
        products: products,
        recipient: GiftRecipient.anyone,
        occasion: GiftOccasion.justBecause,
        budget: GiftBudget.under250,
      );
      expect(result.map((p) => p.id), ['cheap']);
    });

    test('excludes unpublished products', () {
      final products = [
        _product('a', price: 100, isPublished: false),
        _product('b', price: 100),
      ];
      final result = rankGiftConciergeProducts(
        products: products,
        recipient: GiftRecipient.anyone,
        occasion: GiftOccasion.justBecause,
        budget: GiftBudget.any,
      );
      expect(result.map((p) => p.id), ['b']);
    });

    test('ranks stronger keyword affinity first', () {
      final products = [
        _product('generic', price: 100, title: 'Item'),
        _product('for-her', price: 100, title: 'Ceramic earrings'),
      ];
      final result = rankGiftConciergeProducts(
        products: products,
        recipient: GiftRecipient.her,
        occasion: GiftOccasion.justBecause,
        budget: GiftBudget.any,
      );
      expect(result.first.id, 'for-her');
    });

    test('breaks ties by in-stock first, then verified maker', () {
      final products = [
        _product('out-of-stock', price: 100, stockQty: 0),
        _product('verified', price: 100, shopIsVerified: true),
        _product('unverified', price: 100),
      ];
      final result = rankGiftConciergeProducts(
        products: products,
        recipient: GiftRecipient.anyone,
        occasion: GiftOccasion.justBecause,
        budget: GiftBudget.any,
      );
      expect(result.map((p) => p.id), [
        'verified',
        'unverified',
        'out-of-stock',
      ]);
    });

    test('returns empty for an impossible budget', () {
      final products = [_product('a', price: 5000)];
      final result = rankGiftConciergeProducts(
        products: products,
        recipient: GiftRecipient.anyone,
        occasion: GiftOccasion.justBecause,
        budget: GiftBudget.under250,
      );
      expect(result, isEmpty);
    });
  });
}
