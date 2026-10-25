import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/models.dart';
import 'buyer_providers.dart';

/// How many items each front-page row shows before "See all".
const frontPageRowLimit = 10;

/// How many maker posts the "From the makers" preview shows.
const frontPagePostPreviewCount = 3;

/// A seasonal look for the front page's hero slot (for example a festive
/// campaign). Only the copy and colours change; the hero still features a
/// real product and opens it on tap.
@immutable
class FrontPageSeason {
  const FrontPageSeason({
    required this.eyebrow,
    required this.headline,
    required this.background,
    required this.accent,
  });

  /// Small all-caps line above the headline, e.g. "THE FESTIVE EDIT".
  final String eyebrow;

  /// Playfair headline; may contain a line break.
  final String headline;

  /// Panel colour behind the copy.
  final Color background;

  /// Eyebrow colour.
  final Color accent;
}

/// Hook for seasonal campaigns on the front page hero.
///
/// Null means the everyday "Artisan edit" look. To run a seasonal theme,
/// return a [FrontPageSeason] here (for example based on the date, or a
/// remote flag); nothing else on the front page needs to change.
final frontPageSeasonProvider = Provider<FrontPageSeason?>((ref) => null);

/// The latest published maker posts for the "From the makers" preview.
/// Same query as the Feed tab's first "For you" page, just smaller.
final frontPageLatestPostsProvider = FutureProvider<List<ShopPost>>((
  ref,
) async {
  final data = await ref
      .read(supabaseClientProvider)
      .from('shop_posts')
      .select(ShopPost.select)
      .eq('is_published', true)
      .order('published_at', ascending: false)
      .order('id', ascending: false)
      .limit(8);
  return (data as List)
      .map((row) => ShopPost.fromJson(row as Map<String, dynamic>))
      .toList();
});

/// Makers for the front page's "Artisan spotlight": the shops Artisan Lane
/// has spotlighted, or, when none are, listed shops that have a cover photo.
final frontPageSpotlightShopsProvider = FutureProvider<List<Shop>>((ref) async {
  final spotlight = await ref.watch(spotlightShopsProvider.future);
  if (spotlight.isNotEmpty) return spotlight;
  final shops = await ref.watch(shopsProvider.future);
  return spotlightFallbackShops(shops);
});

/// Listed shops with a cover photo, most recently opened first.
List<Shop> spotlightFallbackShops(List<Shop> shops, {int limit = 8}) {
  final withCovers =
      shops
          .where(
            (shop) =>
                shop.isActive &&
                (shop.coverImageUrl?.trim().isNotEmpty ?? false),
          )
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return withCovers.take(limit).toList();
}

/// Picks the hero product and the "Artisan edit" row from the featured
/// products, falling back to the newest arrival for the hero. The hero's
/// product is left out of the row so the page never shows it twice in a row.
({Product? hero, List<Product> picks}) frontPageEditorial({
  required List<Product> featured,
  required List<Product> newArrivals,
}) {
  final hero = featured.isNotEmpty
      ? featured.first
      : (newArrivals.isNotEmpty ? newArrivals.first : null);
  final picks = featured
      .where((product) => product.id != hero?.id)
      .take(frontPageRowLimit)
      .toList();
  return (hero: hero, picks: picks);
}
