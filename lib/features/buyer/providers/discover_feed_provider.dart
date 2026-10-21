import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/product.dart';
import '../../auth/providers/auth_providers.dart';

/// Products are pulled into Discover in pages of this size.
const discoverPageSize = 100;

/// Fetches one page of buyer-visible products (newest first).
typedef DiscoverPageFetcher =
    Future<List<Product>> Function({required int offset, required int limit});

final discoverPageFetcherProvider = Provider<DiscoverPageFetcher>((ref) {
  final service = ref.watch(supabaseServiceProvider);
  return ({required int offset, required int limit}) =>
      service.getProducts(offset: offset, limit: limit);
});

class DiscoverFeed {
  const DiscoverFeed({
    required this.products,
    required this.hasMore,
    this.isLoadingMore = false,
  });

  final List<Product> products;

  /// Whether the server may have another page beyond [products].
  final bool hasMore;
  final bool isLoadingMore;

  DiscoverFeed copyWith({
    List<Product>? products,
    bool? hasMore,
    bool? isLoadingMore,
  }) => DiscoverFeed(
    products: products ?? this.products,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
  );
}

/// The paged product pool behind the Discover deck. Ranking and filtering
/// by the buyer's preferences happens on the client (see
/// `buildDiscoverDeck`), so this only accumulates pages.
class DiscoverFeedNotifier extends AsyncNotifier<DiscoverFeed> {
  @override
  Future<DiscoverFeed> build() async {
    final fetch = ref.watch(discoverPageFetcherProvider);
    final page = await fetch(offset: 0, limit: discoverPageSize);
    return DiscoverFeed(
      products: page,
      hasMore: page.length >= discoverPageSize,
    );
  }

  /// Appends the next page. A failed page just ends paging for this session;
  /// the deck then carries on with what is already loaded.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    state = AsyncData(current.copyWith(isLoadingMore: true));
    final fetch = ref.read(discoverPageFetcherProvider);
    List<Product> page;
    try {
      page = await fetch(
        offset: current.products.length,
        limit: discoverPageSize,
      );
    } catch (_) {
      page = const [];
    }
    if (!ref.mounted) return;
    final latest = state.value;
    // The feed was reloaded meanwhile; drop this stale page.
    if (latest == null || !identical(latest.products, current.products)) {
      return;
    }
    final known = {for (final p in current.products) p.id};
    final added = page.where((p) => known.add(p.id)).toList();
    state = AsyncData(
      DiscoverFeed(
        products: [...current.products, ...added],
        hasMore: page.length >= discoverPageSize && added.isNotEmpty,
      ),
    );
  }
}

final discoverFeedProvider =
    AsyncNotifierProvider<DiscoverFeedNotifier, DiscoverFeed>(
      DiscoverFeedNotifier.new,
    );
