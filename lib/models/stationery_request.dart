class StationeryRequestItem {
  final String key;
  final String name;
  final int quantity;

  const StationeryRequestItem({
    required this.key,
    required this.name,
    required this.quantity,
  });

  factory StationeryRequestItem.fromJson(Map<String, dynamic> json) {
    return StationeryRequestItem(
      key: json['key'] as String? ?? '',
      name: json['name'] as String? ?? json['key'] as String? ?? 'Item',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
    );
  }
}

class StationeryRequest {
  final String id;
  final String shopId;
  final String vendorId;
  final List<StationeryRequestItem> items;
  final String? notes;
  final String? deliveryAddress;
  final String status;
  final String? adminNotes;
  final String? trackingNumber;
  final String? courierName;
  final double amount;
  final String currency;
  final String? checkoutReference;
  final String? paymentReference;
  final String? payfastPaymentId;
  final String? payfastEmail;
  final String? statusReason;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? fulfilledAt;
  final DateTime? paidAt;
  final DateTime? lastItnAt;

  const StationeryRequest({
    required this.id,
    required this.shopId,
    required this.vendorId,
    this.items = const [],
    this.notes,
    this.deliveryAddress,
    required this.status,
    this.adminNotes,
    this.trackingNumber,
    this.courierName,
    required this.amount,
    required this.currency,
    this.checkoutReference,
    this.paymentReference,
    this.payfastPaymentId,
    this.payfastEmail,
    this.statusReason,
    required this.createdAt,
    required this.updatedAt,
    this.fulfilledAt,
    this.paidAt,
    this.lastItnAt,
  });

  factory StationeryRequest.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'];

    return StationeryRequest(
      id: json['id'] as String,
      shopId: json['shop_id'] as String,
      vendorId: json['vendor_id'] as String,
      items: itemsJson is List
          ? itemsJson
                .whereType<Map>()
                .map(
                  (item) => StationeryRequestItem.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
      notes: json['notes'] as String?,
      deliveryAddress: json['delivery_address'] as String?,
      status: json['status'] as String? ?? 'awaiting_payment',
      adminNotes: json['admin_notes'] as String?,
      trackingNumber: json['tracking_number'] as String?,
      courierName: json['courier_name'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'ZAR',
      checkoutReference: json['checkout_reference'] as String?,
      paymentReference: json['payment_reference'] as String?,
      payfastPaymentId: json['payfast_payment_id'] as String?,
      payfastEmail: json['payfast_email'] as String?,
      statusReason: json['status_reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      fulfilledAt: json['fulfilled_at'] != null
          ? DateTime.parse(json['fulfilled_at'] as String)
          : null,
      paidAt: json['paid_at'] != null
          ? DateTime.parse(json['paid_at'] as String)
          : null,
      lastItnAt: json['last_itn_at'] != null
          ? DateTime.parse(json['last_itn_at'] as String)
          : null,
    );
  }

  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);

  bool get isAwaitingPayment => status == 'awaiting_payment';

  bool get isPaid => status == 'paid';

  bool get canRetryPayment => status == 'awaiting_payment';

  bool get isActive =>
      status == 'awaiting_payment' ||
      status == 'paid' ||
      status == 'processing';
}
