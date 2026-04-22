class StationeryCheckoutSession {
  final String requestId;
  final String checkoutUrl;
  final String checkoutReference;
  final double amount;
  final String currency;
  final String status;

  const StationeryCheckoutSession({
    required this.requestId,
    required this.checkoutUrl,
    required this.checkoutReference,
    required this.amount,
    required this.currency,
    required this.status,
  });

  factory StationeryCheckoutSession.fromJson(Map<String, dynamic> json) {
    return StationeryCheckoutSession(
      requestId: json['requestId'] as String,
      checkoutUrl: json['checkoutUrl'] as String,
      checkoutReference: json['checkoutReference'] as String,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'ZAR',
      status: json['status'] as String? ?? 'awaiting_payment',
    );
  }
}
