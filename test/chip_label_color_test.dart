import 'package:artisanal_lane/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Chip labels once had no colour, which iOS drew white on the light chips
// (Discover preferences, shop Sort & Filter).
void main() {
  testWidgets('filter and choice chip labels are dark and readable', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Wrap(
            children: [
              FilterChip(
                label: const Text('Home'),
                selected: false,
                onSelected: (_) {},
              ),
              ChoiceChip(
                label: const Text('Any price'),
                selected: true,
                onSelected: (_) {},
              ),
            ],
          ),
        ),
      ),
    );

    Color? colorOf(String label) =>
        DefaultTextStyle.of(tester.element(find.text(label))).style.color;

    expect(colorOf('Home'), AppTheme.textPrimary);
    expect(colorOf('Any price'), AppTheme.terracotta);
  });
}
