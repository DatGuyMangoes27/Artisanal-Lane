import 'package:flutter_test/flutter_test.dart';
import 'package:artisanal_lane/models/product.dart';
import 'package:artisanal_lane/models/order.dart';

Product buildProduct({
  required String fulfillmentMode,
  int stockQty = 0,
  double price = 100,
  double? madeToOrderPrice,
  int? leadMinDays,
  int? leadMaxDays,
}) {
  final now = DateTime.utc(2026, 1, 1);
  return Product(
    id: 'product-1',
    shopId: 'shop-1',
    title: 'Hand-thrown mug',
    price: price,
    stockQty: stockQty,
    fulfillmentMode: fulfillmentMode,
    madeToOrderPrice: madeToOrderPrice,
    leadMinDays: leadMinDays,
    leadMaxDays: leadMaxDays,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('Product made-to-order helpers', () {
    test('stocked products are never made-to-order', () {
      final product = buildProduct(fulfillmentMode: 'stocked', stockQty: 0);
      expect(product.isMadeToOrderEnabled, isFalse);
      expect(product.isMadeToOrderAvailable, isFalse);
    });

    test('made_to_order only is always available regardless of stock', () {
      final inStock = buildProduct(fulfillmentMode: 'made_to_order', stockQty: 5);
      final outOfStock =
          buildProduct(fulfillmentMode: 'made_to_order', stockQty: 0);
      expect(inStock.isMadeToOrderOnly, isTrue);
      expect(inStock.isMadeToOrderAvailable, isTrue);
      expect(outOfStock.isMadeToOrderAvailable, isTrue);
    });

    test('stocked_with_mto only offers MTO once stock is depleted', () {
      final inStock =
          buildProduct(fulfillmentMode: 'stocked_with_mto', stockQty: 3);
      final soldOut =
          buildProduct(fulfillmentMode: 'stocked_with_mto', stockQty: 0);
      expect(inStock.isMadeToOrderEnabled, isTrue);
      expect(inStock.isMadeToOrderAvailable, isFalse);
      expect(soldOut.isMadeToOrderAvailable, isTrue);
    });

    test('effective MTO price prefers the override, falling back to price', () {
      final withOverride = buildProduct(
        fulfillmentMode: 'made_to_order',
        price: 100,
        madeToOrderPrice: 175,
      );
      final withoutOverride =
          buildProduct(fulfillmentMode: 'made_to_order', price: 100);
      expect(withOverride.effectiveMtoPrice, 175);
      expect(withoutOverride.effectiveMtoPrice, 100);
    });

    test('lead time label collapses equal min/max and handles partial ranges',
        () {
      expect(
        buildProduct(
          fulfillmentMode: 'made_to_order',
          leadMinDays: 14,
          leadMaxDays: 21,
        ).leadTimeLabel,
        '14-21 days',
      );
      expect(
        buildProduct(
          fulfillmentMode: 'made_to_order',
          leadMinDays: 10,
          leadMaxDays: 10,
        ).leadTimeLabel,
        '10 days',
      );
      expect(
        buildProduct(fulfillmentMode: 'made_to_order', leadMinDays: 7)
            .leadTimeLabel,
        '7 days',
      );
      expect(
        buildProduct(fulfillmentMode: 'made_to_order').leadTimeLabel,
        isNull,
      );
    });
  });

  group('OrderItem made-to-order snapshot', () {
    test('parses made-to-order fields and formats the lead time', () {
      final order = Order.fromJson({
        'id': '12345678-1234-1234-1234-123456789abc',
        'buyer_id': 'buyer-1',
        'shop_id': 'shop-1',
        'status': 'paid',
        'total': 175,
        'shipping_cost': 0,
        'shipping_method': null,
        'shipping_address': null,
        'payment_state': 'paid',
        'is_gift': false,
        'created_at': '2026-05-14T08:00:00.000Z',
        'updated_at': '2026-05-14T08:00:00.000Z',
        'shops': null,
        'buyer': null,
        'order_items': [
          {
            'id': 'item-1',
            'order_id': '12345678-1234-1234-1234-123456789abc',
            'product_id': 'product-1',
            'variant_id': null,
            'variant_name': null,
            'variant_image': null,
            'quantity': 1,
            'unit_price': 175,
            'is_made_to_order': true,
            'custom_note': 'Sage green glaze',
            'lead_time_min_days': 14,
            'lead_time_max_days': 21,
            'created_at': '2026-05-14T08:00:00.000Z',
            'products': null,
          },
        ],
      });

      final item = order.items!.single;
      expect(item.isMadeToOrder, isTrue);
      expect(item.customNote, 'Sage green glaze');
      expect(item.leadTimeLabel, '14-21 days');
    });

    test('defaults to a stocked line when MTO fields are absent', () {
      final order = Order.fromJson({
        'id': '12345678-1234-1234-1234-123456789abc',
        'buyer_id': 'buyer-1',
        'shop_id': 'shop-1',
        'status': 'paid',
        'total': 50,
        'shipping_cost': 0,
        'shipping_method': null,
        'shipping_address': null,
        'payment_state': 'paid',
        'is_gift': false,
        'created_at': '2026-05-14T08:00:00.000Z',
        'updated_at': '2026-05-14T08:00:00.000Z',
        'shops': null,
        'buyer': null,
        'order_items': [
          {
            'id': 'item-1',
            'order_id': '12345678-1234-1234-1234-123456789abc',
            'product_id': 'product-1',
            'variant_id': null,
            'variant_name': null,
            'variant_image': null,
            'quantity': 1,
            'unit_price': 50,
            'created_at': '2026-05-14T08:00:00.000Z',
            'products': null,
          },
        ],
      });

      final item = order.items!.single;
      expect(item.isMadeToOrder, isFalse);
      expect(item.customNote, isNull);
      expect(item.leadTimeLabel, isNull);
    });
  });
}
