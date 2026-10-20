import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/bobgo.dart';
import 'buyer_providers.dart';

/// Server-side Bob Go operations used by checkout. Tests override this so no
/// network is ever touched.
///
/// [shopId] narrows the request to one shop's items when the basket holds
/// items from several shops (each shop sends its own parcel).
abstract class BobGoGateway {
  Future<bool> isAvailable({String? shopId});
  Future<BobGoQuote> requestQuote(
    BobGoDeliveryDetails delivery, {
    String? shopId,
  });
}

class _ServiceBobGoGateway implements BobGoGateway {
  _ServiceBobGoGateway(this._ref);
  final Ref _ref;

  @override
  Future<bool> isAvailable({String? shopId}) =>
      _ref.read(supabaseServiceProvider).isBobGoAvailable(shopId: shopId);

  @override
  Future<BobGoQuote> requestQuote(
    BobGoDeliveryDetails delivery, {
    String? shopId,
  }) => _ref
      .read(supabaseServiceProvider)
      .requestBobGoQuote(delivery, shopId: shopId);
}

final bobGoGatewayProvider = Provider<BobGoGateway>(
  (ref) => _ServiceBobGoGateway(ref),
);

/// Whether Bob Go should be offered for the current basket. False whenever the
/// server flag is off (production), the artisan has not enabled it, or parcel
/// measurements are missing.
final bobGoAvailabilityProvider = FutureProvider.autoDispose<bool>((ref) async {
  // Re-check when the basket changes.
  ref.watch(cartItemsProvider);
  return ref.watch(bobGoGatewayProvider).isAvailable();
});

/// Whether Bob Go can deliver one shop's items in the current basket.
final bobGoShopAvailabilityProvider = FutureProvider.autoDispose
    .family<bool, String>((ref, shopId) async {
      // Re-check when the basket changes.
      ref.watch(cartItemsProvider);
      return ref.watch(bobGoGatewayProvider).isAvailable(shopId: shopId);
    });
