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
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? fulfilledAt;

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
    required this.createdAt,
    required this.updatedAt,
    this.fulfilledAt,
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
      status: json['status'] as String? ?? 'pending',
      adminNotes: json['admin_notes'] as String?,
      trackingNumber: json['tracking_number'] as String?,
      courierName: json['courier_name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      fulfilledAt: json['fulfilled_at'] != null
          ? DateTime.parse(json['fulfilled_at'] as String)
          : null,
    );
  }

  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);

  bool get isActive => status == 'pending' || status == 'processing';
}
