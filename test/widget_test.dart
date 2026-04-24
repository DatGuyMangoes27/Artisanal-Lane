import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:artisanal_lane/features/auth/screens/login_screen.dart';
import 'package:artisanal_lane/features/auth/screens/welcome_screen.dart';
import 'package:artisanal_lane/features/chat/utils/live_chat_messages.dart';
import 'package:artisanal_lane/features/buyer/providers/buyer_providers.dart';
import 'package:artisanal_lane/features/buyer/screens/buyer_profile_screen.dart';
import 'package:artisanal_lane/features/buyer/screens/order_detail_screen.dart';
import 'package:artisanal_lane/features/buyer/screens/settings_screen.dart';
import 'package:artisanal_lane/core/pricing/pricing.dart';
import 'package:artisanal_lane/features/buyer/utils/shop_profile_actions.dart';
import 'package:artisanal_lane/features/buyer/utils/curated_collection_destination.dart';
import 'package:artisanal_lane/features/buyer/utils/cart_stock_guard.dart';
import 'package:artisanal_lane/features/buyer/utils/product_detail_actions.dart';
import 'package:artisanal_lane/features/buyer/utils/buyer_home_copy.dart';
import 'package:artisanal_lane/features/buyer/utils/checkout_validation.dart';
import 'package:artisanal_lane/features/buyer/utils/checkout_shipping_layout.dart';
import 'package:artisanal_lane/features/buyer/utils/curated_collection_carousel.dart';
import 'package:artisanal_lane/features/vendor/widgets/stationery_sheet_header.dart';
import 'package:artisanal_lane/features/buyer/utils/search_results_layout.dart';
import 'package:artisanal_lane/features/buyer/utils/payment_deep_links.dart';
import 'package:artisanal_lane/features/buyer/utils/product_shipping_checkout.dart';
import 'package:artisanal_lane/features/buyer/utils/help_support_contact.dart';
import 'package:artisanal_lane/features/disputes/utils/dispute_attachment_support.dart';
import 'package:artisanal_lane/features/vendor/utils/vendor_payout_copy.dart';
import 'package:artisanal_lane/features/vendor/utils/vendor_fulfillment_options.dart';
import 'package:artisanal_lane/features/vendor/providers/vendor_providers.dart';
import 'package:artisanal_lane/features/vendor/screens/vendor_settings_screen.dart';
import 'package:artisanal_lane/features/vendor/utils/product_form_copy.dart';
import 'package:artisanal_lane/features/vendor/utils/vendor_payout_setup.dart';
import 'package:artisanal_lane/models/cart_item.dart';
import 'package:artisanal_lane/models/category.dart';
import 'package:artisanal_lane/models/chat_message.dart';
import 'package:artisanal_lane/models/order.dart';
import 'package:artisanal_lane/models/product.dart';
import 'package:artisanal_lane/models/profile.dart';
import 'package:artisanal_lane/models/shipping_option.dart';
import 'package:artisanal_lane/models/vendor_payout_profile.dart';
import 'package:artisanal_lane/features/vendor/utils/vendor_onboarding_flow.dart';
import 'package:artisanal_lane/widgets/cart_nav_icon.dart';

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
    await tester.pumpWidget(
      const MaterialApp(home: SettingsScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Delete Account'), findsOneWidget);
  });

  testWidgets('Vendor settings screen exposes delete account action', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vendorShopProvider.overrideWith((ref) async => null),
        ],
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
  });

  test('shipping methods map to the expected inline checkout details', () {
    expect(
      inlineDetailsForShippingMethod('courier_guy'),
      CheckoutShippingInlineDetails.courierGuyLockerSearch,
    );
    expect(
      inlineDetailsForShippingMethod('pargo'),
      CheckoutShippingInlineDetails.pickupPointEntry,
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
    expect(isVendorPayoutSetupComplete(completeProfile), isTrue);
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
      buildProductShareText(title: 'Hand-Stitched Leather Journal', price: 165),
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
          requiresPickupPoint: true,
          pickupPoint: '',
        ),
      ),
      CheckoutField.pickupPoint,
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

    final filtered = ShippingOption.listFromJson([
      {'key': 'courier_guy', 'enabled': true, 'price': 99},
      {'key': 'paxi', 'enabled': true, 'price': 45},
      {'key': 'market_pickup', 'enabled': true, 'price': 0},
    ]);

    expect(filtered.map((option) => option.key), ['courier_guy', 'market_pickup']);
  });

  test('Order pickup point summary supports both legacy text and locker maps', () {
    final legacyOrder = Order(
      id: 'ord-1',
      buyerId: 'buyer-1',
      shopId: 'shop-1',
      status: 'pending',
      total: 100,
      createdAt: DateTime.parse('2026-01-01T00:00:00Z'),
      updatedAt: DateTime.parse('2026-01-01T00:00:00Z'),
      shippingAddress: const {
        'pickup_point': 'PAXI Point CPT001',
      },
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
  });

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
    expect(buyerHomeMakerSpotlightSubtitle, 'Handpicked for their exceptional craft');
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
        {'key': 'market_pickup', 'enabled': false, 'price': 0},
      ],
      'created_at': '2026-04-16T12:00:00.000Z',
      'updated_at': '2026-04-16T12:00:00.000Z',
    });

    expect(product.shippingOptions.length, 2);
    expect(product.shippingOptions.first.key, 'courier_guy');
    expect(product.shippingOptions.first.price, 90);
    expect(product.toJson()['shipping_options'], [
      {'key': 'courier_guy', 'enabled': true, 'price': 90.0},
      {'key': 'market_pickup', 'enabled': false, 'price': 0.0},
    ]);
  });
}
