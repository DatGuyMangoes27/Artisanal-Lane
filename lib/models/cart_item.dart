import 'product.dart';

/// How long a cart item is held before it expires and is automatically removed.
const kCartExpiryHours = 48;

class CartItem {
  final String id;
  final String cartId;
  final String productId;
  final int quantity;
  final DateTime createdAt;

  // Joined product data
  final Product? product;

  const CartItem({
    required this.id,
    required this.cartId,
    required this.productId,
    required this.quantity,
    required this.createdAt,
    this.product,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    final productData = json['products'] as Map<String, dynamic>?;

    return CartItem(
      id: json['id'] as String,
      cartId: json['cart_id'] as String,
      productId: json['product_id'] as String,
      quantity: json['quantity'] as int? ?? 1,
      createdAt: DateTime.parse(json['created_at'] as String),
      product: productData != null ? Product.fromJson(productData) : null,
    );
  }

  DateTime get expiresAt =>
      createdAt.toLocal().add(Duration(hours: kCartExpiryHours));

  /// Positive = hours remaining; negative = already expired.
  double get hoursRemaining =>
      expiresAt.difference(DateTime.now()).inMinutes / 60.0;

  bool get isExpired => hoursRemaining <= 0;

  /// True when fewer than 6 hours remain — shown as a warning.
  bool get isExpiringSoon => !isExpired && hoursRemaining < 6;

  /// Human-readable label, e.g. "23h left", "45 min left", "Expired"
  String get expiryLabel {
    if (isExpired) return 'Expired';
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining.inHours >= 1) return '${remaining.inHours}h left';
    return '${remaining.inMinutes}m left';
  }

  double get lineTotal => (product?.price ?? 0) * quantity;
}
