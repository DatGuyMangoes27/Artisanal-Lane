class CheckoutSession {
  /// The (first) order created. For several shops see [orderIds].
  final String orderId;

  /// TradeSafe payment page. Null for a several-shop checkout that the
  /// buyer's TradeSafe wallet already covered (status "funded").
  final String? checkoutUrl;
  final String? transactionId;

  /// Set only when the basket had several shops: one order per shop, paid
  /// with one TradeSafe payment.
  final String? checkoutGroupId;
  final List<String> orderIds;

  /// "awaiting_payment" or "funded" for a several-shop checkout.
  final String? status;

  /// Amount due for a several-shop checkout, as worked out by the server.
  final double? total;

  const CheckoutSession({
    required this.orderId,
    required this.checkoutUrl,
    this.transactionId,
    this.checkoutGroupId,
    this.orderIds = const [],
    this.status,
    this.total,
  });

  factory CheckoutSession.fromJson(Map<String, dynamic> json) {
    final orderId = json['orderId'] as String;
    final orderIds = (json['orderIds'] as List? ?? const [])
        .whereType<String>()
        .toList(growable: false);
    final url = json['checkoutUrl'] as String?;
    return CheckoutSession(
      orderId: orderId,
      checkoutUrl: url == null || url.trim().isEmpty ? null : url,
      transactionId: json['transactionId'] as String?,
      checkoutGroupId: json['checkoutGroupId'] as String?,
      orderIds: orderIds.isEmpty ? [orderId] : orderIds,
      status: json['status'] as String?,
      total: (json['total'] as num?)?.toDouble(),
    );
  }

  bool get isMultiShop => checkoutGroupId != null;

  /// Already paid from the buyer's TradeSafe wallet: no payment page needed.
  bool get isFunded => status == CheckoutGroupStatus.funded;
}

/// Result of the `checkout-group-status` edge function.
class CheckoutGroupStatus {
  static const awaitingPayment = 'awaiting_payment';
  static const funded = 'funded';
  static const cancelled = 'cancelled';
  static const needsAttention = 'needs_attention';

  final String checkoutGroupId;
  final String status;
  final List<String> orderIds;
  final List<String> paidOrderIds;
  final String? checkoutUrl;

  const CheckoutGroupStatus({
    required this.checkoutGroupId,
    required this.status,
    this.orderIds = const [],
    this.paidOrderIds = const [],
    this.checkoutUrl,
  });

  factory CheckoutGroupStatus.fromJson(Map<String, dynamic> json) {
    List<String> ids(String key) => (json[key] as List? ?? const [])
        .whereType<String>()
        .toList(growable: false);
    final url = json['checkoutUrl'] as String?;
    return CheckoutGroupStatus(
      checkoutGroupId: json['checkoutGroupId'] as String? ?? '',
      status: json['status'] as String? ?? awaitingPayment,
      orderIds: ids('orderIds'),
      paidOrderIds: ids('paidOrderIds'),
      checkoutUrl: url == null || url.trim().isEmpty ? null : url,
    );
  }

  bool get isFunded => status == funded;
  bool get isAwaitingPayment => status == awaitingPayment;
  bool get isCancelled => status == cancelled;
  bool get needsHelp => status == needsAttention;
}
