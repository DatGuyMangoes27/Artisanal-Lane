import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:artisanal_lane/features/auth/providers/auth_providers.dart';
import 'package:artisanal_lane/features/vendor/screens/listing_assistant_screen.dart';
import 'package:artisanal_lane/features/vendor/services/artisan_ai_service.dart';
import 'package:artisanal_lane/features/vendor/widgets/studio/compare_slider.dart';
import 'package:artisanal_lane/features/vendor/widgets/studio/look_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

final _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

class FakeAi implements ArtisanAiService {
  FakeAi({this.enabled = true});
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  final bool enabled;
  final requests = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>> capabilities() async => {
    'listing': enabled,
    'image': enabled,
  };
  @override
  Future<Map<String, dynamic>> generate(Map<String, dynamic> request) async {
    requests.add(Map.of(request));
    return request['operation'] == 'image'
        ? {'image_path': 'user/result.png'}
        : {'title': 'Handmade bowl', 'description': 'Made by hand.'};
  }

  @override
  Future<Uint8List> download(String path) async => _pixel;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<Directory> tempDirWithTearDown(WidgetTester tester) async {
    final directory = Directory.systemTemp.createTempSync('ux-studio-test');
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
    return directory;
  }

  Future<void> open(
    WidgetTester tester,
    FakeAi service, {
    required File photo,
    List<String> candidateTags = const [],
    List<String> existingTags = const [],
    String? category,
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
                            category: category,
                            existingTags: existingTags,
                            candidateTags: candidateTags,
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
    await tester.tap(find.text('Photos'));
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('photo tools expose straighten, brightness and warmth sliders '
      'that start at rest and reset clears them', (tester) async {
    final directory = await tempDirWithTearDown(tester);
    final file = File('${directory.path}/original.png')
      ..writeAsBytesSync(_pixel);
    await open(tester, FakeAi(), photo: file);

    expect(find.text('Straighten'), findsOneWidget);
    expect(find.text('Brightness'), findsOneWidget);
    expect(find.text('Warmth'), findsOneWidget);
    final sliders = find.byType(Slider);
    expect(sliders, findsNWidgets(3));

    // Nothing edited yet: save is disabled, reset is disabled.
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Save edited photo'),
          )
          .onPressed,
      isNull,
    );
    final resetButton = find.widgetWithIcon(IconButton, Icons.restart_alt);
    expect(tester.widget<IconButton>(resetButton).onPressed, isNull);

    // Move the brightness slider.
    final brightnessSlider = tester.widget<Slider>(sliders.at(1));
    brightnessSlider.onChanged!(.2);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Save edited photo'),
          )
          .onPressed,
      isNotNull,
    );
    expect(tester.widget<IconButton>(resetButton).onPressed, isNotNull);

    await tapVisible(tester, resetButton);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Save edited photo'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets(
    'saving an edited photo appends it via the results contract without '
    'touching the original file',
    (tester) async {
      final directory = await tempDirWithTearDown(tester);
      final file = File('${directory.path}/original.png')
        ..writeAsBytesSync(_pixel);
      List<ListingAssistantResult>? result;
      await open(tester, FakeAi(), photo: file, result: (r) => result = r);

      final warmthSlider = tester.widget<Slider>(find.byType(Slider).at(2));
      warmthSlider.onChanged!(.15);
      await tester.pumpAndSettle();

      final saveButton = find.widgetWithText(FilledButton, 'Save edited photo');
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(saveButton, warnIfMissed: false);
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(FilledButton, 'Edited photo saved ✓'),
        findsOneWidget,
      );
      expect(file.readAsBytesSync(), _pixel); // original untouched
      expect(result, isNull); // not returned until Done is tapped

      await tapVisible(tester, find.text('Done (1)'));
      expect(result, hasLength(1));
      expect(result!.single.photo, isNotNull);
      expect(result!.single.photo, isNot(equals(_pixel)));
    },
  );

  testWidgets('before/after compare appears once a photo is chosen and '
      'each side can be enlarged', (tester) async {
    final directory = await tempDirWithTearDown(tester);
    final file = File('${directory.path}/original.png')
      ..writeAsBytesSync(_pixel);
    await open(tester, FakeAi(), photo: file);

    expect(find.text('Before & after'), findsOneWidget);
    final compareFinder = find.byType(BeforeAfterCompare);
    expect(compareFinder, findsOneWidget);

    // Exercise the enlarge callbacks the compare widget was wired with
    // (the same viewer `_enlarge` opens for every other studio photo).
    final compare = tester.widget<BeforeAfterCompare>(compareFinder);
    expect(compare.onTapBefore, isNotNull);
    expect(compare.onTapAfter, isNotNull);
    compare.onTapBefore!();
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await tester.tap(find.byTooltip('Close photo'));
    await tester.pumpAndSettle();
  });

  testWidgets('four store looks are offered and disabled with a friendly '
      'note when AI is unavailable', (tester) async {
    final directory = await tempDirWithTearDown(tester);
    final file = File('${directory.path}/original.png')
      ..writeAsBytesSync(_pixel);
    await open(tester, FakeAi(enabled: false), photo: file);

    expect(find.byType(StudioLookCard), findsNWidgets(4));
    expect(find.text('Warm studio'), findsOneWidget);
    expect(find.text('Natural linen'), findsOneWidget);
    expect(find.text('Clean ivory'), findsOneWidget);
    expect(find.text('Deep earth'), findsOneWidget);
    expect(
      find.textContaining("aren't available on your account yet"),
      findsWidgets,
    );

    final card = tester.widget<StudioLookCard>(
      find.widgetWithText(StudioLookCard, 'Deep earth'),
    );
    expect(card.enabled, isFalse);
    expect(card.onTap, isNotNull); // callback exists, gating is via enabled
  });

  testWidgets('suggested tags are local, deterministic, toggleable and '
      'apply through the existing multi-apply contract', (tester) async {
    final directory = await tempDirWithTearDown(tester);
    final file = File('${directory.path}/original.png')
      ..writeAsBytesSync(_pixel);
    List<ListingAssistantResult>? result;
    await open(
      tester,
      FakeAi(enabled: false),
      photo: file,
      category: 'Home',
      candidateTags: const ['pottery', 'woodwork', 'textile'],
      result: (r) => result = r,
    );
    await tester.tap(find.text('Words'));
    await tester.pumpAndSettle();

    expect(find.text('Suggestions'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'pottery'), findsOneWidget);

    // Nothing selected yet.
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Add selected tags'),
          )
          .onPressed,
      isNull,
    );

    await tapVisible(tester, find.widgetWithText(FilterChip, 'pottery'));
    await tapVisible(tester, find.text('Add selected tags'));
    expect(result, isNull);
    await tapVisible(tester, find.text('Done (1)'));
    expect(result, hasLength(1));
    expect(result!.single.tags, contains('pottery'));
  });
}
