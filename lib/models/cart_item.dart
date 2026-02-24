import 'product.dart';

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

  double get lineTotal => (product?.price ?? 0) * quantity;
}
