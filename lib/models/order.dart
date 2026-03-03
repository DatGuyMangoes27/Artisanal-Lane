class Order {
  final String id;
  final String buyerId;
  final String shopId;
  final String status;
  final double total;
  final double shippingCost;
  final String? shippingMethod;
  final Map<String, dynamic>? shippingAddress;
  final String? trackingNumber;
  final bool isGift;
  final String? giftRecipient;
  final String? giftMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined data
  final String? shopName;
  final List<OrderItem>? items;

  const Order({
    required this.id,
    required this.buyerId,
    required this.shopId,
    required this.status,
    required this.total,
    this.shippingCost = 0,
    this.shippingMethod,
    this.shippingAddress,
    this.trackingNumber,
    this.isGift = false,
    this.giftRecipient,
    this.giftMessage,
    required this.createdAt,
    required this.updatedAt,
    this.shopName,
    this.items,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    final shopData = json['shops'] as Map<String, dynamic>?;
    final itemsData = json['order_items'] as List?;

    return Order(
      id: json['id'] as String,
      buyerId: json['buyer_id'] as String,
      shopId: json['shop_id'] as String,
      status: json['status'] as String? ?? 'pending',
      total: (json['total'] as num).toDouble(),
      shippingCost: (json['shipping_cost'] as num?)?.toDouble() ?? 0,
      shippingMethod: json['shipping_method'] as String?,
      shippingAddress: json['shipping_address'] as Map<String, dynamic>?,
      trackingNumber: json['tracking_number'] as String?,
      isGift: json['is_gift'] as bool? ?? false,
      giftRecipient: json['gift_recipient'] as String?,
      giftMessage: json['gift_message'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      shopName: shopData?['name'] as String?,
      items: itemsData?.map((e) => OrderItem.fromJson(e)).toList(),
    );
  }

  String get shortId => id.substring(0, 8).toUpperCase();
  double get grandTotal => total + shippingCost;

  String get shippingMethodDisplay {
    switch (shippingMethod) {
      case 'courier_guy':
        return 'The Courier Guy';
      case 'pargo':
        return 'Pargo';
      case 'paxi':
        return 'PAXI';
      case 'market_pickup':
        return 'Market Pickup';
      default:
        return shippingMethod ?? 'Unknown';
    }
  }
}

class OrderItem {
  final String id;
  final String orderId;
  final String productId;
  final int quantity;
  final double unitPrice;
  final DateTime createdAt;

  // Joined data
  final String? productTitle;
  final String? productImage;

  const OrderItem({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.createdAt,
    this.productTitle,
    this.productImage,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    final productData = json['products'] as Map<String, dynamic>?;
    List<String> parseImages(dynamic img) {
      if (img == null) return [];
      if (img is List) return img.map((e) => e.toString()).toList();
      return [];
    }

    return OrderItem(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      productId: json['product_id'] as String,
      quantity: json['quantity'] as int,
      unitPrice: (json['unit_price'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      productTitle: productData?['title'] as String?,
      productImage: parseImages(productData?['images']).isNotEmpty
          ? parseImages(productData?['images']).first
          : null,
    );
  }

  double get lineTotal => unitPrice * quantity;
}
