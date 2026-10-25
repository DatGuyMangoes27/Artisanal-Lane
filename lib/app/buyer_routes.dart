import '../core/constants/feature_flags.dart';

/// The buyer app's front page (first bottom-nav tab, "Home").
const String frontPageRoute = '/';

/// The Shop tab. Its path stays `/home` so existing links such as
/// `/home/product/:id`, `/home/shop/:id` and `/home/shops` keep working.
const String shopTabRoute = '/home';

/// Where a buyer lands when the app opens or after signing in: the front
/// page in the creator-commerce app, the classic home otherwise.
const String buyerLandingRoute = creatorCommerceEnabled
    ? frontPageRoute
    : shopTabRoute;

/// The router's first location. The creator-commerce app opens on the
/// front page; the classic app opens on the welcome screen (guests may
/// browse from there).
String appInitialLocation({
  bool creatorCommercePreview = creatorCommercePreviewEnabled,
  bool creatorCommerce = creatorCommerceEnabled,
}) {
  if (creatorCommercePreview) return '/internal/creator-commerce';
  return creatorCommerce ? frontPageRoute : '/welcome';
}
