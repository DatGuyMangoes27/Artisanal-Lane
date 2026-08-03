class ShopCoupon {
  final String id;
  final String shopId;
  final String code;
  final String? description;
  final String discountType;
  final double discountValue;
  final String scope;
  final double minimumSubtotal;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool isActive;
  final List<String> productIds;

  const ShopCoupon({
    required this.id,
    required this.shopId,
    required this.code,
    required this.description,
    required this.discountType,
    required this.discountValue,
    required this.scope,
    required this.minimumSubtotal,
    required this.startsAt,
    required this.endsAt,
    required this.isActive,
    required this.productIds,
  });

  factory ShopCoupon.fromJson(Map<String, dynamic> json) {
    final links = json['shop_coupon_products'] as List? ?? const [];
    return ShopCoupon(
      id: json['id'] as String,
      shopId: json['shop_id'] as String,
      code: json['code'] as String,
      description: json['description'] as String?,
      discountType: json['discount_type'] as String,
      discountValue: (json['discount_value'] as num).toDouble(),
      scope: json['scope'] as String,
      minimumSubtotal: (json['minimum_subtotal'] as num?)?.toDouble() ?? 0,
      startsAt: DateTime.tryParse(json['starts_at'] as String? ?? ''),
      endsAt: DateTime.tryParse(json['ends_at'] as String? ?? ''),
      isActive: json['is_active'] as bool? ?? true,
      productIds: links
          .map((link) => (link as Map)['product_id'] as String)
          .toList(growable: false),
    );
  }
}
