class VendorSubscription {
  final String vendorId;
  final String planCode;
  final double amount;
  final String currency;
  final String status;
  final String? checkoutReference;
  final String? payfastSubscriptionId;
  final String? payfastToken;
  final String? payfastPaymentId;
  final String? payfastEmail;
  final DateTime? currentPeriodStart;
  final DateTime? currentPeriodEnd;
  final DateTime? startedAt;
  final DateTime? lastPaymentAt;
  final DateTime? cancelledAt;
  final String? statusReason;
  final DateTime? lastItnAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const VendorSubscription({
    required this.vendorId,
    required this.planCode,
    required this.amount,
    required this.currency,
    required this.status,
    this.checkoutReference,
    this.payfastSubscriptionId,
    this.payfastToken,
    this.payfastPaymentId,
    this.payfastEmail,
    this.currentPeriodStart,
    this.currentPeriodEnd,
    this.startedAt,
    this.lastPaymentAt,
    this.cancelledAt,
    this.statusReason,
    this.lastItnAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VendorSubscription.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String key) {
      final value = json[key];
      if (value == null) return null;
      return DateTime.parse(value as String);
    }

    return VendorSubscription(
      vendorId: json['vendor_id'] as String,
      planCode: json['plan_code'] as String? ?? 'artisan-monthly',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'ZAR',
      status: json['status'] as String? ?? 'inactive',
      checkoutReference: json['checkout_reference'] as String?,
      payfastSubscriptionId: json['payfast_subscription_id'] as String?,
      payfastToken: json['payfast_token'] as String?,
      payfastPaymentId: json['payfast_payment_id'] as String?,
      payfastEmail: json['payfast_email'] as String?,
      currentPeriodStart: parseDate('current_period_start'),
      currentPeriodEnd: parseDate('current_period_end'),
      startedAt: parseDate('started_at'),
      lastPaymentAt: parseDate('last_payment_at'),
      cancelledAt: parseDate('cancelled_at'),
      statusReason: json['status_reason'] as String?,
      lastItnAt: parseDate('last_itn_at'),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'vendor_id': vendorId,
        'plan_code': planCode,
        'amount': amount,
        'currency': currency,
        'status': status,
        'checkout_reference': checkoutReference,
        'payfast_subscription_id': payfastSubscriptionId,
        'payfast_token': payfastToken,
        'payfast_payment_id': payfastPaymentId,
        'payfast_email': payfastEmail,
        'current_period_start': currentPeriodStart?.toIso8601String(),
        'current_period_end': currentPeriodEnd?.toIso8601String(),
        'started_at': startedAt?.toIso8601String(),
        'last_payment_at': lastPaymentAt?.toIso8601String(),
        'cancelled_at': cancelledAt?.toIso8601String(),
        'status_reason': statusReason,
        'last_itn_at': lastItnAt?.toIso8601String(),
      };
}
