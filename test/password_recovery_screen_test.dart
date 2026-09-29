import 'dart:async';
import 'package:artisanal_lane/features/auth/screens/forgot_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'requests recovery without a profile lookup and avoids account enumeration',
    (tester) async {
      final emails = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: ForgotPasswordScreen(
            sendReset: (email) async => emails.add(email),
          ),
        ),
      );
      await tester.enterText(
        find.byType(TextFormField),
        '  PERSON@Example.com  ',
      );
      await tester.tap(find.text('Send Reset Link'));
      await tester.pumpAndSettle();
      expect(emails, ['person@example.com']);
      expect(find.textContaining('If an account exists'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('leaving recovery while a failed request is pending is safe', (
    tester,
  ) async {
    final result = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ForgotPasswordScreen(
          sendReset: (_) {
            calls++;
            return result.future;
          },
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField), 'person@example.com');
    await tester.tap(find.text('Send Reset Link'));
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(calls, 1);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    result.completeError(StateError('offline'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
