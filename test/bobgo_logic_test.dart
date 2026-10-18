import 'package:artisanal_lane/features/buyer/utils/bobgo_checkout.dart';
import 'package:artisanal_lane/features/buyer/utils/checkout_shipping_layout.dart';
import 'package:artisanal_lane/features/buyer/utils/checkout_validation.dart';
import 'package:artisanal_lane/features/vendor/utils/parcel_measurements.dart';
import 'package:artisanal_lane/models/bobgo.dart';
import 'package:artisanal_lane/models/bobgo_status.dart';
import 'package:artisanal_lane/models/order.dart';
import 'package:artisanal_lane/models/product.dart';
import 'package:artisanal_lane/models/shop_fulfillment_profile.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _rateJson({
  int id = 7,
  String service = 'ECO',
  double amount = 95,
  Map<String, dynamic> extra = const {},
}) => {
  'rateResponseId': id,
  'providerSlug': 'sandbox',
  'providerName': 'Sandbox Couriers',
  'serviceLevelCode': service,
  'serviceLevelName': 'Economy',
  'description': 'Door delivery',
  'amount': amount,
  'amountExcludingVat': 82.61,
  'chargedWeightKg': 1.5,
  ...extra,
};

Map<String, dynamic> _orderJson(Map<String, dynamic> overrides) => {
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
};

void main() {
  group('BobGoRate / BobGoQuote', () {
    test('parses the quote payload and keeps VAT-inclusive amounts', () {
      final quote = BobGoQuote.fromJson({
        'quoteId': 'q-1',
        'expiresAt': '2026-09-29T12:20:00.000Z',
        'rates': [_rateJson(), _rateJson(id: 8, service: 'EXP', amount: 150)],
      });
      expect(quote.quoteId, 'q-1');
      expect(quote.rates, hasLength(2));
      expect(quote.rates.first.amount, 95);
      expect(quote.rates.first.amountExcludingVat, closeTo(82.61, 0.001));
      expect(quote.rates.first.key, '7|sandbox|ECO');
    });

    test('formats ETA from days, dates, or not at all', () {
      expect(BobGoRate.fromJson(_rateJson()).etaLabel, isNull);
      expect(
        BobGoRate.fromJson(
          _rateJson(extra: {'etaMinDays': 2, 'etaMaxDays': 4}),
        ).etaLabel,
        'Estimated 2-4 business days',
      );
      expect(
        BobGoRate.fromJson(_rateJson(extra: {'etaMaxDays': 1})).etaLabel,
        'Estimated 1 business day',
      );
      expect(
        BobGoRate.fromJson(
          _rateJson(
            extra: {
              'etaFrom': '2026-10-03T10:00:00.000Z',
              'etaTo': '2026-10-05T10:00:00.000Z',
            },
          ),
        ).etaLabel,
        matches(r'^Estimated \d+ Oct - \d+ Oct$'),
      );
    });

    test('quote expiry is based on the server timestamp', () {
      final quote = BobGoQuote.fromJson({
        'quoteId': 'q',
        'expiresAt': '2026-09-29T12:20:00.000Z',
        'rates': [_rateJson()],
      });
      expect(quote.isExpiredAt(DateTime.utc(2026, 9, 29, 12, 19, 59)), false);
      expect(quote.isExpiredAt(DateTime.utc(2026, 9, 29, 12, 20)), true);
    });

    test('checkout body carries identifiers only, never a price', () {
      final selection = BobGoSelection(
        quoteId: 'q-1',
        rate: BobGoRate.fromJson(_rateJson()),
      );
      expect(selection.toCheckoutJson(), {
        'bobgoQuoteId': 'q-1',
        'bobgoRateResponseId': 7,
        'bobgoProviderSlug': 'sandbox',
        'bobgoServiceLevelCode': 'ECO',
      });
    });

    test('address fingerprint ignores case and whitespace only', () {
      const base = BobGoDeliveryDetails(
        fullName: 'A',
        phone: '1',
        streetAddress: '2 Buyer  Road',
        localArea: 'Bryanston',
        city: 'Johannesburg',
        province: 'Gauteng',
        postalCode: '2191',
      );
      const same = BobGoDeliveryDetails(
        fullName: 'Different name',
        phone: '2',
        streetAddress: ' 2 buyer road ',
        localArea: 'BRYANSTON',
        city: 'Johannesburg',
        province: 'Gauteng',
        postalCode: '2191',
      );
      const moved = BobGoDeliveryDetails(
        fullName: 'A',
        phone: '1',
        streetAddress: '9 Other Road',
        localArea: 'Bryanston',
        city: 'Johannesburg',
        province: 'Gauteng',
        postalCode: '2191',
      );
      expect(same.fingerprint, base.fingerprint);
      expect(moved.fingerprint, isNot(base.fingerprint));
    });
  });

  group('bobGoQuoteStatus', () {
    final rate = BobGoRate.fromJson(_rateJson());
    final quote = BobGoQuote(
      quoteId: 'q',
      expiresAt: DateTime.utc(2026, 9, 29, 12, 20),
      rates: [rate],
    );
    final now = DateTime.utc(2026, 9, 29, 12, 0);

    BobGoQuoteStatus status({
      BobGoQuote? q,
      BobGoRate? selected,
      String quoted = 'a',
      String current = 'a',
      DateTime? at,
    }) => bobGoQuoteStatus(
      quote: q,
      selectedRate: selected,
      quotedFingerprint: quoted,
      currentFingerprint: current,
      now: at ?? now,
    );

    test('walks through none, needs selection, ready', () {
      expect(status(), BobGoQuoteStatus.none);
      expect(status(q: quote), BobGoQuoteStatus.needsSelection);
      expect(status(q: quote, selected: rate), BobGoQuoteStatus.ready);
    });

    test('expired and stale quotes are never ready', () {
      expect(
        status(q: quote, selected: rate, at: DateTime.utc(2026, 9, 29, 12, 21)),
        BobGoQuoteStatus.expired,
      );
      expect(
        status(q: quote, selected: rate, current: 'b'),
        BobGoQuoteStatus.stale,
      );
      expect(bobGoQuoteProblemMessage(BobGoQuoteStatus.expired), isNotNull);
      expect(bobGoQuoteProblemMessage(BobGoQuoteStatus.ready), isNull);
    });

    test('validity label counts down and reports expiry', () {
      expect(
        bobGoQuoteValidityLabel(
          DateTime.utc(2026, 9, 29, 12, 12),
          DateTime.utc(2026, 9, 29, 12, 0),
        ),
        'Quote valid for 12 more minutes',
      );
      expect(
        bobGoQuoteValidityLabel(
          DateTime.utc(2026, 9, 29, 12, 0),
          DateTime.utc(2026, 9, 29, 12, 5),
        ),
        'Quote expired',
      );
      expect(formatBobGoPrice(95), 'R95.00');
    });
  });

  group('checkout validation for Bob Go', () {
    CheckoutFormSnapshot snapshot({
      String suburb = 'Bryanston',
      bool usable = true,
    }) => CheckoutFormSnapshot(
      fullName: 'Alicia',
      streetAddress: '2 Buyer Road',
      city: 'Johannesburg',
      postalCode: '2191',
      province: 'Gauteng',
      phoneNumber: '0820000000',
      selectedShippingMethod: bobGoShippingKey,
      hasAvailableShippingMethods: true,
      requiresShippingAddress: true,
      requiresPickupPoint: false,
      pickupPoint: '',
      requiresSuburb: true,
      suburb: suburb,
      requiresBobGoRate: true,
      hasUsableBobGoRate: usable,
    );

    test('needs a suburb and a usable rate', () {
      expect(firstIncompleteCheckoutField(snapshot()), isNull);
      expect(
        firstIncompleteCheckoutField(snapshot(suburb: ' ')),
        CheckoutField.suburb,
      );
      expect(
        firstIncompleteCheckoutField(snapshot(usable: false)),
        CheckoutField.bobGoRate,
      );
      expect(checkoutBlockingMessage(CheckoutField.bobGoRate), contains('rates'));
    });

    test('non Bob Go checkout is unaffected by the new fields', () {
      expect(
        firstIncompleteCheckoutField(
          const CheckoutFormSnapshot(
            fullName: 'Alicia',
            streetAddress: '',
            city: '',
            postalCode: '',
            province: null,
            phoneNumber: '0820000000',
            selectedShippingMethod: 'pargo',
            hasAvailableShippingMethods: true,
            requiresShippingAddress: false,
            requiresPickupPoint: true,
            pickupPoint: 'Pargo Sandton',
          ),
        ),
        isNull,
      );
    });

    test('inline details map Bob Go to the rate picker', () {
      expect(
        inlineDetailsForShippingMethod(bobGoShippingKey),
        CheckoutShippingInlineDetails.bobGoRates,
      );
      expect(
        inlineDetailsForShippingMethod('courier_guy'),
        CheckoutShippingInlineDetails.courierGuyLockerSearch,
      );
    });
  });

  group('Order courier fields', () {
    test('booked orders expose tracking progress', () {
      final order = Order.fromJson(
        _orderJson({
          'bobgo_booking_state': 'booked',
          'bobgo_status': 'in-transit',
          'tracking_number': 'TRK1',
          'bobgo_last_event_at': '2026-09-29T10:00:00.000Z',
        }),
      );
      expect(order.isBobGo, true);
      expect(order.bobgoIsBooked, true);
      expect(order.bobgoCourierSummary, 'On its way');
      expect(order.shippingMethodDisplay, 'Bob Go Door to Door');
      expect(order.bobgoLastEventAt, isNotNull);
    });

    test('unbooked, failed and cancelled orders get plain messages', () {
      expect(
        Order.fromJson(
          _orderJson({'bobgo_booking_state': 'failed'}),
        ).bobgoCourierSummary,
        contains('arranging your courier'),
      );
      expect(
        Order.fromJson(
          _orderJson({'bobgo_booking_state': 'cancelled'}),
        ).bobgoCourierSummary,
        'Courier booking cancelled',
      );
    });

    test('non Bob Go orders have no courier summary', () {
      final order = Order.fromJson(
        _orderJson({'shipping_method': 'pargo', 'bobgo_status': 'in-transit'}),
      );
      expect(order.isBobGo, false);
      expect(order.bobgoCourierSummary, isNull);
    });

    test('status vocabulary is tolerant of unknown values', () {
      expect(bobGoStatusGroup('Out_For Delivery'), BobGoStatusGroup.outForDelivery);
      expect(bobGoStatusLabel('who-knows'), 'In progress');
      expect(bobGoStatusLabel(null), 'In progress');
    });

    test('official Bob Go statuses and server aliases are grouped', () {
      for (final status in [
        'collection-exception',
        'delivery-exception',
        'failed-collection',
        'exception',
      ]) {
        expect(bobGoStatusGroup(status), BobGoStatusGroup.exception);
      }
      expect(
        bobGoStatusGroup('ready-for-pickup'),
        BobGoStatusGroup.outForDelivery,
      );
      expect(
        bobGoStatusGroup('pending-collection'),
        BobGoStatusGroup.awaitingCollection,
      );
    });
  });

  group('Parcel measurements', () {
    ParcelMeasurementsResult parse(String w, String l, String wd, String h) =>
        parseParcelMeasurements(
          weightKg: w,
          lengthCm: l,
          widthCm: wd,
          heightCm: h,
        );

    test('all blank is allowed and saves nulls', () {
      final result = parse('', '', '', '');
      expect(result.error, isNull);
      expect(result.measurements.isEmpty, true);
      expect(result.measurements.toProductJson()['shipping_weight_kg'], isNull);
    });

    test('complete values parse, including comma decimals', () {
      final result = parse('1,5', '20', '15.5', '10');
      expect(result.error, isNull);
      expect(result.measurements.weightKg, 1.5);
      expect(result.measurements.widthCm, 15.5);
      expect(result.measurements.toProductJson()['shipping_height_cm'], 10);
    });

    test('partial, zero, non numeric and oversized entries are rejected', () {
      expect(parse('1', '', '', '').error, contains('together'));
      expect(parse('0', '10', '10', '10').error, contains('greater than zero'));
      expect(parse('-1', '10', '10', '10').error, contains('greater than zero'));
      expect(parse('abc', '10', '10', '10').error, contains('numbers'));
      expect(parse('100', '10', '10', '10').error, contains('too large'));
      expect(parse('1', '10', '10', '500').error, contains('too large'));
    });

    test('product model round trips the four columns', () {
      final product = Product.fromJson({
        'id': 'p1',
        'shop_id': 's1',
        'title': 'Mug',
        'price': 100,
        'created_at': '2026-01-01T00:00:00.000Z',
        'updated_at': '2026-01-01T00:00:00.000Z',
        'shipping_weight_kg': 0.75,
        'shipping_length_cm': 20,
        'shipping_width_cm': 15,
        'shipping_height_cm': 10.5,
      });
      expect(product.shippingWeightKg, 0.75);
      expect(product.shippingHeightCm, 10.5);
      expect(product.toJson()['shipping_length_cm'], 20);
    });
  });

  group('ShopFulfillmentProfile', () {
    const complete = ShopFulfillmentProfile(
      shopId: 'shop-1',
      contactFullName: 'Maker',
      contactEmail: 'maker@example.com',
      contactPhone: '+27 82 000 0000',
      streetAddress: '1 Maker Road',
      localArea: 'Woodstock',
      city: 'Cape Town',
      province: 'Western Cape',
      postalCode: '7925',
      bobgoEnabled: true,
    );

    test('complete details validate and upsert with ZA country', () {
      expect(complete.validate(), isNull);
      final json = complete.toUpsertJson();
      expect(json['country_code'], 'ZA');
      expect(json['bobgo_enabled'], true);
      expect(json['company'], isNull);
    });

    test('reports the first missing field in plain language', () {
      expect(complete.copyWith(contactEmail: 'nope').validate(), contains('email'));
      expect(complete.copyWith(contactPhone: '12').validate(), contains('phone'));
      expect(complete.copyWith(localArea: ' ').validate(), contains('suburb'));
      expect(complete.copyWith(province: '').validate(), contains('province'));
    });

    test('parses a database row', () {
      final parsed = ShopFulfillmentProfile.fromJson({
        'shop_id': 'shop-1',
        'contact_full_name': 'Maker',
        'contact_email': 'maker@example.com',
        'contact_phone': '0820000000',
        'company': '  ',
        'street_address': '1 Maker Road',
        'local_area': 'Woodstock',
        'city': 'Cape Town',
        'province': 'Western Cape',
        'postal_code': '7925',
        'bobgo_enabled': true,
      });
      expect(parsed.company, isNull);
      expect(parsed.bobgoEnabled, true);
      expect(parsed.validate(), isNull);
    });
  });
}
