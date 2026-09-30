enum CheckoutField {
  fullName,
  streetAddress,
  city,
  postalCode,
  province,
  phoneNumber,
  shippingMethod,
  pickupPoint,
  suburb,
  bobGoRate,
}

class CheckoutFormSnapshot {
  final String fullName;
  final String streetAddress;
  final String city;
  final String postalCode;
  final String? province;
  final String phoneNumber;
  final String? selectedShippingMethod;
  final bool hasAvailableShippingMethods;
  final bool requiresShippingAddress;
  final bool requiresPickupPoint;
  final String pickupPoint;

  /// Bob Go door-to-door needs a suburb and a current saved rate.
  final bool requiresSuburb;
  final String suburb;
  final bool requiresBobGoRate;
  final bool hasUsableBobGoRate;

  const CheckoutFormSnapshot({
    required this.fullName,
    required this.streetAddress,
    required this.city,
    required this.postalCode,
    required this.province,
    required this.phoneNumber,
    required this.selectedShippingMethod,
    required this.hasAvailableShippingMethods,
    required this.requiresShippingAddress,
    required this.requiresPickupPoint,
    required this.pickupPoint,
    this.requiresSuburb = false,
    this.suburb = '',
    this.requiresBobGoRate = false,
    this.hasUsableBobGoRate = false,
  });
}

CheckoutField? firstIncompleteCheckoutField(CheckoutFormSnapshot snapshot) {
  if (snapshot.fullName.trim().isEmpty) return CheckoutField.fullName;
  if (snapshot.requiresShippingAddress) {
    if (snapshot.streetAddress.trim().isEmpty) {
      return CheckoutField.streetAddress;
    }
    if (snapshot.city.trim().isEmpty) return CheckoutField.city;
    if (snapshot.postalCode.trim().isEmpty) return CheckoutField.postalCode;
    if ((snapshot.province ?? '').trim().isEmpty) return CheckoutField.province;
    if (snapshot.requiresSuburb && snapshot.suburb.trim().isEmpty) {
      return CheckoutField.suburb;
    }
  }
  if (snapshot.phoneNumber.trim().isEmpty) return CheckoutField.phoneNumber;
  if (!snapshot.hasAvailableShippingMethods ||
      (snapshot.selectedShippingMethod ?? '').trim().isEmpty) {
    return CheckoutField.shippingMethod;
  }
  if (snapshot.requiresPickupPoint && snapshot.pickupPoint.trim().isEmpty) {
    return CheckoutField.pickupPoint;
  }
  if (snapshot.requiresBobGoRate && !snapshot.hasUsableBobGoRate) {
    return CheckoutField.bobGoRate;
  }
  return null;
}

String checkoutBlockingMessage(CheckoutField? field) {
  if (field == CheckoutField.pickupPoint) {
    return 'Please enter the pickup point or drop-off location for this shipping method.';
  }
  if (field == CheckoutField.bobGoRate) {
    return 'Get delivery rates and choose a courier service before paying.';
  }
  if (field == CheckoutField.suburb) {
    return 'Please add your suburb so the courier can price delivery.';
  }
  if (field == CheckoutField.shippingMethod) {
    return 'This product does not have any shipping options available yet.';
  }
  return 'Please complete your checkout details before continuing to TradeSafe.';
}
