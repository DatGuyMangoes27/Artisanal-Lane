import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:artisanal_lane/features/auth/screens/login_screen.dart';
import 'package:artisanal_lane/features/auth/screens/welcome_screen.dart';
import 'package:artisanal_lane/core/pricing/pricing.dart';
import 'package:artisanal_lane/features/buyer/utils/shop_profile_actions.dart';
import 'package:artisanal_lane/features/buyer/utils/curated_collection_destination.dart';
import 'package:artisanal_lane/features/buyer/utils/product_detail_actions.dart';
import 'package:artisanal_lane/features/buyer/utils/curated_collection_carousel.dart';
import 'package:artisanal_lane/features/vendor/utils/vendor_fulfillment_options.dart';
import 'package:artisanal_lane/models/category.dart';
import 'package:artisanal_lane/models/profile.dart';
import 'package:artisanal_lane/models/vendor_payout_profile.dart';
import 'package:artisanal_lane/features/vendor/utils/vendor_onboarding_flow.dart';

void main() {
  testWidgets('Welcome screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: WelcomeScreen())),
    );
    await tester.pump();

    expect(find.text('Artisan Lane'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
  });

  testWidgets('Login screen shows social auth buttons', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );
    await tester.pump();

    expect(find.text('Continue with Google'), findsOneWidget);
  });

  test('Profile parses vendor approval dismissal timestamp', () {
    final profile = Profile.fromJson({
      'id': 'user-1',
      'role': 'vendor',
      'display_name': 'Alicia',
      'email': 'alicia@example.com',
      'avatar_url': null,
      'phone': '0820000000',
      'vendor_approved_seen_at': '2026-04-07T12:00:00.000Z',
      'created_at': '2026-04-01T10:00:00.000Z',
      'updated_at': '2026-04-07T12:00:00.000Z',
    });

    expect(
      profile.vendorApprovedSeenAt,
      DateTime.parse('2026-04-07T12:00:00.000Z'),
    );
  });

  test('VendorPayoutProfile masks account details for UI display', () {
    final payoutProfile = VendorPayoutProfile.fromJson({
      'vendor_id': 'vendor-1',
      'account_holder_name': 'Artisan Lane Test',
      'bank_name': 'Standard Bank',
      'account_number': '10271380908',
      'branch_code': '051001',
      'account_type': 'business',
      'registered_phone': '0820000000',
      'registered_email': 'vendor@example.com',
      'verification_status': 'under_review',
      'created_at': '2026-04-07T12:00:00.000Z',
      'updated_at': '2026-04-07T12:00:00.000Z',
    });

    expect(payoutProfile.verificationStatus, 'under_review');
    expect(payoutProfile.maskedAccountNumber, '*******0908');
  });

  test('Approval celebration only shows until vendor dismisses it', () {
    expect(
      shouldShowVendorApprovalCelebration(
        isApproved: true,
        hasSeenVendorApproval: false,
      ),
      isTrue,
    );
    expect(
      shouldShowVendorApprovalCelebration(
        isApproved: true,
        hasSeenVendorApproval: true,
      ),
      isFalse,
    );
    expect(
      shouldShowVendorApprovalCelebration(
        isApproved: false,
        hasSeenVendorApproval: false,
      ),
      isFalse,
    );
  });

  test('Payout banner copy matches verification status', () {
    expect(
      vendorPayoutBannerMessage('not_started'),
      'Payout details required before payouts can be completed.',
    );
    expect(
      vendorPayoutBannerMessage('under_review'),
      'Your payout details have been submitted and are under review.',
    );
    expect(
      vendorPayoutBannerMessage('verified'),
      'TradeSafe payouts are active.',
    );
    expect(
      vendorPayoutBannerMessage('action_required'),
      'Action required: update your payout details to continue receiving payouts.',
    );
  });

  test('Product share text is built from title and price', () {
    expect(
      buildProductShareText(
        title: 'Hand-Stitched Leather Journal',
        price: 165,
      ),
      'Check out Hand-Stitched Leather Journal on Artisan Lane! R165',
    );
  });

  test('Favourites require sign-in when no current user exists', () {
    expect(requiresSignInForFavourite(null), isTrue);
    expect(requiresSignInForFavourite('user-1'), isFalse);
  });

  test('Basket actions require sign-in when browsing as a guest', () {
    expect(requiresSignInForCart(null), isTrue);
    expect(requiresSignInForCart(''), isTrue);
    expect(requiresSignInForCart('user-1'), isFalse);
  });

  test('Shop profile message action uses buyer chat route and guest gating', () {
    expect(requiresSignInToMessageShop(null), isTrue);
    expect(requiresSignInToMessageShop(''), isTrue);
    expect(requiresSignInToMessageShop('buyer-1'), isFalse);
    expect(buyerShopMessageRoute('thread-42'), '/profile/messages/thread-42');
  });

  test('Gift pricing adds the gift service fee to checkout totals', () {
    expect(giftServiceFee, 7);
    expect(giftFeeForSelection(isGift: false), 0);
    expect(giftFeeForSelection(isGift: true), 7);
    expect(
      calculateCheckoutTotal(
        subtotal: 380,
        shippingCost: 0,
        isGift: true,
      ),
      387,
    );
  });

  test('Vendor onboarding fulfillment options exclude self-delivery', () {
    expect(vendorFulfillmentOptions.contains('Self-delivery'), isFalse);
    expect(
      vendorFulfillmentOptions,
      ['Courier', 'Click & collect', 'Market pickup', 'Locker pickup'],
    );
  });

  test('Curated collection auto-scroll only runs with multiple items', () {
    expect(shouldAutoScrollCuratedCollection(0), isFalse);
    expect(shouldAutoScrollCuratedCollection(1), isFalse);
    expect(shouldAutoScrollCuratedCollection(2), isTrue);
  });

  test('Curated collection resumes after the expected idle delay', () {
    expect(
      curatedCollectionResumeDelay,
      const Duration(seconds: 3),
    );
  });

  test('Curated collection routes to its own listing screen', () {
    expect(curatedCollectionRoute, '/home/curated');
    expect(curatedCollectionTitle, 'Curated Collection');
    expect(
      curatedCollectionSubtitle,
      'Handpicked for their exceptional craft',
    );
  });

  test('Other category uses explicit icon and filter tags', () {
    final category = Category.fromJson({
      'id': 'c0000000-0000-0000-0000-000000000010',
      'name': 'Other',
      'slug': 'other',
      'icon_url': null,
      'sort_order': 10,
      'created_at': '2026-04-07T12:00:00.000Z',
    });

    expect(category.icon, Icons.more_horiz_rounded);
    expect(category.availableFilterTags, ['misc', 'gift', 'seasonal']);
  });
}
