class VendorSubscriptionCheckoutSession {
  final String checkoutUrl;
  final String checkoutReference;
  final double amount;
  final String status;

  const VendorSubscriptionCheckoutSession({
    required this.checkoutUrl,
    required this.checkoutReference,
    required this.amount,
    required this.status,
  });

  factory VendorSubscriptionCheckoutSession.fromJson(
    Map<String, dynamic> json,
  ) {
    return VendorSubscriptionCheckoutSession(
      checkoutUrl: json['checkoutUrl'] as String,
      checkoutReference: json['checkoutReference'] as String,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'inactive',
    );
  }
}
