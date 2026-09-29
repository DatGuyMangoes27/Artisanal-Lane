import 'package:artisanal_lane/features/buyer/providers/creator_safety_providers.dart';
import 'package:artisanal_lane/features/buyer/widgets/content_report_sheet.dart';
import 'package:artisanal_lane/features/auth/providers/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeReports implements ContentReportRepository {
  Map<String, Object?>? submitted;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<void> submit({
    required String expectedUserId,
    required ContentReportTargetType targetType,
    required String targetId,
    required String reason,
    String details = '',
  }) async {
    submitted = {
      'targetType': targetType,
      'expectedUserId': expectedUserId,
      'targetId': targetId,
      'reason': reason,
      'details': details,
    };
  }
}

class TestAccount extends Notifier<String?> {
  @override
  String? build() => 'buyer';

  void switchTo(String? id) => state = id;
}

final testAccountProvider = NotifierProvider<TestAccount, String?>(
  TestAccount.new,
);

void main() {
  testWidgets('report sheet requires a reason and submits a private receipt', (
    tester,
  ) async {
    final reports = FakeReports();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('buyer'),
          contentReportRepositoryProvider.overrideWithValue(reports),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ContentReportSheet(
              targetType: ContentReportTargetType.comment,
              targetId: 'comment-id',
            ),
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.text('Send report'));
    await tester.tap(find.text('Send report'));
    await tester.pump();
    expect(
      find.text('Choose a reason so our team can review this.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Harassment or bullying'));
    await tester.enterText(
      find.byType(TextField),
      'Repeated unwanted messages',
    );
    await tester.ensureVisible(find.text('Send report'));
    await tester.tap(find.text('Send report'));
    await tester.pump();
    expect(reports.submitted, {
      'targetType': ContentReportTargetType.comment,
      'expectedUserId': 'buyer',
      'targetId': 'comment-id',
      'reason': 'harassment',
      'details': 'Repeated unwanted messages',
    });
  });

  testWidgets('account switch cannot submit the report as another user', (
    tester,
  ) async {
    final reports = FakeReports();
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWith(
          (ref) => ref.watch(testAccountProvider),
        ),
        contentReportRepositoryProvider.overrideWithValue(reports),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: ContentReportSheet(
              targetType: ContentReportTargetType.story,
              targetId: 'story-id',
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Spam or scam'));
    container.read(testAccountProvider.notifier).switchTo('other');
    await tester.ensureVisible(find.text('Send report'));
    await tester.tap(find.text('Send report'));
    await tester.pump();
    expect(reports.submitted, isNull);
    expect(
      find.text('Your account changed. Close this report and start again.'),
      findsOneWidget,
    );
  });
}
