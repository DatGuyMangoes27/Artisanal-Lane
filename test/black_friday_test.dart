// Black Friday: on-sale pieces get the sticker from 27 Nov 00:00 until
// 1 Dec 00:00 South African time, and only then.
import 'package:artisanal_lane/core/promotions/black_friday.dart';
import 'package:artisanal_lane/widgets/black_friday_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

Widget _host(DateTime now, Widget child) => ProviderScope(
  overrides: [clockProvider.overrideWithValue(() => now)],
  child: MaterialApp(
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('window runs 27 Nov 00:00 to 1 Dec 00:00 SAST', () {
    expect(
      blackFridayActiveAt(DateTime.utc(2026, 11, 26, 21, 59, 59)),
      isFalse,
    );
    expect(blackFridayActiveAt(DateTime.utc(2026, 11, 26, 22)), isTrue);
    expect(blackFridayActiveAt(DateTime.utc(2026, 11, 30, 21, 59, 59)), isTrue);
    expect(blackFridayActiveAt(DateTime.utc(2026, 11, 30, 22)), isFalse);
  });

  const saleBadge = Text('Sale');

  testWidgets('sale badge becomes the Black Friday sticker during the window', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        DateTime.utc(2026, 11, 28, 10),
        const SaleOrBlackFridayBadge(child: saleBadge),
      ),
    );
    expect(find.byKey(const Key('black-friday-sticker')), findsOneWidget);
    expect(find.text('Sale'), findsNothing);
  });

  testWidgets('outside the window everything stays as normal', (tester) async {
    await tester.pumpWidget(
      _host(
        DateTime.utc(2026, 12, 1, 9),
        const Column(
          children: [
            SaleOrBlackFridayBadge(child: saleBadge),
            BlackFridayBanner(),
            BlackFridayTag(onSale: true),
          ],
        ),
      ),
    );
    expect(find.text('Sale'), findsOneWidget);
    expect(find.byKey(const Key('black-friday-sticker')), findsNothing);
    expect(find.byKey(const Key('black-friday-banner')), findsNothing);
  });

  testWidgets('banner shows during the window; tag only for sale pieces', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        DateTime.utc(2026, 11, 27, 6),
        const Column(
          children: [BlackFridayBanner(), BlackFridayTag(onSale: false)],
        ),
      ),
    );
    expect(find.text('Black Friday Specials Now Live'), findsOneWidget);
    // The banner carries one sticker; the not-on-sale tag adds none.
    expect(find.byKey(const Key('black-friday-sticker')), findsOneWidget);
  });
}
