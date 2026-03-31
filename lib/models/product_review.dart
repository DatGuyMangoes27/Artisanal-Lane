class ProductReview {
  final String id;
  final String productId;
  final String shopId;
  final String buyerId;
  final String? orderId;
  final String? orderItemId;
  final int rating;
  final String? reviewText;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? buyerDisplayName;
  final String? buyerAvatarUrl;

  const ProductReview({
    required this.id,
    required this.productId,
    required this.shopId,
    required this.buyerId,
    this.orderId,
    this.orderItemId,
    required this.rating,
    this.reviewText,
    required this.createdAt,
    required this.updatedAt,
    this.buyerDisplayName,
    this.buyerAvatarUrl,
  });

  factory ProductReview.fromJson(Map<String, dynamic> json) {
    final profileData = json['profiles'] as Map<String, dynamic>?;

    return ProductReview(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      shopId: json['shop_id'] as String,
      buyerId: json['buyer_id'] as String,
      orderId: json['order_id'] as String?,
      orderItemId: json['order_item_id'] as String?,
      rating: json['rating'] as int,
      reviewText: json['review_text'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      buyerDisplayName: profileData?['display_name'] as String?,
      buyerAvatarUrl: profileData?['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'product_id': productId,
    'shop_id': shopId,
    'buyer_id': buyerId,
    'order_id': orderId,
    'order_item_id': orderItemId,
    'rating': rating,
    'review_text': reviewText,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}
