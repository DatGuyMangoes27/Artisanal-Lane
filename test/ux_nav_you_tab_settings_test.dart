// Regression test for the "You tab has no way to reach Settings or Sign
// out in creator mode" bug: buyer_profile_screen.dart previously returned a
// compact creator-mode card with no settings affordance, and its menu had
// no Settings row either.
import 'package:artisanal_lane/core/constants/feature_flags.dart';
import 'package:artisanal_lane/features/auth/providers/auth_providers.dart';
import 'package:artisanal_lane/features/buyer/providers/buyer_providers.dart';
import 'package:artisanal_lane/features/buyer/screens/buyer_profile_screen.dart';
import 'package:artisanal_lane/features/buyer/screens/settings_screen.dart';
import 'package:artisanal_lane/models/cart_item.dart';
import 'package:artisanal_lane/models/order.dart';
import 'package:artisanal_lane/models/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'creator-mode You tab exposes a settings icon and a Settings menu row '
    'that reach /profile/settings',
    (tester) async {
      final now = DateTime(2026, 5, 3, 18);
      final profile = Profile(
        id: 'buyer-1',
        role: 'buyer',
        displayName: 'Alicia',
        email: 'alicia@example.com',
        createdAt: now,
        updatedAt: now,
      );

      final router = GoRouter(
        initialLocation: '/profile',
        routes: [
          GoRoute(
            path: '/profile',
            builder: (context, state) => const BuyerProfileScreen(),
            routes: [
              GoRoute(
                path: 'settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWith((ref) => 'buyer-1'),
            currentProfileProvider.overrideWith((ref) async => profile),
            profileProvider.overrideWith((ref) async => profile),
            ordersProvider.overrideWith((ref) async => const <Order>[]),
            favouriteIdsProvider.overrideWith((ref) async => const <String>[]),
            cartItemsProvider.overrideWith((ref) async => const <CartItem>[]),
            buyerUnreadThreadsCountProvider.overrideWith((ref) => 0),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      // The header settings icon (top-right of the You header).
      expect(find.byTooltip('Settings'), findsOneWidget);
      // The dedicated Settings row in the menu list.
      expect(find.text('Settings'), findsOneWidget);
      // Email is no longer shown on the public header.
      expect(find.text('alicia@example.com'), findsNothing);

      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
    },
    skip: !creatorCommerceEnabled,
  );
}
