import 'dart:convert';

import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../models/cart_item.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../models/product_variant.dart';

final metaAppEventsServiceProvider = Provider<MetaAppEventsService>((ref) {
  return MetaAppEventsService();
});

abstract class MetaAppEventsClient {
  Future<void> activateApp({String? applicationId});

  Future<void> flush();

  Future<void> logAddToCart({
    Map<String, dynamic>? content,
    required String id,
    required String type,
    required String currency,
    required double price,
    Map<String, dynamic>? parameters,
  });

  Future<void> logCompletedRegistration({
    String? registrationMethod,
    Map<String, dynamic>? parameters,
  });

  Future<void> logEvent({
    required String name,
    Map<String, dynamic>? parameters,
    double? valueToSum,
  });

  Future<void> logInitiatedCheckout({
    double? totalPrice,
    String? currency,
    String? contentType,
    String? contentId,
    int? numItems,
    bool paymentInfoAvailable = false,
    Map<String, dynamic>? parameters,
  });

  Future<void> logPurchase({
    required double amount,
    required String currency,
    Map<String, dynamic>? parameters,
  });

  Future<void> logViewContent({
    Map<String, dynamic>? content,
    String? id,
    String? type,
    String? currency,
    double? price,
    Map<String, dynamic>? parameters,
  });

  Future<void> setAutoLogAppEventsEnabled(bool enabled);
}

class FacebookMetaAppEventsClient implements MetaAppEventsClient {
  FacebookMetaAppEventsClient({FacebookAppEvents? events})
    : _events = events ?? FacebookAppEvents();

  final FacebookAppEvents _events;

  @override
  Future<void> activateApp({String? applicationId}) {
    return _events.activateApp(applicationId: applicationId);
  }

  @override
  Future<void> flush() {
    return _events.flush();
  }

  @override
  Future<void> logAddToCart({
    Map<String, dynamic>? content,
    required String id,
    required String type,
    required String currency,
    required double price,
    Map<String, dynamic>? parameters,
  }) {
    return _events.logAddToCart(
      content: content,
      id: id,
      type: type,
      currency: currency,
      price: price,
      parameters: parameters,
    );
  }

  @override
  Future<void> logCompletedRegistration({
    String? registrationMethod,
    Map<String, dynamic>? parameters,
  }) {
    return _events.logCompletedRegistration(
      registrationMethod: registrationMethod,
      parameters: parameters,
    );
  }

  @override
  Future<void> logEvent({
    required String name,
    Map<String, dynamic>? parameters,
    double? valueToSum,
  }) {
    return _events.logEvent(
      name: name,
      parameters: parameters,
      valueToSum: valueToSum,
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
  }) {
    return _events.logInitiatedCheckout(
      totalPrice: totalPrice,
      currency: currency,
      contentType: contentType,
      contentId: contentId,
      numItems: numItems,
      paymentInfoAvailable: paymentInfoAvailable,
      parameters: parameters,
    );
  }

  @override
  Future<void> logPurchase({
    required double amount,
    required String currency,
    Map<String, dynamic>? parameters,
  }) {
    return _events.logPurchase(
      amount: amount,
      currency: currency,
      parameters: parameters,
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
  }) {
    return _events.logViewContent(
      content: content,
      id: id,
      type: type,
      currency: currency,
      price: price,
      parameters: parameters,
    );
  }

  @override
  Future<void> setAutoLogAppEventsEnabled(bool enabled) {
    return _events.setAutoLogAppEventsEnabled(enabled);
  }
}

class MetaAppEventsService {
  MetaAppEventsService({MetaAppEventsClient? client})
    : _client = client ?? FacebookMetaAppEventsClient();

  final MetaAppEventsClient _client;
  final Set<String> _trackedProductViews = <String>{};
  final Set<String> _trackedPurchases = <String>{};

  Future<void> initialize() async {
    await _safe(() async {
      await _client.setAutoLogAppEventsEnabled(true);
      await _client.activateApp();
    });
  }

  Future<void> logCompletedRegistration({
    required String registrationMethod,
    required String requestedRole,
  }) async {
    final normalizedMethod = registrationMethod.trim();
    if (normalizedMethod.isEmpty) return;

    await _safe(() {
      return _client.logCompletedRegistration(
        registrationMethod: normalizedMethod,
        parameters: <String, dynamic>{'requested_role': requestedRole},
      );
    });
  }

  Future<void> logSearch({required String query}) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return;

    await _safe(() {
      return _client.logEvent(
        name: 'fb_mobile_search',
        parameters: <String, dynamic>{
          'fb_search_string': normalizedQuery,
          'fb_content_type': 'product',
        },
      );
    });
  }

  Future<void> logViewedProduct(Product product, {ProductVariant? variant}) async {
    final contentItem = _MetaContentItem.fromProduct(
      product,
      variant: variant,
      quantity: 1,
    );
    if (!_trackedProductViews.add(contentItem.eventKey)) return;

    await _safe(() {
      return _client.logViewContent(
        content: contentItem.toContentMap(),
        id: contentItem.id,
        type: 'product',
        currency: AppConstants.currencyCode,
        price: contentItem.itemPrice,
        parameters: <String, dynamic>{
          'fb_content_id': contentItem.id,
          'fb_content_type': 'product',
          'product_name': product.title,
          if ((product.categoryName ?? '').trim().isNotEmpty)
            'category_name': product.categoryName!.trim(),
          if ((variant?.displayName ?? '').trim().isNotEmpty)
            'variant_name': variant!.displayName.trim(),
        },
      );
    });
  }

  Future<void> logAddToCart(
    Product product, {
    ProductVariant? variant,
    int quantity = 1,
  }) async {
    if (quantity <= 0) return;
    final contentItem = _MetaContentItem.fromProduct(
      product,
      variant: variant,
      quantity: quantity,
    );

    await _safe(() {
      return _client.logAddToCart(
        content: contentItem.toContentMap(),
        id: contentItem.id,
        type: 'product',
        currency: AppConstants.currencyCode,
        price: contentItem.itemPrice,
        parameters: <String, dynamic>{
          'fb_content_id': contentItem.id,
          'fb_content_type': 'product',
          'product_name': product.title,
          if ((variant?.displayName ?? '').trim().isNotEmpty)
            'variant_name': variant!.displayName.trim(),
        },
      );
    });
  }

  Future<void> logInitiatedCheckout({
    required List<CartItem> items,
    required double totalPrice,
    String? shippingMethod,
  }) async {
    if (items.isEmpty) return;
    final contentItems = items
        .map(_MetaContentItem.fromCartItem)
        .toList(growable: false);

    await _safe(() {
      return _client.logInitiatedCheckout(
        totalPrice: totalPrice,
        currency: AppConstants.currencyCode,
        contentType: 'product',
        numItems: _itemCount(contentItems),
        parameters: <String, dynamic>{
          'fb_content_type': 'product',
          'fb_content': jsonEncode(
            contentItems.map((item) => item.toContentMap()).toList(),
          ),
          if ((shippingMethod ?? '').trim().isNotEmpty)
            'shipping_method': shippingMethod!.trim(),
        },
      );
    });
  }

  Future<void> logPurchasedOrder(Order order) async {
    if (order.status == 'pending' || !_trackedPurchases.add(order.id)) return;
    final contentItems =
        (order.items ?? const <OrderItem>[])
            .map(_MetaContentItem.fromOrderItem)
            .toList(growable: false);

    await _safe(() async {
      await _client.logPurchase(
        amount: order.grandTotal,
        currency: AppConstants.currencyCode,
        parameters: <String, dynamic>{
          'fb_order_id': order.id,
          'fb_num_items': _itemCount(contentItems),
          'fb_content_type': 'product',
          if (contentItems.isNotEmpty)
            'fb_content': jsonEncode(
              contentItems.map((item) => item.toContentMap()).toList(),
            ),
          if ((order.shippingMethod ?? '').trim().isNotEmpty)
            'shipping_method': order.shippingMethod!.trim(),
        },
      );
      await _client.flush();
    });
  }

  int _itemCount(List<_MetaContentItem> items) {
    return items.fold<int>(0, (sum, item) => sum + item.quantity);
  }

  Future<void> _safe(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {}
  }
}

class _MetaContentItem {
  const _MetaContentItem({
    required this.id,
    required this.quantity,
    required this.itemPrice,
  });

  factory _MetaContentItem.fromCartItem(CartItem item) {
    final identifier = item.variant?.id ?? item.productId;
    final unitPrice = item.variant?.price ?? item.product?.price ?? 0;
    return _MetaContentItem(
      id: identifier,
      quantity: item.quantity,
      itemPrice: unitPrice,
    );
  }

  factory _MetaContentItem.fromOrderItem(OrderItem item) {
    return _MetaContentItem(
      id: item.variantId ?? item.productId,
      quantity: item.quantity,
      itemPrice: item.unitPrice,
    );
  }

  factory _MetaContentItem.fromProduct(
    Product product, {
    ProductVariant? variant,
    required int quantity,
  }) {
    return _MetaContentItem(
      id: variant?.id ?? product.id,
      quantity: quantity,
      itemPrice: variant?.price ?? product.price,
    );
  }

  final String id;
  final int quantity;
  final double itemPrice;

  String get eventKey => '$id:$quantity:${itemPrice.toStringAsFixed(2)}';

  Map<String, dynamic> toContentMap() {
    return <String, dynamic>{
      'id': id,
      'quantity': quantity,
      'item_price': itemPrice,
    };
  }
}
