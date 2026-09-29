import 'dart:convert';
import 'dart:typed_data';
import 'package:artisanal_lane/features/auth/providers/auth_providers.dart';
import 'package:artisanal_lane/features/buyer/providers/story_providers.dart';
import 'package:artisanal_lane/features/buyer/screens/story_viewer_screen.dart';
import 'package:artisanal_lane/features/buyer/widgets/creator_story_rail.dart';
import 'package:artisanal_lane/models/shop_story.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeStories implements StoryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  final viewed = <String>[];
  final requested = <String>[];
  @override
  Future<Uint8List> media(ShopStory story) async {
    requested.add(story.id);
    return base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==',
    );
  }

  @override
  Future<void> markSeen(String id) async {
    viewed.add(id);
  }
}

ShopStory story(String id) => ShopStory(
  id: id,
  shopId: 'maker',
  mediaPath: 'owner/$id.jpg',
  mediaType: 'image',
  caption: 'Caption $id',
  createdAt: DateTime.now().subtract(const Duration(hours: 1)),
  expiresAt: DateTime.now().add(const Duration(hours: 23)),
  shopName: 'Real maker',
);

void main() {
  testWidgets(
    'rail opens a story, not a shop shortcut; next loads distinct media',
    (tester) async {
      final repository = FakeStories();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWithValue(null),
            storyRepositoryProvider.overrideWithValue(repository),
            storiesProvider.overrideWith(
              (ref) async => [story('a'), story('b')],
            ),
            seenStoriesProvider.overrideWith((ref) async => <String>{}),
          ],
          child: MaterialApp(
            home: Scaffold(
              bottomNavigationBar: const Text('Shell navigation'),
              body: Navigator(
                onGenerateRoute: (_) => MaterialPageRoute(
                  builder: (_) => const Scaffold(body: CreatorStoryRail()),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Real maker'), findsOneWidget);
      await tester.tap(find.text('Real maker'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(StoryViewerScreen), findsOneWidget);
      expect(find.text('Shell navigation'), findsNothing);
      expect(find.text('Caption a'), findsOneWidget);
      // No visible "Next"/"Previous" text controls; only gesture zones.
      expect(find.text('Next'), findsNothing);
      expect(find.text('Previous'), findsNothing);
      expect(find.text('Hold to pause'), findsNothing);
      await tester.tap(find.bySemanticsLabel('Next story'));
      await tester.pump();
      expect(find.text('Caption b'), findsOneWidget);
      expect(repository.requested, ['a', 'b']);
      // Hold to pause: a sustained press pauses; releasing resumes.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('story-media-gesture'))),
      );
      await tester.pump(kLongPressTimeout + kPressTimeout);
      expect(find.bySemanticsLabel(RegExp('story, paused')), findsOneWidget);
      await gesture.up();
      await tester.pump();
      expect(find.bySemanticsLabel(RegExp('story, playing')), findsOneWidget);
      await tester.tap(find.byTooltip('Close story'));
      await tester.pumpAndSettle();
      expect(find.byType(StoryViewerScreen), findsNothing);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('missing backend has explicit retry without fake stories', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue(null),
          storiesProvider.overrideWith(
            (ref) async => throw StateError('not deployed'),
          ),
          seenStoriesProvider.overrideWith((ref) async => <String>{}),
        ],
        child: const MaterialApp(home: Scaffold(body: CreatorStoryRail())),
      ),
    );
    await tester.pump();
    expect(find.text('Stories are unavailable right now.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
