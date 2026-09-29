import 'dart:convert';
import 'dart:typed_data';
import 'package:artisanal_lane/features/auth/providers/auth_providers.dart';
import 'package:artisanal_lane/features/buyer/providers/story_providers.dart';
import 'package:artisanal_lane/features/buyer/screens/story_viewer_screen.dart';
import 'package:artisanal_lane/features/buyer/widgets/stories/story_reaction_bar.dart';
import 'package:artisanal_lane/models/shop_story.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeStories implements StoryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<Uint8List> media(ShopStory story) async => base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==',
  );
  @override
  Future<void> markSeen(String id) async {}
}

/// Drives [myStoryReactionProvider] without touching the network so viewer
/// widget tests can control the initial reaction and simulate save failure.
class FakeMyStoryReactionController extends MyStoryReactionController {
  FakeMyStoryReactionController(
    super.storyId, {
    this.initial,
    this.shouldFail = false,
  });
  final String? initial;
  final bool shouldFail;
  final calls = <String?>[];

  @override
  Future<String?> build() async => initial;

  @override
  Future<bool> setReaction(String? emoji) async {
    final previous = state.value;
    if (previous == emoji) return true;
    calls.add(emoji);
    state = AsyncData(emoji);
    if (shouldFail) {
      state = AsyncData(previous);
      return false;
    }
    return true;
  }
}

ShopStory story(String id, {String shopId = 'maker'}) => ShopStory(
  id: id,
  shopId: shopId,
  mediaPath: 'owner/$id.jpg',
  mediaType: 'image',
  caption: 'Caption $id',
  createdAt: DateTime.now().subtract(const Duration(hours: 1)),
  expiresAt: DateTime.now().add(const Duration(hours: 23)),
  shopName: 'Real maker',
);

void main() {
  testWidgets('signed-in viewer reacts, changes and removes a reaction', (
    tester,
  ) async {
    final s = story('a');
    final controller = FakeMyStoryReactionController(s.id, initial: null);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('buyer1'),
          storyRepositoryProvider.overrideWithValue(FakeStories()),
          seenStoriesProvider.overrideWith((ref) async => <String>{}),
          myStoryReactionProvider(s.id).overrideWith(() => controller),
        ],
        child: MaterialApp(
          home: StoryViewerScreen(
            groups: [
              [s],
            ],
            initialGroupIndex: 0,
          ),
        ),
      ),
    );
    await tester.pump();

    // React: tap the heart to expand the row, then pick an emoji.
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('story-reaction-heart')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.bySemanticsLabel(RegExp('story, paused')), findsOneWidget);
    expect(find.text('❤️'), findsOneWidget);
    await tester.tap(find.text('❤️'));
    await tester.pump();
    expect(controller.calls, ['❤️']);
    // Row collapses back to the heart button showing the chosen emoji, and
    // playback resumes.
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.bySemanticsLabel(RegExp('story, playing')), findsOneWidget);
    // Let the floating-emoji animation finish so it doesn't linger.
    await tester.pump(const Duration(milliseconds: 950));
    expect(find.byKey(const ValueKey('story-reaction-heart')), findsOneWidget);
    expect(find.text('❤️'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsNothing);

    // Change: open the row again and pick a different emoji.
    await tester.tap(find.byKey(const ValueKey('story-reaction-heart')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('🔥'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 950));
    expect(controller.calls, ['❤️', '🔥']);
    expect(find.text('🔥'), findsOneWidget);

    // Remove: tap the same reaction again to clear it.
    await tester.tap(find.byKey(const ValueKey('story-reaction-heart')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('🔥'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(controller.calls, ['❤️', '🔥', null]);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a failed reaction rolls back and shows a toast', (tester) async {
    final s = story('b');
    final controller = FakeMyStoryReactionController(
      s.id,
      initial: null,
      shouldFail: true,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('buyer1'),
          storyRepositoryProvider.overrideWithValue(FakeStories()),
          seenStoriesProvider.overrideWith((ref) async => <String>{}),
          myStoryReactionProvider(s.id).overrideWith(() => controller),
        ],
        child: MaterialApp(
          home: StoryViewerScreen(
            groups: [
              [s],
            ],
            initialGroupIndex: 0,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('story-reaction-heart')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('😍'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      find.text("Couldn't send your reaction. Please try again."),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a guest is sent to the sign-in sheet instead of reacting', (
    tester,
  ) async {
    final s = story('c');
    // The shared sign-in sheet needs more than the default 600px height.
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue(null),
          storyRepositoryProvider.overrideWithValue(FakeStories()),
          seenStoriesProvider.overrideWith((ref) async => <String>{}),
        ],
        child: MaterialApp(
          home: StoryViewerScreen(
            groups: [
              [s],
            ],
            initialGroupIndex: 0,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('story-reaction-heart')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('👏'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in to react'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the reaction control is hidden on an expired story', (
    tester,
  ) async {
    final expired = ShopStory(
      id: 'expired',
      shopId: 'maker',
      mediaPath: 'owner/expired.jpg',
      mediaType: 'image',
      caption: '',
      createdAt: DateTime.now().subtract(const Duration(hours: 30)),
      expiresAt: DateTime.now().subtract(const Duration(hours: 6)),
      shopName: 'Real maker',
    );
    // Exercised directly (not through the full viewer screen) so the
    // screen's own expiry timer — which closes the viewer — never fires.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [currentUserIdProvider.overrideWithValue('buyer1')],
        child: MaterialApp(
          home: Scaffold(
            body: StoryReactionBar(story: expired, onExpandChanged: (_) {}),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('story-reaction-heart')), findsNothing);
  });

  testWidgets('the maker sees a reactions pill that opens a sheet', (
    tester,
  ) async {
    final s = story('m', shopId: 'my-shop');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('maker1'),
          storyRepositoryProvider.overrideWithValue(FakeStories()),
          seenStoriesProvider.overrideWith((ref) async => <String>{}),
          storyReactionsProvider(
            s.id,
          ).overrideWith((ref) async => [(emoji: '🔥', name: 'Amara')]),
        ],
        child: MaterialApp(
          home: StoryViewerScreen(
            groups: [
              [s],
            ],
            initialGroupIndex: 0,
            ownShopId: 'my-shop',
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Reactions · 1'), findsOneWidget);
    // Visitor pills never show on a maker's own story.
    expect(find.text('Visit shop'), findsNothing);
    expect(find.text('Send message'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('story-reactions-pill')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.bySemanticsLabel(RegExp('story, paused')), findsOneWidget);
    expect(find.text('Amara'), findsOneWidget);
    expect(find.text('🔥'), findsOneWidget);
    // Close the sheet.
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the maker sheet shows an empty state with no reactions', (
    tester,
  ) async {
    final s = story('n', shopId: 'my-shop');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('maker1'),
          storyRepositoryProvider.overrideWithValue(FakeStories()),
          seenStoriesProvider.overrideWith((ref) async => <String>{}),
          storyReactionsProvider(s.id).overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          home: StoryViewerScreen(
            groups: [
              [s],
            ],
            initialGroupIndex: 0,
            ownShopId: 'my-shop',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('story-reactions-pill')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('No reactions yet'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
