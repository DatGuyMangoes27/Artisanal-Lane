import '../../../core/pricing/pricing.dart';
import '../../../models/cart_item.dart';
import '../../../models/checkout_session.dart';
import '../../../models/shipping_option.dart';
import 'bobgo_checkout.dart';
import 'product_shipping_checkout.dart';

/// Shown when a product arrives without its shop name.
const fallbackShopName = 'Artisan shop';

/// The basket lines that belong to one shop. Each shop packs and sends its
/// own parcel, so delivery is chosen per shop.
class CartShopGroup {
  final String shopId;
  final String shopName;
  final List<CartItem> items;

  const CartShopGroup({
    required this.shopId,
    required this.shopName,
    required this.items,
  });

  double get subtotal =>
      items.fold<double>(0, (sum, item) => sum + item.lineTotal);

  /// Number of pieces (quantities added up).
  int get itemCount => items.fold<int>(0, (sum, item) => sum + item.quantity);

  List<int> get quantities =>
      items.map((item) => item.quantity).toList(growable: false);

  List<List<ShippingOption>> get productShippingOptions => items
      .map((item) => item.product?.shippingOptions ?? const <ShippingOption>[])
      .toList(growable: false);

  /// Delivery options every product of this shop offers.
  List<ShippingOption> get availableShippingOptions =>
      availableShippingOptionsForProducts(productShippingOptions);
}

/// Groups basket lines by shop, keeping shops (and the lines inside each
/// shop) in the order they were first added.
List<CartShopGroup> groupCartItemsByShop(List<CartItem> items) {
  final order = <String>[];
  final lines = <String, List<CartItem>>{};
  final names = <String, String>{};
  for (final item in items) {
    final shopId = item.product?.shopId ?? '';
    if (!lines.containsKey(shopId)) {
      order.add(shopId);
      lines[shopId] = [];
    }
    lines[shopId]!.add(item);
    final name = item.product?.shopName?.trim();
    if (name != null && name.isNotEmpty) names.putIfAbsent(shopId, () => name);
  }
  return [
    for (final shopId in order)
      CartShopGroup(
        shopId: shopId,
        shopName: names[shopId] ?? fallbackShopName,
        items: List.unmodifiable(lines[shopId]!),
      ),
  ];
}

/// Shipping for one shop's parcel. [bobGoAmount] is the chosen Bob Go rate
/// (0 / null until one is picked). Returns 0 when no method is chosen or the
/// method is not offered for every product of the shop.
double shopShippingCost({
  required CartShopGroup group,
  required String? methodKey,
  required bool combinedShippingEnabled,
  double? bobGoAmount,
}) {
  if (methodKey == null) return 0;
  if (methodKey == bobGoShippingKey) return bobGoAmount ?? 0;
  try {
    return calculateProductShippingTotal(
      methodKey: methodKey,
      itemQuantities: group.quantities,
      productShippingOptions: group.productShippingOptions,
      combinedShippingEnabled: combinedShippingEnabled,
    );
  } on ArgumentError {
    return 0;
  }
}

/// One shop's share of the checkout total.
class CheckoutShopTotals {
  final String shopId;
  final String shopName;
  final double subtotal;
  final double discountAmount;
  final double shippingCost;
  final double giftFee;

  const CheckoutShopTotals({
    required this.shopId,
    required this.shopName,
    required this.subtotal,
    required this.discountAmount,
    required this.shippingCost,
    required this.giftFee,
  });

  double get total {
    final discounted = (subtotal - discountAmount)
        .clamp(0, double.infinity)
        .toDouble();
    return discounted + shippingCost + giftFee;
  }
}

class CheckoutTotals {
  final List<CheckoutShopTotals> shops;

  const CheckoutTotals(this.shops);

  double _sum(double Function(CheckoutShopTotals shop) pick) =>
      shops.fold<double>(0, (sum, shop) => sum + pick(shop));

  double get subtotal => _sum((shop) => shop.subtotal);
  double get discountAmount => _sum((shop) => shop.discountAmount);
  double get shippingCost => _sum((shop) => shop.shippingCost);

  /// The gift fee is charged per shop: each shop wraps its own parcel.
  double get giftFee => _sum((shop) => shop.giftFee);
  double get total => _sum((shop) => shop.total);
}

/// Totals per shop and for the basket. [discountByShop] holds the saving of
/// an applied code under the shop that owns the code.
CheckoutTotals calculateShopTotals({
  required List<CartShopGroup> groups,
  required Map<String, double> shippingByShop,
  required bool isGift,
  Map<String, double> discountByShop = const {},
}) {
  return CheckoutTotals([
    for (final group in groups)
      CheckoutShopTotals(
        shopId: group.shopId,
        shopName: group.shopName,
        subtotal: group.subtotal,
        discountAmount: discountByShop[group.shopId] ?? 0,
        shippingCost: shippingByShop[group.shopId] ?? 0,
        giftFee: giftFeeForSelection(isGift: isGift),
      ),
  ]);
}

/// The `pickup_point` for one shop's order, in the shape the app has always
/// sent: the chosen locker / Pargo point, the shop's market, or the typed
/// pickup point. Null when the method needs none.
Object? pickupPointForMethod({
  required String? method,
  Map<String, dynamic>? courierGuyLocker,
  Map<String, dynamic>? pargoPoint,
  ShippingOption? marketOption,
  String typedPickupPoint = '',
}) {
  if (method == 'courier_guy' && courierGuyLocker != null) {
    return courierGuyLocker;
  }
  if (method == 'pargo' && pargoPoint != null) return pargoPoint;
  if (method == 'market_pickup' && marketOption != null) {
    return {
      'carrier': 'market_pickup',
      'point_type': 'market',
      'name': marketOption.marketName,
      'address': marketOption.marketLocation,
      'province': marketOption.marketProvince,
    };
  }
  final typed = typedPickupPoint.trim();
  return typed.isEmpty ? null : typed;
}

/// What the payment screen should do with a several-shop checkout status.
enum CheckoutGroupOutcome { waiting, paid, expired, needsHelp }

CheckoutGroupOutcome checkoutGroupOutcome(String status) {
  switch (status) {
    case CheckoutGroupStatus.funded:
      return CheckoutGroupOutcome.paid;
    case CheckoutGroupStatus.cancelled:
      return CheckoutGroupOutcome.expired;
    case CheckoutGroupStatus.needsAttention:
      return CheckoutGroupOutcome.needsHelp;
    default:
      return CheckoutGroupOutcome.waiting;
  }
}

/// Buyer-facing message for a several-shop checkout that cannot continue,
/// or null while it is still waiting for payment or already paid.
String? checkoutGroupProblemMessage(CheckoutGroupOutcome outcome) {
  switch (outcome) {
    case CheckoutGroupOutcome.expired:
      return 'This checkout expired before payment. If you paid, the money is '
          'in your TradeSafe wallet and will be used on your next checkout.';
    case CheckoutGroupOutcome.needsHelp:
      return 'We could not finish paying every shop in your basket. Your money '
          'is safe with TradeSafe. Please contact support so we can sort it '
          'out.';
    case CheckoutGroupOutcome.waiting:
    case CheckoutGroupOutcome.paid:
      return null;
  }
}

/// Small print for a several-shop payment.
const wholeRandPaymentNote =
    'TradeSafe takes whole rands; any change stays in your TradeSafe wallet '
    'for next time.';
