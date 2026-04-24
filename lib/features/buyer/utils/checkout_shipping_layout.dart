enum CheckoutShippingInlineDetails {
  none,
  courierGuyLockerSearch,
  pickupPointEntry,
  marketPickupNote,
}

CheckoutShippingInlineDetails inlineDetailsForShippingMethod(
  String? shippingMethod,
) {
  switch (shippingMethod) {
    case 'courier_guy':
      return CheckoutShippingInlineDetails.courierGuyLockerSearch;
    case 'pargo':
      return CheckoutShippingInlineDetails.pickupPointEntry;
    case 'market_pickup':
      return CheckoutShippingInlineDetails.marketPickupNote;
    default:
      return CheckoutShippingInlineDetails.none;
  }
}
