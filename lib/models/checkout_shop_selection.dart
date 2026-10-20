import 'bobgo.dart';

/// The buyer's delivery choice for one shop in the basket, sent to
/// `create-checkout` as one entry of `shops`.
class CheckoutShopSelection {
  final String shopId;
  final String shippingMethod;
  final double shippingCost;
  final BobGoSelection? bobgo;

  /// Address fields for this shop's order only (e.g. its `pickup_point`).
  /// The server lays them over the top-level `shippingAddress`.
  final Map<String, dynamic>? shippingAddress;

  const CheckoutShopSelection({
    required this.shopId,
    required this.shippingMethod,
    required this.shippingCost,
    this.bobgo,
    this.shippingAddress,
  });

  CheckoutShopSelection copyWith({Map<String, dynamic>? shippingAddress}) =>
      CheckoutShopSelection(
        shopId: shopId,
        shippingMethod: shippingMethod,
        shippingCost: shippingCost,
        bobgo: bobgo,
        shippingAddress: shippingAddress ?? this.shippingAddress,
      );

  Map<String, dynamic> toJson() => {
    'shopId': shopId,
    'shippingMethod': shippingMethod,
    'shippingCost': shippingCost,
    if (bobgo != null) ...bobgo!.toCheckoutJson(),
    if (shippingAddress != null && shippingAddress!.isNotEmpty)
      'shippingAddress': shippingAddress,
  };
}

/// Request body for `create-checkout` (real checkout and `previewOnly`).
///
/// Always sends `shops` (one entry per basket shop). A one-shop basket also
/// keeps the original top-level delivery fields so the server treats it
/// exactly as before.
Map<String, dynamic> buildCheckoutRequestBody({
  required String userId,
  required List<CheckoutShopSelection> shops,
  required bool isGift,
  Map<String, dynamic>? shippingAddress,
  String? giftRecipient,
  String? giftMessage,
  String? couponCode,
  bool previewOnly = false,
}) {
  if (shops.isEmpty) {
    throw ArgumentError.value(shops, 'shops', 'At least one shop is needed.');
  }
  final normalizedCoupon = couponCode?.trim().toUpperCase();
  final single = shops.length == 1 ? shops.single : null;
  return {
    'userId': userId,
    if (shippingAddress != null) 'shippingAddress': shippingAddress,
    if (single != null) ...{
      'shippingMethod': single.shippingMethod,
      'shippingCost': single.shippingCost,
      if (single.bobgo != null) ...single.bobgo!.toCheckoutJson(),
    },
    'shops': shops.map((shop) => shop.toJson()).toList(growable: false),
    'isGift': isGift,
    if (!previewOnly) ...{
      'giftRecipient': giftRecipient,
      'giftMessage': giftMessage,
    },
    'couponCode': normalizedCoupon == null || normalizedCoupon.isEmpty
        ? null
        : normalizedCoupon,
    if (previewOnly) 'previewOnly': true,
  };
}
