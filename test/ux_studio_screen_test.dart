import 'dart:convert';
import 'dart:typed_data';

import 'package:artisanal_lane/features/auth/providers/auth_providers.dart';
import 'package:artisanal_lane/features/vendor/screens/listing_assistant_screen.dart';
import 'package:artisanal_lane/features/vendor/services/artisan_ai_service.dart';
import 'package:artisanal_lane/features/vendor/widgets/studio/compare_slider.dart';
import 'package:artisanal_lane/features/vendor/widgets/studio/look_card.dart';
import 'package:artisanal_lane/features/vendor/widgets/studio/photo_adjustments.dart';
import 'package:artisanal_lane/features/vendor/widgets/studio/studio_photo_source.dart';
import 'package:artisanal_lane/features/vendor/widgets/studio/studio_photo_tool.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

class FakeAi implements ArtisanAiService {
  FakeAi({this.enabled = false});
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
    return {'image_path': 'user/result.png'};
  }

  @override
  Future<Uint8List> download(String path) async => _pixel;
}

StudioPhotoSource _source(String id) => StudioPhotoSource(
  id: id,
  thumbnail: MemoryImage(_pixel),
  loadBytes: () async => Uint8List.fromList(_pixel),
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  final renders = <({double rotation, double brightness, double warmth})>[];
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'listing_studio_tip_dismissed_v1': true,
    });
    renders.clear();
    // Real decoding/rendering needs the real event loop; renderStudioPhoto
    // is covered by ux_studio_helpers_test.dart.
    studioPhotoAspectReader = (_) async => 1;
    studioPhotoRenderer =
        (
          bytes, {
          required rotationDegrees,
          required brightness,
          required warmth,
        }) async {
          renders.add((
            rotation: rotationDegrees,
            brightness: brightness,
            warmth: warmth,
          ));
          return Uint8List.fromList([...bytes, 1]);
        };
  });

  Future<void> open(
    WidgetTester tester,
    FakeAi service, {
    List<StudioPhotoSource>? photos,
    int initialPhotoIndex = 0,
    ValueChanged<ListingAssistantResult?>? result,
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
                        photos: photos ?? [_source('1'), _source('2')],
                        initialPhotoIndex: initialPhotoIndex,
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
    await tester.pumpAndSettle();

  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('photo tool offers rotate, straighten, brightness and warmth '
      'with before/after, and save needs an edit', (tester) async {
    await open(tester, FakeAi());

    expect(find.byType(BeforeAfterCompare), findsOneWidget);
    expect(find.text('Rotate 90°'), findsOneWidget);
    expect(find.text('Straighten'), findsOneWidget);
    expect(find.text('Brightness'), findsOneWidget);
    expect(find.text('Warmth'), findsOneWidget);
    expect(find.byType(Slider), findsNWidgets(3));
    expect(find.text('Make an adjustment to save'), findsOneWidget);

    tester.widget<Slider>(find.byType(Slider).at(1)).onChanged!(.1);
    await tester.pumpAndSettle();
    expect(find.text('Save photo to listing'), findsOneWidget);
    expect(find.text('+40'), findsOneWidget);

    await tapVisible(tester, find.text('Reset'));
    expect(find.text('Make an adjustment to save'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saving returns new bytes tagged with the photo they replace', (
    tester,
  ) async {
    ListingAssistantResult? result;
    await open(
      tester,
      FakeAi(),
      initialPhotoIndex: 1,
      result: (r) => result = r,
    );

    await tapVisible(tester, find.text('Rotate 90°'));
    tester.widget<Slider>(find.byType(Slider).at(2)).onChanged!(.15);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save photo to listing'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.replacesPhotoId, '2');
    expect(result!.photo, isNotNull);
    expect(result!.photo, isNot(equals(_pixel)));
    expect(result!.price, isNull);
    expect(renders.single.rotation, 90);
    expect(renders.single.warmth, .15);
  });

  testWidgets('choosing another listing photo resets the edits', (
    tester,
  ) async {
    await open(tester, FakeAi());
    tester.widget<Slider>(find.byType(Slider).first).onChanged!(5);
    await tester.pumpAndSettle();
    expect(find.text('5°'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Photo 2'));
    await tester.pumpAndSettle();

    expect(find.text('0°'), findsOneWidget);
    expect(find.text('Make an adjustment to save'), findsOneWidget);
  });

  testWidgets('before/after sides can be enlarged', (tester) async {
    await open(tester, FakeAi());
    final compare = tester.widget<BeforeAfterCompare>(
      find.byType(BeforeAfterCompare),
    );
    compare.onTapAfter!();
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await tester.tap(find.byTooltip('Close photo'));
    await tester.pumpAndSettle();
  });

  testWidgets('no photos: a friendly empty state instead of tools', (
    tester,
  ) async {
    await open(tester, FakeAi(), photos: const []);
    expect(find.byKey(const Key('studio-photo-empty')), findsOneWidget);
    expect(find.text('Choose a photo'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('small phone: photo tool has no overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await open(tester, FakeAi(enabled: true));
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -1500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('AI styled photo only exists when enabled, and adds a new photo', (
    tester,
  ) async {
    ListingAssistantResult? result;
    await open(tester, FakeAi(enabled: true), result: (r) => result = r);
    await tapVisible(tester, find.text('AI styled photo'));
    expect(find.byType(StudioLookCard), findsNWidgets(4));
    await tapVisible(tester, find.byType(CheckboxListTile));
    await tester.tap(find.byKey(const Key('studio-ai-photo')));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Add styled photo to listing'));
    expect(result?.photo, _pixel);
    expect(result?.replacesPhotoId, isNull);
  });

  group('placeStudioPhoto', () {
    test('replaces the source photo in place', () {
      final placed = placeStudioPhoto<String>(
        ['a', 'b', 'c'],
        edited: 'b2',
        isSource: (p) => p == 'b',
      );
      expect(placed, ['a', 'b2', 'c']);
    });

    test('appends when there is no source, up to the limit', () {
      expect(
        placeStudioPhoto<String>(['a'], edited: 'new', isSource: (_) => false),
        ['a', 'new'],
      );
      expect(
        placeStudioPhoto<String>(
          List.generate(8, (i) => '$i'),
          edited: 'new',
          isSource: (_) => false,
        ),
        isNull,
      );
    });
  });

  group('straighten maths', () {
    test('no rotation needs no enlargement', () {
      expect(studioStraightenScale(100, 100, 0), 1);
    });

    test('a tilted square is enlarged to fill its frame', () {
      final scale = studioStraightenScale(100, 100, 10);
      expect(scale, greaterThan(1.1));
      expect(scale, lessThan(1.2));
    });

    test('splits quarter turns from the straighten angle', () {
      final split = splitStudioRotation(90 + 7);
      expect(split.quarterTurns, 1);
      expect(split.straighten, closeTo(7, 1e-9));
      expect(splitStudioRotation(270 - 5).quarterTurns, 3);
    });
  });
}
