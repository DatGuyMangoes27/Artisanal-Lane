const double giftServiceFee = 7;

double giftFeeForSelection({required bool isGift}) {
  return isGift ? giftServiceFee : 0;
}

double calculateCheckoutTotal({
  required double subtotal,
  required double shippingCost,
  required bool isGift,
}) {
  return subtotal + shippingCost + giftFeeForSelection(isGift: isGift);
}
