class CheckoutSession {
  final String orderId;
  final String checkoutUrl;
  final String? transactionId;

  const CheckoutSession({
    required this.orderId,
    required this.checkoutUrl,
    this.transactionId,
  });

  factory CheckoutSession.fromJson(Map<String, dynamic> json) {
    return CheckoutSession(
      orderId: json['orderId'] as String,
      checkoutUrl: json['checkoutUrl'] as String,
      transactionId: json['transactionId'] as String?,
    );
  }
}
