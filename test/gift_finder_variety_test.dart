// Nicky: gift ideas should come from a variety of shops, and buyers should
// be able to ask for other ideas.
import 'package:artisanal_lane/features/buyer/providers/gift_finder_providers.dart';
import 'package:artisanal_lane/features/buyer/utils/shop_discovery_gift.dart';
import 'package:artisanal_lane/models/product.dart';
import 'package:flutter_test/flutter_test.dart';

final _base = DateTime(2026, 11, 1);

Product _piece(String id, String shopId, {int ageDays = 0}) => Product(
  id: id,
  shopId: shopId,
  title: 'Piece $id',
  price: 200,
  stockQty: 3,
  isPublished: true,
  createdAt: _base.subtract(Duration(days: ageDays)),
  updatedAt: _base,
);

GiftFinderResults _find(
  List<Product> products, {
  int limit = 24,
  int page = 0,
}) => findGiftIdeas(
  products: products,
  recipient: GiftRecipient.anyone,
  occasion: GiftOccasion.values.first,
  budget: GiftBudget.any,
  limit: limit,
  page: page,
);

void main() {
  // One shop uploaded a big batch most recently; two others are older.
  final products = [
    for (var i = 0; i < 6; i++) _piece('batch$i', 'busy-shop'),
    _piece('a', 'shop-a', ageDays: 5),
    _piece('b', 'shop-b', ageDays: 6),
  ];

  test('every shop gets a turn before any shop gets a second piece', () {
    final shops = [
      for (final match in _find(products).matches) match.product.shopId,
    ];
    expect(shops.take(3).toSet(), {'busy-shop', 'shop-a', 'shop-b'});
    expect(shops, hasLength(8));
  });

  test('"Show me other ideas" pages through, then starts over', () {
    final first = _find(products, limit: 3);
    expect(first.hasMore, isTrue);
    expect(first.totalMatches, 8);
    final second = _find(products, limit: 3, page: 1);
    final firstIds = {for (final m in first.matches) m.product.id};
    final secondIds = {for (final m in second.matches) m.product.id};
    expect(firstIds.intersection(secondIds), isEmpty);

    final last = _find(products, limit: 3, page: 2);
    expect(last.isLastPage, isTrue);
    expect(last.matches, hasLength(2));
    final again = _find(products, limit: 3, page: 3);
    expect(
      [for (final m in again.matches) m.product.id],
      [for (final m in first.matches) m.product.id],
    );
  });

  test('a short list has no other ideas button', () {
    expect(_find(products.take(2).toList()).hasMore, isFalse);
  });
}
