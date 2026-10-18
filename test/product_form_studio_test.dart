import 'dart:typed_data';

import 'package:artisanal_lane/features/auth/providers/auth_providers.dart';
import 'package:artisanal_lane/features/vendor/providers/vendor_providers.dart';
import 'package:artisanal_lane/features/vendor/screens/product_form_screen.dart';
import 'package:artisanal_lane/features/vendor/services/artisan_ai_service.dart';
import 'package:artisanal_lane/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoAi implements ArtisanAiService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<Map<String, dynamic>> capabilities() async => {
    'listing': false,
    'image': false,
  };
  @override
  Future<Map<String, dynamic>> generate(Map<String, dynamic> request) =>
      throw UnimplementedError('AI must not be called');
  @override
  Future<Uint8List> download(String path) =>
      throw UnimplementedError('AI must not be called');
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'listing_studio_tip_dismissed_v1': true,
    }),
  );

  final now = DateTime.now();
  final subscription = VendorSubscription(
    vendorId: 'vendor-1',
    planCode: 'artisan',
    amount: 199,
    currency: 'ZAR',
    status: 'active',
    currentPeriodEnd: now.add(const Duration(days: 20)),
    createdAt: now,
    updatedAt: now,
  );
  final payout = VendorPayoutProfile(
    vendorId: 'vendor-1',
    accountHolderName: 'Test Maker',
    bankName: 'Test Bank',
    accountNumber: '000000',
    branchCode: '000',
    accountType: 'cheque',
    registeredPhone: '0000000000',
    registeredEmail: 'maker@example.test',
    identityNumber: '0000000000000',
    verificationStatus: 'verified',
    createdAt: now,
    updatedAt: now,
  );
  final shop = Shop(
    id: 'shop-1',
    vendorId: 'vendor-1',
    name: 'Test Shop',
    slug: 'test-shop',
    createdAt: now,
    updatedAt: now,
  );

  testWidgets('Listing Studio opens from the photo area and its price comes '
      'back into the product form', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        retry: (_, __) => null,
        overrides: [
          currentUserIdProvider.overrideWithValue('vendor-1'),
          vendorShopProvider.overrideWith((ref) async => shop),
          vendorSubscriptionProvider.overrideWith((ref) async => subscription),
          vendorSubscriptionStreamProvider.overrideWith(
            (ref) => Stream.value(subscription),
          ),
          vendorPayoutProfileProvider.overrideWith((ref) async => payout),
          vendorPayoutProfileStreamProvider.overrideWith(
            (ref) => Stream.value(payout),
          ),
          vendorCategoriesProvider.overrideWith(
            (ref) async => const <Category>[],
          ),
          artisanAiServiceProvider.overrideWithValue(_NoAi()),
        ],
        child: const MaterialApp(home: ProductFormScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final entry = find.byKey(const Key('open-listing-studio'));
    expect(entry, findsOneWidget);
    expect(
      find.text('Touch up your photos and work out a fair price.'),
      findsOneWidget,
    );
    // Old, confusing entry is gone.
    expect(find.text('Make it listing-ready'), findsNothing);

    await tester.ensureVisible(entry);
    await tester.pumpAndSettle();
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Listing Studio'), findsOneWidget);
    expect(find.textContaining('AI'), findsNothing);

    await tester.tap(find.text('Price calculator'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Materials'), '60');
    await tester.enterText(find.widgetWithText(TextField, 'Your time'), '30');
    await tester.enterText(
      find.widgetWithText(TextField, 'Packaging & other costs'),
      '10',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Margin'), '50');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use R200.00 as my price'));
    await tester.pumpAndSettle();

    // Back on the form with the price filled in and a confirmation.
    expect(find.widgetWithText(AppBar, 'Listing Studio'), findsNothing);
    expect(find.text('Price set to R200.00.'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is EditableText && w.controller.text == '200.00',
      ),
      findsOneWidget,
    );
  });
}
