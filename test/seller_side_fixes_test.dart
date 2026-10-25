// Seller-side fixes:
// 1. An artisan's You tab always shows the Buying / Selling switch and opens
//    on the selling hub, even straight after sign-in (when the shared
//    currentProfileProvider has not caught up), and never offers
//    "Start selling" to someone who already has a shop.
// 2. The seller tools use the honest "Photo enhancer" name.
// 3. Shop Settings keeps the field being typed in visible above the keyboard,
//    also inside the artisan workspace shell (a nested Scaffold).
// 4. Courier Guy door-to-door is no longer offered, but past orders keep
//    their label.
import 'package:artisanal_lane/core/constants/feature_flags.dart';
import 'package:artisanal_lane/features/auth/providers/auth_providers.dart';
import 'package:artisanal_lane/features/buyer/providers/buyer_providers.dart';
import 'package:artisanal_lane/features/buyer/screens/buyer_profile_screen.dart';
import 'package:artisanal_lane/features/vendor/providers/bobgo_vendor_providers.dart';
import 'package:artisanal_lane/features/vendor/providers/selling_mode_provider.dart';
import 'package:artisanal_lane/features/vendor/providers/vendor_providers.dart';
import 'package:artisanal_lane/features/vendor/screens/shop_insights_screen.dart';
import 'package:artisanal_lane/features/vendor/screens/vendor_shop_settings_screen.dart';
import 'package:artisanal_lane/features/vendor/widgets/seller_hub.dart';
import 'package:artisanal_lane/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _now = DateTime(2026, 10, 1);

Profile _profile(String role) => Profile(
  id: 'maker-1',
  role: role,
  displayName: 'Thandi',
  email: 'thandi@example.com',
  createdAt: _now,
  updatedAt: _now,
);

Shop _shop({List<Map<String, dynamic>>? shippingOptions}) => Shop.fromJson({
  'id': 'shop-1',
  'vendor_id': 'maker-1',
  'name': 'Artisan Lane',
  'slug': 'artisan-lane-772355',
  'bio': 'Handmade ceramics from Woodstock.',
  'shipping_options': shippingOptions,
  'created_at': '2026-10-01T00:00:00.000Z',
  'updated_at': '2026-10-01T00:00:00.000Z',
});

Widget _youTab({required Profile loadedProfile, Profile? sharedProfile}) {
  final router = GoRouter(
    initialLocation: '/profile',
    routes: [
      GoRoute(
        path: '/profile',
        builder: (context, state) => const BuyerProfileScreen(),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      currentUserIdProvider.overrideWith((ref) => 'maker-1'),
      // Straight after sign-in the shared profile may still be missing
      // (loading, or a first fetch that failed while the token refreshed).
      currentProfileProvider.overrideWith((ref) async => sharedProfile),
      profileProvider.overrideWith((ref) async => loadedProfile),
      ordersProvider.overrideWith((ref) async => const <Order>[]),
      favouriteIdsProvider.overrideWith((ref) async => const <String>[]),
      cartItemsProvider.overrideWith((ref) async => const <CartItem>[]),
      buyerUnreadThreadsCountProvider.overrideWith((ref) => 0),
      vendorShopProvider.overrideWith((ref) async => _shop()),
      vendorPostsProvider.overrideWith((ref) async => const <ShopPost>[]),
      vendorProductsProvider.overrideWith((ref) async => const <Product>[]),
      shopInsightsProvider.overrideWith((ref, days) async => null),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('You tab for artisans', () {
    testWidgets(
      'opens on the selling hub straight after sign-in, without Start selling',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await tester.pumpWidget(
          _youTab(loadedProfile: _profile('vendor'), sharedProfile: null),
        );
        await tester.pumpAndSettle();

        expect(find.text('Buying'), findsOneWidget);
        expect(find.text('Selling'), findsOneWidget);
        expect(find.byKey(const ValueKey('seller-shop-card')), findsOneWidget);
        expect(find.text('@artisan-lane-772355'), findsOneWidget);
        expect(find.text('Create post'), findsOneWidget);
        expect(find.text('Add story'), findsOneWidget);
        expect(find.text(kPhotoEnhancerTitle), findsOneWidget);
        expect(find.text(kPhotoEnhancerSubtitle), findsOneWidget);
        expect(find.text('AI studio'), findsNothing);
        expect(find.text('Insights'), findsOneWidget);
        expect(find.text('Start selling'), findsNothing);
        // Buyer-only stats are not the default view for an artisan.
        expect(find.text('In Cart'), findsNothing);
      },
      skip: !creatorCommerceEnabled,
    );

    testWidgets(
      'Buying view never offers Start selling and the choice is remembered',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await tester.pumpWidget(
          _youTab(loadedProfile: _profile('vendor'), sharedProfile: null),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Buying'));
        await tester.pumpAndSettle();

        expect(find.text('In Cart'), findsOneWidget);
        expect(find.text('Start selling'), findsNothing);
        await tester.scrollUntilVisible(find.text('Artisan workspace'), 200);
        expect(find.text('Artisan workspace'), findsOneWidget);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool(youTabSellingModeKey), isFalse);
      },
      skip: !creatorCommerceEnabled,
    );

    testWidgets('a remembered Buying choice is restored', (tester) async {
      SharedPreferences.setMockInitialValues({youTabSellingModeKey: false});
      await tester.pumpWidget(
        _youTab(
          loadedProfile: _profile('vendor'),
          sharedProfile: _profile('vendor'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Buying'), findsOneWidget);
      expect(find.text('In Cart'), findsOneWidget);
      expect(find.text('Create post'), findsNothing);
    }, skip: !creatorCommerceEnabled);

    testWidgets(
      'buyers keep the buyer view and are offered Start selling',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await tester.pumpWidget(
          _youTab(
            loadedProfile: _profile('buyer'),
            sharedProfile: _profile('buyer'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Selling'), findsNothing);
        expect(find.text('Create post'), findsNothing);
        await tester.scrollUntilVisible(find.text('Start selling'), 200);
        expect(find.text('Start selling'), findsOneWidget);
      },
      skip: !creatorCommerceEnabled,
    );
  });

  group('Shop Settings with the keyboard open', () {
    // A small phone with a tall keyboard (suggestion strip included).
    const screenHeight = 640.0;
    const keyboardHeight = 340.0;

    Future<void> pumpSettings(
      WidgetTester tester, {
      bool bobGo = false,
      List<Map<String, dynamic>>? shippingOptions,
    }) async {
      tester.view.physicalSize = const Size(390, screenHeight);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWith((ref) => 'maker-1'),
            vendorShopProvider.overrideWith(
              (ref) async => _shop(shippingOptions: shippingOptions),
            ),
            vendorMarketEventsProvider.overrideWith(
              (ref) async => const <ShopMarketEvent>[],
            ),
            bobGoServerEnabledProvider.overrideWith((ref) async => bobGo),
            shopFulfillmentProfileProvider.overrideWith(
              (ref, shopId) async => null,
            ),
          ],
          // Same nesting as the artisan workspace: the screen's Scaffold sits
          // inside the shell's Scaffold, which has its own bottom bar.
          child: const MaterialApp(
            home: Scaffold(
              body: VendorShopSettingsScreen(),
              bottomNavigationBar: SizedBox(height: 70),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder listScrollable() => find
        .descendant(
          of: find.byKey(const ValueKey('shop-settings-list')),
          matching: find.byType(Scrollable),
        )
        .first;

    Future<void> openKeyboardOn(WidgetTester tester, Finder field) async {
      await tester.scrollUntilVisible(field, 120, scrollable: listScrollable());
      // Start with the field at the very bottom of the screen, where the
      // keyboard is about to cover it.
      Scrollable.ensureVisible(tester.element(field), alignment: 1.0);
      await tester.pumpAndSettle();
      // Tap the first line, as a seller starting to type would.
      await tester.tapAt(tester.getTopLeft(field) + const Offset(40, 24));
      await tester.pump();
      tester.view.viewInsets = const FakeViewPadding(bottom: keyboardHeight);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
    }

    void expectFullyVisible(WidgetTester tester, Finder field) {
      final fieldRect = tester.getRect(field);
      final appBarBottom = tester.getRect(find.byType(AppBar)).bottom;
      final doneBarTop = tester
          .getRect(find.byKey(const ValueKey('keyboard-done-bar')))
          .top;
      expect(fieldRect.top, greaterThanOrEqualTo(appBarBottom));
      expect(fieldRect.bottom, lessThanOrEqualTo(doneBarTop));
      expect(doneBarTop, lessThanOrEqualTo(screenHeight - keyboardHeight));
    }

    testWidgets('the bio field stays fully visible above the keyboard', (
      tester,
    ) async {
      await pumpSettings(tester);
      final bio = find.byKey(const ValueKey('shop-bio-field'));
      await openKeyboardOn(tester, bio);

      // The save bar gives way to the slim Done bar while typing.
      expect(find.text('Save Changes'), findsNothing);
      expect(find.byKey(const ValueKey('keyboard-done-bar')), findsOneWidget);
      expectFullyVisible(tester, bio);

      // Done closes the keyboard and brings the save bar back.
      await tester.tap(find.text('Done'));
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(find.text('Save Changes'), findsOneWidget);
    });

    testWidgets('Bob Go postal code (number keyboard) stays visible', (
      tester,
    ) async {
      await pumpSettings(tester, bobGo: true);
      final postal = find.byKey(const ValueKey('bobgo-postal'));
      await openKeyboardOn(tester, postal);

      expectFullyVisible(tester, postal);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('Courier Guy door-to-door is not offered in shop settings', (
      tester,
    ) async {
      await pumpSettings(
        tester,
        shippingOptions: [
          {'key': 'courier_guy', 'enabled': true, 'price': 69},
          {'key': 'courier_guy_door_to_door', 'enabled': true, 'price': 110},
          {'key': 'pargo', 'enabled': true, 'price': 65},
        ],
      );
      await tester.scrollUntilVisible(
        find.text('Pargo'),
        200,
        scrollable: listScrollable(),
      );
      expect(find.text('Pudo Locker (Courier Guy)'), findsOneWidget);
      expect(find.text('Courier Guy Door to Door'), findsNothing);
    });
  });

  group('Courier Guy door-to-door retirement', () {
    test('is not a default and is dropped from stored options', () {
      expect(
        ShippingOption.defaults().map((o) => o.key),
        isNot(contains('courier_guy_door_to_door')),
      );
      expect(ShippingOption.isOffered('courier_guy_door_to_door'), isFalse);
      expect(ShippingOption.isOffered('courier_guy'), isTrue);
      expect(ShippingOption.isOffered('pargo'), isTrue);
      expect(ShippingOption.isOffered('market_pickup'), isTrue);
      expect(ShippingOption.isOffered('bobgo_door_to_door'), isTrue);

      final options = ShippingOption.listFromJson([
        {'key': 'courier_guy_door_to_door', 'enabled': true, 'price': 110},
        {'key': 'market_pickup', 'enabled': true, 'price': 0},
      ], fallback: const []);
      expect(options.map((o) => o.key), ['market_pickup']);
    });

    test('past orders still show their delivery label', () {
      final order = Order.fromJson({
        'id': '12345678-1234-1234-1234-123456789abc',
        'buyer_id': 'buyer-1',
        'shop_id': 'shop-1',
        'status': 'delivered',
        'total': 250,
        'shipping_cost': 110,
        'shipping_method': 'courier_guy_door_to_door',
        'shipping_address': null,
        'payment_state': null,
        'is_gift': false,
        'created_at': '2026-05-14T08:00:00.000Z',
        'updated_at': '2026-05-14T08:00:00.000Z',
        'shops': null,
        'buyer': null,
        'order_items': const [],
      });
      expect(order.shippingMethodDisplay, 'Courier Guy Door to Door');
    });
  });
}
