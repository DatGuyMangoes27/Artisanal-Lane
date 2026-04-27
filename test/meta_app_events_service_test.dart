import 'dart:convert';

import 'package:artisanal_lane/core/constants/app_constants.dart';
import 'package:artisanal_lane/models/cart_item.dart';
import 'package:artisanal_lane/models/order.dart';
import 'package:artisanal_lane/models/product.dart';
import 'package:artisanal_lane/models/product_variant.dart';
import 'package:artisanal_lane/services/meta_app_events_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Product product({
    String id = 'product-1',
    String title = 'Handwoven Basket',
    double price = 129,
    String? categoryName = 'Home Decor',
  }) {
    return Product(
      id: id,
      shopId: 'shop-1',
      title: title,
      price: price,
      categoryName: categoryName,
      createdAt: DateTime(2026, 4, 16),
      updatedAt: DateTime(2026, 4, 16),
    );
  }

  ProductVariant variant({
    String id = 'variant-1',
    String displayName = 'Natural Large',
    double price = 149,
  }) {
    return ProductVariant(
      id: id,
      productId: 'product-1',
      displayName: displayName,
      price: price,
      createdAt: DateTime(2026, 4, 16),
      updatedAt: DateTime(2026, 4, 16),
    );
  }

  CartItem cartItem({
    required Product product,
    ProductVariant? variant,
    int quantity = 1,
  }) {
    return CartItem(
      id: 'cart-item-${variant?.id ?? product.id}',
      cartId: 'cart-1',
      productId: product.id,
      variantId: variant?.id,
      quantity: quantity,
      createdAt: DateTime(2026, 4, 16),
      product: product,
      variant: variant,
    );
  }

  Order order({
    String id = 'order-1',
    String status = 'paid',
    double total = 249,
    double shippingCost = 50,
    List<OrderItem>? items,
  }) {
    return Order(
      id: id,
      buyerId: 'buyer-1',
      shopId: 'shop-1',
      status: status,
      total: total,
      shippingCost: shippingCost,
      paymentState: status == 'paid' ? 'paid' : 'pending',
      shippingMethod: 'courier_guy',
      createdAt: DateTime(2026, 4, 16),
      updatedAt: DateTime(2026, 4, 16),
      items: items,
    );
  }

  OrderItem orderItem({
    String id = 'order-item-1',
    String productId = 'product-1',
    String? variantId,
    int quantity = 1,
    double unitPrice = 149,
    String? productTitle = 'Handwoven Basket',
  }) {
    return OrderItem(
      id: id,
      orderId: 'order-1',
      productId: productId,
      variantId: variantId,
      quantity: quantity,
      unitPrice: unitPrice,
      createdAt: DateTime(2026, 4, 16),
      productTitle: productTitle,
    );
  }

  test('initialize activates app logging and enables auto log events', () async {
    final client = _FakeMetaAppEventsClient();
    final service = MetaAppEventsService(client: client);

    await service.initialize();

    expect(client.activateCalls, 1);
    expect(client.autoLogEnabledStates, [true]);
  });

  test('search events use the standard Meta searched event shape', () async {
    final client = _FakeMetaAppEventsClient();
    final service = MetaAppEventsService(client: client);

    await service.logSearch(query: '  ceramic mugs  ');

    final event = client.eventCalls.single;
    expect(event.name, 'fb_mobile_search');
    expect(event.parameters['fb_search_string'], 'ceramic mugs');
    expect(event.parameters['fb_content_type'], 'product');
    expect(event.valueToSum, isNull);
  });

  test('viewed product is deduped and prefers selected variant data', () async {
    final client = _FakeMetaAppEventsClient();
    final service = MetaAppEventsService(client: client);
    final item = product();
    final selectedVariant = variant();

    await service.logViewedProduct(item, variant: selectedVariant);
    await service.logViewedProduct(item, variant: selectedVariant);

    final call = client.viewContentCalls.single;
    expect(client.viewContentCalls, hasLength(1));
    expect(call.id, selectedVariant.id);
    expect(call.type, 'product');
    expect(call.currency, AppConstants.currencyCode);
    expect(call.price, selectedVariant.price);
    expect(call.content, {
      'id': selectedVariant.id,
      'quantity': 1,
      'item_price': selectedVariant.price,
    });
    expect(call.parameters['product_name'], item.title);
    expect(call.parameters['variant_name'], selectedVariant.displayName);
  });

  test('add to cart logs product content with quantity and price', () async {
    final client = _FakeMetaAppEventsClient();
    final service = MetaAppEventsService(client: client);
    final item = product();
    final selectedVariant = variant();

    await service.logAddToCart(
      item,
      variant: selectedVariant,
      quantity: 3,
    );

    final call = client.addToCartCalls.single;
    expect(call.id, selectedVariant.id);
    expect(call.type, 'product');
    expect(call.currency, AppConstants.currencyCode);
    expect(call.price, selectedVariant.price);
    expect(call.content, {
      'id': selectedVariant.id,
      'quantity': 3,
      'item_price': selectedVariant.price,
    });
    expect(call.parameters['product_name'], item.title);
  });

  test('initiate checkout serializes basket contents for Meta', () async {
    final client = _FakeMetaAppEventsClient();
    final service = MetaAppEventsService(client: client);
    final basketItems = [
      cartItem(product: product(id: 'prod-1', price: 99), quantity: 2),
      cartItem(
        product: product(id: 'prod-2', price: 50),
        variant: variant(id: 'var-2', price: 50),
        quantity: 1,
      ),
    ];

    await service.logInitiatedCheckout(
      items: basketItems,
      totalPrice: 248,
      shippingMethod: 'courier_guy',
    );

    final call = client.initiatedCheckoutCalls.single;
    expect(call.totalPrice, 248);
    expect(call.currency, AppConstants.currencyCode);
    expect(call.contentType, 'product');
    expect(call.numItems, 3);
    expect(call.parameters['shipping_method'], 'courier_guy');
    expect(
      jsonDecode(call.parameters['fb_content'] as String),
      [
        {'id': 'prod-1', 'quantity': 2, 'item_price': 99.0},
        {'id': 'var-2', 'quantity': 1, 'item_price': 50.0},
      ],
    );
  });

  test('purchase logging is deduped per order id and includes totals', () async {
    final client = _FakeMetaAppEventsClient();
    final service = MetaAppEventsService(client: client);
    final paidOrder = order(
      items: [
        orderItem(productId: 'prod-1', quantity: 2, unitPrice: 99),
        orderItem(
          id: 'order-item-2',
          productId: 'prod-2',
          variantId: 'var-2',
          quantity: 1,
          unitPrice: 50,
        ),
      ],
    );

    await service.logPurchasedOrder(paidOrder);
    await service.logPurchasedOrder(paidOrder);

    final call = client.purchaseCalls.single;
    expect(client.purchaseCalls, hasLength(1));
    expect(call.amount, paidOrder.grandTotal);
    expect(call.currency, AppConstants.currencyCode);
    expect(call.parameters['fb_order_id'], paidOrder.id);
    expect(call.parameters['fb_num_items'], 3);
    expect(
      jsonDecode(call.parameters['fb_content'] as String),
      [
        {'id': 'prod-1', 'quantity': 2, 'item_price': 99.0},
        {'id': 'var-2', 'quantity': 1, 'item_price': 50.0},
      ],
    );
  });

  test('sdk failures do not crash the app flow', () async {
    final client = _FakeMetaAppEventsClient(throwOnCalls: true);
    final service = MetaAppEventsService(client: client);

    await expectLater(service.initialize(), completes);
    await expectLater(
      service.logSearch(query: 'candles'),
      completes,
    );
  });
}

class _FakeMetaAppEventsClient implements MetaAppEventsClient {
  _FakeMetaAppEventsClient({this.throwOnCalls = false});

  final bool throwOnCalls;
  int activateCalls = 0;
  final List<bool> autoLogEnabledStates = [];
  final List<_EventCall> eventCalls = [];
  final List<_ViewContentCall> viewContentCalls = [];
  final List<_AddToCartCall> addToCartCalls = [];
  final List<_InitiatedCheckoutCall> initiatedCheckoutCalls = [];
  final List<_PurchaseCall> purchaseCalls = [];

  void _maybeThrow() {
    if (throwOnCalls) {
      throw Exception('meta sdk unavailable');
    }
  }

  @override
  Future<void> activateApp({String? applicationId}) async {
    _maybeThrow();
    activateCalls += 1;
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> logAddToCart({
    Map<String, dynamic>? content,
    required String id,
    required String type,
    required String currency,
    required double price,
    Map<String, dynamic>? parameters,
  }) async {
    _maybeThrow();
    addToCartCalls.add(
      _AddToCartCall(
        content: content ?? const {},
        id: id,
        type: type,
        currency: currency,
        price: price,
        parameters: parameters ?? const {},
      ),
    );
  }

  @override
  Future<void> logCompletedRegistration({
    String? registrationMethod,
    Map<String, dynamic>? parameters,
  }) async {
    _maybeThrow();
  }

  @override
  Future<void> logEvent({
    required String name,
    Map<String, dynamic>? parameters,
    double? valueToSum,
  }) async {
    _maybeThrow();
    eventCalls.add(
      _EventCall(
        name: name,
        parameters: parameters ?? const {},
        valueToSum: valueToSum,
      ),
    );
  }

  @override
  Future<void> logInitiatedCheckout({
    double? totalPrice,
    String? currency,
    String? contentType,
    String? contentId,
    int? numItems,
    bool paymentInfoAvailable = false,
    Map<String, dynamic>? parameters,
  }) async {
    _maybeThrow();
    initiatedCheckoutCalls.add(
      _InitiatedCheckoutCall(
        totalPrice: totalPrice,
        currency: currency,
        contentType: contentType,
        contentId: contentId,
        numItems: numItems,
        paymentInfoAvailable: paymentInfoAvailable,
        parameters: parameters ?? const {},
      ),
    );
  }

  @override
  Future<void> logPurchase({
    required double amount,
    required String currency,
    Map<String, dynamic>? parameters,
  }) async {
    _maybeThrow();
    purchaseCalls.add(
      _PurchaseCall(
        amount: amount,
        currency: currency,
        parameters: parameters ?? const {},
      ),
    );
  }

  @override
  Future<void> logViewContent({
    Map<String, dynamic>? content,
    String? id,
    String? type,
    String? currency,
    double? price,
    Map<String, dynamic>? parameters,
  }) async {
    _maybeThrow();
    viewContentCalls.add(
      _ViewContentCall(
        content: content ?? const {},
        id: id,
        type: type,
        currency: currency,
        price: price,
        parameters: parameters ?? const {},
      ),
    );
  }

  @override
  Future<void> setAutoLogAppEventsEnabled(bool enabled) async {
    _maybeThrow();
    autoLogEnabledStates.add(enabled);
  }
}

class _EventCall {
  const _EventCall({
    required this.name,
    required this.parameters,
    required this.valueToSum,
  });

  final String name;
  final Map<String, dynamic> parameters;
  final double? valueToSum;
}

class _ViewContentCall {
  const _ViewContentCall({
    required this.content,
    required this.id,
    required this.type,
    required this.currency,
    required this.price,
    required this.parameters,
  });

  final Map<String, dynamic> content;
  final String? id;
  final String? type;
  final String? currency;
  final double? price;
  final Map<String, dynamic> parameters;
}

class _AddToCartCall {
  const _AddToCartCall({
    required this.content,
    required this.id,
    required this.type,
    required this.currency,
    required this.price,
    required this.parameters,
  });

  final Map<String, dynamic> content;
  final String id;
  final String type;
  final String currency;
  final double price;
  final Map<String, dynamic> parameters;
}

class _InitiatedCheckoutCall {
  const _InitiatedCheckoutCall({
    required this.totalPrice,
    required this.currency,
    required this.contentType,
    required this.contentId,
    required this.numItems,
    required this.paymentInfoAvailable,
    required this.parameters,
  });

  final double? totalPrice;
  final String? currency;
  final String? contentType;
  final String? contentId;
  final int? numItems;
  final bool paymentInfoAvailable;
  final Map<String, dynamic> parameters;
}

class _PurchaseCall {
  const _PurchaseCall({
    required this.amount,
    required this.currency,
    required this.parameters,
  });

  final double amount;
  final String currency;
  final Map<String, dynamic> parameters;
}
