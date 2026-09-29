import 'package:artisanal_lane/features/buyer/utils/shop_discovery_reasons.dart';
import 'package:artisanal_lane/models/product.dart';
import 'package:flutter_test/flutter_test.dart';

Product _product(
  String id, {
  String? categoryId,
  String? categoryName,
  List<String> tags = const [],
}) => Product(
  id: id,
  shopId: 'shop-$id',
  categoryId: categoryId,
  categoryName: categoryName,
  title: 'Product $id',
  price: 100,
  tags: tags,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

void main() {
  group('shopForYouReason', () {
    test('cites the saved taste category when it matches', () {
      final product = _product(
        'a',
        categoryId: 'ceramics',
        categoryName: 'Ceramics',
      );
      final reason = shopForYouReason(
        product: product,
        likedCategoryIds: {'ceramics'},
        referenceProducts: const [],
      );
      expect(reason, 'Because you liked Ceramics');
    });

    test('cites a liked/favourited reference product in the same category', () {
      final liked = _product(
        'liked',
        categoryId: 'textiles',
        categoryName: 'Textiles',
      );
      final product = _product(
        'a',
        categoryId: 'textiles',
        categoryName: 'Textiles',
      );
      final reason = shopForYouReason(
        product: product,
        likedCategoryIds: const {},
        referenceProducts: [liked],
      );
      expect(reason, 'Because you liked Textiles');
    });

    test('falls back to a shared tag between reference and candidate', () {
      final liked = _product(
        'liked',
        categoryId: 'other',
        tags: const ['brass'],
      );
      final product = _product(
        'a',
        categoryId: 'jewellery',
        categoryName: 'Jewellery',
        tags: const ['brass'],
      );
      final reason = shopForYouReason(
        product: product,
        likedCategoryIds: const {},
        referenceProducts: [liked],
      );
      expect(reason, 'Because you liked brass pieces');
    });

    test('returns null when nothing matches', () {
      final liked = _product('liked', categoryId: 'wood', categoryName: 'Wood');
      final product = _product(
        'a',
        categoryId: 'ceramics',
        categoryName: 'Ceramics',
      );
      final reason = shopForYouReason(
        product: product,
        likedCategoryIds: const {},
        referenceProducts: [liked],
      );
      expect(reason, isNull);
    });

    test('returns null when the product has no category name', () {
      final product = _product('a', categoryId: 'ceramics');
      final reason = shopForYouReason(
        product: product,
        likedCategoryIds: {'ceramics'},
        referenceProducts: const [],
      );
      expect(reason, isNull);
    });

    test('never cites the product itself as a reference', () {
      final product = _product(
        'a',
        categoryId: 'ceramics',
        categoryName: 'Ceramics',
      );
      final reason = shopForYouReason(
        product: product,
        likedCategoryIds: const {},
        referenceProducts: [product],
      );
      expect(reason, isNull);
    });
  });
}
