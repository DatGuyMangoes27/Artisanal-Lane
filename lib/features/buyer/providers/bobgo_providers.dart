import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/bobgo.dart';
import 'buyer_providers.dart';

/// Server-side Bob Go operations used by checkout. Tests override this so no
/// network is ever touched.
abstract class BobGoGateway {
  Future<bool> isAvailable();
  Future<BobGoQuote> requestQuote(BobGoDeliveryDetails delivery);
}

class _ServiceBobGoGateway implements BobGoGateway {
  _ServiceBobGoGateway(this._ref);
  final Ref _ref;

  @override
  Future<bool> isAvailable() =>
      _ref.read(supabaseServiceProvider).isBobGoAvailable();

  @override
  Future<BobGoQuote> requestQuote(BobGoDeliveryDetails delivery) =>
      _ref.read(supabaseServiceProvider).requestBobGoQuote(delivery);
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
