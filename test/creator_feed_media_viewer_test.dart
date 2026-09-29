import 'package:artisanal_lane/features/auth/providers/auth_providers.dart';
import 'package:artisanal_lane/features/buyer/widgets/creator_feed/creator_feed_media_viewer.dart';
import 'package:artisanal_lane/features/buyer/widgets/creator_feed/creator_feed_post_card.dart';
import 'package:artisanal_lane/models/shop_post.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpCard(WidgetTester tester, ShopPost post) =>
      tester.pumpWidget(
        ProviderScope(
          overrides: [currentUserIdProvider.overrideWithValue(null)],
          child: MaterialApp(
            home: Scaffold(
              body: ListView(
                children: [
                  CreatorFeedPostCard(
                    post: post,
                    isFollowing: false,
                    onOpenShop: () {},
                    onFollowToggle: () async {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  test('detects common video URLs and only accepts HTTPS player URLs', () {
    expect(
      isCreatorFeedVideoUrl('https://cdn.example.com/maker/clip.MP4?token=1'),
      isTrue,
    );
    expect(isCreatorFeedVideoUrl('https://cdn.example.com/still.jpg'), isFalse);
    expect(isCreatorFeedHttpsUrl('https://cdn.example.com/clip.mp4'), isTrue);
    expect(isCreatorFeedHttpsUrl('http://cdn.example.com/clip.mp4'), isFalse);
    expect(isCreatorFeedHttpsUrl('javascript:alert(1)'), isFalse);
  });

  testWidgets('tapping a feed photo opens the contained zoom viewer', (
    tester,
  ) async {
    final post = ShopPost(
      id: 'post-1',
      shopId: 'shop-1',
      caption: '',
      mediaUrls: const ['https://images.example.com/photo.jpg'],
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    await pumpCard(tester, post);

    tester
        .widget<InkWell>(find.byKey(const Key('open-creator-feed-photo')))
        .onTap!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(CreatorFeedMediaViewer), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });

  testWidgets('insecure feed video stays in-app and explains the block', (
    tester,
  ) async {
    final post = ShopPost(
      id: 'post-2',
      shopId: 'shop-1',
      caption: '',
      mediaUrls: const ['http://media.example.com/clip.mp4'],
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    await pumpCard(tester, post);

    await tester.tap(find.byKey(const Key('open-creator-feed-video')));
    // The media area also listens for a double-tap-to-like gesture, so a
    // single tap only resolves after the double-tap timeout.
    await tester.pump(kDoubleTapTimeout);
    await tester.pump();

    expect(find.text('This video needs a secure link.'), findsOneWidget);
    expect(find.byType(CreatorFeedMediaViewer), findsNothing);
  });
}
