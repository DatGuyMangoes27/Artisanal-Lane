import 'package:artisanal_lane/features/buyer/providers/bobgo_providers.dart';
import 'package:artisanal_lane/features/buyer/providers/buyer_providers.dart';
import 'package:artisanal_lane/features/buyer/screens/checkout_screen.dart';
import 'package:artisanal_lane/features/buyer/utils/bobgo_checkout.dart';
import 'package:artisanal_lane/features/buyer/utils/multi_shop_checkout.dart';
import 'package:artisanal_lane/models/bobgo.dart';
import 'package:artisanal_lane/models/cart_item.dart';
import 'package:artisanal_lane/models/checkout_quote.dart';
import 'package:artisanal_lane/models/checkout_session.dart';
import 'package:artisanal_lane/models/checkout_shop_selection.dart';
import 'package:artisanal_lane/models/product.dart';
import 'package:artisanal_lane/models/shipping_option.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

Product _product({
  required String id,
  required String shopId,
  String? shopName,
  double price = 100,
  List<ShippingOption> shipping = const [
    ShippingOption(key: 'pargo', enabled: true, price: 65),
  ],
}) => Product(
  id: id,
  shopId: shopId,
  shopName: shopName,
  title: 'Product $id',
  price: price,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  shippingOptions: shipping,
);

CartItem _line(Product product, {int quantity = 1}) => CartItem(
  id: 'line-${product.id}',
  cartId: 'cart',
  productId: product.id,
  quantity: quantity,
  createdAt: DateTime.now(),
  product: product,
);

class _FakeGateway implements BobGoGateway {
  @override
  Future<bool> isAvailable({String? shopId}) async => false;

  @override
  Future<BobGoQuote> requestQuote(
    BobGoDeliveryDetails delivery, {
    String? shopId,
  }) => throw UnimplementedError();
}

void main() {
  group('groupCartItemsByShop', () {
    test('keeps shops and lines in the order they were added', () {
      final items = [
        _line(_product(id: 'a1', shopId: 'clay', shopName: 'Clay Studio')),
        _line(_product(id: 'b1', shopId: 'weave', shopName: 'Weave Co')),
        _line(_product(id: 'a2', shopId: 'clay', shopName: 'Clay Studio')),
      ];

      final groups = groupCartItemsByShop(items);

      expect(groups.map((g) => g.shopId), ['clay', 'weave']);
      expect(groups.first.shopName, 'Clay Studio');
      expect(groups.first.items.map((i) => i.productId), ['a1', 'a2']);
      expect(groups.last.items.single.productId, 'b1');
    });

    test('falls back to a generic name and adds up pieces and subtotal', () {
      final groups = groupCartItemsByShop([
        _line(_product(id: 'a1', shopId: 'clay', price: 120), quantity: 2),
        _line(_product(id: 'a2', shopId: 'clay', price: 50)),
      ]);

      expect(groups.single.shopName, fallbackShopName);
      expect(groups.single.itemCount, 3);
      expect(groups.single.subtotal, 290);
    });

    test('an empty basket has no shops', () {
      expect(groupCartItemsByShop(const []), isEmpty);
    });

    test('options are worked out per shop, not across the basket', () {
      final groups = groupCartItemsByShop([
        _line(
          _product(
            id: 'a1',
            shopId: 'clay',
            shipping: const [
              ShippingOption(key: 'pargo', enabled: true, price: 65),
            ],
          ),
        ),
        _line(
          _product(
            id: 'b1',
            shopId: 'weave',
            shipping: const [
              ShippingOption(key: 'courier_guy', enabled: true, price: 70),
            ],
          ),
        ),
      ]);

      expect(groups[0].availableShippingOptions.map((o) => o.key), ['pargo']);
      expect(groups[1].availableShippingOptions.map((o) => o.key), [
        'courier_guy',
      ]);
    });
  });

  group('shopShippingCost', () {
    final group = groupCartItemsByShop([
      _line(
        _product(
          id: 'a1',
          shopId: 'clay',
          shipping: const [
            ShippingOption(key: 'pargo', enabled: true, price: 65),
          ],
        ),
        quantity: 2,
      ),
      _line(
        _product(
          id: 'a2',
          shopId: 'clay',
          shipping: const [
            ShippingOption(key: 'pargo', enabled: true, price: 80),
          ],
        ),
      ),
    ]).single;

    test('combined shipping charges the dearest item once', () {
      expect(
        shopShippingCost(
          group: group,
          methodKey: 'pargo',
          combinedShippingEnabled: true,
        ),
        80,
      );
    });

    test('without combined shipping every piece is charged', () {
      expect(
        shopShippingCost(
          group: group,
          methodKey: 'pargo',
          combinedShippingEnabled: false,
        ),
        65 * 2 + 80,
      );
    });

    test('Bob Go uses the chosen rate; nothing chosen costs nothing', () {
      expect(
        shopShippingCost(
          group: group,
          methodKey: bobGoShippingKey,
          combinedShippingEnabled: true,
          bobGoAmount: 95,
        ),
        95,
      );
      expect(
        shopShippingCost(
          group: group,
          methodKey: null,
          combinedShippingEnabled: true,
        ),
        0,
      );
      expect(
        shopShippingCost(
          group: group,
          methodKey: 'courier_guy',
          combinedShippingEnabled: true,
        ),
        0,
      );
    });
  });

  group('calculateShopTotals', () {
    final groups = groupCartItemsByShop([
      _line(_product(id: 'a1', shopId: 'clay', shopName: 'Clay', price: 200)),
      _line(_product(id: 'b1', shopId: 'weave', shopName: 'Weave', price: 300)),
    ]);

    test('adds shipping per shop and charges the gift fee per shop', () {
      final totals = calculateShopTotals(
        groups: groups,
        shippingByShop: const {'clay': 65, 'weave': 70},
        isGift: true,
      );

      expect(totals.shops.map((s) => s.total), [200 + 65 + 30, 300 + 70 + 30]);
      expect(totals.giftFee, 60);
      expect(totals.shippingCost, 135);
      expect(totals.total, 695);
    });

    test('a discount only lowers the shop that owns the code', () {
      final totals = calculateShopTotals(
        groups: groups,
        shippingByShop: const {'clay': 65, 'weave': 70},
        isGift: false,
        discountByShop: const {'weave': 50},
      );

      expect(totals.shops.first.total, 265);
      expect(totals.shops.last.total, 320);
      expect(totals.discountAmount, 50);
      expect(totals.total, 585);
    });
  });

  group('buildCheckoutRequestBody', () {
    const bobgo = BobGoSelection(
      quoteId: 'quote-1',
      rate: BobGoRate(
        rateResponseId: 7,
        providerSlug: 'sandbox',
        providerName: 'Sandbox',
        serviceLevelCode: 'ECO',
        serviceLevelName: 'Economy',
        amount: 95,
      ),
    );

    test('one shop keeps the top-level fields and also sends shops', () {
      final body = buildCheckoutRequestBody(
        userId: 'user-1',
        shops: const [
          CheckoutShopSelection(
            shopId: 'clay',
            shippingMethod: bobGoShippingKey,
            shippingCost: 95,
            bobgo: bobgo,
          ),
        ],
        isGift: true,
        giftRecipient: 'Thandi',
        giftMessage: 'Enjoy',
        couponCode: ' save10 ',
        shippingAddress: const {'name': 'Alicia'},
      );

      expect(body['shippingMethod'], bobGoShippingKey);
      expect(body['shippingCost'], 95);
      expect(body['bobgoQuoteId'], 'quote-1');
      expect(body['bobgoRateResponseId'], 7);
      expect(body['couponCode'], 'SAVE10');
      expect(body['giftRecipient'], 'Thandi');
      expect(body['shippingAddress'], {'name': 'Alicia'});
      expect(body.containsKey('previewOnly'), isFalse);
      expect(body['shops'], [
        {
          'shopId': 'clay',
          'shippingMethod': bobGoShippingKey,
          'shippingCost': 95,
          'bobgoQuoteId': 'quote-1',
          'bobgoRateResponseId': 7,
          'bobgoProviderSlug': 'sandbox',
          'bobgoServiceLevelCode': 'ECO',
        },
      ]);
    });

    test('several shops send each delivery choice in shops only', () {
      final body = buildCheckoutRequestBody(
        userId: 'user-1',
        shops: const [
          CheckoutShopSelection(
            shopId: 'clay',
            shippingMethod: 'pargo',
            shippingCost: 65,
            shippingAddress: {
              'pickup_point': {'carrier': 'pargo', 'code': 'P1'},
            },
          ),
          CheckoutShopSelection(
            shopId: 'weave',
            shippingMethod: 'courier_guy_door_to_door',
            shippingCost: 90,
          ),
        ],
        isGift: false,
        couponCode: '',
        previewOnly: true,
      );

      expect(body.containsKey('shippingMethod'), isFalse);
      expect(body.containsKey('shippingCost'), isFalse);
      expect(body.containsKey('giftRecipient'), isFalse);
      expect(body['couponCode'], isNull);
      expect(body['previewOnly'], isTrue);
      final shops = body['shops'] as List;
      expect(shops, hasLength(2));
      expect((shops.first as Map)['shippingAddress'], {
        'pickup_point': {'carrier': 'pargo', 'code': 'P1'},
      });
      expect((shops.last as Map).containsKey('shippingAddress'), isFalse);
      expect((shops.last as Map)['shippingMethod'], 'courier_guy_door_to_door');
    });

    test('needs at least one shop', () {
      expect(
        () => buildCheckoutRequestBody(
          userId: 'user-1',
          shops: const [],
          isGift: false,
        ),
        throwsArgumentError,
      );
    });
  });

  group('pickupPointForMethod', () {
    test('uses the chosen locker, Pargo point, market or typed entry', () {
      expect(
        pickupPointForMethod(
          method: 'courier_guy',
          courierGuyLocker: const {'code': 'L1'},
          pargoPoint: const {'code': 'P1'},
        ),
        {'code': 'L1'},
      );
      expect(
        pickupPointForMethod(
          method: 'pargo',
          courierGuyLocker: const {'code': 'L1'},
          pargoPoint: const {'code': 'P1'},
        ),
        {'code': 'P1'},
      );
      expect(
        pickupPointForMethod(
          method: 'market_pickup',
          marketOption: const ShippingOption(
            key: 'market_pickup',
            enabled: true,
            price: 0,
            marketName: 'Neighbourgoods',
            marketLocation: 'Braamfontein',
            marketProvince: 'Gauteng',
          ),
        ),
        {
          'carrier': 'market_pickup',
          'point_type': 'market',
          'name': 'Neighbourgoods',
          'address': 'Braamfontein',
          'province': 'Gauteng',
        },
      );
      expect(
        pickupPointForMethod(method: 'pargo', typedPickupPoint: ' Mall '),
        'Mall',
      );
      expect(pickupPointForMethod(method: 'courier_guy_door_to_door'), isNull);
    });
  });

  group('server responses', () {
    test('several-shop checkout session', () {
      final session = CheckoutSession.fromJson({
        'checkoutGroupId': 'group-1',
        'status': 'awaiting_payment',
        'orderId': 'o1',
        'orderIds': ['o1', 'o2'],
        'checkoutUrl': 'https://pay.example/deposit',
        'total': 701,
      });

      expect(session.isMultiShop, isTrue);
      expect(session.isFunded, isFalse);
      expect(session.orderIds, ['o1', 'o2']);
      expect(session.total, 701);
    });

    test('funded several-shop checkout has no payment page', () {
      final session = CheckoutSession.fromJson({
        'checkoutGroupId': 'group-1',
        'status': 'funded',
        'orderId': 'o1',
        'orderIds': ['o1', 'o2'],
        'checkoutUrl': null,
      });

      expect(session.isFunded, isTrue);
      expect(session.checkoutUrl, isNull);
    });

    test('one-shop checkout session is unchanged', () {
      final session = CheckoutSession.fromJson({
        'orderId': 'o1',
        'checkoutUrl': 'https://pay.example/checkout',
        'transactionId': 't1',
      });

      expect(session.isMultiShop, isFalse);
      expect(session.orderIds, ['o1']);
      expect(session.transactionId, 't1');
    });

    test('preview quote reads the per-shop breakdown', () {
      final quote = CheckoutQuote.fromJson({
        'preview': true,
        'couponCode': 'SAVE10',
        'subtotal': 500,
        'discountAmount': 30,
        'discountedSubtotal': 470,
        'shippingCost': 135,
        'giftFee': 0,
        'total': 605,
        'shops': [
          {
            'shopId': 'clay',
            'shopName': 'Clay Studio',
            'subtotal': 200,
            'discountAmount': 0,
            'shippingCost': 65,
            'giftFee': 0,
            'total': 265,
          },
          {
            'shopId': 'weave',
            'shopName': 'Weave Co',
            'subtotal': 300,
            'discountAmount': 30,
            'shippingCost': 70,
            'giftFee': 0,
            'total': 340,
          },
        ],
      });

      expect(quote.shops, hasLength(2));
      expect(quote.shops.last.shopName, 'Weave Co');
      expect(quote.discountByShop, {'weave': 30});
    });

    test('checkout group status and outcomes', () {
      final status = CheckoutGroupStatus.fromJson({
        'checkoutGroupId': 'group-1',
        'status': 'cancelled',
        'orderIds': ['o1', 'o2'],
        'paidOrderIds': <String>[],
        'checkoutUrl': '',
      });

      expect(status.isCancelled, isTrue);
      expect(status.checkoutUrl, isNull);
      expect(checkoutGroupOutcome(status.status), CheckoutGroupOutcome.expired);
      expect(checkoutGroupOutcome('funded'), CheckoutGroupOutcome.paid);
      expect(
        checkoutGroupOutcome('needs_attention'),
        CheckoutGroupOutcome.needsHelp,
      );
      expect(
        checkoutGroupOutcome('awaiting_payment'),
        CheckoutGroupOutcome.waiting,
      );
      expect(
        checkoutGroupProblemMessage(CheckoutGroupOutcome.expired),
        contains('TradeSafe wallet'),
      );
      expect(checkoutGroupProblemMessage(CheckoutGroupOutcome.paid), isNull);
    });
  });

  group('CheckoutScreen with several shops', () {
    setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

    testWidgets('shows delivery per shop and per-shop totals', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cartItemsProvider.overrideWith(
              (ref) async => [
                _line(
                  _product(
                    id: 'a1',
                    shopId: 'clay',
                    shopName: 'Clay Studio',
                    price: 200,
                  ),
                ),
                _line(
                  _product(
                    id: 'b1',
                    shopId: 'weave',
                    shopName: 'Weave Co',
                    price: 300,
                    shipping: const [
                      ShippingOption(
                        key: 'courier_guy',
                        enabled: true,
                        price: 70,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            shopDetailProvider.overrideWith(
              (ref, id) async => throw StateError('offline'),
            ),
            bobGoGatewayProvider.overrideWithValue(_FakeGateway()),
          ],
          child: const MaterialApp(home: CheckoutScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Delivery'), findsOneWidget);
      expect(find.text('Delivery from Clay Studio'), findsOneWidget);
      expect(find.text('Delivery from Weave Co'), findsOneWidget);
      // Each shop offers its own option; nothing blocks the mixed basket.
      expect(find.text('Pargo'), findsOneWidget);
      expect(find.text('Pudo Locker (Courier Guy)'), findsOneWidget);
      expect(find.text('Shop total'), findsNWidgets(2));
      // 200 + 65 and 300 + 70.
      expect(find.text('R265'), findsOneWidget);
      expect(find.text('R370'), findsOneWidget);
      expect(find.text('R635'), findsWidgets);
    });
  });
}
