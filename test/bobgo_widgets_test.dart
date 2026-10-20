import 'package:artisanal_lane/features/buyer/providers/bobgo_providers.dart';
import 'package:artisanal_lane/features/buyer/providers/buyer_providers.dart';
import 'package:artisanal_lane/features/buyer/screens/checkout_screen.dart';
import 'package:artisanal_lane/features/buyer/utils/bobgo_checkout.dart';
import 'package:artisanal_lane/features/buyer/widgets/bobgo_rate_picker.dart';
import 'package:artisanal_lane/features/vendor/widgets/bobgo_collection_section.dart';
import 'package:artisanal_lane/features/vendor/widgets/parcel_measurements_fields.dart';
import 'package:artisanal_lane/models/bobgo.dart';
import 'package:artisanal_lane/models/cart_item.dart';
import 'package:artisanal_lane/models/order.dart';
import 'package:artisanal_lane/models/product.dart';
import 'package:artisanal_lane/models/shipping_option.dart';
import 'package:artisanal_lane/models/shop_fulfillment_profile.dart';
import 'package:artisanal_lane/widgets/bobgo_courier_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

BobGoRate _rate({
  int id = 7,
  String service = 'ECO',
  double amount = 95,
  int? minDays = 2,
  int? maxDays = 4,
}) => BobGoRate(
  rateResponseId: id,
  providerSlug: 'sandbox',
  providerName: 'Sandbox Couriers',
  serviceLevelCode: service,
  serviceLevelName: service == 'ECO' ? 'Economy' : 'Express',
  amount: amount,
  etaMinDays: minDays,
  etaMaxDays: maxDays,
);

BobGoQuote _quote({DateTime? expiresAt, List<BobGoRate>? rates}) => BobGoQuote(
  quoteId: 'quote-1',
  expiresAt: expiresAt ?? DateTime.now().add(const Duration(minutes: 20)),
  rates: rates ?? [_rate(), _rate(id: 8, service: 'EXP', amount: 150)],
);

Order _order(Map<String, dynamic> overrides) => Order.fromJson({
  'id': '12345678-1234-1234-1234-123456789abc',
  'buyer_id': 'buyer-1',
  'shop_id': 'shop-1',
  'status': 'paid',
  'total': 250,
  'shipping_cost': 95,
  'shipping_method': 'bobgo_door_to_door',
  'payment_state': 'paid',
  'created_at': '2026-09-29T08:00:00.000Z',
  'updated_at': '2026-09-29T08:00:00.000Z',
  ...overrides,
});

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

class _FakeGateway implements BobGoGateway {
  _FakeGateway({this.available = true, this.quote, this.error});

  final bool available;
  final BobGoQuote? quote;
  final BobGoQuoteException? error;
  final requests = <BobGoDeliveryDetails>[];
  final quotedShopIds = <String?>[];

  @override
  Future<bool> isAvailable({String? shopId}) async => available;

  @override
  Future<BobGoQuote> requestQuote(
    BobGoDeliveryDetails delivery, {
    String? shopId,
  }) async {
    requests.add(delivery);
    quotedShopIds.add(shopId);
    if (error != null) throw error!;
    return quote!;
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('BobGoRatePicker', () {
    Widget picker({
      BobGoQuoteStatus status = BobGoQuoteStatus.none,
      BobGoQuote? quote,
      BobGoRate? selected,
      bool loading = false,
      String? error,
      bool canRequest = true,
      VoidCallback? onRequest,
      ValueChanged<BobGoRate>? onSelect,
    }) => _host(
      SingleChildScrollView(
        child: BobGoRatePicker(
          status: status,
          quote: quote,
          selectedRate: selected,
          isLoading: loading,
          errorMessage: error,
          canRequest: canRequest,
          now: DateTime.now(),
          onRequest: onRequest ?? () {},
          onSelect: onSelect ?? (_) {},
        ),
      ),
    );

    testWidgets('disables the request until the address is complete', (
      tester,
    ) async {
      var requested = 0;
      await tester.pumpWidget(
        picker(canRequest: false, onRequest: () => requested++),
      );
      expect(
        find.textContaining('Fill in your delivery address'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('bobgo-get-rates')));
      expect(requested, 0);
    });

    testWidgets('shows VAT inclusive prices with ETA and lets the buyer pick', (
      tester,
    ) async {
      BobGoRate? picked;
      final quote = _quote();
      await tester.pumpWidget(
        picker(
          status: BobGoQuoteStatus.needsSelection,
          quote: quote,
          onSelect: (rate) => picked = rate,
        ),
      );
      expect(find.text('R95.00'), findsOneWidget);
      expect(find.text('R150.00'), findsOneWidget);
      expect(find.text('incl. VAT'), findsNWidgets(2));
      expect(find.text('Estimated 2-4 business days'), findsWidgets);
      expect(find.textContaining('Quote valid for'), findsOneWidget);

      await tester.tap(
        find.byKey(ValueKey('bobgo-rate-${quote.rates[1].key}')),
      );
      expect(picked?.serviceLevelCode, 'EXP');
    });

    testWidgets('expired quote hides rates and asks for a refresh', (
      tester,
    ) async {
      await tester.pumpWidget(
        picker(status: BobGoQuoteStatus.expired, quote: _quote()),
      );
      expect(find.byKey(const ValueKey('bobgo-problem')), findsOneWidget);
      expect(find.textContaining('expired'), findsOneWidget);
      expect(find.text('R95.00'), findsNothing);
      expect(find.text('Refresh rates'), findsOneWidget);
    });

    testWidgets('shows a server error message without raw exception text', (
      tester,
    ) async {
      await tester.pumpWidget(
        picker(
          error: 'This artisan has not enabled Bob Go door-to-door delivery.',
        ),
      );
      expect(find.textContaining('has not enabled Bob Go'), findsOneWidget);
    });
  });

  group('BobGoCourierCard', () {
    testWidgets('renders nothing for other delivery methods', (tester) async {
      await tester.pumpWidget(
        _host(BobGoCourierCard(order: _order({'shipping_method': 'pargo'}))),
      );
      expect(find.byKey(const ValueKey('bobgo-courier-card')), findsNothing);
    });

    testWidgets('buyer sees status and tracking but no vendor actions', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          BobGoCourierCard(
            order: _order({
              'bobgo_booking_state': 'booked',
              'bobgo_status': 'out-for-delivery',
              'tracking_number': 'TRK99',
              'tracking_url': 'https://track.example/TRK99',
            }),
            onOpenTracking: () {},
          ),
        ),
      );
      expect(find.text('Out for delivery'), findsOneWidget);
      expect(find.text('TRK99'), findsOneWidget);
      expect(find.byKey(const ValueKey('bobgo-open-tracking')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('bobgo-download-waybill')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('bobgo-retry-booking')), findsNothing);
    });

    testWidgets('vendor can download the waybill once booked', (tester) async {
      var downloads = 0;
      await tester.pumpWidget(
        _host(
          BobGoCourierCard(
            order: _order({
              'bobgo_booking_state': 'booked',
              'bobgo_status': 'submitted',
              'tracking_number': 'TRK99',
            }),
            isVendor: true,
            onDownloadWaybill: () => downloads++,
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('bobgo-download-waybill')));
      expect(downloads, 1);
      expect(
        find.textContaining('waiting for courier collection'),
        findsOneWidget,
      );
    });

    testWidgets('vendor can retry a failed booking on a paid order', (
      tester,
    ) async {
      var retries = 0;
      await tester.pumpWidget(
        _host(
          BobGoCourierCard(
            order: _order({'bobgo_booking_state': 'failed'}),
            isVendor: true,
            onRetryBooking: () => retries++,
          ),
        ),
      );
      expect(find.textContaining('did not go through'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('bobgo-retry-booking')));
      expect(retries, 1);
    });

    testWidgets('buyers never get a retry button', (tester) async {
      await tester.pumpWidget(
        _host(
          BobGoCourierCard(order: _order({'bobgo_booking_state': 'failed'})),
        ),
      );
      expect(find.byKey(const ValueKey('bobgo-retry-booking')), findsNothing);
      expect(find.textContaining('arranging your courier'), findsOneWidget);
    });
  });

  group('BobGoCollectionSection', () {
    Future<void> fill(WidgetTester tester, String key, String text) async {
      await tester.enterText(find.byKey(ValueKey(key)), text);
    }

    testWidgets('requires complete details before enabling Bob Go', (
      tester,
    ) async {
      final saved = <ShopFulfillmentProfile>[];
      await tester.pumpWidget(
        _host(
          SingleChildScrollView(
            child: BobGoCollectionSection(
              shopId: 'shop-1',
              initial: null,
              onSave: (p) async => saved.add(p),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('bobgo-enabled-switch')));
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const ValueKey('bobgo-collection-save')),
      );
      await tester.tap(find.byKey(const ValueKey('bobgo-collection-save')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('bobgo-collection-error')),
        findsOneWidget,
      );
      expect(saved, isEmpty);
    });

    testWidgets('saves a complete profile with the enable flag', (
      tester,
    ) async {
      final saved = <ShopFulfillmentProfile>[];
      await tester.binding.setSurfaceSize(const Size(420, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _host(
          SingleChildScrollView(
            child: BobGoCollectionSection(
              shopId: 'shop-1',
              initial: null,
              onSave: (p) async => saved.add(p),
            ),
          ),
        ),
      );
      await fill(tester, 'bobgo-name', 'Maker Name');
      await fill(tester, 'bobgo-email', 'maker@example.com');
      await fill(tester, 'bobgo-phone', '0820000000');
      await fill(tester, 'bobgo-street', '1 Maker Road');
      await fill(tester, 'bobgo-suburb', 'Woodstock');
      await fill(tester, 'bobgo-city', 'Cape Town');
      await fill(tester, 'bobgo-postal', '7925');
      await tester.tap(find.byKey(const ValueKey('bobgo-province')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Western Cape').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('bobgo-enabled-switch')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('bobgo-collection-save')));
      await tester.pumpAndSettle();

      expect(saved, hasLength(1));
      expect(saved.single.bobgoEnabled, true);
      expect(saved.single.province, 'Western Cape');
      expect(saved.single.shopId, 'shop-1');
    });

    testWidgets('shows a friendly message when saving fails', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _host(
          SingleChildScrollView(
            child: BobGoCollectionSection(
              shopId: 'shop-1',
              initial: const ShopFulfillmentProfile(
                shopId: 'shop-1',
                contactFullName: 'Maker',
                contactEmail: 'maker@example.com',
                contactPhone: '0820000000',
                streetAddress: '1 Maker Road',
                localArea: 'Woodstock',
                city: 'Cape Town',
                province: 'Western Cape',
                postalCode: '7925',
                bobgoEnabled: true,
              ),
              onSave: (_) async => throw StateError('network down'),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('bobgo-collection-save')));
      await tester.pumpAndSettle();
      expect(find.textContaining('could not save'), findsOneWidget);
      expect(find.textContaining('network down'), findsNothing);
    });
  });

  testWidgets('ParcelMeasurementsFields renders the four inputs and an error', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        SingleChildScrollView(
          child: ParcelMeasurementsFields(
            weightController: TextEditingController(),
            lengthController: TextEditingController(),
            widthController: TextEditingController(),
            heightController: TextEditingController(),
            errorText: 'Packed weight and size must be numbers.',
          ),
        ),
      ),
    );
    for (final key in [
      'parcel-weight',
      'parcel-length',
      'parcel-width',
      'parcel-height',
    ]) {
      expect(find.byKey(ValueKey(key)), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('parcel-error')), findsOneWidget);
  });

  group('CheckoutScreen with Bob Go', () {
    Product product() => Product(
      id: 'p1',
      shopId: 'shop-1',
      title: 'Ceramic mug',
      price: 250,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      shippingOptions: const [
        ShippingOption(key: 'pargo', enabled: true, price: 65),
      ],
    );

    Future<void> pumpCheckout(WidgetTester tester, _FakeGateway gateway) async {
      await tester.binding.setSurfaceSize(const Size(430, 3200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cartItemsProvider.overrideWith(
              (ref) async => [
                CartItem(
                  id: 'c1',
                  cartId: 'cart',
                  productId: 'p1',
                  quantity: 1,
                  createdAt: DateTime.now(),
                  product: product(),
                ),
              ],
            ),
            shopDetailProvider.overrideWith(
              (ref, id) async => throw StateError('offline'),
            ),
            bobGoGatewayProvider.overrideWithValue(gateway),
          ],
          child: const MaterialApp(home: CheckoutScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> fillAddress(WidgetTester tester) async {
      Future<void> enter(String label, String text) async {
        await tester.enterText(find.widgetWithText(TextFormField, label), text);
      }

      await enter('Full Name', 'Alicia Buyer');
      await enter('Street Address', '2 Buyer Road');
      await enter('Suburb', 'Bryanston');
      await enter('City', 'Johannesburg');
      await enter('Postal Code', '2191');
      await enter('Phone Number', '0820000000');
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gauteng').last);
      await tester.pumpAndSettle();
    }

    testWidgets('is hidden when the server has Bob Go switched off', (
      tester,
    ) async {
      await pumpCheckout(tester, _FakeGateway(available: false));
      expect(find.text('Bob Go Door to Door'), findsNothing);
      expect(find.text('Pargo'), findsOneWidget);
    });

    testWidgets('quotes, selects a rate and shows the VAT inclusive total', (
      tester,
    ) async {
      final gateway = _FakeGateway(quote: _quote());
      await pumpCheckout(tester, gateway);

      await tester.tap(find.text('Bob Go Door to Door'));
      await tester.pumpAndSettle();
      // Rates cannot be requested before the address is complete.
      expect(find.text('Get delivery rates'), findsOneWidget);
      await fillAddress(tester);

      await tester.ensureVisible(find.byKey(const ValueKey('bobgo-get-rates')));
      await tester.tap(find.byKey(const ValueKey('bobgo-get-rates')));
      await tester.pumpAndSettle();

      expect(gateway.requests, hasLength(1));
      expect(gateway.requests.single.localArea, 'Bryanston');
      expect(gateway.requests.single.province, 'Gauteng');
      expect(find.text('R95.00'), findsOneWidget);

      await tester.tap(find.byKey(ValueKey('bobgo-rate-${_rate().key}')));
      await tester.pumpAndSettle();
      expect(find.text('R95.00 incl. VAT'), findsOneWidget);
      // Subtotal 250 + shipping 95.
      expect(find.text('R345'), findsWidgets);
    });

    testWidgets('a changed address invalidates the saved quote', (
      tester,
    ) async {
      await pumpCheckout(tester, _FakeGateway(quote: _quote()));
      await tester.tap(find.text('Bob Go Door to Door'));
      await tester.pumpAndSettle();
      await fillAddress(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('bobgo-get-rates')));
      await tester.tap(find.byKey(const ValueKey('bobgo-get-rates')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('bobgo-rate-${_rate().key}')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Street Address'),
        '99 Somewhere Else',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('bobgo-get-rates')));
      expect(find.textContaining('address changed'), findsOneWidget);
      expect(find.text('R95.00 incl. VAT'), findsNothing);
    });

    testWidgets('server quote errors are shown in plain language', (
      tester,
    ) async {
      await pumpCheckout(
        tester,
        _FakeGateway(
          error: const BobGoQuoteException(
            'Bob Go returned no door-to-door services for these addresses.',
          ),
        ),
      );
      await tester.tap(find.text('Bob Go Door to Door'));
      await tester.pumpAndSettle();
      await fillAddress(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('bobgo-get-rates')));
      await tester.tap(find.byKey(const ValueKey('bobgo-get-rates')));
      await tester.pumpAndSettle();
      expect(find.textContaining('no door-to-door services'), findsOneWidget);
      expect(find.textContaining('Exception'), findsNothing);
    });
  });
}
