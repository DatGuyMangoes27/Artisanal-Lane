import 'package:artisanal_lane/concepts/creator_commerce/creator_commerce_mockup_app.dart';
import 'package:artisanal_lane/models/product.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpConcept(
    WidgetTester tester,
    CreatorCommerceScreen screen, {
    CreatorCommerceCatalog catalog = const CreatorCommerceCatalog(),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 915);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      CreatorCommerceMockupApp(initialScreen: screen, catalog: catalog),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('feed and shop are first-class navigation destinations', (
    tester,
  ) async {
    await pumpConcept(tester, CreatorCommerceScreen.feed);

    expect(find.text('Made with a story'), findsOneWidget);
    expect(find.text('Feed'), findsOneWidget);
    expect(find.text('Shop'), findsOneWidget);
    expect(find.text('Sunburst brass earrings'), findsOneWidget);

    await tester.tap(find.text('Shop'));
    await tester.pumpAndSettle();
    expect(find.text('Shop the lane'), findsOneWidget);
    expect(find.text('Because you liked brass'), findsOneWidget);
  });

  testWidgets('discovery explains preference learning', (tester) async {
    await pumpConcept(tester, CreatorCommerceScreen.discover);

    expect(find.text('Find your kind of craft'), findsOneWidget);
    expect(find.text('Love it'), findsOneWidget);
    expect(find.text('Not for me'), findsOneWidget);
    expect(find.text('Tune my preferences'), findsOneWidget);
  });

  testWidgets('discovery card follows a Tinder-style horizontal swipe', (
    tester,
  ) async {
    final now = DateTime(2026, 9, 2);
    Product product(String id, String title) => Product(
      id: id,
      shopId: 'shop-1',
      title: title,
      description: 'Handmade locally.',
      price: 500,
      stockQty: 1,
      images: const [''],
      tags: const ['handmade'],
      shopName: 'Test Artisan',
      createdAt: now,
      updatedAt: now,
    );
    final catalog = CreatorCommerceCatalog(
      products: [
        product('product-1', 'First discovery piece'),
        product('product-2', 'Second discovery piece'),
      ],
      liveSources: 1,
    );

    await pumpConcept(tester, CreatorCommerceScreen.discover, catalog: catalog);
    expect(find.text('First discovery piece'), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('discover-swipe-card')),
      const Offset(240, 8),
    );
    await tester.pump();
    expect(find.text('LOVE IT'), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.text('Second discovery piece'), findsOneWidget);
    expect(find.textContaining('Loved'), findsOneWidget);
  });

  testWidgets('artisan tools link creation and AI listing support', (
    tester,
  ) async {
    await pumpConcept(tester, CreatorCommerceScreen.creator);

    expect(find.text('Create post'), findsOneWidget);
    expect(find.text('AI studio'), findsOneWidget);

    await tester.tap(find.text('AI studio'));
    await tester.pumpAndSettle();
    expect(find.text('AI Listing Studio'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Product integrity lock'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Product integrity lock'), findsOneWidget);
  });

  testWidgets('composer exposes working camera and gallery choices', (
    tester,
  ) async {
    await pumpConcept(tester, CreatorCommerceScreen.compose);

    await tester.tap(find.text('Add media'));
    await tester.pumpAndSettle();

    expect(find.text('Take a photo'), findsOneWidget);
    expect(find.text('Choose from gallery'), findsOneWidget);
    expect(find.text('Use demo product photo'), findsOneWidget);
  });

  testWidgets('feed engagement controls react in place', (tester) async {
    await pumpConcept(tester, CreatorCommerceScreen.feed);

    await tester.tap(find.byIcon(Icons.favorite_border).first);
    await tester.pumpAndSettle();
    expect(find.text('Liked'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('Join the conversation'), findsOneWidget);
    expect(find.textContaining('Ask '), findsOneWidget);
  });

  testWidgets('creator profile exposes follow and custom order actions', (
    tester,
  ) async {
    await pumpConcept(tester, CreatorCommerceScreen.creator);

    await tester.tap(find.text('Ask for custom'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ask Thando Made'), findsOneWidget);
  });

  testWidgets('AI studio runs the generation state', (tester) async {
    await pumpConcept(tester, CreatorCommerceScreen.aiStudio);

    expect(find.text('Load test photo'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Generate image'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -140));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generate image'));
    await tester.pump();
    expect(find.text('Generating…'), findsWidgets);
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pump();
    expect(find.text('Generate image'), findsOneWidget);
  });

  testWidgets('both AI comparison photos open a full-screen zoom viewer', (
    tester,
  ) async {
    await pumpConcept(tester, CreatorCommerceScreen.aiStudio);

    await tester.tap(find.byKey(const ValueKey('enlarge-REAL LISTING')));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text('PINCH TO ZOOM · DRAG TO INSPECT'), findsOneWidget);
    await tester.tap(find.byKey(const Key('close-ai-photo-preview')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('enlarge-SHOWCASE RESULT')));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text('SHOWCASE RESULT'), findsWidgets);
  });

  testWidgets('live catalogue content replaces demo product copy', (
    tester,
  ) async {
    final now = DateTime(2026, 9, 2);
    final catalog = CreatorCommerceCatalog(
      products: [
        Product(
          id: 'real-product-1',
          shopId: 'real-shop-1',
          title: 'Cape Fynbos Serving Bowl',
          description: 'Hand-thrown stoneware with a locally inspired glaze.',
          price: 725,
          stockQty: 2,
          images: const [''],
          tags: const ['stoneware', 'fynbos'],
          shopName: 'Clay & Coast',
          createdAt: now,
          updatedAt: now,
        ),
      ],
      liveSources: 1,
    );

    await pumpConcept(tester, CreatorCommerceScreen.shop, catalog: catalog);

    expect(find.text('Live catalogue'), findsOneWidget);
    expect(find.text('Cape Fynbos Serving Bowl'), findsOneWidget);
    expect(find.text('R 725'), findsOneWidget);
    expect(find.text('Clay & Coast'), findsOneWidget);
    expect(find.text('Sunburst brass earrings'), findsNothing);
  });

  for (final screen in CreatorCommerceScreen.values) {
    testWidgets('renders ${screen.name} concept at Android phone size', (
      tester,
    ) async {
      await pumpConcept(tester, screen);
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/creator_commerce_${screen.name}.png'),
      );
    });
  }
}
