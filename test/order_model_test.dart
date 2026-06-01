import 'package:flutter_test/flutter_test.dart';
import 'package:artisanal_lane/models/order.dart';

void main() {
  test(
    'Order parser tolerates historical rows with removed shop or product references',
    () {
      final order = Order.fromJson({
        'id': '12345678-1234-1234-1234-123456789abc',
        'buyer_id': 'buyer-1',
        'shop_id': null,
        'status': 'completed',
        'total': 250,
        'shipping_cost': 0,
        'shipping_method': null,
        'shipping_address': null,
        'payment_state': null,
        'is_gift': false,
        'created_at': '2026-05-14T08:00:00.000Z',
        'updated_at': '2026-05-14T08:00:00.000Z',
        'shops': null,
        'buyer': {'display_name': null, 'email': null, 'phone': null},
        'order_items': [
          {
            'id': 'item-1',
            'order_id': '12345678-1234-1234-1234-123456789abc',
            'product_id': null,
            'variant_id': null,
            'variant_name': null,
            'variant_image': null,
            'quantity': 1,
            'unit_price': 250,
            'created_at': '2026-05-14T08:00:00.000Z',
            'products': null,
          },
        ],
      });

      expect(order.shopId, isEmpty);
      expect(order.shopName, isNull);
      expect(order.items, hasLength(1));
      expect(order.items!.single.productId, isEmpty);
      expect(order.items!.single.productTitle, isNull);
    },
  );

  test(
    'Order shipping address summary hides missing pickup address fields',
    () {
      final order = Order.fromJson({
        'id': '12345678-1234-1234-1234-123456789abc',
        'buyer_id': 'buyer-1',
        'shop_id': 'shop-1',
        'status': 'paid',
        'total': 50,
        'shipping_cost': 0,
        'shipping_method': 'courier_guy',
        'shipping_address': {
          'street': null,
          'city': null,
          'postal_code': null,
          'pickup_point': {
            'name': '2Acre Hardware',
            'code': 'RVM00281',
            'address': '3QW4+VX, Piketberg, 7320 Western Cape',
          },
        },
        'payment_state': 'paid',
        'is_gift': false,
        'created_at': '2026-05-14T08:00:00.000Z',
        'updated_at': '2026-05-14T08:00:00.000Z',
        'shops': null,
        'buyer': null,
        'order_items': const [],
      });

      expect(order.shippingAddressSummary, isNull);
      expect(order.pickupPointSummary, contains('2Acre Hardware'));
    },
  );
}
