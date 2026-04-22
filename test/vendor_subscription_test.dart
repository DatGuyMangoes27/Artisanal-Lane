import 'dart:async';

import 'package:artisanal_lane/features/buyer/utils/payment_deep_links.dart';
import 'package:artisanal_lane/features/vendor/providers/vendor_providers.dart';
import 'package:artisanal_lane/features/vendor/screens/product_form_screen.dart';
import 'package:artisanal_lane/features/vendor/screens/vendor_products_screen.dart';
import 'package:artisanal_lane/features/vendor/screens/vendor_subscription_screen.dart';
import 'package:artisanal_lane/features/vendor/utils/vendor_subscription_setup.dart';
import 'package:artisanal_lane/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  VendorSubscription activeSubscription({
    DateTime? periodEnd,
    String status = 'active',
  }) {
    final now = DateTime(2026, 4, 15);
    return VendorSubscription(
      vendorId: 'vendor-1',
      planCode: 'artisan-monthly',
      amount: 349,
      currency: 'ZAR',
      status: status,
      currentPeriodStart: now,
      currentPeriodEnd: periodEnd ?? now.add(const Duration(days: 30)),
      startedAt: now,
      lastPaymentAt: now,
      createdAt: now,
      updatedAt: now,
    );
  }

  test('active subscription helper requires active status and future period', () {
    expect(isVendorSubscriptionActive(activeSubscription()), isTrue);
    expect(
      isVendorSubscriptionActive(
        activeSubscription(periodEnd: DateTime(2026, 4, 1)),
      ),
      isFalse,
    );
    expect(
      isVendorSubscriptionActive(activeSubscription(status: 'pending')),
      isFalse,
    );
  });

  test('cancelled subscription stays active until current_period_end', () {
    final stillInPeriod = activeSubscription(
      status: 'cancelled',
      periodEnd: DateTime.now().add(const Duration(days: 5)),
    );
    expect(isVendorSubscriptionActive(stillInPeriod), isTrue);
    expect(isVendorSubscriptionCancelledButAccessible(stillInPeriod), isTrue);

    final expired = activeSubscription(
      status: 'cancelled',
      periodEnd: DateTime.now().subtract(const Duration(days: 1)),
    );
    expect(isVendorSubscriptionActive(expired), isFalse);
    expect(isVendorSubscriptionCancelledButAccessible(expired), isFalse);
  });

  test('payment deep links resolve vendor subscription returns', () {
    expect(
      resolvePaymentDeepLinkRoute(vendorSubscriptionSuccessDeepLink),
      '/vendor/profile/subscription?status=success',
    );
    expect(
      resolvePaymentDeepLinkRoute(vendorSubscriptionFailureWebUrl),
      '/vendor/profile/subscription?status=error',
    );
  });

  testWidgets('subscription screen shows active state copy', (tester) async {
    final subscription = activeSubscription();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vendorSubscriptionProvider.overrideWith((ref) async => subscription),
          vendorSubscriptionStreamProvider.overrideWith(
            (ref) => Stream.value(subscription),
          ),
        ],
        child: const MaterialApp(
          home: VendorSubscriptionScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Subscription active'), findsOneWidget);
    expect(find.textContaining('Current period ends'), findsOneWidget);
  });

  test('inactive subscription copy mentions the free first month', () {
    expect(
      vendorSubscriptionGateMessage,
      contains('free first month'),
    );
  });

  test('inactive subscription CTA uses the shorter free-month label', () {
    expect(
      vendorSubscriptionCtaLabel(
        status: 'inactive',
        isSubscriptionLoading: false,
        isActivating: false,
        isCancelledButAccessible: false,
      ),
      'Start Free Month',
    );
  });

  testWidgets('subscription screen uses the shorter free-month CTA copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vendorSubscriptionProvider.overrideWith((ref) async => null),
          vendorSubscriptionStreamProvider.overrideWith(
            (ref) => Stream.value(null),
          ),
        ],
        child: const MaterialApp(
          home: VendorSubscriptionScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Start Subscription • R349/month'), findsNothing);
    expect(find.textContaining('First month free'), findsWidgets);
  });

  testWidgets(
    'subscription screen shows loading state instead of inactive fallback',
    (tester) async {
      final pendingFuture = Completer<VendorSubscription?>();
      final streamController = StreamController<VendorSubscription?>();
      addTearDown(streamController.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vendorSubscriptionProvider.overrideWith((ref) => pendingFuture.future),
            vendorSubscriptionStreamProvider.overrideWith(
              (ref) => streamController.stream,
            ),
          ],
          child: const MaterialApp(
            home: VendorSubscriptionScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Subscription inactive'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(find.text('Checking your subscription status...'), findsOneWidget);
      expect(find.text('Start Subscription • R349/month'), findsNothing);
    },
  );

  testWidgets('product form blocks new listings without subscription', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vendorSubscriptionProvider.overrideWith((ref) async => null),
          vendorSubscriptionStreamProvider.overrideWith(
            (ref) => Stream.value(null),
          ),
          vendorPayoutProfileProvider.overrideWith((ref) async => null),
          vendorPayoutProfileStreamProvider.overrideWith(
            (ref) => Stream.value(null),
          ),
          vendorCategoriesProvider.overrideWith((ref) async => const <Category>[]),
        ],
        child: const MaterialApp(
          home: ProductFormScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Start your artisan subscription first'), findsOneWidget);
    expect(find.text('Open subscription'), findsOneWidget);
  });

  testWidgets('products screen shows subscription gate before add product', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vendorProductsProvider.overrideWith((ref) async => const <Product>[]),
          vendorSubscriptionProvider.overrideWith((ref) async => null),
          vendorSubscriptionStreamProvider.overrideWith(
            (ref) => Stream.value(null),
          ),
          vendorPayoutProfileProvider.overrideWith((ref) async => null),
          vendorPayoutProfileStreamProvider.overrideWith(
            (ref) => Stream.value(null),
          ),
        ],
        child: const MaterialApp(
          home: VendorProductsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Product').first);
    await tester.pumpAndSettle();

    expect(find.text('Start your artisan subscription'), findsOneWidget);
    expect(find.text('Open subscription'), findsOneWidget);
  });
}
