import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;

import 'buyer_providers.dart';
import 'front_page_providers.dart';

/// How long the buyer catalogue may stay on screen before coming back to the
/// app reloads it. Phones (iPhones especially) keep the app alive in the
/// background for days, so without this new products never appeared in New
/// arrivals / New drops until the app was fully closed.
const catalogueRefreshAfter = Duration(minutes: 5);

/// Reloads the product lists buyers browse (front page sections and the
/// Shop tab). Discover is left alone: it keeps its own deck and position.
void refreshBuyerCatalogue(
  void Function(ProviderOrFamily provider) invalidate,
) {
  invalidate(freshArrivalsProvider);
  invalidate(categoryProductsProvider);
  invalidate(featuredProductsProvider);
  invalidate(onSaleProductsProvider);
  invalidate(curatedCollectionProductsProvider);
  invalidate(frontPageSpotlightShopsProvider);
  invalidate(frontPageLatestPostsProvider);
}

/// Wraps the buyer shell and reloads the catalogue when the app returns to
/// the foreground after [catalogueRefreshAfter].
class CatalogueAutoRefresh extends ConsumerStatefulWidget {
  const CatalogueAutoRefresh({
    super.key,
    required this.child,
    this.clock = DateTime.now,
  });

  final Widget child;
  final DateTime Function() clock;

  @override
  ConsumerState<CatalogueAutoRefresh> createState() =>
      _CatalogueAutoRefreshState();
}

class _CatalogueAutoRefreshState extends ConsumerState<CatalogueAutoRefresh>
    with WidgetsBindingObserver {
  late DateTime _loadedAt = widget.clock();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final now = widget.clock();
    if (now.difference(_loadedAt) < catalogueRefreshAfter) return;
    _loadedAt = now;
    refreshBuyerCatalogue(ref.invalidate);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
