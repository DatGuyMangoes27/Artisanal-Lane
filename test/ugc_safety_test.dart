import 'package:artisanal_lane/core/constants/feature_flags.dart';
import 'package:artisanal_lane/features/auth/providers/auth_providers.dart';
import 'package:artisanal_lane/features/buyer/providers/blocking_providers.dart';
import 'package:artisanal_lane/features/buyer/providers/creator_parity_providers.dart';
import 'package:artisanal_lane/features/buyer/providers/post_social_providers.dart';
import 'package:artisanal_lane/features/buyer/screens/post_comments_screen.dart';
import 'package:artisanal_lane/features/buyer/widgets/content_report_sheet.dart';
import 'package:artisanal_lane/features/chat/widgets/chat_message_actions.dart';
import 'package:artisanal_lane/features/chat/widgets/chat_widgets.dart';
import 'package:artisanal_lane/features/safety/community_guidelines_gate.dart';
import 'package:artisanal_lane/features/safety/community_guidelines_screen.dart';
import 'package:artisanal_lane/features/safety/content_filter.dart';
import 'package:artisanal_lane/features/safety/review_safety.dart';
import 'package:artisanal_lane/features/vendor/providers/vendor_providers.dart';
import 'package:artisanal_lane/models/chat_message.dart';
import 'package:artisanal_lane/models/post_interaction.dart';
import 'package:artisanal_lane/services/safety_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeSafety implements SafetyService {
  FakeSafety({this.acceptedAt, this.failAccept = false});
  DateTime? acceptedAt;
  bool failAccept;
  int fetches = 0, accepts = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<DateTime?> fetchCommunityGuidelinesAcceptedAt() async {
    fetches++;
    return acceptedAt;
  }

  @override
  Future<DateTime> acceptCommunityGuidelines() async {
    accepts++;
    if (failAccept) throw StateError('offline');
    return acceptedAt ??= DateTime(2026, 10, 18);
  }
}

class FakeSocial implements PostSocialRepository {
  final sent = <String>[];
  Object? failWith;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<PostEngagement> engagement(String id) async =>
      const PostEngagement(likes: 0, comments: 0, liked: false);
  @override
  Future<List<PostComment>> comments(String id, {PostComment? before}) async =>
      const [];
  @override
  Future<void> addComment(String post, String body, String requestId) async {
    if (failWith != null) throw failWith!;
    sent.add(body);
  }
}

/// Hosts a button that runs the gate and records its answer.
class _GateHost extends ConsumerWidget {
  const _GateHost(this.results);
  final List<bool> results;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Center(
      child: ElevatedButton(
        onPressed: () async =>
            results.add(await ensureCommunityGuidelinesAccepted(context, ref)),
        child: const Text('Post'),
      ),
    ),
  );
}

Widget _app(List overrides, Widget home) => ProviderScope(
  overrides: overrides.cast(),
  child: MaterialApp(home: home),
);

ChatMessage _message(String id, String sender, String body) => ChatMessage(
  id: id,
  threadId: 'thread',
  senderId: sender,
  body: body,
  messageType: 'text',
  createdAt: DateTime(2026, 10, 18, 9),
);

void main() {
  group('content filter', () {
    test(
      'blocks slurs, explicit terms and severe profanity as whole words',
      () {
        for (final text in [
          'FUCK off',
          'f*ck this',
          'you kaffir',
          'faggots',
          'free porn here',
          'Motherfucker',
          'what a CUNT.',
          'n1gger',
        ]) {
          expect(containsBlockedTerms(text), isTrue, reason: text);
        }
      },
    );

    test('allows normal words that contain a blocked term (Scunthorpe)', () {
      for (final text in [
        'Scunthorpe pottery',
        'cocktail glasses',
        "Assassin's Creed mug",
        'shipped from Pakistan',
        'spice rack',
        'art therapist',
        'flame retardant fabric',
        'Hancock street',
        'Dickens bookends',
        'shiitake grow kit',
        'damn this is lovely',
        'Maine Coon collar',
        'pussy willow wreath',
        'cum laude gift',
        'Sussex trug',
        'rapeseed oil soap',
        '',
        null,
      ]) {
        expect(containsBlockedTerms(text), isFalse, reason: '$text');
      }
    });

    test('validateUgcText and server error mapping', () {
      expect(validateUgcText(['Lovely', 'clean']), isNull);
      expect(validateUgcText(['Lovely', 'slut']), blockedTermsFriendlyMessage);
      const serverError = PostgrestException(
        message: blockedTermsServerMessage,
        code: 'P0001',
      );
      expect(isBlockedTermsError(serverError), isTrue);
      expect(ugcErrorMessage(serverError), blockedTermsFriendlyMessage);
      expect(ugcErrorMessage(StateError('network')), isNull);
    });
  });

  group('community guidelines gate', () {
    testWidgets(
      'asks once, records agreement and then passes straight through',
      (tester) async {
        final safety = FakeSafety();
        final results = <bool>[];
        await tester.pumpWidget(
          _app([
            currentUserIdProvider.overrideWithValue('buyer'),
            safetyServiceProvider.overrideWithValue(safety),
          ], _GateHost(results)),
        );
        await tester.tap(find.text('Post'));
        await tester.pumpAndSettle();
        expect(find.text('Our community guidelines'), findsOneWidget);
        expect(find.textContaining('within 24 hours'), findsOneWidget);
        expect(find.text('Read the full community guidelines'), findsOneWidget);
        await tester.ensureVisible(find.text('I agree'));
        await tester.tap(find.text('I agree'));
        await tester.pumpAndSettle();
        expect(results, [true]);
        expect(safety.accepts, 1);

        await tester.tap(find.text('Post'));
        await tester.pumpAndSettle();
        expect(results, [true, true]);
        expect(find.text('Our community guidelines'), findsNothing);
        expect(safety.fetches, 1, reason: 'acceptance is cached per account');
      },
    );

    testWidgets('already-accepted members never see the sheet', (tester) async {
      final safety = FakeSafety(acceptedAt: DateTime(2026, 10, 1));
      final results = <bool>[];
      await tester.pumpWidget(
        _app([
          currentUserIdProvider.overrideWithValue('buyer'),
          safetyServiceProvider.overrideWithValue(safety),
        ], _GateHost(results)),
      );
      await tester.tap(find.text('Post'));
      await tester.pumpAndSettle();
      expect(results, [true]);
      expect(find.text('Our community guidelines'), findsNothing);
      expect(safety.accepts, 0);
    });

    testWidgets('closing without agreeing, or a failed save, blocks posting', (
      tester,
    ) async {
      final safety = FakeSafety(failAccept: true);
      final results = <bool>[];
      await tester.pumpWidget(
        _app([
          currentUserIdProvider.overrideWithValue('buyer'),
          safetyServiceProvider.overrideWithValue(safety),
        ], _GateHost(results)),
      );
      await tester.tap(find.text('Post'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('I agree'));
      await tester.tap(find.text('I agree'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining("Couldn't save your agreement"),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Not now'));
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(results, [false]);
    });

    testWidgets('guests are refused without a sheet', (tester) async {
      final results = <bool>[];
      await tester.pumpWidget(
        _app([
          currentUserIdProvider.overrideWithValue(null),
          safetyServiceProvider.overrideWithValue(FakeSafety()),
        ], _GateHost(results)),
      );
      await tester.tap(find.text('Post'));
      await tester.pumpAndSettle();
      expect(results, [false]);
    });

    testWidgets(
      'the full guidelines screen states zero tolerance and contact',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: CommunityGuidelinesScreen()),
        );
        expect(find.text('Community Guidelines'), findsOneWidget);
        expect(find.text('Zero tolerance'), findsOneWidget);
        expect(
          find.textContaining('no tolerance for objectionable content'),
          findsOneWidget,
        );
      },
    );
  });

  group('comment posting', () {
    List overrides(FakeSocial social, FakeSafety safety) => [
      currentUserIdProvider.overrideWithValue('buyer'),
      vendorShopProvider.overrideWith((ref) async => null),
      postSocialRepositoryProvider.overrideWithValue(social),
      safetyServiceProvider.overrideWithValue(safety),
    ];

    testWidgets('requires guideline agreement before the first comment', (
      tester,
    ) async {
      final social = FakeSocial();
      await tester.pumpWidget(
        _app(
          overrides(social, FakeSafety()),
          const PostCommentsScreen(postId: 'post', shopId: 'shop'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Beautiful glaze');
      await tester.tap(find.byTooltip('Send comment'));
      await tester.pumpAndSettle();
      expect(find.text('Our community guidelines'), findsOneWidget);
      expect(social.sent, isEmpty);
      await tester.ensureVisible(find.text('I agree'));
      await tester.tap(find.text('I agree'));
      await tester.pumpAndSettle();
      expect(social.sent, ['Beautiful glaze']);
    });

    testWidgets('objectionable text gets an inline error and is not sent', (
      tester,
    ) async {
      final social = FakeSocial();
      await tester.pumpWidget(
        _app(
          overrides(social, FakeSafety(acceptedAt: DateTime(2026))),
          const PostCommentsScreen(postId: 'post', shopId: 'shop'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'what a cunt');
      await tester.tap(find.byTooltip('Send comment'));
      await tester.pumpAndSettle();
      expect(find.text(blockedTermsFriendlyMessage), findsOneWidget);
      expect(social.sent, isEmpty);
    });

    testWidgets('the server filter rejection is shown in friendly words', (
      tester,
    ) async {
      final social = FakeSocial()
        ..failWith = const PostgrestException(
          message: blockedTermsServerMessage,
          code: 'P0001',
        );
      await tester.pumpWidget(
        _app(
          overrides(social, FakeSafety(acceptedAt: DateTime(2026))),
          const PostCommentsScreen(postId: 'post', shopId: 'shop'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'A new slang word');
      await tester.tap(find.byTooltip('Send comment'));
      await tester.pumpAndSettle();
      expect(find.text(blockedTermsFriendlyMessage), findsOneWidget);
    });
  });

  group('report entries', () {
    testWidgets('report sheet titles cover reviews and messages', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          [currentUserIdProvider.overrideWithValue('buyer')],
          const Scaffold(
            body: ContentReportSheet(
              rawTargetType: ExtraReportTargets.productReview,
              targetId: 'review',
            ),
          ),
        ),
      );
      expect(find.text('Report review'), findsOneWidget);
      expect(find.textContaining('within 24 hours'), findsOneWidget);
      await tester.pumpWidget(
        _app(
          [currentUserIdProvider.overrideWithValue('buyer')],
          const Scaffold(
            body: ContentReportSheet(
              key: ValueKey('message'),
              rawTargetType: ExtraReportTargets.message,
              targetId: 'message',
            ),
          ),
        ),
      );
      expect(find.text('Report message'), findsOneWidget);
    });

    testWidgets(
      'reviews by others offer Report and Block; own reviews do not',
      (tester) async {
        await tester.pumpWidget(
          _app(
            [
              currentUserIdProvider.overrideWithValue('buyer'),
              blockedUserIdsProvider.overrideWith(
                () => OptimisticIdSet(
                  (ref) async => <String>{},
                  (ref, id, on) async {},
                ),
              ),
            ],
            const Scaffold(
              body: Column(
                children: [
                  ReviewSafetyActions(
                    reviewId: 'theirs',
                    authorId: 'other',
                    authorName: 'Sam',
                    isProductReview: true,
                  ),
                  ReviewSafetyActions(
                    reviewId: 'mine',
                    authorId: 'buyer',
                    authorName: 'Me',
                    isProductReview: false,
                  ),
                ],
              ),
            ),
          ),
        );
        if (!creatorSafetyEnabled) {
          expect(find.text('Report'), findsNothing);
          return;
        }
        expect(
          find.byKey(const ValueKey('report-review-theirs')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('report-review-mine')), findsNothing);
        await tester.tap(find.byKey(const ValueKey('report-review-theirs')));
        await tester.pumpAndSettle();
        expect(find.text('Report review'), findsOneWidget);
      },
    );

    test('blocked reviewers are hidden', () {
      final reviews = ['a', 'b', 'c'];
      expect(withoutBlockedAuthors(reviews, {'b'}, (r) => r), ['a', 'c']);
      expect(withoutBlockedAuthors(reviews, <String>{}, (r) => r), reviews);
    });

    test(
      'chat reporting follows the safety flag and skips support threads',
      () {
        expect(
          canReportInChatThread(
            currentUserId: 'me',
            isSupportThread: false,
            safetyEnabled: true,
          ),
          isTrue,
        );
        expect(
          canReportInChatThread(
            currentUserId: 'me',
            isSupportThread: true,
            safetyEnabled: true,
          ),
          isFalse,
        );
        expect(
          canReportInChatThread(
            currentUserId: 'me',
            isSupportThread: false,
            safetyEnabled: false,
          ),
          isFalse,
        );
        expect(
          canReportInChatThread(
            currentUserId: null,
            isSupportThread: false,
            safetyEnabled: true,
          ),
          isFalse,
        );
      },
    );

    testWidgets('long-pressing a received message opens Report message', (
      tester,
    ) async {
      final pressed = <String>[];
      await tester.pumpWidget(
        _app(
          [currentUserIdProvider.overrideWithValue('me')],
          Builder(
            builder: (context) => ChatThreadScaffold(
              messagesAsync: AsyncData([
                _message('theirs', 'maker', 'Pay me outside the app'),
                _message('mine', 'me', 'No thanks'),
              ]),
              currentUserId: 'me',
              title: 'Maker',
              avatarFallback: 'M',
              composer: const SizedBox.shrink(),
              onMessageLongPress: (message) {
                pressed.add(message.id);
                showChatMessageActions(context, message);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Long-press a message to report'),
        findsOneWidget,
      );
      await tester.longPress(find.text('No thanks'));
      await tester.pumpAndSettle();
      expect(pressed, isEmpty, reason: 'own messages have no report menu');
      await tester.longPress(find.text('Pay me outside the app'));
      await tester.pumpAndSettle();
      expect(pressed, ['theirs']);
      expect(find.text('Copy text'), findsOneWidget);
      await tester.tap(find.text('Report message'));
      await tester.pumpAndSettle();
      expect(find.text('Report message'), findsOneWidget);
      expect(find.text('Send report'), findsOneWidget);
    });
  });
}
