import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:artisanal_lane/features/auth/providers/auth_providers.dart';
import 'package:artisanal_lane/features/vendor/screens/listing_assistant_screen.dart';
import 'package:artisanal_lane/features/vendor/services/artisan_ai_service.dart';
import 'package:artisanal_lane/features/vendor/widgets/composer/composer_ai_caption_button.dart';
import 'package:artisanal_lane/features/vendor/widgets/studio/studio_tip_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

final pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

/// Capability modes for [FakeAi].
enum Caps { enabled, disabled, failing, pending }

class FakeAi implements ArtisanAiService {
  FakeAi(this.caps, {this.failFirst = false});
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  final Caps caps;
  final bool failFirst;
  final requests = <Map<String, dynamic>>[];
  final _never = Completer<Map<String, dynamic>>();

  @override
  Future<Map<String, dynamic>> capabilities() async => switch (caps) {
    Caps.enabled => {'listing': true, 'image': true},
    Caps.disabled => {'listing': false, 'image': false},
    Caps.failing => throw const ArtisanAiException('unavailable'),
    Caps.pending => _never.future,
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
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> open(
    WidgetTester tester,
    FakeAi service, {
    ValueChanged<ListingAssistantResult?>? result,
    StudioTool initialTool = StudioTool.photo,
    bool settle = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, __) => null,
        overrides: [
          currentUserIdProvider.overrideWithValue('user'),
          artisanAiServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  final value = await Navigator.push<ListingAssistantResult>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ListingAssistantScreen(
                        shopId: 'shop',
                        title: 'Blue ceramic bowl',
                        description: 'Made by hand.',
                        initialTool: initialTool,
                      ),
                    ),
                  );
                  result?.call(value);
                },
                child: const Text('Open studio'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open studio'));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  void expectNoAiUi() {
    expect(find.text('AI listing text'), findsNothing);
    expect(find.text('AI styled photo'), findsNothing);
    expect(find.textContaining('AI'), findsNothing);
    expect(find.textContaining('OpenAI'), findsNothing);
    expect(find.textContaining('available'), findsNothing);
    expect(find.textContaining('coming soon'), findsNothing);
  }

  group('suggestedListingPrice', () {
    test('is transparent gross margin and rejects invalid costs', () {
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
  });

  group('AI gating', () {
    for (final caps in [Caps.disabled, Caps.failing]) {
      testWidgets('capabilities ${caps.name}: studio shows only the photo and '
          'price tools and no AI wording at all', (tester) async {
        final ai = FakeAi(caps);
        await open(tester, ai);
        expect(find.text('Listing Studio'), findsOneWidget);
        expect(find.text('Photo touch-up'), findsWidgets);
        expect(find.text('Price calculator'), findsOneWidget);
        expectNoAiUi();

        await tapVisible(tester, find.text('Price calculator'));
        expectNoAiUi();
        expect(ai.requests, isEmpty);
      });
    }

    testWidgets('while capabilities are still loading no AI UI flashes', (
      tester,
    ) async {
      await open(tester, FakeAi(Caps.pending));
      expectNoAiUi();
      await tester.pump(const Duration(seconds: 5));
      expectNoAiUi();
    });

    testWidgets('enabled: AI tools appear and listing text applies only when '
        'used', (tester) async {
      final ai = FakeAi(Caps.enabled);
      ListingAssistantResult? result;
      await open(tester, ai, result: (r) => result = r);
      expect(find.text('AI listing text'), findsOneWidget);
      expect(find.text('AI styled photo'), findsOneWidget);

      await tapVisible(tester, find.text('AI listing text'));
      final write = find.byKey(const Key('studio-ai-write'));
      expect(tester.widget<FilledButton>(write).onPressed, isNull);
      await tapVisible(tester, find.byType(CheckboxListTile));
      await tapVisible(tester, write);
      expect(ai.requests, hasLength(1));
      expect(result, isNull);

      final title = find.widgetWithText(TextField, 'Suggested title');
      await tester.ensureVisible(title);
      await tester.enterText(title, 'My approved bowl');
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Use this wording'));
      expect(result?.title, 'My approved bowl');
      expect(result?.description, 'A blue ceramic bowl, made by hand.');
    });

    testWidgets('an uncertain AI request keeps the same id on re-check', (
      tester,
    ) async {
      final ai = FakeAi(Caps.enabled, failFirst: true);
      await open(tester, ai, initialTool: StudioTool.aiWriting);
      await tapVisible(tester, find.byType(CheckboxListTile));
      await tapVisible(tester, find.byKey(const Key('studio-ai-write')));
      expect(find.text('Check for my result'), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('studio-ai-write')));
      expect(ai.requests, hasLength(2));
      expect(ai.requests[0], ai.requests[1]);
    });
  });

  group('price calculator', () {
    testWidgets('works offline on a small phone and returns the price', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      ListingAssistantResult? result;
      await open(
        tester,
        FakeAi(Caps.disabled),
        result: (r) => result = r,
        initialTool: StudioTool.price,
      );
      expect(find.byKey(const Key('studio-price-empty')), findsOneWidget);
      expect(find.textContaining('cost-based guide'), findsOneWidget);

      for (final entry in {
        'Materials': '60',
        'Your time': '30',
        'Packaging & other costs': '10',
      }.entries) {
        final field = find.widgetWithText(TextField, entry.key);
        await tester.ensureVisible(field);
        await tester.enterText(field, entry.value);
      }
      // Done on the keyboard, then pick a margin preset.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('50%'));
      expect(find.byKey(const Key('studio-price-result')), findsOneWidget);
      expect(find.text('R200.00'), findsOneWidget);
      expect(find.text('Your margin (50%)'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(result, isNull);

      await tapVisible(tester, find.text('Use R200.00 as my price'));
      expect(result?.price, 200);
      expect(result?.photo, isNull);
    });

    testWidgets('invalid margin keeps the action disabled', (tester) async {
      await open(tester, FakeAi(Caps.disabled), initialTool: StudioTool.price);
      await tester.enterText(find.widgetWithText(TextField, 'Materials'), '10');
      await tester.enterText(find.widgetWithText(TextField, 'Your time'), '0');
      await tester.enterText(
        find.widgetWithText(TextField, 'Packaging & other costs'),
        '0',
      );
      await tester.enterText(find.widgetWithText(TextField, 'Margin'), '100');
      await tester.pumpAndSettle();
      expect(find.text('Enter your costs'), findsOneWidget);
    });
  });

  group('first-run tip', () {
    testWidgets('shows once, and stays dismissed', (tester) async {
      await open(tester, FakeAi(Caps.disabled));
      expect(find.byKey(const Key('studio-tip')), findsOneWidget);
      await tapVisible(tester, find.byTooltip('Got it'));
      expect(find.byKey(const Key('studio-tip')), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(listingStudioTipDismissedKey), isTrue);

      await tapVisible(tester, find.byTooltip('Back to your listing'));
      await tapVisible(tester, find.text('Open studio'));
      expect(find.text('Listing Studio'), findsOneWidget);
      expect(find.byKey(const Key('studio-tip')), findsNothing);
    });
  });

  group('composer AI caption button', () {
    Future<void> pumpButton(WidgetTester tester, FakeAi ai) async {
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, __) => null,
          overrides: [
            currentUserIdProvider.overrideWithValue('user'),
            artisanAiServiceProvider.overrideWithValue(ai),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ComposerAiCaptionButton(
                shopId: 'shop',
                captionController: TextEditingController(text: 'My bowl'),
              ),
            ),
          ),
        ),
      );
    }

    for (final caps in [Caps.disabled, Caps.failing, Caps.pending]) {
      testWidgets('renders nothing when capabilities are ${caps.name}', (
        tester,
      ) async {
        await pumpButton(tester, FakeAi(caps));
        expect(find.byKey(const Key('composer-polish-ai')), findsNothing);
        await tester.pump(const Duration(seconds: 1));
        expect(find.byKey(const Key('composer-polish-ai')), findsNothing);
        expect(find.textContaining('AI'), findsNothing);
      });
    }

    testWidgets('renders and polishes when AI listing is enabled', (
      tester,
    ) async {
      final ai = FakeAi(Caps.enabled);
      await pumpButton(tester, ai);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('composer-polish-ai')), findsOneWidget);
      await tester.tap(find.byKey(const Key('composer-polish-ai')));
      await tester.pumpAndSettle();
      expect(ai.requests, hasLength(1));
    });
  });
}
