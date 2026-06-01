import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:artisanal_lane/features/auth/providers/auth_providers.dart';
import 'package:artisanal_lane/features/auth/screens/reset_password_screen.dart';
import 'package:artisanal_lane/features/auth/utils/auth_redirects.dart';
import 'package:artisanal_lane/features/auth/utils/forgot_password_validation.dart';
import 'package:artisanal_lane/features/auth/utils/social_auth_error_messages.dart';
import 'package:artisanal_lane/features/auth/screens/login_screen.dart';
import 'package:artisanal_lane/features/auth/screens/welcome_screen.dart';
import 'package:artisanal_lane/features/chat/utils/live_chat_messages.dart';
import 'package:artisanal_lane/features/buyer/providers/buyer_providers.dart';
import 'package:artisanal_lane/features/buyer/screens/buyer_home_screen.dart';
import 'package:artisanal_lane/features/buyer/screens/buyer_profile_screen.dart';
import 'package:artisanal_lane/features/buyer/screens/order_detail_screen.dart';
import 'package:artisanal_lane/features/buyer/screens/settings_screen.dart';
import 'package:artisanal_lane/core/pricing/pricing.dart';
import 'package:artisanal_lane/features/buyer/utils/shop_profile_actions.dart';
import 'package:artisanal_lane/features/buyer/utils/curated_collection_destination.dart';
import 'package:artisanal_lane/features/buyer/utils/cart_stock_guard.dart';
import 'package:artisanal_lane/features/buyer/utils/product_detail_actions.dart';
import 'package:artisanal_lane/features/buyer/utils/product_image_zoom.dart';
import 'package:artisanal_lane/features/buyer/utils/product_sorting.dart';
import 'package:artisanal_lane/features/buyer/utils/product_visibility.dart';
import 'package:artisanal_lane/features/buyer/utils/receipt_reminders.dart';
import 'package:artisanal_lane/features/buyer/utils/favourite_products.dart';
import 'package:artisanal_lane/features/buyer/utils/buyer_home_copy.dart';
import 'package:artisanal_lane/features/buyer/utils/checkout_validation.dart';
import 'package:artisanal_lane/features/buyer/utils/checkout_shipping_layout.dart';
import 'package:artisanal_lane/features/buyer/utils/curated_collection_carousel.dart';
import 'package:artisanal_lane/features/vendor/widgets/stationery_sheet_header.dart';
import 'package:artisanal_lane/features/buyer/utils/search_results_layout.dart';
import 'package:artisanal_lane/features/buyer/utils/search_trends.dart';
import 'package:artisanal_lane/features/buyer/utils/payment_deep_links.dart';
import 'package:artisanal_lane/features/buyer/utils/tracking_links.dart';
import 'package:artisanal_lane/features/buyer/utils/order_history_filters.dart';
import 'package:artisanal_lane/features/buyer/utils/product_shipping_checkout.dart';
import 'package:artisanal_lane/features/buyer/utils/help_support_contact.dart';
import 'package:artisanal_lane/features/buyer/utils/profile_avatar_upload.dart';
import 'package:artisanal_lane/features/disputes/utils/dispute_attachment_support.dart';
import 'package:artisanal_lane/features/vendor/utils/vendor_payout_copy.dart';
import 'package:artisanal_lane/features/vendor/utils/vendor_fulfillment_options.dart';
import 'package:artisanal_lane/features/vendor/providers/vendor_providers.dart';
import 'package:artisanal_lane/features/vendor/screens/vendor_dashboard_screen.dart';
import 'package:artisanal_lane/features/vendor/screens/vendor_application_screen.dart';
import 'package:artisanal_lane/features/vendor/screens/vendor_order_detail_screen.dart';
import 'package:artisanal_lane/features/vendor/screens/vendor_settings_screen.dart';
import 'package:artisanal_lane/features/vendor/utils/product_form_copy.dart';
import 'package:artisanal_lane/features/vendor/utils/vendor_payout_setup.dart';
import 'package:artisanal_lane/features/vendor/utils/vendor_earnings.dart';
import 'package:artisanal_lane/models/cart_item.dart';
import 'package:artisanal_lane/models/category.dart';
import 'package:artisanal_lane/models/chat_message.dart';
import 'package:artisanal_lane/models/order.dart';
import 'package:artisanal_lane/models/product.dart';
import 'package:artisanal_lane/models/profile.dart';
import 'package:artisanal_lane/models/shop.dart';
import 'package:artisanal_lane/models/shipping_option.dart';
import 'package:artisanal_lane/models/vendor_subscription.dart';
import 'package:artisanal_lane/models/vendor_payout_profile.dart';
import 'package:artisanal_lane/features/vendor/utils/vendor_onboarding_flow.dart';
import 'package:artisanal_lane/widgets/african_patterns.dart';
import 'package:artisanal_lane/widgets/buyer_shell.dart';
import 'package:artisanal_lane/widgets/cart_nav_icon.dart';
import 'package:artisanal_lane/widgets/gradient_button.dart';
import 'package:artisanal_lane/widgets/unread_messages_fab.dart';
import 'package:artisanal_lane/widgets/vendor_shell.dart';

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

  testWidgets('Welcome screen exposes terms of service as a link', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: WelcomeScreen())),
    );
    await tester.pump();

    expect(find.widgetWithText(TextButton, 'Terms of Service'), findsOneWidget);
  });

  testWidgets('Footer brand mark displays the full logo', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: TripleDot())),
    );

    expect(find.byType(Image), findsOneWidget);
    expect(find.bySemanticsLabel('Artisan Lane logo'), findsOneWidget);
  });

  test('Profile avatar uploads are scoped to the current user', () {
    expect(
      profileAvatarStoragePath(
        userId: 'user-1',
        originalPath: 'photo.PNG',
        timestampMillis: 123,
      ),
      'user-1/avatar-123.png',
    );
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

  test('Auth redirect helper routes password recovery into reset password', () {
    expect(
      routeForAuthEvent(AuthChangeEvent.passwordRecovery),
      '/reset-password',
    );
    expect(isPasswordRecoveryRoute('/reset-password'), isTrue);
    expect(
      routeForIncomingAuthRedirect(
        Uri.parse('artisanlane://login-callback?type=recovery'),
      ),
      '/reset-password',
    );
    expect(
      routeForIncomingAuthRedirect(
        Uri.parse('artisanlane://login-callback#type=recovery'),
      ),
      '/reset-password',
    );
    expect(
      routeForIncomingAuthRedirect(
        Uri.parse('artisanlane://login-callback?type=signup'),
      ),
      isNull,
    );
    expect(
      routeForAuthEvent(AuthChangeEvent.signedIn, role: 'vendor'),
      '/vendor',
    );
    expect(
      routeForAuthEvent(AuthChangeEvent.signedIn, requestedRole: 'vendor'),
      '/vendor/onboarding',
    );
    expect(routeForAuthEvent(AuthChangeEvent.signedIn), '/home');
    expect(routeForAuthEvent(AuthChangeEvent.signedOut), '/welcome');
  });

  test(
    'Forgot password validation normalizes email and detects missing profiles',
    () {
      expect(
        normalizeForgotPasswordEmail('  HANNAH@example.COM  '),
        'hannah@example.com',
      );
      expect(isRegisteredEmailLookupResult({'id': 'profile-1'}), isTrue);
      expect(isRegisteredEmailLookupResult(null), isFalse);
      expect(
        forgotPasswordEmailNotFoundMessage,
        'No Artisan Lane account exists for this email address.',
      );
    },
  );

  test('Social auth errors are translated into friendly copy', () {
    expect(
      friendlySocialAuthError(
        'GoogleSignInException(code GoogleSignInExceptionCode.canceled, [16] Account reauth failed., null)',
      ),
      'Google sign-in could not continue. Please try again or create an account.',
    );
    expect(
      friendlySocialAuthError(Exception('Network unavailable')),
      'Unable to start Google sign-in. Please check your connection and try again.',
    );
  });

  testWidgets('Reset password screen shows the new password form', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ResetPasswordScreen()));
    await tester.pump();

    expect(find.text('Create\nNew Password'), findsOneWidget);
    expect(find.text('New Password'), findsOneWidget);
    expect(find.text('Confirm Password'), findsOneWidget);
    expect(find.text('Update Password'), findsOneWidget);
  });

  testWidgets('Stationery sheet header exposes a back button', (
    WidgetTester tester,
  ) async {
    var wasClosed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StationerySheetHeader(
            title: 'Order Stationery',
            subtitle: 'Artisan Lane branded materials',
            onBackTap: () => wasClosed = true,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pump();

    expect(wasClosed, isTrue);
  });

  testWidgets('Buyer settings screen exposes delete account action', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Delete Account'), findsOneWidget);
    expect(find.text('Currency'), findsNothing);
  });

  testWidgets('Vendor settings screen exposes delete account action', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [vendorShopProvider.overrideWith((ref) async => null)],
        child: const MaterialApp(home: VendorSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Delete Account'), findsOneWidget);
  });

  test('Search results chip rail leaves vertical room for rounded filters', () {
    expect(searchResultsChipRailHeight, greaterThan(44));
    expect(searchResultsChipRailVerticalPadding, greaterThan(0));
    expect(searchResultsChipMinHeight, greaterThanOrEqualTo(48));
    expect(searchResultsChipVerticalInset, greaterThanOrEqualTo(13));
    expect(searchResultsChipTextHeight, greaterThan(1));
  });

  test('Help support contact details use the latest support channels', () {
    expect(helpSupportEmail, 'nicky@artisanlanesa.com');
    expect(
      helpSupportEmailLaunchUri.toString(),
      'mailto:nicky@artisanlanesa.com',
    );
    expect(helpSupportWhatsappDisplay, '+27730687908');
    expect(
      helpSupportWhatsappLaunchUri.toString(),
      'https://wa.me/27730687908',
    );
  });

  test('Vendor application contact chat includes review context', () {
    final uri = vendorApplicationReviewWhatsappUri(
      businessName: 'Luminousence Creative Group',
    );

    expect(uri.host, 'wa.me');
    expect(
      Uri.decodeComponent(uri.queryParameters['text']!),
      contains('Luminousence Creative Group'),
    );
    expect(
      Uri.decodeComponent(uri.queryParameters['text']!),
      contains('vendor application'),
    );
  });

  test('Buyer home category hero relies on the card tap only', () {
    expect(buyerHomeCategoryHeroShowsInlineButton, isFalse);
  });

  test('TradeSafe payment deep links map back into the app', () {
    expect(paymentSuccessDeepLink.toString(), 'artisanlane://payment/success');
    expect(paymentFailureDeepLink.toString(), 'artisanlane://payment/error');
    expect(
      resolvePaymentDeepLinkRoute(Uri.parse('artisanlane://payment/success')),
      '/cart/confirmation',
    );
    expect(
      resolvePaymentDeepLinkRoute(Uri.parse('artisanlane://payment/error')),
      '/cart',
    );
    expect(
      resolvePaymentDeepLinkRoute(Uri.parse('artisanlane://login-callback')),
      isNull,
    );
    expect(
      resolvePaymentDeepLinkRoute(
        Uri.parse('https://artisanlanesa.co.za/payment/success'),
      ),
      '/cart/confirmation',
    );
    expect(
      resolvePaymentDeepLinkRoute(
        Uri.parse('https://artisanlanesa.co.za/payment/error'),
      ),
      '/cart',
    );
    expect(
      resolvePaymentDeepLinkRoute(
        Uri.parse('https://artisanlanesa.co.za/products/product-123'),
      ),
      '/home/product/product-123',
    );
    expect(
      resolvePaymentDeepLinkRoute(
        Uri.parse('https://artisanlanesa.co.za/shops/shop-123'),
      ),
      '/home/shop/shop-123',
    );
  });

  test('shipping methods map to the expected inline checkout details', () {
    expect(
      inlineDetailsForShippingMethod('courier_guy'),
      CheckoutShippingInlineDetails.courierGuyLockerSearch,
    );
    expect(
      inlineDetailsForShippingMethod('courier_guy_door_to_door'),
      CheckoutShippingInlineDetails.none,
    );
    expect(
      inlineDetailsForShippingMethod('pargo'),
      CheckoutShippingInlineDetails.pargoPickupPointSearch,
    );
    expect(
      inlineDetailsForShippingMethod('market_pickup'),
      CheckoutShippingInlineDetails.marketPickupNote,
    );
    expect(
      inlineDetailsForShippingMethod(null),
      CheckoutShippingInlineDetails.none,
    );
  });

  test('Dispute evidence supports image and video attachments', () {
    expect(
      disputeAttachmentAllowedExtensions,
      containsAll(['jpg', 'png', 'mp4', 'mov', 'webm']),
    );
    expect(disputeAttachmentMaxBytes, greaterThan(10 * 1024 * 1024));
    expect(disputeAttachmentMimeTypeForExtension('mp4'), 'video/mp4');
    expect(disputeAttachmentMimeTypeForExtension('mov'), 'video/quicktime');
    expect(disputeAttachmentMimeTypeForExtension('webm'), 'video/webm');
  });

  test(
    'Displayed chat messages include local sends until stream catches up',
    () {
      final serverMessage = ChatMessage.fromJson({
        'id': 'server-1',
        'thread_id': 'thread-1',
        'sender_id': 'buyer-1',
        'body': 'Earlier message',
        'message_type': 'text',
        'created_at': '2026-04-16T10:00:00.000Z',
      });
      final localMessage = ChatMessage.fromJson({
        'id': 'local-1',
        'thread_id': 'thread-1',
        'sender_id': 'buyer-1',
        'body': 'Just sent',
        'message_type': 'text',
        'created_at': '2026-04-16T10:00:05.000Z',
      });

      final mergedBeforeStream = buildDisplayedChatMessages(
        streamedMessages: [serverMessage],
        localMessages: [localMessage],
      );
      expect(mergedBeforeStream.map((message) => message.id).toList(), [
        'server-1',
        'local-1',
      ]);

      final mergedAfterStream = buildDisplayedChatMessages(
        streamedMessages: [serverMessage, localMessage],
        localMessages: [localMessage],
      );
      expect(mergedAfterStream.map((message) => message.id).toList(), [
        'server-1',
        'local-1',
      ]);
    },
  );

  testWidgets(
    'unread messages FAB only shows when unread threads exist and routes to the target inbox',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            floatingActionButton: UnreadMessagesFab(
              count: 0,
              route: '/profile/messages',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.forum_rounded), findsNothing);

      final router = GoRouter(
        initialLocation: '/profile',
        routes: [
          GoRoute(
            path: '/profile',
            builder: (context, state) => Scaffold(
              body: const Text('Profile Page'),
              floatingActionButton: const UnreadMessagesFab(
                count: 2,
                route: '/profile/messages',
              ),
            ),
          ),
          GoRoute(
            path: '/profile/messages',
            builder: (context, state) =>
                const Scaffold(body: Text('Messages Page')),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.forum_rounded), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.forum_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Messages Page'), findsOneWidget);
    },
  );

  testWidgets('unread messages FAB shows the unread counter badge', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          floatingActionButton: UnreadMessagesFab(
            count: 3,
            route: '/vendor/messages',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.forum_rounded), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('buyer shell does not show the unread messages FAB', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(
          path: '/profile',
          builder: (context, state) =>
              const BuyerShell(child: Scaffold(body: Text('Profile Page'))),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cartItemsProvider.overrideWith((ref) async => const <CartItem>[]),
          buyerUnreadThreadsCountProvider.overrideWith((ref) => 2),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.forum_rounded), findsNothing);
  });

  testWidgets('vendor shell does not show the unread messages FAB', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/vendor/profile',
      routes: [
        GoRoute(
          path: '/vendor/profile',
          builder: (context, state) =>
              const VendorShell(child: Scaffold(body: Text('Vendor Profile'))),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [vendorUnreadThreadsCountProvider.overrideWith((ref) => 3)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.forum_rounded), findsNothing);
  });

  testWidgets('buyer home screen shows unread messages FAB', (tester) async {
    final now = DateTime(2026, 5, 3, 18);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => 'buyer-1'),
          currentProfileProvider.overrideWith(
            (ref) async => Profile(
              id: 'buyer-1',
              role: 'buyer',
              displayName: 'Buyer',
              email: 'buyer@example.com',
              createdAt: now,
              updatedAt: now,
            ),
          ),
          categoriesProvider.overrideWith((ref) async => const <Category>[]),
          featuredProductsProvider.overrideWith(
            (ref) async => const <Product>[],
          ),
          onSaleProductsProvider.overrideWith((ref) async => const <Product>[]),
          spotlightShopsProvider.overrideWith((ref) async => const <Shop>[]),
          followingFeedProvider.overrideWith((ref) async => const []),
          buyerUnreadThreadsCountProvider.overrideWith((ref) => 2),
        ],
        child: const MaterialApp(home: BuyerHomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.forum_rounded), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('buyer home artist spotlight shows multiple shops as carousel', (
    tester,
  ) async {
    final now = DateTime(2026, 5, 18, 15);
    final older = now.subtract(const Duration(days: 1));
    final spotlightShops = [
      Shop(
        id: 'shop-new',
        vendorId: 'vendor-new',
        name: 'New Spotlight Studio',
        slug: 'new-spotlight-studio',
        location: 'Cape Town',
        isSpotlight: true,
        spotlightedAt: now,
        createdAt: now,
        updatedAt: now,
      ),
      Shop(
        id: 'shop-older',
        vendorId: 'vendor-older',
        name: 'Older Spotlight Studio',
        slug: 'older-spotlight-studio',
        location: 'Durban',
        isSpotlight: true,
        spotlightedAt: older,
        createdAt: older,
        updatedAt: older,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => null),
          currentProfileProvider.overrideWith((ref) async => null),
          categoriesProvider.overrideWith((ref) async => const <Category>[]),
          featuredProductsProvider.overrideWith(
            (ref) async => const <Product>[],
          ),
          onSaleProductsProvider.overrideWith((ref) async => const <Product>[]),
          freshArrivalsProvider.overrideWith((ref) async => const <Product>[]),
          spotlightShopsProvider.overrideWith((ref) async => spotlightShops),
          followingFeedProvider.overrideWith((ref) async => const []),
          buyerUnreadThreadsCountProvider.overrideWith((ref) => 0),
        ],
        child: const MaterialApp(home: BuyerHomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(find.text('Artist Spotlight'), findsOneWidget);
    expect(find.text('New Spotlight Studio'), findsOneWidget);
    expect(find.text('Older Spotlight Studio'), findsOneWidget);
  });

  testWidgets('buyer home fresh arrivals shows latest non-sale products', (
    tester,
  ) async {
    final now = DateTime(2026, 5, 7, 18);
    final freshProduct = Product.fromJson({
      'id': 'fresh-product-1',
      'shop_id': 'shop-1',
      'category_id': null,
      'subcategory_id': null,
      'title': 'Fresh Leather Jacket',
      'description': 'Newly listed',
      'price': 1550,
      'compare_at_price': null,
      'stock_qty': 1,
      'images': const [],
      'option_groups': const [],
      'product_variants': const [],
      'tags': const [],
      'is_published': true,
      'is_featured': false,
      'shipping_options': const [],
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => null),
          currentProfileProvider.overrideWith((ref) async => null),
          categoriesProvider.overrideWith((ref) async => const <Category>[]),
          featuredProductsProvider.overrideWith(
            (ref) async => const <Product>[],
          ),
          onSaleProductsProvider.overrideWith((ref) async => const <Product>[]),
          freshArrivalsProvider.overrideWith((ref) async => [freshProduct]),
          spotlightShopsProvider.overrideWith((ref) async => const <Shop>[]),
          followingFeedProvider.overrideWith((ref) async => const []),
          buyerUnreadThreadsCountProvider.overrideWith((ref) => 0),
        ],
        child: const MaterialApp(home: BuyerHomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Fresh Arrivals'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
    await tester.pumpAndSettle();

    expect(find.text('Fresh Leather Jacket'), findsOneWidget);
  });

  testWidgets('vendor dashboard screen shows unread messages FAB', (
    tester,
  ) async {
    final now = DateTime(2026, 5, 3, 18);
    final shop = Shop(
      id: 'shop-1',
      vendorId: 'vendor-1',
      name: 'Test Shop',
      slug: 'test-shop',
      createdAt: now,
      updatedAt: now,
    );
    final payoutProfile = VendorPayoutProfile(
      vendorId: 'vendor-1',
      accountHolderName: 'Vendor Example',
      bankName: 'FNB',
      accountNumber: '1234567890',
      branchCode: '250655',
      accountType: 'cheque',
      registeredPhone: '0820000000',
      registeredEmail: 'vendor@example.com',
      verificationStatus: 'submitted',
      createdAt: now,
      updatedAt: now,
    );
    final subscription = {
      'vendor_id': 'vendor-1',
      'plan_code': 'artisan-monthly',
      'amount': 349,
      'currency': 'ZAR',
      'status': 'active',
      'current_period_start': now.toIso8601String(),
      'current_period_end': now.add(const Duration(days: 30)).toIso8601String(),
      'started_at': now.toIso8601String(),
      'last_payment_at': now.toIso8601String(),
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentProfileProvider.overrideWith(
            (ref) async => Profile(
              id: 'vendor-1',
              role: 'vendor',
              displayName: 'Vendor',
              email: 'vendor@example.com',
              createdAt: now,
              updatedAt: now,
            ),
          ),
          vendorShopProvider.overrideWith((ref) async => shop),
          vendorOrdersProvider.overrideWith((ref) async => const <Order>[]),
          vendorProductsProvider.overrideWith((ref) async => const <Product>[]),
          vendorEarningsProvider.overrideWith(
            (ref) async => {
              'totalSales': 0.0,
              'held': 0.0,
              'released': 0.0,
              'fees': 0.0,
            },
          ),
          vendorPayoutProfileProvider.overrideWith(
            (ref) async => payoutProfile,
          ),
          vendorPayoutProfileStreamProvider.overrideWith(
            (ref) => Stream.value(payoutProfile),
          ),
          vendorSubscriptionProvider.overrideWith(
            (ref) async => VendorSubscription.fromJson(subscription),
          ),
          vendorSubscriptionStreamProvider.overrideWith(
            (ref) => Stream.value(VendorSubscription.fromJson(subscription)),
          ),
          vendorUnreadThreadsCountProvider.overrideWith((ref) => 3),
        ],
        child: const MaterialApp(home: VendorDashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.forum_rounded), findsOneWidget);
    expect(find.text('3'), findsWidgets);
  });

  testWidgets('Vendor order detail wraps long tracking URLs', (tester) async {
    final now = DateTime(2026, 5, 20);
    const orderId = 'a3c9019d-1111-4222-8333-444444444444';
    final order = Order(
      id: orderId,
      buyerId: 'buyer-1',
      shopId: 'shop-1',
      status: 'paid',
      total: 50,
      shippingMethod: 'market_pickup',
      trackingNumber: '57475 57547 577474',
      trackingUrl:
          'https://www.lipsum.com/feed/html?very-long-query-string-that-should-wrap-inside-the-card=abcdefghijklmnopqrstuvwxyz',
      shippingAddress: const {'name': 'Hannah Dalwai'},
      buyerDisplayName: 'Hannah Dalwai',
      buyerEmail: 'tester@seven.com',
      buyerPhone: '0742270686',
      createdAt: now,
      updatedAt: now,
      items: [
        OrderItem(
          id: 'item-1',
          orderId: orderId,
          productId: 'product-1',
          productTitle: 'Aurora Collection: Press On Nails',
          quantity: 1,
          unitPrice: 50,
          createdAt: now,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vendorOrderDetailStreamProvider(
            orderId,
          ).overrideWith((ref) => Stream.value(order)),
        ],
        child: const MaterialApp(
          home: VendorOrderDetailScreen(orderId: orderId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tracking URL'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Vendor application terms error scrolls back to the top banner', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [currentUserIdProvider.overrideWith((ref) => null)],
        child: const MaterialApp(home: VendorApplicationScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final applicationScrollView = find.byType(Scrollable).first;
    Finder fieldWithHint(String hint) =>
        find.widgetWithText(TextFormField, hint);

    await tester.scrollUntilVisible(
      find.text('Business Name'),
      160,
      scrollable: applicationScrollView,
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      fieldWithHint('Your craft business name'),
      'Ninousence Creative Group',
    );
    await tester.scrollUntilVisible(
      find.text('How will you fulfil orders?'),
      160,
      scrollable: applicationScrollView,
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      fieldWithHint(
        'e.g. I use Courier Guy for deliveries, or offer locker collection options',
      ),
      'I use courier delivery.',
    );
    await tester.scrollUntilVisible(
      find.text('What is your typical turnaround time?'),
      160,
      scrollable: applicationScrollView,
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      fieldWithHint(
        'e.g. 3–5 business days for ready stock, 10–14 days for custom orders',
      ),
      '3 to 5 business days.',
    );

    await tester.scrollUntilVisible(
      find.text('Submit Application'),
      160,
      scrollable: applicationScrollView,
    );
    await tester.pumpAndSettle();
    expect(find.text('Application Review'), findsNothing);

    final submitButton = find.byKey(const Key('vendorApplicationSubmitButton'));
    await tester.ensureVisible(submitButton);
    await tester.pumpAndSettle();
    final button = tester.widget<GradientButton>(submitButton);
    expect(button.onPressed, isNotNull);
    button.onPressed!();
    await tester.pumpAndSettle();

    expect(
      find.text('Please accept the Terms & Conditions to continue.'),
      findsOneWidget,
    );
    expect(find.text('Application Review'), findsOneWidget);
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

  test('Business registration label is marked optional for payout setup', () {
    expect(
      businessRegistrationNumberLabel,
      'Business registration number (optional)',
    );
  });

  test('Vendor earnings exclude cancelled and pending orders', () {
    expect(countsTowardVendorEarnings('paid'), isTrue);
    expect(countsTowardVendorEarnings('shipped'), isTrue);
    expect(countsTowardVendorEarnings('completed'), isTrue);
    expect(countsTowardVendorEarnings('cancelled'), isFalse);
    expect(countsTowardVendorEarnings('pending'), isFalse);
    expect(escrowCountsTowardVendorEarnings('held'), isTrue);
    expect(escrowCountsTowardVendorEarnings('released'), isTrue);
    expect(escrowCountsTowardVendorEarnings('cancelled'), isFalse);
    expect(escrowCountsTowardVendorEarnings('refunded'), isFalse);
  });

  test('Supported TradeSafe banks match the mapped backend list', () {
    expect(supportedTradeSafeBanks, const [
      'ABSA',
      'African Bank',
      'Capitec',
      'Discovery Bank',
      'FNB',
      'Investec',
      'MTN',
      'Nedbank',
      'Postbank',
      'Sasfin',
      'Standard Bank',
      'TymeBank',
      'Other',
    ]);
  });

  test('Supported TradeSafe account types match the mapped backend list', () {
    expect(
      supportedTradeSafeAccountTypes.map((option) => option.label).toList(),
      const ['Cheque', 'Savings', 'Transmission', 'Bond'],
    );
  });

  test('Vendor payout completion requires the needed payout fields', () {
    expect(isVendorPayoutSetupComplete(null), isFalse);

    final incompleteProfile = VendorPayoutProfile.fromJson({
      'vendor_id': 'vendor-1',
      'account_holder_name': 'Artisan Lane Test',
      'bank_name': 'Standard Bank',
      'account_number': '',
      'branch_code': '051001',
      'account_type': 'cheque',
      'registered_phone': '0820000000',
      'registered_email': 'vendor@example.com',
      'verification_status': 'verified',
      'created_at': '2026-04-07T12:00:00.000Z',
      'updated_at': '2026-04-07T12:00:00.000Z',
    });

    final completeProfile = VendorPayoutProfile.fromJson({
      'vendor_id': 'vendor-1',
      'account_holder_name': 'Artisan Lane Test',
      'bank_name': 'Standard Bank',
      'account_number': '10271380908',
      'branch_code': '051001',
      'account_type': 'cheque',
      'registered_phone': '0820000000',
      'registered_email': 'vendor@example.com',
      'verification_status': 'verified',
      'created_at': '2026-04-07T12:00:00.000Z',
      'updated_at': '2026-04-07T12:00:00.000Z',
    });

    expect(isVendorPayoutSetupComplete(incompleteProfile), isFalse);
    expect(isVendorPayoutSetupComplete(completeProfile), isFalse);

    final completeProfileWithId = VendorPayoutProfile.fromJson({
      'vendor_id': 'vendor-1',
      'account_holder_name': 'Artisan Lane Test',
      'bank_name': 'Standard Bank',
      'account_number': '10271380908',
      'branch_code': '051001',
      'account_type': 'cheque',
      'registered_phone': '0820000000',
      'registered_email': 'vendor@example.com',
      'identity_number': '8001015009087',
      'verification_status': 'verified',
      'created_at': '2026-04-07T12:00:00.000Z',
      'updated_at': '2026-04-07T12:00:00.000Z',
    });

    expect(isVendorPayoutSetupComplete(completeProfileWithId), isTrue);
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
      'Complete your payout details before adding products and receiving payouts.',
    );
    expect(
      vendorPayoutBannerMessage('under_review'),
      'Your payout details are saved and ready to use.',
    );
    expect(
      vendorPayoutBannerMessage('verified'),
      'TradeSafe payouts are active.',
    );
    expect(
      vendorPayoutBannerMessage('action_required'),
      'Update your payout details to continue adding products and receiving payouts.',
    );
  });

  test('Product share text is built from title and price', () {
    expect(
      buildProductShareText(
        productId: 'product-123',
        title: 'Hand-Stitched Leather Journal',
        price: 165,
      ),
      'Check out Hand-Stitched Leather Journal on Artisan Lane! R165\n'
      'https://artisanlanesa.co.za/products/product-123',
    );
  });

  test('Product image zoom uses visible gallery images with fallback', () {
    expect(
      productZoomImages(
        displayImages: const ['https://example.com/front.jpg'],
        fallbackImage: 'https://example.com/fallback.jpg',
      ),
      const ['https://example.com/front.jpg'],
    );
    expect(
      productZoomImages(
        displayImages: const [],
        fallbackImage: 'https://example.com/fallback.jpg',
      ),
      const ['https://example.com/fallback.jpg'],
    );
  });

  test('Shop share text includes the public shop link', () {
    expect(
      buildShopShareText(shopId: 'shop-123', shopName: 'Lianne Studio'),
      'Check out Lianne Studio on Artisan Lane!\n'
      'https://artisanlanesa.co.za/shops/shop-123',
    );
  });

  test('Favourites require sign-in when no current user exists', () {
    expect(requiresSignInForFavourite(null), isTrue);
    expect(requiresSignInForFavourite('user-1'), isFalse);
  });

  test('Favourite product rows skip missing and unavailable product joins', () {
    final products = favouriteProductsFromRows([
      {'product_id': 'archived-product', 'products': null},
      {
        'product_id': 'sold-out-product',
        'products': {
          'id': 'sold-out-product',
          'shop_id': 'shop-1',
          'title': 'Sold Out Product',
          'price': 120,
          'stock_qty': 0,
          'created_at': '2026-04-15T12:00:00.000Z',
          'updated_at': '2026-04-15T12:00:00.000Z',
        },
      },
      {
        'product_id': 'visible-product',
        'products': {
          'id': 'visible-product',
          'shop_id': 'shop-1',
          'title': 'Visible Product',
          'price': 120,
          'stock_qty': 2,
          'created_at': '2026-04-15T12:00:00.000Z',
          'updated_at': '2026-04-15T12:00:00.000Z',
        },
      },
    ]);

    expect(products.map((product) => product.id), ['visible-product']);
  });

  test('Buyer-visible products must be published and in stock', () {
    Product item({bool isPublished = true, int stockQty = 1}) => Product(
      id: 'product',
      shopId: 'shop-1',
      title: 'Product',
      price: 120,
      stockQty: stockQty,
      isPublished: isPublished,
      createdAt: DateTime(2026, 5, 21),
      updatedAt: DateTime(2026, 5, 21),
    );

    expect(isBuyerVisibleProduct(item()), isTrue);
    expect(isBuyerVisibleProduct(item(stockQty: 0)), isFalse);
    expect(isBuyerVisibleProduct(item(isPublished: false)), isFalse);
  });

  test('Favourite ids prefer live stream values over cached fetch values', () {
    expect(
      resolveFavouriteIds(
        liveIds: const ['live-product'],
        loadedIds: const ['cached-product'],
      ),
      const ['live-product'],
    );
    expect(resolveFavouriteIds(loadedIds: const ['cached-product']), const [
      'cached-product',
    ]);
  });

  test('Basket actions require sign-in when browsing as a guest', () {
    expect(requiresSignInForCart(null), isTrue);
    expect(requiresSignInForCart(''), isTrue);
    expect(requiresSignInForCart('user-1'), isFalse);
  });

  test('Trending searches fall back to popular product terms', () {
    expect(
      resolveTrendingSearchTerms(
        configuredTerms: const [],
        fallbackTerms: const ['  Ceramics  ', 'ceramics', '', 'Leather'],
      ),
      const ['Ceramics', 'Leather'],
    );
    expect(
      resolveTrendingSearchTerms(
        configuredTerms: const ['Jewellery'],
        fallbackTerms: const ['Ceramics'],
      ),
      const ['Jewellery'],
    );
  });

  test('Product display sorting orders price low to high', () {
    Product item(String id, double price) => Product(
      id: id,
      shopId: 'shop-1',
      title: id,
      price: price,
      createdAt: DateTime(2026, 4, 15),
      updatedAt: DateTime(2026, 4, 15),
    );

    final sorted = sortProductsForDisplay(
      [item('expensive', 950), item('cheap', 50), item('middle', 500)],
      sortBy: 'price',
      ascending: true,
    );

    expect(sorted.map((product) => product.id), [
      'cheap',
      'middle',
      'expensive',
    ]);
  });

  test('Product display sorting orders price high to low', () {
    Product item(String id, double price) => Product(
      id: id,
      shopId: 'shop-1',
      title: id,
      price: price,
      createdAt: DateTime(2026, 4, 15),
      updatedAt: DateTime(2026, 4, 15),
    );

    final sorted = sortProductsForDisplay(
      [item('middle', 500), item('cheap', 50), item('expensive', 950)],
      sortBy: 'price',
      ascending: false,
    );

    expect(sorted.map((product) => product.id), [
      'expensive',
      'middle',
      'cheap',
    ]);
  });

  test('Product display sorting orders newest first', () {
    Product item(String id, DateTime createdAt) => Product(
      id: id,
      shopId: 'shop-1',
      title: id,
      price: 100,
      createdAt: createdAt,
      updatedAt: createdAt,
    );

    final sorted = sortProductsForDisplay(
      [
        item('older', DateTime(2026, 4, 10)),
        item('newest', DateTime(2026, 4, 18)),
        item('middle', DateTime(2026, 4, 14)),
      ],
      sortBy: 'created_at',
      ascending: false,
    );

    expect(sorted.map((product) => product.id), ['newest', 'middle', 'older']);
  });

  test('Product display sorting orders title A to Z', () {
    Product item(String id, String title) => Product(
      id: id,
      shopId: 'shop-1',
      title: title,
      price: 100,
      createdAt: DateTime(2026, 4, 15),
      updatedAt: DateTime(2026, 4, 15),
    );

    final sorted = sortProductsForDisplay(
      [
        item('zebra', 'Zebra Bowl'),
        item('amber', 'amber Vase'),
        item('middle', 'Moon Basket'),
      ],
      sortBy: 'title',
      ascending: true,
    );

    expect(sorted.map((product) => product.id), ['amber', 'middle', 'zebra']);
  });

  test('Product display sorting orders popular items first', () {
    Product item(
      String id, {
      bool isFeatured = false,
      DateTime? featuredAt,
      DateTime? createdAt,
    }) => Product(
      id: id,
      shopId: 'shop-1',
      title: id,
      price: 100,
      isFeatured: isFeatured,
      featuredAt: featuredAt,
      createdAt: createdAt ?? DateTime(2026, 4, 15),
      updatedAt: createdAt ?? DateTime(2026, 4, 15),
    );

    final sorted = sortProductsForDisplay(
      [
        item('regular-new', createdAt: DateTime(2026, 4, 18)),
        item(
          'featured-old',
          isFeatured: true,
          featuredAt: DateTime(2026, 4, 10),
        ),
        item(
          'featured-new',
          isFeatured: true,
          featuredAt: DateTime(2026, 4, 17),
        ),
      ],
      sortBy: 'popular',
      ascending: false,
    );

    expect(sorted.map((product) => product.id), [
      'featured-new',
      'featured-old',
      'regular-new',
    ]);
  });

  test('Product display filters only on-sale items', () {
    Product item(String id, {double? compareAtPrice}) => Product(
      id: id,
      shopId: 'shop-1',
      title: id,
      price: 100,
      compareAtPrice: compareAtPrice,
      stockQty: 1,
      createdAt: DateTime(2026, 4, 15),
      updatedAt: DateTime(2026, 4, 15),
    );

    final filtered = filterProductsForDisplay([
      item('sale', compareAtPrice: 150),
      item('not-sale'),
      item('invalid-sale', compareAtPrice: 90),
    ], onSale: true);

    expect(filtered.map((product) => product.id), ['sale']);
  });

  test('Product display filters out out-of-stock items', () {
    Product item(String id, int stockQty) => Product(
      id: id,
      shopId: 'shop-1',
      title: id,
      price: 100,
      stockQty: stockQty,
      createdAt: DateTime(2026, 5, 18),
      updatedAt: DateTime(2026, 5, 18),
    );

    final filtered = filterProductsForDisplay([
      item('available', 2),
      item('sold-out', 0),
    ]);

    expect(filtered.map((product) => product.id), ['available']);
  });

  test('Search product display filters out out-of-stock items', () {
    Product item(String id, int stockQty) => Product(
      id: id,
      shopId: 'shop-1',
      title: id,
      price: 100,
      stockQty: stockQty,
      createdAt: DateTime(2026, 5, 18),
      updatedAt: DateTime(2026, 5, 18),
    );

    final filtered = filterSearchProductsForDisplay([
      item('available', 2),
      item('sold-out', 0),
    ], selectedFilter: 0);

    expect(filtered.map((product) => product.id), ['available']);
  });

  test('Tracking links normalize pasted courier URLs for opening', () {
    expect(
      normalizeTrackingUri(' courier.example/track/123 ')?.toString(),
      'https://courier.example/track/123',
    );
    expect(
      trackingUriLaunchCandidates(
        'courier.example/track/123',
      ).map((uri) => uri.toString()),
      const [
        'https://courier.example/track/123',
        'http://courier.example/track/123',
      ],
    );
    expect(
      normalizeTrackingUri('https://courier.example/track/123')?.scheme,
      'https',
    );
    expect(trackingUriLaunchCandidates('ftp://courier.example'), isEmpty);
    expect(normalizeTrackingUri(''), isNull);
  });

  test('Order history hides cancelled orders by default', () {
    Order order(String id, String status) => Order(
      id: id,
      buyerId: 'buyer-1',
      shopId: 'shop-1',
      status: status,
      total: 100,
      createdAt: DateTime(2026, 5, 18),
      updatedAt: DateTime(2026, 5, 18),
    );

    final orders = [
      order('paid-order-0001', 'paid'),
      order('cancelled-order', 'cancelled'),
    ];

    expect(visibleOrderHistoryItems(orders).map((order) => order.id), [
      'paid-order-0001',
    ]);
    expect(
      visibleOrderHistoryItems(
        orders,
        hideCancelledOrders: false,
      ).map((order) => order.id),
      ['paid-order-0001', 'cancelled-order'],
    );
  });

  test('Receipt reminders prompt only active shipped orders', () {
    Order order(String status, {DateTime? shippedAt, DateTime? receivedAt}) =>
        Order(
          id: 'order-$status',
          buyerId: 'buyer-1',
          shopId: 'shop-1',
          status: status,
          total: 100,
          shippedAt: shippedAt,
          receivedAt: receivedAt,
          createdAt: DateTime(2026, 5, 18),
          updatedAt: DateTime(2026, 5, 18),
        );

    expect(
      shouldPromptReceiptReminder(
        order('shipped', shippedAt: DateTime(2026, 5, 15)),
      ),
      isTrue,
    );
    expect(
      shouldPromptReceiptReminder(
        order('delivered', shippedAt: DateTime(2026, 5, 15)),
      ),
      isTrue,
    );
    expect(
      shouldPromptReceiptReminder(
        order(
          'completed',
          shippedAt: DateTime(2026, 5, 15),
          receivedAt: DateTime(2026, 5, 18),
        ),
      ),
      isFalse,
    );
    expect(shouldPromptReceiptReminder(order('disputed')), isFalse);
  });

  test(
    'Shop profile message action uses buyer chat route and guest gating',
    () {
      expect(requiresSignInToMessageShop(null), isTrue);
      expect(requiresSignInToMessageShop(''), isTrue);
      expect(requiresSignInToMessageShop('buyer-1'), isFalse);
      expect(buyerShopMessageRoute('thread-42'), '/profile/messages/thread-42');
    },
  );

  test('Guest shop message action prompts sign in', () async {
    var prompted = false;
    var threadCreated = false;
    var openedRoute = '';

    final outcome = await handleShopMessageTap(
      userId: null,
      promptSignIn: () async => prompted = true,
      createOrGetThreadId: (userId) async {
        threadCreated = true;
        return 'thread-guest';
      },
      openChat: (route) async => openedRoute = route,
    );

    expect(outcome, ShopMessageTapOutcome.promptSignIn);
    expect(prompted, isTrue);
    expect(threadCreated, isFalse);
    expect(openedRoute, isEmpty);
  });

  test('Signed-in shop message action opens the buyer chat thread', () async {
    var prompted = false;
    var createdForUser = '';
    var openedRoute = '';

    final outcome = await handleShopMessageTap(
      userId: 'buyer-1',
      promptSignIn: () async => prompted = true,
      createOrGetThreadId: (userId) async {
        createdForUser = userId;
        return 'thread-42';
      },
      openChat: (route) async => openedRoute = route,
    );

    expect(outcome, ShopMessageTapOutcome.openChat);
    expect(prompted, isFalse);
    expect(createdForUser, 'buyer-1');
    expect(openedRoute, '/profile/messages/thread-42');
  });

  test('Shop profile hides the collection meta pill when count is unknown', () {
    expect(shopCollectionMetaLabel(null), isNull);
    expect(shopCollectionMetaLabel(12), '12 pieces');
  });

  test('Gift pricing adds the gift service fee to checkout totals', () {
    expect(giftServiceFee, 30);
    expect(giftServiceLabel, 'Gift wrap & card');
    expect(giftFeeForSelection(isGift: false), 0);
    expect(giftFeeForSelection(isGift: true), 30);
    expect(
      calculateCheckoutTotal(subtotal: 380, shippingCost: 0, isGift: true),
      410,
    );
  });

  test('Vendor onboarding fulfillment options exclude self-delivery', () {
    expect(vendorFulfillmentOptions.contains('Self-delivery'), isFalse);
    expect(vendorFulfillmentOptions, [
      'Courier',
      'Click & collect',
      'Market pickup',
      'Locker pickup',
    ]);
  });

  test('Product form defaults to size and color option names', () {
    expect(defaultProductOptionOneName, 'Size');
    expect(defaultProductOptionTwoName, 'Color');
  });

  test('Current price label changes when sale price is present', () {
    expect(currentPriceLabelForSalePrice(''), 'Price (R)');
    expect(currentPriceLabelForSalePrice('   '), 'Price (R)');
    expect(currentPriceLabelForSalePrice('249.00'), 'Original Price (R)');
  });

  test('Product form pricing normalizes sale prices for saving', () {
    expect(
      normalizeProductPricingForSave(
        currentPriceText: '250.00',
        salePriceText: '190.00',
      ),
      const ProductPricingValues(price: 190, compareAtPrice: 250),
    );
    expect(
      normalizeProductPricingForSave(
        currentPriceText: '190.00',
        salePriceText: '',
      ),
      const ProductPricingValues(price: 190, compareAtPrice: null),
    );
    expect(
      normalizeProductPricingForSave(
        currentPriceText: '70',
        salePriceText: '66,50',
      ),
      const ProductPricingValues(price: 66.5, compareAtPrice: 70),
    );
  });

  test('Product form pricing loads sale values into the correct fields', () {
    expect(
      pricingFieldsFromStoredValues(price: 190, compareAtPrice: 250),
      const ProductPricingFieldValues(
        currentPriceText: '250.00',
        salePriceText: '190.00',
      ),
    );
    expect(
      pricingFieldsFromStoredValues(price: 250, compareAtPrice: 190),
      const ProductPricingFieldValues(
        currentPriceText: '250.00',
        salePriceText: '190.00',
      ),
    );
  });

  test('Checkout validation identifies the first missing field', () {
    expect(
      firstIncompleteCheckoutField(
        const CheckoutFormSnapshot(
          fullName: '',
          streetAddress: '12 Main Road',
          city: 'Cape Town',
          postalCode: '8001',
          province: 'Western Cape',
          phoneNumber: '0820000000',
          selectedShippingMethod: 'courier_guy',
          hasAvailableShippingMethods: true,
          requiresShippingAddress: true,
          requiresPickupPoint: false,
          pickupPoint: '',
        ),
      ),
      CheckoutField.fullName,
    );
    expect(
      firstIncompleteCheckoutField(
        const CheckoutFormSnapshot(
          fullName: 'Alicia',
          streetAddress: '12 Main Road',
          city: 'Cape Town',
          postalCode: '8001',
          province: null,
          phoneNumber: '0820000000',
          selectedShippingMethod: 'courier_guy',
          hasAvailableShippingMethods: true,
          requiresShippingAddress: true,
          requiresPickupPoint: false,
          pickupPoint: '',
        ),
      ),
      CheckoutField.province,
    );
    expect(
      firstIncompleteCheckoutField(
        const CheckoutFormSnapshot(
          fullName: 'Alicia',
          streetAddress: '12 Main Road',
          city: 'Cape Town',
          postalCode: '8001',
          province: 'Western Cape',
          phoneNumber: '0820000000',
          selectedShippingMethod: null,
          hasAvailableShippingMethods: true,
          requiresShippingAddress: true,
          requiresPickupPoint: false,
          pickupPoint: '',
        ),
      ),
      CheckoutField.shippingMethod,
    );
    expect(
      firstIncompleteCheckoutField(
        const CheckoutFormSnapshot(
          fullName: 'Alicia',
          streetAddress: '12 Main Road',
          city: 'Cape Town',
          postalCode: '8001',
          province: 'Western Cape',
          phoneNumber: '0820000000',
          selectedShippingMethod: 'courier_guy',
          hasAvailableShippingMethods: true,
          requiresShippingAddress: false,
          requiresPickupPoint: true,
          pickupPoint: '',
        ),
      ),
      CheckoutField.pickupPoint,
    );
    expect(
      firstIncompleteCheckoutField(
        const CheckoutFormSnapshot(
          fullName: 'Alicia',
          streetAddress: '',
          city: '',
          postalCode: '',
          province: null,
          phoneNumber: '0820000000',
          selectedShippingMethod: 'market_pickup',
          hasAvailableShippingMethods: true,
          requiresShippingAddress: false,
          requiresPickupPoint: false,
          pickupPoint: '',
        ),
      ),
      isNull,
    );
    expect(
      firstIncompleteCheckoutField(
        const CheckoutFormSnapshot(
          fullName: 'Alicia',
          streetAddress: '',
          city: '',
          postalCode: '',
          province: null,
          phoneNumber: '0820000000',
          selectedShippingMethod: 'courier_guy_door_to_door',
          hasAvailableShippingMethods: true,
          requiresShippingAddress: true,
          requiresPickupPoint: false,
          pickupPoint: '',
        ),
      ),
      CheckoutField.streetAddress,
    );
  });

  test('Checkout validation reports why payment cannot proceed', () {
    expect(
      checkoutBlockingMessage(
        firstIncompleteCheckoutField(
          const CheckoutFormSnapshot(
            fullName: 'Alicia',
            streetAddress: '12 Main Road',
            city: 'Cape Town',
            postalCode: '8001',
            province: 'Western Cape',
            phoneNumber: '0820000000',
            selectedShippingMethod: null,
            hasAvailableShippingMethods: false,
            requiresShippingAddress: true,
            requiresPickupPoint: false,
            pickupPoint: '',
          ),
        ),
      ),
      'This product does not have any shipping options available yet.',
    );
    expect(
      checkoutBlockingMessage(CheckoutField.phoneNumber),
      'Please complete your checkout details before continuing to TradeSafe.',
    );
    expect(
      checkoutBlockingMessage(CheckoutField.pickupPoint),
      'Please enter the pickup point or drop-off location for this shipping method.',
    );
  });

  test('shipping option catalogue excludes paxi from selectable methods', () {
    expect(
      ShippingOption.defaults().map((option) => option.key),
      isNot(contains('paxi')),
    );
    expect(
      ShippingOption.defaults().map((option) => option.key),
      containsAll(['courier_guy', 'courier_guy_door_to_door']),
    );

    final filtered = ShippingOption.listFromJson([
      {'key': 'courier_guy', 'enabled': true, 'price': 99},
      {'key': 'courier_guy_door_to_door', 'enabled': true, 'price': 110},
      {'key': 'paxi', 'enabled': true, 'price': 45},
      {'key': 'market_pickup', 'enabled': true, 'price': 0},
    ]);

    expect(filtered.map((option) => option.key), [
      'courier_guy',
      'courier_guy_door_to_door',
      'market_pickup',
    ]);
  });

  test(
    'market pickup shipping option stores location and province metadata',
    () {
      final option = ShippingOption.fromJson(const {
        'key': 'market_pickup',
        'enabled': true,
        'price': 0,
        'market_name': 'Bryanston Organic Market',
        'market_location': 'Johannesburg',
        'market_province': 'Gauteng',
      });

      expect(option.marketName, 'Bryanston Organic Market');
      expect(option.marketLocation, 'Johannesburg');
      expect(option.marketProvince, 'Gauteng');
      expect(option.toJson(), containsPair('market_location', 'Johannesburg'));
      expect(option.toJson(), containsPair('market_province', 'Gauteng'));
    },
  );

  test(
    'Order pickup point summary supports both legacy text and locker maps',
    () {
      final legacyOrder = Order(
        id: 'ord-1',
        buyerId: 'buyer-1',
        shopId: 'shop-1',
        status: 'pending',
        total: 100,
        createdAt: DateTime.parse('2026-01-01T00:00:00Z'),
        updatedAt: DateTime.parse('2026-01-01T00:00:00Z'),
        shippingAddress: const {'pickup_point': 'PAXI Point CPT001'},
      );
      expect(legacyOrder.pickupPointSummary, 'PAXI Point CPT001');

      final structuredOrder = Order(
        id: 'ord-2',
        buyerId: 'buyer-1',
        shopId: 'shop-1',
        status: 'pending',
        total: 100,
        createdAt: DateTime.parse('2026-01-01T00:00:00Z'),
        updatedAt: DateTime.parse('2026-01-01T00:00:00Z'),
        shippingAddress: const {
          'pickup_point': {
            'name': 'Cradlestone Mall',
            'code': 'CG70',
            'address': '17 Hendrik Potgieter Rd, Krugersdorp',
            'province': 'Gauteng',
          },
        },
      );
      expect(
        structuredOrder.pickupPointSummary,
        'Cradlestone Mall (CG70) 17 Hendrik Potgieter Rd, Krugersdorp Gauteng',
      );
    },
  );

  test('Product form helper copy explains editable size and color defaults', () {
    expect(
      productOptionsHelperText,
      'Most products only need Size and Color. You can rename these if your product needs something different.',
    );
  });

  test('Cart badge count sums item quantities', () {
    expect(
      cartBadgeCount([
        CartItem(
          id: 'line-1',
          cartId: 'cart-1',
          productId: 'product-1',
          quantity: 2,
          createdAt: DateTime.parse('2026-04-15T12:00:00.000Z'),
        ),
        CartItem(
          id: 'line-2',
          cartId: 'cart-1',
          productId: 'product-2',
          quantity: 3,
          createdAt: DateTime.parse('2026-04-15T12:00:00.000Z'),
        ),
      ]),
      5,
    );
  });

  test('Cart stock guard blocks adding beyond the available stock', () {
    final product = Product.fromJson({
      'id': 'product-1',
      'shop_id': 'shop-1',
      'category_id': null,
      'subcategory_id': null,
      'title': 'Handwoven Basket',
      'description': 'Made by hand',
      'price': 350,
      'stock_qty': 2,
      'images': const [],
      'option_groups': const [],
      'product_variants': const [],
      'tags': const [],
      'is_published': true,
      'is_featured': false,
      'shipping_options': const [],
      'created_at': '2026-04-16T12:00:00.000Z',
      'updated_at': '2026-04-16T12:00:00.000Z',
    });

    final cartItems = [
      CartItem(
        id: 'line-1',
        cartId: 'cart-1',
        productId: 'product-1',
        quantity: 2,
        createdAt: DateTime.parse('2026-04-16T12:00:00.000Z'),
        product: product,
      ),
    ];

    expect(canAddSelectionToCart(cartItems, product, increment: 1), isFalse);
    expect(stockLimitMessage(2), 'Only 2 items left in stock');
  });

  test('Cart stock guard blocks quantity increases once stock is reached', () {
    final product = Product.fromJson({
      'id': 'product-1',
      'shop_id': 'shop-1',
      'category_id': null,
      'subcategory_id': null,
      'title': 'Handwoven Basket',
      'description': 'Made by hand',
      'price': 350,
      'stock_qty': 3,
      'images': const [],
      'option_groups': const [],
      'product_variants': const [],
      'tags': const [],
      'is_published': true,
      'is_featured': false,
      'shipping_options': const [],
      'created_at': '2026-04-16T12:00:00.000Z',
      'updated_at': '2026-04-16T12:00:00.000Z',
    });

    final item = CartItem(
      id: 'line-1',
      cartId: 'cart-1',
      productId: 'product-1',
      quantity: 3,
      createdAt: DateTime.parse('2026-04-16T12:00:00.000Z'),
      product: product,
    );

    expect(canIncreaseCartItemQuantity(item), isFalse);
    expect(availableStockForCartItem(item), 3);
  });

  testWidgets('Cart nav icon shows badge when count is above zero', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CartNavIcon(count: 3, isActive: false)),
      ),
    );

    expect(find.text('3'), findsOneWidget);
    expect(find.byIcon(Icons.shopping_bag_outlined), findsOneWidget);
  });

  testWidgets('Buyer profile screen shows live counts and no payment methods', (
    WidgetTester tester,
  ) async {
    final profile = Profile(
      id: 'buyer-1',
      role: 'buyer',
      displayName: 'Alicia',
      email: 'alicia@example.com',
      createdAt: DateTime.parse('2026-04-15T12:00:00.000Z'),
      updatedAt: DateTime.parse('2026-04-15T12:00:00.000Z'),
    );
    final orders = [
      Order(
        id: 'order-1',
        buyerId: 'buyer-1',
        shopId: 'shop-1',
        status: 'paid',
        total: 120,
        createdAt: DateTime.parse('2026-04-15T12:00:00.000Z'),
        updatedAt: DateTime.parse('2026-04-15T12:00:00.000Z'),
      ),
      Order(
        id: 'order-2',
        buyerId: 'buyer-1',
        shopId: 'shop-2',
        status: 'completed',
        total: 240,
        createdAt: DateTime.parse('2026-04-15T12:00:00.000Z'),
        updatedAt: DateTime.parse('2026-04-15T12:00:00.000Z'),
      ),
    ];
    final cartItems = [
      CartItem(
        id: 'line-1',
        cartId: 'cart-1',
        productId: 'product-1',
        quantity: 2,
        createdAt: DateTime.parse('2026-04-15T12:00:00.000Z'),
      ),
      CartItem(
        id: 'line-2',
        cartId: 'cart-1',
        productId: 'product-2',
        quantity: 4,
        createdAt: DateTime.parse('2026-04-15T12:00:00.000Z'),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith((ref) async => profile),
          ordersProvider.overrideWith((ref) async => orders),
          favouriteIdsProvider.overrideWith(
            (ref) async => ['fav-1', 'fav-2', 'fav-3', 'fav-4'],
          ),
          cartItemsProvider.overrideWith((ref) async => cartItems),
          buyerUnreadThreadsCountProvider.overrideWith((ref) => 0),
        ],
        child: const MaterialApp(home: BuyerProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    expect(find.text('Payment Methods'), findsNothing);
    expect(find.text('My Orders'), findsOneWidget);
  });

  testWidgets('Buyer profile screen includes a disputes entry', (
    WidgetTester tester,
  ) async {
    final profile = Profile(
      id: 'buyer-1',
      role: 'buyer',
      displayName: 'Alicia',
      email: 'alicia@example.com',
      createdAt: DateTime.parse('2026-04-15T12:00:00.000Z'),
      updatedAt: DateTime.parse('2026-04-15T12:00:00.000Z'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith((ref) async => profile),
          ordersProvider.overrideWith((ref) async => const <Order>[]),
          favouriteIdsProvider.overrideWith((ref) async => const <String>[]),
          cartItemsProvider.overrideWith((ref) async => const <CartItem>[]),
          buyerUnreadThreadsCountProvider.overrideWith((ref) => 0),
        ],
        child: const MaterialApp(home: BuyerProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Disputes'), findsOneWidget);
  });

  testWidgets('Completed orders show a leave review prompt', (
    WidgetTester tester,
  ) async {
    const orderId = '12345678-1234-1234-1234-123456789012';
    final order = Order(
      id: orderId,
      buyerId: 'buyer-1',
      shopId: 'shop-1',
      status: 'completed',
      total: 450,
      shippingCost: 50,
      createdAt: DateTime.parse('2026-04-15T12:00:00.000Z'),
      updatedAt: DateTime.parse('2026-04-15T12:00:00.000Z'),
      items: [
        OrderItem(
          id: 'item-1',
          orderId: orderId,
          productId: 'product-1',
          quantity: 1,
          unitPrice: 450,
          createdAt: DateTime.parse('2026-04-15T12:00:00.000Z'),
          productTitle: 'Handwoven Basket',
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => 'buyer-1'),
          orderDetailStreamProvider(
            orderId,
          ).overrideWith((ref) => Stream.value(order)),
          canReviewProductProvider(
            'product-1',
          ).overrideWith((ref) async => true),
        ],
        child: const MaterialApp(home: OrderDetailScreen(orderId: orderId)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reviews'), findsOneWidget);
    expect(find.text('Leave a Review'), findsOneWidget);
  });

  test('Curated collection auto-scroll only runs with multiple items', () {
    expect(shouldAutoScrollCuratedCollection(0), isFalse);
    expect(shouldAutoScrollCuratedCollection(1), isFalse);
    expect(shouldAutoScrollCuratedCollection(2), isTrue);
  });

  test('Curated collection resumes after the expected idle delay', () {
    expect(curatedCollectionResumeDelay, const Duration(seconds: 3));
    expect(
      curatedCollectionTick,
      lessThanOrEqualTo(const Duration(milliseconds: 20)),
    );
    expect(curatedCollectionScrollStep, greaterThan(1.0));
  });

  test('Curated collection routes to its own listing screen', () {
    expect(curatedCollectionRoute, '/home/curated');
    expect(curatedCollectionTitle, 'Curated Collection');
    expect(curatedCollectionSubtitle, 'Our top finds');
    expect(
      buyerHomeMakerSpotlightSubtitle,
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

  test('Home category includes candle as a product tag', () {
    final category = Category.fromJson({
      'id': 'c0000000-0000-0000-0000-000000000001',
      'name': 'Home',
      'slug': 'home',
      'icon_url': null,
      'sort_order': 1,
      'created_at': '2026-04-07T12:00:00.000Z',
    });

    expect(category.availableFilterTags, contains('candle'));
  });

  test(
    'Product shipping checkout hides methods missing from any cart item',
    () {
      final available = availableShippingOptionsForProducts([
        [
          const ShippingOption(key: 'courier_guy', enabled: true, price: 99),
          const ShippingOption(key: 'market_pickup', enabled: true, price: 0),
        ],
        [const ShippingOption(key: 'courier_guy', enabled: true, price: 120)],
      ]);

      expect(available.map((option) => option.key).toList(), ['courier_guy']);
    },
  );

  test('Product shipping checkout totals selected shipping per cart item', () {
    final total = calculateProductShippingTotal(
      methodKey: 'courier_guy',
      itemQuantities: const [2, 1],
      productShippingOptions: const [
        [ShippingOption(key: 'courier_guy', enabled: true, price: 80)],
        [ShippingOption(key: 'courier_guy', enabled: true, price: 50)],
      ],
    );

    expect(total, 210);
  });

  test('Product parses product-level shipping options', () {
    final product = Product.fromJson({
      'id': 'product-1',
      'shop_id': 'shop-1',
      'category_id': null,
      'subcategory_id': null,
      'title': 'Handwoven Basket',
      'description': 'Made by hand',
      'price': 350,
      'stock_qty': 4,
      'images': const [],
      'option_groups': const [],
      'product_variants': const [],
      'tags': const [],
      'is_published': true,
      'is_featured': false,
      'shipping_options': const [
        {'key': 'courier_guy', 'enabled': true, 'price': 90},
        {
          'key': 'market_pickup',
          'enabled': false,
          'price': 0,
          'market_name': 'Bryanston Market',
        },
      ],
      'created_at': '2026-04-16T12:00:00.000Z',
      'updated_at': '2026-04-16T12:00:00.000Z',
    });

    expect(product.shippingOptions.length, 2);
    expect(product.shippingOptions.first.key, 'courier_guy');
    expect(product.shippingOptions.first.price, 90);
    expect(product.shippingOptions.last.marketName, 'Bryanston Market');
    expect(product.toJson()['shipping_options'], [
      {'key': 'courier_guy', 'enabled': true, 'price': 90.0},
      {
        'key': 'market_pickup',
        'enabled': false,
        'price': 0.0,
        'market_name': 'Bryanston Market',
      },
    ]);
  });
}
