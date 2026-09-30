/// Courier status vocabulary for Bob Go shipments. Mirrors
/// supabase/functions/_shared/bobgo-tracking.mjs; unknown statuses are shown as
/// "In progress" rather than as raw courier text.
enum BobGoStatusGroup {
  awaitingCollection,
  collected,
  inTransit,
  outForDelivery,
  delivered,
  exception,
  returned,
  cancelled,
  unknown,
}

const _groups = <BobGoStatusGroup, List<String>>{
  BobGoStatusGroup.delivered: ['delivered', 'collected-by-customer'],
  BobGoStatusGroup.cancelled: [
    'cancelled',
    'canceled',
    'shipment-cancelled',
  ],
  BobGoStatusGroup.returned: [
    'returned',
    'returning',
    'return-to-sender',
    'returned-to-sender',
  ],
  BobGoStatusGroup.exception: [
    'failed-delivery',
    'delivery-failed',
    'exception',
    'failed',
    'delayed',
    'lost',
    'damaged',
    'undeliverable',
  ],
  BobGoStatusGroup.outForDelivery: [
    'out-for-delivery',
    'with-delivery-courier',
    'out-for-delivery-attempt',
  ],
  BobGoStatusGroup.inTransit: [
    'in-transit',
    'in-transit-to-destination',
    'at-hub',
    'at-destination-hub',
    'dispatched',
    'departed',
    'arrived',
  ],
  BobGoStatusGroup.collected: [
    'collected',
    'picked-up',
    'pickup-complete',
    'collection-complete',
  ],
  BobGoStatusGroup.awaitingCollection: [
    'submitted',
    'pending',
    'pending-collection',
    'collection-assigned',
    'collection-pending',
    'booked',
    'created',
    'confirmed',
    'ready-for-collection',
    'awaiting-collection',
  ],
};

BobGoStatusGroup bobGoStatusGroup(String? raw) {
  final normalized = (raw ?? '')
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[_\s]+'), '-');
  if (normalized.isEmpty) return BobGoStatusGroup.unknown;
  for (final entry in _groups.entries) {
    if (entry.value.contains(normalized)) return entry.key;
  }
  return BobGoStatusGroup.unknown;
}

String bobGoStatusLabel(String? raw) {
  switch (bobGoStatusGroup(raw)) {
    case BobGoStatusGroup.awaitingCollection:
      return 'Booked - waiting for courier collection';
    case BobGoStatusGroup.collected:
      return 'Collected by the courier';
    case BobGoStatusGroup.inTransit:
      return 'On its way';
    case BobGoStatusGroup.outForDelivery:
      return 'Out for delivery';
    case BobGoStatusGroup.delivered:
      return 'Delivered';
    case BobGoStatusGroup.exception:
      return 'Delivery problem - the courier will retry';
    case BobGoStatusGroup.returned:
      return 'Returning to the artisan';
    case BobGoStatusGroup.cancelled:
      return 'Courier booking cancelled';
    case BobGoStatusGroup.unknown:
      return 'In progress';
  }
}
