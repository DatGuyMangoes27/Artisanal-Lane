// Regression coverage for the maker profile's ⋯ menu: mute/unmute a maker
// and (behind CREATOR_SAFETY_ENABLED, signed in, never your own shop) report
// them, plus the verified tick / @handle / Instagram-style stats row on the
// shop_profile_screen.dart identity card.
import 'package:artisanal_lane/core/constants/feature_flags.dart';
import 'package:artisanal_lane/features/auth/providers/auth_providers.dart';
import 'package:artisanal_lane/features/buyer/providers/buyer_providers.dart';
import 'package:artisanal_lane/features/buyer/providers/creator_parity_providers.dart';
import 'package:artisanal_lane/features/buyer/screens/shop_profile_screen.dart';
import 'package:artisanal_lane/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Shop _makerShop({
  required String id,
  required String vendorId,
  bool isVerified = false,
}) {
  final now = DateTime(2026, 5, 3, 18);
  return Shop(
    id: id,
    vendorId: vendorId,
    name: 'Thando Made',
    slug: 'thando-made',
    location: 'Johannesburg',
    isVerified: isVerified,
    createdAt: now,
    updatedAt: now,
  );
}

List<dynamic> _baseOverrides(Shop shop, {String? userId}) => [
  currentUserIdProvider.overrideWith((ref) => userId),
  currentProfileProvider.overrideWith((ref) async => null),
  shopDetailProvider.overrideWith((ref, id) async => shop),
  shopProductsProvider.overrideWith((ref, id) async => const <Product>[]),
  shopPostsProvider.overrideWith((ref, id) async => const <ShopPost>[]),
  shopReviewsProvider.overrideWith((ref, id) async => const <ShopReview>[]),
  shopReviewSummaryProvider.overrideWith(
    (ref, id) async => const ReviewSummary(),
  ),
  canReviewShopProvider.overrideWith((ref, id) async => false),
  shopMarketEventsProvider.overrideWith(
    (ref, id) async => const <ShopMarketEvent>[],
  ),
  isFollowingProvider.overrideWith((ref, id) async => false),
  followerCountProvider.overrideWith((ref, id) async => 0),
  mutedShopIdsProvider.overrideWith(
    () => OptimisticIdSet((ref) async => <String>{}, (ref, id, on) async {}),
  ),
];

void main() {
  testWidgets('shows a verified tick and @handle on the maker identity card', (
    tester,
  ) async {
    final shop = _makerShop(
      id: 'shop-1',
      vendorId: 'vendor-1',
      isVerified: true,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: _baseOverrides(shop, userId: null).cast(),
        child: const MaterialApp(home: ShopProfileScreen(shopId: 'shop-1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('@thando-made'), findsOneWidget);
    expect(find.byIcon(Icons.verified), findsOneWidget);
  });

  testWidgets('signed-in visitor can mute a maker from the ⋯ menu', (
    tester,
  ) async {
    final shop = _makerShop(id: 'shop-2', vendorId: 'vendor-2');
    await tester.pumpWidget(
      ProviderScope(
        overrides: _baseOverrides(shop, userId: 'buyer-1').cast(),
        child: const MaterialApp(home: ShopProfileScreen(shopId: 'shop-2')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Mute'), findsOneWidget);
    await tester.tap(find.text('Mute'));
    await tester.pumpAndSettle();

    expect(find.textContaining("won't see posts from"), findsOneWidget);
  });

  testWidgets('the ⋯ menu never offers to report or mute your own shop', (
    tester,
  ) async {
    final shop = _makerShop(id: 'shop-3', vendorId: 'vendor-owner');
    await tester.pumpWidget(
      ProviderScope(
        overrides: _baseOverrides(shop, userId: 'vendor-owner').cast(),
        child: const MaterialApp(home: ShopProfileScreen(shopId: 'shop-3')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Mute'), findsNothing);
    expect(find.text('Report'), findsNothing);
    // Owners see Insights/Edit shop instead of Follow/Message.
    expect(find.text('Insights'), findsOneWidget);
    expect(find.text('Edit shop'), findsOneWidget);
  });

  testWidgets(
    'a signed-in visitor can open "Report this maker" when creator safety '
    'is enabled',
    (tester) async {
      final shop = _makerShop(id: 'shop-4', vendorId: 'vendor-4');
      await tester.pumpWidget(
        ProviderScope(
          overrides: _baseOverrides(shop, userId: 'buyer-2').cast(),
          child: const MaterialApp(home: ShopProfileScreen(shopId: 'shop-4')),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Report'), findsOneWidget);
      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();

      expect(find.text('Report this maker'), findsOneWidget);
    },
    skip: !creatorSafetyEnabled,
  );
}
