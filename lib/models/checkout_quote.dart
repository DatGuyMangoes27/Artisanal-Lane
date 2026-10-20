class CheckoutQuote {
  final String? couponCode;
  final double subtotal;
  final double discountAmount;
  final double discountedSubtotal;
  final double shippingCost;
  final double giftFee;
  final double total;

  /// Per-shop breakdown. Only filled in for a basket with several shops; a
  /// one-shop preview returns the basket totals alone.
  final List<CheckoutQuoteShop> shops;

  const CheckoutQuote({
    required this.couponCode,
    required this.subtotal,
    required this.discountAmount,
    required this.discountedSubtotal,
    required this.shippingCost,
    required this.giftFee,
    required this.total,
    this.shops = const [],
  });

  factory CheckoutQuote.fromJson(Map<String, dynamic> json) {
    double number(String key) => (json[key] as num?)?.toDouble() ?? 0;

    return CheckoutQuote(
      couponCode: json['couponCode'] as String?,
      subtotal: number('subtotal'),
      discountAmount: number('discountAmount'),
      discountedSubtotal: number('discountedSubtotal'),
      shippingCost: number('shippingCost'),
      giftFee: number('giftFee'),
      total: number('total'),
      shops: (json['shops'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (shop) =>
                CheckoutQuoteShop.fromJson(Map<String, dynamic>.from(shop)),
          )
          .toList(growable: false),
    );
  }

  /// Discount per shop id, for showing the saving under the right shop.
  Map<String, double> get discountByShop => {
    for (final shop in shops)
      if (shop.discountAmount > 0) shop.shopId: shop.discountAmount,
  };
}

/// One shop's share of a several-shop checkout preview.
class CheckoutQuoteShop {
  final String shopId;
  final String? shopName;
  final double subtotal;
  final double discountAmount;
  final double shippingCost;
  final double giftFee;
  final double total;

  const CheckoutQuoteShop({
    required this.shopId,
    this.shopName,
    required this.subtotal,
    required this.discountAmount,
    required this.shippingCost,
    required this.giftFee,
    required this.total,
  });

  factory CheckoutQuoteShop.fromJson(Map<String, dynamic> json) {
    double number(String key) => (json[key] as num?)?.toDouble() ?? 0;

    return CheckoutQuoteShop(
      shopId: json['shopId'] as String? ?? '',
      shopName: json['shopName'] as String?,
      subtotal: number('subtotal'),
      discountAmount: number('discountAmount'),
      shippingCost: number('shippingCost'),
      giftFee: number('giftFee'),
      total: number('total'),
    );
  }
}
