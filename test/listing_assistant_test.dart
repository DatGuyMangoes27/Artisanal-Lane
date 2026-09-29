import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:artisanal_lane/features/auth/providers/auth_providers.dart';
import 'package:artisanal_lane/features/vendor/screens/listing_assistant_screen.dart';
import 'package:artisanal_lane/features/vendor/services/artisan_ai_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

final pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

class FakeAi implements ArtisanAiService {
  FakeAi({this.enabled = true, this.failFirst = false});
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  final bool enabled, failFirst;
  final requests = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>> capabilities() async => {
    'listing': enabled,
    'image': enabled,
  };
  @override
  Future<Map<String, dynamic>> generate(Map<String, dynamic> request) async {
    requests.add(Map.of(request));
    if (failFirst && requests.length == 1) {
      throw const ArtisanAiException('pending');
    }
    return request['operation'] == 'image'
        ? {'image_path': 'user/result.png'}
        : {
            'title': 'Handmade blue bowl',
            'description': 'A blue ceramic bowl, made by hand.',
          };
  }

  @override
  Future<Uint8List> download(String path) async => pixel;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  Future<void> open(
    WidgetTester tester,
    FakeAi service, {
    File? photo,
    ValueChanged<List<ListingAssistantResult>?>? result,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('user'),
          artisanAiServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  final value =
                      await Navigator.push<List<ListingAssistantResult>>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ListingAssistantScreen(
                            shopId: 'shop',
                            title: 'Blue ceramic bowl',
                            description: 'Made by hand.',
                            photo: photo,
                          ),
                        ),
                      );
                  result?.call(value);
                },
                child: const Text('Open editor help'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open editor help'));
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  test('pricing is transparent gross margin and rejects invalid costs', () {
    expect(
      suggestedListingPrice(
        materials: 60,
        labour: 30,
        overheads: 10,
        margin: 50,
      ),
      200,
    );
    expect(
      suggestedListingPrice(
        materials: 60,
        labour: 30,
        overheads: 10,
        margin: 0,
      ),
      100,
    );
    for (final margin in [-1.0, 100.0, double.nan, double.infinity]) {
      expect(
        suggestedListingPrice(
          materials: 60,
          labour: 30,
          overheads: 10,
          margin: margin,
        ),
        isNull,
      );
    }
    expect(
      suggestedListingPrice(
        materials: -1,
        labour: 30,
        overheads: 10,
        margin: 20,
      ),
      isNull,
    );
  });
  testWidgets('unconfigured AI does not pretend to generate', (tester) async {
    final ai = FakeAi(enabled: false);
    await open(tester, ai);
    expect(
      find.textContaining("aren't available on your account yet"),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Suggest title & description'),
          )
          .onPressed,
      isNull,
    );
    expect(ai.requests, isEmpty);
  });
  testWidgets('wording needs consent, supports edits, and applies explicitly', (
    tester,
  ) async {
    final ai = FakeAi();
    List<ListingAssistantResult>? result;
    await open(tester, ai, result: (r) => result = r);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Suggest title & description'),
          )
          .onPressed,
      isNull,
    );
    await tapVisible(tester, find.byType(CheckboxListTile).first);
    await tapVisible(tester, find.text('Suggest title & description'));
    expect(result, isNull);
    expect(ai.requests.length, 1);
    final title = find.widgetWithText(TextField, 'Suggested title');
    await tester.ensureVisible(title);
    await tester.enterText(title, 'My approved bowl');
    await tapVisible(tester, find.text('Use this wording'));
    expect(result, isNull);
    await tapVisible(tester, find.text('Done (1)'));
    expect(result, hasLength(1));
    expect(result!.single.title, 'My approved bowl');
  });
  testWidgets('uncertain requests keep the same ID and facts on retry', (
    tester,
  ) async {
    final ai = FakeAi(failFirst: true);
    await open(tester, ai);
    await tapVisible(tester, find.byType(CheckboxListTile).first);
    await tapVisible(tester, find.text('Suggest title & description'));
    expect(find.text('Check existing result'), findsOneWidget);
    await tapVisible(tester, find.text('Check existing result'));
    expect(ai.requests.length, 2);
    expect(ai.requests[0], ai.requests[1]);
  });
  testWidgets(
    'pricing works offline on a small phone and applies only on confirmation',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      List<ListingAssistantResult>? result;
      await open(tester, FakeAi(enabled: false), result: (r) => result = r);
      await tester.tap(find.text('Pricing'));
      await tester.pumpAndSettle();
      for (final entry in {
        'Materials per item (R)': '60',
        'Labour per item (R)': '30',
        'Packaging & other costs (R)': '10',
        'Target gross margin (%)': '50',
      }.entries) {
        final field = find.widgetWithText(TextField, entry.key);
        await tester.ensureVisible(field);
        await tester.enterText(field, entry.value);
      }
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(tester.takeException(), isNull);
      await tapVisible(tester, find.text('Use this price'));
      expect(result, isNull);
      await tapVisible(tester, find.text('Done (1)'));
      expect(result!.single.price, 200);
    },
  );
  testWidgets('original and generated photos enlarge and apply separately', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync('artisan-photo-test');
    addTearDown(() async {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      await tester.runAsync(() async {
        for (var attempt = 0; attempt < 5; attempt++) {
          try {
            await directory.delete(recursive: true);
            return;
          } on FileSystemException {
            if (attempt == 4) rethrow;
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }
        }
      });
    });
    final file = File('${directory.path}/original.png')
      ..writeAsBytesSync(pixel);
    final ai = FakeAi();
    List<ListingAssistantResult>? result;
    await open(tester, ai, photo: file, result: (r) => result = r);
    await tester.tap(find.text('Photos'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byType(CheckboxListTile).last);
    await tester.ensureVisible(find.text('Create styled photo'));
    await tester.runAsync(() async {
      await tester.tap(find.text('Create styled photo'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(file.readAsBytesSync(), pixel);
    await tapVisible(
      tester,
      find.bySemanticsLabel('Enlarge AI-styled result · tap to inspect'),
    );
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await tester.tap(find.byTooltip('Close photo'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Add result to listing'));
    expect(result, isNull);
    await tapVisible(tester, find.text('Done (1)'));
    expect(result!.single.photo, pixel);
  });
}
