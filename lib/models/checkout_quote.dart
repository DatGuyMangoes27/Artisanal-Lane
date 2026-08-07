class CheckoutQuote {
  final String? couponCode;
  final double subtotal;
  final double discountAmount;
  final double discountedSubtotal;
  final double shippingCost;
  final double giftFee;
  final double total;

  const CheckoutQuote({
    required this.couponCode,
    required this.subtotal,
    required this.discountAmount,
    required this.discountedSubtotal,
    required this.shippingCost,
    required this.giftFee,
    required this.total,
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
    );
  }
}
