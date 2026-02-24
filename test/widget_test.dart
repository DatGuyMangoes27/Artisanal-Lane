import 'package:flutter_test/flutter_test.dart';
import 'package:artisanal_lane/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ArtisanalLaneApp());
    await tester.pump();
    expect(find.textContaining('Artisanal'), findsWidgets);
  });
}
