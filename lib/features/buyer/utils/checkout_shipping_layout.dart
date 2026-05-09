enum CheckoutShippingInlineDetails {
  none,
  courierGuyLockerSearch,
  pargoPickupPointSearch,
  pickupPointEntry,
  marketPickupNote,
}

CheckoutShippingInlineDetails inlineDetailsForShippingMethod(
  String? shippingMethod,
) {
  switch (shippingMethod) {
    case 'courier_guy':
      return CheckoutShippingInlineDetails.courierGuyLockerSearch;
    case 'courier_guy_door_to_door':
      return CheckoutShippingInlineDetails.none;
    case 'pargo':
      return CheckoutShippingInlineDetails.pargoPickupPointSearch;
    case 'market_pickup':
      return CheckoutShippingInlineDetails.marketPickupNote;
    default:
      return CheckoutShippingInlineDetails.none;
  }
}
