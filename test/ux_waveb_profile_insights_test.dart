// Coverage for the maker's Insights screen (lib/features/vendor/screens/
// shop_insights_screen.dart): stat tiles render from a fake ShopInsights,
// the period chips switch the requested window, and a shop with no
// insights yet gets the friendly empty state instead of zeroed tiles.
import 'package:artisanal_lane/features/vendor/screens/shop_insights_screen.dart';
import 'package:artisanal_lane/models/creator_parity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ShopInsights _insights({int days = 30}) => ShopInsights(
  days: days,
  postViews: 214,
  productViews: 58,
  profileViews: 76,
  likes: 40,
  comments: 12,
  saves: 9,
  newFollowers: 5,
  followers: 132,
  topPosts: const [(postId: 'post-1', views: 87)],
);

void main() {
  testWidgets('renders stat tiles from a fake ShopInsights', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shopInsightsProvider.overrideWith((ref, days) async => _insights()),
        ],
        child: const MaterialApp(home: ShopInsightsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Insights'), findsOneWidget);
    expect(find.text('214'), findsOneWidget); // post views
    expect(find.text('132'), findsOneWidget); // followers
    expect(find.text('Post views'), findsOneWidget);
    expect(find.text('Followers'), findsOneWidget);
    expect(find.text('Top posts'), findsOneWidget);
  });

  testWidgets('switching the period chip requests a different window', (
    tester,
  ) async {
    final requestedDays = <int>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shopInsightsProvider.overrideWith((ref, days) async {
            requestedDays.add(days);
            return _insights(days: days);
          }),
        ],
        child: const MaterialApp(home: ShopInsightsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(requestedDays, contains(30));

    await tester.tap(find.text('7 days'));
    await tester.pumpAndSettle();

    expect(requestedDays, contains(7));
  });

  testWidgets('a shop with no insights yet gets the friendly empty state', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shopInsightsProvider.overrideWith((ref, days) async => null),
        ],
        child: const MaterialApp(home: ShopInsightsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Share your first post to start seeing insights'),
      findsOneWidget,
    );
  });
}
