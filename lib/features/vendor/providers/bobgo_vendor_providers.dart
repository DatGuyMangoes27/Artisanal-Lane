import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/shop_fulfillment_profile.dart';
import '../../auth/providers/auth_providers.dart';

/// Whether the server has Bob Go switched on. Vendor UI for Bob Go is hidden
/// while this is false (production until sign-off). Tests override it.
final bobGoServerEnabledProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.read(supabaseServiceProvider).isBobGoEnabled(),
);

/// The shop's private collection details (null until first saved).
final shopFulfillmentProfileProvider = FutureProvider.autoDispose
    .family<ShopFulfillmentProfile?, String>(
      (ref, shopId) =>
          ref.read(supabaseServiceProvider).getShopFulfillmentProfile(shopId),
    );
