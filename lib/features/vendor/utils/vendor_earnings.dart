const Set<String> vendorEarningOrderStatuses = {
  'paid',
  'shipped',
  'delivered',
  'completed',
  'disputed',
};

const Set<String> vendorEarningEscrowStatuses = {'held', 'released'};

bool countsTowardVendorEarnings(String? orderStatus) {
  return vendorEarningOrderStatuses.contains(orderStatus);
}

bool escrowCountsTowardVendorEarnings(String? escrowStatus) {
  return vendorEarningEscrowStatuses.contains(escrowStatus);
}
