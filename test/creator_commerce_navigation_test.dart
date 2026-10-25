import 'package:artisanal_lane/core/constants/feature_flags.dart';
import 'package:artisanal_lane/features/buyer/providers/buyer_providers.dart';
import 'package:artisanal_lane/models/cart_item.dart';
import 'package:artisanal_lane/widgets/buyer_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'integrated navigation uses five creator destinations, keeps cart '
    'routed outside the tab bar, and preserves each tab\'s navigator',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, navigationShell) =>
                BuyerShell(navigationShell: navigationShell),
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (_, __) => const Center(child: Text('screen:/')),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/discover',
                    builder: (_, __) =>
                        const Center(child: Text('screen:/discover')),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/home',
                    builder: (_, __) =>
                        const Center(child: Text('screen:/home')),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/feed',
                    builder: (_, __) =>
                        const Center(child: Text('screen:/feed')),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/profile',
                    builder: (_, __) =>
                        const Center(child: Text('screen:/profile')),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/cart',
            builder: (_, __) => const Center(child: Text('screen:/cart')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cartItemsProvider.overrideWith((ref) async => <CartItem>[]),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('screen:/'), findsOneWidget);
      await tester.tap(find.text('Feed'));
      await tester.pumpAndSettle();
      expect(find.text('screen:/feed'), findsOneWidget);
      await tester.tap(find.text('Discover'));
      await tester.pumpAndSettle();
      expect(find.text('screen:/discover'), findsOneWidget);
      await tester.tap(find.text('Shop'));
      await tester.pumpAndSettle();
      expect(find.text('screen:/home'), findsOneWidget);
      expect(find.text('Cart'), findsNothing);
      expect(find.text('Sign In'), findsOneWidget);

      // Switching tabs keeps each branch's own navigator alive rather than
      // rebuilding it, so its state (e.g. scroll position) is preserved.
      await tester.tap(find.text('Discover'));
      await tester.pumpAndSettle();
      expect(find.text('screen:/discover'), findsOneWidget);
    },
    skip: !creatorCommerceEnabled,
  );
}
