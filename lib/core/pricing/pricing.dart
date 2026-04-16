const double giftServiceFee = 30;
const String giftServiceLabel = 'Gift wrap & card';

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
