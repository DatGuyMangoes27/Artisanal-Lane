import 'dart:io';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/theme.dart';
import '../../models/product.dart';
import '../../models/shop.dart';
import '../../models/shop_post.dart';
import '../../services/supabase_service.dart';

enum CreatorCommerceScreen { feed, discover, shop, creator, compose, aiStudio }

class CreatorCommerceCatalog {
  const CreatorCommerceCatalog({
    this.products = const [],
    this.shops = const [],
    this.posts = const [],
    this.followingPosts = const [],
    this.vendorProducts = const [],
    this.vendorShop,
    this.liveSources = 0,
    this.failedSources = 0,
  });

  final List<Product> products;
  final List<Shop> shops;
  final List<ShopPost> posts;
  final List<ShopPost> followingPosts;
  final List<Product> vendorProducts;
  final Shop? vendorShop;
  final int liveSources;
  final int failedSources;

  bool get hasLiveCatalog => products.isNotEmpty || shops.isNotEmpty;
  bool get hasLivePosts => posts.isNotEmpty || followingPosts.isNotEmpty;
  bool get usesFallback => failedSources > 0 || !hasLiveCatalog;

  Product? get heroProduct => products.isEmpty ? null : products.first;
  Product? get artisanProduct =>
      vendorProducts.isNotEmpty ? vendorProducts.first : heroProduct;
  Product? get studioProduct {
    const showcaseId = 'd7e0ab75-eec3-435d-a8c3-e64d1d4fb0bc';
    for (final product in products) {
      if (product.id == showcaseId) return product;
    }
    return artisanProduct;
  }

  Shop? get creatorShop => vendorShop ?? heroShop;
  Shop? get heroShop {
    final product = heroProduct;
    if (product != null) {
      for (final shop in shops) {
        if (shop.id == product.shopId) return shop;
      }
    }
    return shops.isEmpty ? null : shops.first;
  }

  Shop? shopFor(String? shopId) {
    if (shopId == null) return null;
    for (final shop in shops) {
      if (shop.id == shopId) return shop;
    }
    return null;
  }

  Product? productForShop(String? shopId) {
    if (shopId == null) return null;
    for (final product in products) {
      if (product.shopId == shopId) return product;
    }
    return null;
  }
}

class CreatorCommerceMockupApp extends StatelessWidget {
  const CreatorCommerceMockupApp({
    super.key,
    this.initialScreen = CreatorCommerceScreen.feed,
    this.catalog = const CreatorCommerceCatalog(),
  });

  final CreatorCommerceScreen initialScreen;
  final CreatorCommerceCatalog catalog;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Artisan Lane — Creator Commerce Concept',
      theme: AppTheme.lightTheme,
      home: CreatorCommerceMockupHost(
        initialScreen: initialScreen,
        catalog: catalog,
      ),
    );
  }
}

class CreatorCommerceMockupHost extends StatefulWidget {
  const CreatorCommerceMockupHost({
    super.key,
    this.initialScreen = CreatorCommerceScreen.feed,
    this.catalog = const CreatorCommerceCatalog(),
  });

  final CreatorCommerceScreen initialScreen;
  final CreatorCommerceCatalog catalog;

  @override
  State<CreatorCommerceMockupHost> createState() =>
      _CreatorCommerceMockupHostState();
}

class _CreatorCommerceMockupHostState extends State<CreatorCommerceMockupHost> {
  late CreatorCommerceScreen _screen = widget.initialScreen;

  void _open(CreatorCommerceScreen screen) => setState(() => _screen = screen);

  @override
  Widget build(BuildContext context) {
    final index = switch (_screen) {
      CreatorCommerceScreen.feed => 0,
      CreatorCommerceScreen.discover => 1,
      CreatorCommerceScreen.shop => 2,
      _ => 3,
    };

    final body = switch (_screen) {
      CreatorCommerceScreen.feed => FeedConcept(
        catalog: widget.catalog,
        onOpenCreator: () => _open(CreatorCommerceScreen.creator),
      ),
      CreatorCommerceScreen.discover => DiscoverConcept(
        catalog: widget.catalog,
      ),
      CreatorCommerceScreen.shop => ShopConcept(catalog: widget.catalog),
      CreatorCommerceScreen.creator => CreatorConcept(
        catalog: widget.catalog,
        onBack: () => _open(CreatorCommerceScreen.feed),
        onCreate: () => _open(CreatorCommerceScreen.compose),
        onAiStudio: () => _open(CreatorCommerceScreen.aiStudio),
      ),
      CreatorCommerceScreen.compose => ComposeConcept(
        product: widget.catalog.artisanProduct,
        onBack: () => _open(CreatorCommerceScreen.creator),
        onAiStudio: () => _open(CreatorCommerceScreen.aiStudio),
      ),
      CreatorCommerceScreen.aiStudio => AiStudioConcept(
        product: widget.catalog.studioProduct,
        onBack: () => _open(CreatorCommerceScreen.creator),
      ),
    };

    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) {
          _open(switch (value) {
            0 => CreatorCommerceScreen.feed,
            1 => CreatorCommerceScreen.discover,
            2 => CreatorCommerceScreen.shop,
            _ => CreatorCommerceScreen.creator,
          });
        },
        backgroundColor: AppTheme.cardBg,
        indicatorColor: AppTheme.terracotta.withValues(alpha: .12),
        height: 70,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dynamic_feed_outlined),
            selectedIcon: Icon(Icons.dynamic_feed),
            label: 'Feed',
          ),
          NavigationDestination(
            icon: Icon(Icons.style_outlined),
            selectedIcon: Icon(Icons.style),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Shop',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'You',
          ),
        ],
      ),
    );
  }
}

class _ScreenHeader extends StatelessWidget {
  const _ScreenHeader({
    required this.eyebrow,
    required this.title,
    this.status,
  });

  final String eyebrow;
  final String title;
  final String? status;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.terracotta,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(title, style: Theme.of(context).textTheme.headlineLarge),
              ],
            ),
          ),
          if (status != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.baobab.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.baobab,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.notifications_none_rounded),
            ),
        ],
      ),
    );
  }
}

class FeedConcept extends StatefulWidget {
  const FeedConcept({
    super.key,
    required this.catalog,
    required this.onOpenCreator,
  });

  final CreatorCommerceCatalog catalog;
  final VoidCallback onOpenCreator;

  @override
  State<FeedConcept> createState() => _FeedConceptState();
}

class _FeedConceptState extends State<FeedConcept> {
  bool _followingOnly = false;

  void _showPreferences() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.cardBg,
      showDragHandle: true,
      builder: (context) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(22, 0, 22, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Shape your feed',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 8),
              Text(
                'Your likes, saves and followed artisans make this feed more personal over time.',
              ),
              SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text('Handmade jewellery')),
                  Chip(label: Text('Homeware')),
                  Chip(label: Text('Slow fashion')),
                  Chip(label: Text('Local gifts')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = widget.catalog;
    final onOpenCreator = widget.onOpenCreator;
    final livePosts = _followingOnly
        ? catalog.followingPosts
        : (catalog.posts.isNotEmpty ? catalog.posts : catalog.followingPosts);
    final feedCards = <Widget>[];

    for (var index = 0; index < livePosts.length && index < 3; index++) {
      final post = livePosts[index];
      final shop = catalog.shopFor(post.shopId);
      final product =
          catalog.productForShop(post.shopId) ??
          (catalog.products.length > index ? catalog.products[index] : null);
      feedCards.add(
        _FeedPost(
          artisan: post.shopName ?? shop?.name ?? 'Artisan Lane maker',
          location: '${shop?.location ?? 'South Africa'} · ${post.timeAgo}',
          kind: _kindForIndex(index),
          format: 'REAL SHOP POST',
          caption: post.caption.trim().isEmpty
              ? product?.description ??
                    'A new handmade piece from this artisan.'
              : post.caption,
          product: product?.title ?? 'Explore this artisan’s shop',
          price: product == null ? 'View shop' : _priceLabel(product.price),
          likes: 'Preview',
          comments: 'Preview',
          imageUrl: post.mediaUrls.isNotEmpty
              ? post.mediaUrls.first
              : product?.primaryImage,
          avatarUrl: post.shopLogoUrl ?? shop?.logoUrl,
          productImageUrl: product?.primaryImage,
          productId: product?.id,
          onOpenCreator: onOpenCreator,
        ),
      );
    }

    if (feedCards.isEmpty && catalog.products.isNotEmpty) {
      for (
        var index = 0;
        index < catalog.products.length && index < 3;
        index++
      ) {
        final product = catalog.products[index];
        final shop = catalog.shopFor(product.shopId);
        feedCards.add(
          _FeedPost(
            artisan: product.shopName ?? shop?.name ?? 'Artisan Lane maker',
            location: shop?.location ?? 'South Africa',
            kind: _kindForIndex(index),
            format: 'REAL PRODUCT · DEMO STORY',
            caption: product.description?.trim().isNotEmpty == true
                ? product.description!
                : 'A handmade piece from ${product.shopName ?? shop?.name ?? 'an Artisan Lane maker'}.',
            product: product.title,
            price: _priceLabel(product.price),
            likes: 'Preview',
            comments: 'Preview',
            imageUrl: product.primaryImage,
            avatarUrl: product.shopLogoUrl ?? shop?.logoUrl,
            productImageUrl: product.primaryImage,
            productId: product.id,
            onOpenCreator: onOpenCreator,
          ),
        );
      }
    }

    if (feedCards.isEmpty) {
      feedCards.addAll([
        _FeedPost(
          artisan: 'Thando Made',
          location: 'Johannesburg · Demo',
          kind: CraftKind.earrings,
          format: 'DEMO STORY',
          caption:
              'From raw brass to a pair of sunburst earrings. Each line is cut and polished by hand.',
          product: 'Sunburst brass earrings',
          price: 'R 480',
          likes: 'Preview',
          comments: 'Preview',
          onOpenCreator: onOpenCreator,
        ),
        const _FeedPost(
          artisan: 'Imbali Ceramics',
          location: 'Cape Town · Demo',
          kind: CraftKind.ceramic,
          format: 'DEMO STORY',
          caption:
              'The Karoo collection is here — slow-fired stoneware inspired by desert skies.',
          product: 'Karoo serving bowl',
          price: 'R 720',
          likes: 'Preview',
          comments: 'Preview',
        ),
      ]);
    }

    final storyShops = catalog.shops.take(6).toList(growable: false);
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                _ScreenHeader(
                  eyebrow: 'Artisan Lane',
                  title: 'Made with a story',
                  status: catalog.hasLiveCatalog
                      ? (catalog.usesFallback ? 'Live + demo' : 'Live data')
                      : 'Demo fallback',
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _Pill(
                        label: 'For you',
                        selected: !_followingOnly,
                        onTap: () => setState(() => _followingOnly = false),
                      ),
                      const SizedBox(width: 8),
                      _Pill(
                        label: 'Following',
                        selected: _followingOnly,
                        onTap: () => setState(() => _followingOnly = true),
                      ),
                      const Spacer(),
                      IconButton.filledTonal(
                        onPressed: _showPreferences,
                        icon: const Icon(Icons.tune_rounded, size: 19),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 88,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      const _StoryBubble(
                        label: 'Your story',
                        kind: CraftKind.logo,
                        add: true,
                      ),
                      if (storyShops.isNotEmpty)
                        ...storyShops.asMap().entries.map(
                          (entry) => _StoryBubble(
                            label: entry.value.name,
                            kind: _kindForIndex(entry.key),
                            imageUrl: entry.value.logoUrl,
                          ),
                        )
                      else ...const [
                        _StoryBubble(label: 'Thando', kind: CraftKind.earrings),
                        _StoryBubble(label: 'Lindiwe', kind: CraftKind.basket),
                        _StoryBubble(label: 'Mia', kind: CraftKind.ceramic),
                        _StoryBubble(label: 'Naledi', kind: CraftKind.textile),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate.fixed([
              ...feedCards,
              const SizedBox(height: 24),
            ]),
          ),
        ],
      ),
    );
  }
}

class _StoryBubble extends StatelessWidget {
  const _StoryBubble({
    required this.label,
    required this.kind,
    this.add = false,
    this.imageUrl,
  });

  final String label;
  final CraftKind kind;
  final bool add;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 74,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 58,
                height: 58,
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.ochre,
                      AppTheme.terracotta,
                      AppTheme.baobab,
                    ],
                  ),
                ),
                child: ClipOval(
                  child: _MediaArtwork(
                    imageUrl: imageUrl,
                    kind: kind,
                    compact: true,
                  ),
                ),
              ),
              if (add)
                const Positioned(
                  right: -2,
                  bottom: -1,
                  child: CircleAvatar(
                    radius: 10,
                    backgroundColor: AppTheme.terracotta,
                    child: Icon(Icons.add, color: Colors.white, size: 14),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppTheme.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _FeedPost extends StatefulWidget {
  const _FeedPost({
    required this.artisan,
    required this.location,
    required this.kind,
    required this.format,
    required this.caption,
    required this.product,
    required this.price,
    required this.likes,
    required this.comments,
    this.imageUrl,
    this.avatarUrl,
    this.productImageUrl,
    this.productId,
    this.onOpenCreator,
  });

  final String artisan;
  final String location;
  final CraftKind kind;
  final String format;
  final String caption;
  final String product;
  final String price;
  final String likes;
  final String comments;
  final String? imageUrl;
  final String? avatarUrl;
  final String? productImageUrl;
  final String? productId;
  final VoidCallback? onOpenCreator;

  @override
  State<_FeedPost> createState() => _FeedPostState();
}

class _FeedPostState extends State<_FeedPost> {
  bool _liked = false;
  bool _saved = false;
  bool _following = false;

  String get artisan => widget.artisan;
  String get location => widget.location;
  CraftKind get kind => widget.kind;
  String get format => widget.format;
  String get caption => widget.caption;
  String get product => widget.product;
  String get price => widget.price;
  String get likes => widget.likes;
  String get comments => widget.comments;
  String? get imageUrl => widget.imageUrl;
  String? get avatarUrl => widget.avatarUrl;
  String? get productImageUrl => widget.productImageUrl;
  String? get productId => widget.productId;
  VoidCallback? get onOpenCreator => widget.onOpenCreator;

  void _showComments() {
    final controller = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardBg,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          0,
          18,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Join the conversation',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Ask $artisan about the process or this piece.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Write a thoughtful comment…',
                suffixIcon: IconButton(
                  onPressed: () {
                    if (controller.text.trim().isEmpty) return;
                    Navigator.pop(sheetContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Comment added to this preview.'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.arrow_upward_rounded),
                ),
              ),
            ),
          ],
        ),
      ),
    ).whenComplete(controller.dispose);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 7, 16, 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.clay),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                ClipOval(
                  child: SizedBox(
                    width: 42,
                    height: 42,
                    child: _MediaArtwork(
                      imageUrl: avatarUrl,
                      kind: kind,
                      compact: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: onOpenCreator,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                artisan,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified,
                              size: 15,
                              color: AppTheme.baobab,
                            ),
                          ],
                        ),
                        Text(
                          location,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ),
                OutlinedButton(
                  onPressed: () => setState(() => _following = !_following),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: Text(_following ? 'Following' : 'Follow'),
                ),
              ],
            ),
          ),
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 1.06,
                child: _MediaArtwork(imageUrl: imageUrl, kind: kind),
              ),
              Positioned(
                left: 14,
                top: 14,
                child: _Badge(label: format, icon: Icons.auto_awesome),
              ),
              const Positioned(
                right: 14,
                top: 14,
                child: _Badge(label: '1 / 3'),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _liked = !_liked),
                  icon: Icon(
                    _liked ? Icons.favorite_rounded : Icons.favorite_border,
                    color: _liked ? AppTheme.terracotta : AppTheme.textPrimary,
                    size: 23,
                  ),
                ),
                Text(
                  _liked ? 'Liked' : likes,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: _showComments,
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 22),
                ),
                Text(comments, style: Theme.of(context).textTheme.labelMedium),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Post ready to share.')),
                  ),
                  icon: const Icon(Icons.send_outlined, size: 22),
                ),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _saved = !_saved),
                  icon: Icon(
                    _saved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 12),
            child: Text(
              caption,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(height: 1.45),
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.bone.withValues(alpha: .7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: SizedBox(
                    width: 54,
                    height: 54,
                    child: _MediaArtwork(
                      imageUrl: productImageUrl ?? imageUrl,
                      kind: kind,
                      compact: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        price,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonal(
                  onPressed: productId == null
                      ? null
                      : () => context.push('/home/product/$productId'),
                  style: FilledButton.styleFrom(
                    foregroundColor: AppTheme.terracotta,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: const Text('View'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DiscoverConcept extends StatefulWidget {
  const DiscoverConcept({super.key, required this.catalog});

  final CreatorCommerceCatalog catalog;

  @override
  State<DiscoverConcept> createState() => _DiscoverConceptState();
}

class _DiscoverConceptState extends State<DiscoverConcept> {
  int _index = 0;
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;
  bool _isDismissing = false;

  CreatorCommerceCatalog get catalog => widget.catalog;

  void _advance(String message) {
    final count = catalog.products.isEmpty ? 1 : catalog.products.length;
    setState(() => _index = (_index + 1) % count);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
    );
  }

  void _updateDrag(DragUpdateDetails details) {
    if (_isDismissing) return;
    setState(() {
      _isDragging = true;
      _dragOffset += Offset(details.delta.dx, details.delta.dy * .16);
    });
  }

  Future<void> _finishDrag(DragEndDetails details) async {
    if (_isDismissing) return;
    final velocity = details.velocity.pixelsPerSecond.dx;
    final shouldDismiss = _dragOffset.dx.abs() >= 90 || velocity.abs() >= 650;
    if (!shouldDismiss) {
      setState(() {
        _isDragging = false;
        _dragOffset = Offset.zero;
      });
      return;
    }
    await _dismiss(_dragOffset.dx == 0 ? velocity.sign : _dragOffset.dx.sign);
  }

  Future<void> _dismiss(double direction) async {
    if (_isDismissing) return;
    final liked = direction > 0;
    setState(() {
      _isDragging = false;
      _isDismissing = true;
      _dragOffset = Offset(
        MediaQuery.sizeOf(context).width * 1.35 * direction,
        -24,
      );
    });
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;
    final count = catalog.products.isEmpty ? 1 : catalog.products.length;
    setState(() {
      _index = (_index + 1) % count;
      _dragOffset = Offset.zero;
      _isDismissing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          liked
              ? 'Loved — your recommendations just improved.'
              : 'Skipped — we’ll show fewer pieces like this.',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = catalog.products;
    final product = products.isEmpty
        ? null
        : products[_index % products.length];
    final shop = catalog.shopFor(product?.shopId) ?? catalog.heroShop;
    final tags = product?.tags.take(3).toList(growable: false) ?? const [];
    return SafeArea(
      child: Column(
        children: [
          _ScreenHeader(
            eyebrow: 'Taste builder',
            title: 'Find your kind of craft',
            status: product == null ? 'Demo fallback' : 'Live product',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'A few quick choices make your Feed and Shop feel more like you.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(height: 1.45),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  products.isEmpty
                      ? 'Demo'
                      : '${_index + 1} of ${products.length}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: LinearProgressIndicator(
              value: products.isEmpty ? .5 : (_index + 1) / products.length,
              minHeight: 5,
              borderRadius: BorderRadius.circular(4),
              backgroundColor: AppTheme.clay,
              color: AppTheme.terracotta,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 35,
                  right: 35,
                  top: 18,
                  bottom: 16,
                  child: Transform.rotate(
                    angle: -.025,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.clay,
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 22,
                  right: 22,
                  top: 0,
                  bottom: 28,
                  child: GestureDetector(
                    key: const Key('discover-swipe-card'),
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragUpdate: _updateDrag,
                    onHorizontalDragEnd: _finishDrag,
                    child: AnimatedContainer(
                      duration: _isDragging
                          ? Duration.zero
                          : const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      transformAlignment: Alignment.center,
                      transform: Matrix4.translationValues(
                        _dragOffset.dx,
                        _dragOffset.dy,
                        0,
                      )..rotateZ(_dragOffset.dx / 1450),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.indigo.withValues(alpha: .12),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          Expanded(
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                _MediaArtwork(
                                  imageUrl: product?.primaryImage,
                                  kind: CraftKind.basket,
                                ),
                                Positioned(
                                  left: 16,
                                  top: 16,
                                  child: _Badge(
                                    label: (shop?.location ?? 'South Africa')
                                        .toUpperCase(),
                                    icon: Icons.place_outlined,
                                  ),
                                ),
                                Positioned(
                                  right: 16,
                                  top: 16,
                                  child: _Badge(
                                    label: product == null
                                        ? 'DEMO PRODUCT'
                                        : 'REAL PRODUCT',
                                  ),
                                ),
                                Positioned(
                                  left: 18,
                                  top: 76,
                                  child: Opacity(
                                    opacity: (_dragOffset.dx / 110).clamp(0, 1),
                                    child: const _SwipeStamp(
                                      label: 'LOVE IT',
                                      icon: Icons.favorite,
                                      color: AppTheme.baobab,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 18,
                                  top: 76,
                                  child: Opacity(
                                    opacity: (-_dragOffset.dx / 110).clamp(
                                      0,
                                      1,
                                    ),
                                    child: const _SwipeStamp(
                                      label: 'NOT FOR ME',
                                      icon: Icons.close,
                                      color: AppTheme.terracotta,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        product?.title ?? 'Ilala market basket',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.headlineMedium,
                                      ),
                                    ),
                                    Text(
                                      product == null
                                          ? 'R 890'
                                          : _priceLabel(product.price),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            color: AppTheme.terracotta,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '${product?.shopName ?? shop?.name ?? 'Lindiwe Weaves'} · ${product?.categoryName ?? 'Handmade'} · ${product?.stockQty == 1 ? 'One of a kind' : 'Available now'}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 7,
                                  runSpacing: 7,
                                  children: tags.isEmpty
                                      ? const [
                                          _MiniTag('Natural'),
                                          _MiniTag('Homeware'),
                                          _MiniTag('Warm neutral'),
                                        ]
                                      : tags
                                            .map((tag) => _MiniTag(tag))
                                            .toList(growable: false),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(26, 8, 26, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SwipeAction(
                  icon: Icons.close,
                  label: 'Not for me',
                  color: AppTheme.textSecondary,
                  onTap: () => _dismiss(-1),
                ),
                _SwipeAction(
                  icon: Icons.bookmark_border,
                  label: 'Save',
                  color: AppTheme.ochre,
                  onTap: () => _advance('Saved to your inspiration board.'),
                ),
                _SwipeAction(
                  icon: Icons.favorite,
                  label: 'Love it',
                  color: AppTheme.terracotta,
                  large: true,
                  onTap: () => _dismiss(1),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextButton.icon(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                backgroundColor: AppTheme.cardBg,
                showDragHandle: true,
                builder: (context) => const SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(22, 0, 22, 28),
                    child: Text(
                      'Preference controls\n\nMaterials: Natural, textile, ceramic\nStyle: Warm, contemporary, locally made\nBudget: R250 – R1,500',
                    ),
                  ),
                ),
              ),
              icon: const Icon(Icons.tune, size: 17),
              label: const Text('Tune my preferences'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwipeStamp extends StatelessWidget {
  const _SwipeStamp({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -.08,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.cardBg.withValues(alpha: .9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 2.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwipeAction extends StatelessWidget {
  const _SwipeAction({
    required this.icon,
    required this.label,
    required this.color,
    this.large = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool large;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Column(
        children: [
          Container(
            width: large ? 62 : 54,
            height: large ? 62 : 54,
            decoration: BoxDecoration(
              color: large ? color : AppTheme.cardBg,
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: .45)),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: .12),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: large ? Colors.white : color,
              size: large ? 28 : 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class ShopConcept extends StatefulWidget {
  const ShopConcept({super.key, required this.catalog});

  final CreatorCommerceCatalog catalog;

  @override
  State<ShopConcept> createState() => _ShopConceptState();
}

class _ShopConceptState extends State<ShopConcept> {
  String _query = '';
  int _filter = 0;

  CreatorCommerceCatalog get catalog => widget.catalog;

  @override
  Widget build(BuildContext context) {
    const demoProducts = [
      ('Sunburst earrings', 'R 480', CraftKind.earrings),
      ('Karoo serving bowl', 'R 720', CraftKind.ceramic),
      ('Ilala market basket', 'R 890', CraftKind.basket),
      ('Indigo table runner', 'R 640', CraftKind.textile),
    ];
    final normalizedQuery = _query.trim().toLowerCase();
    final liveProducts = catalog.products
        .where((product) {
          final matchesQuery =
              normalizedQuery.isEmpty ||
              product.title.toLowerCase().contains(normalizedQuery) ||
              (product.shopName ?? '').toLowerCase().contains(normalizedQuery);
          final matchesFilter = _filter != 2 || product.price < 500;
          return matchesQuery && matchesFilter;
        })
        .take(20)
        .toList(growable: false);

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _ScreenHeader(
              eyebrow: 'Curated for you',
              title: 'Shop the lane',
              status: liveProducts.isEmpty ? 'Demo fallback' : 'Live catalogue',
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Search handmade pieces, artisans…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() {
                      _query = '';
                      _filter = 0;
                    }),
                    icon: const Icon(Icons.tune_rounded),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _Pill(
                    label: 'For you',
                    selected: _filter == 0,
                    onTap: () => setState(() => _filter = 0),
                  ),
                  const SizedBox(width: 8),
                  _Pill(
                    label: 'New drops',
                    selected: _filter == 1,
                    onTap: () => setState(() => _filter = 1),
                  ),
                  const SizedBox(width: 8),
                  _Pill(
                    label: 'Under R500',
                    selected: _filter == 2,
                    onTap: () => setState(() => _filter = 2),
                  ),
                  const SizedBox(width: 8),
                  _Pill(
                    label: 'Near me',
                    selected: _filter == 3,
                    onTap: () => setState(() => _filter = 3),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.indigo,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GIFT CONCIERGE',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: AppTheme.ochre,
                                letterSpacing: 1.5,
                              ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Tell us who it’s for.\nWe’ll curate the rest.',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(color: Colors.white, height: 1.25),
                        ),
                        const SizedBox(height: 10),
                        FilledButton.tonal(
                          onPressed: () => showModalBottomSheet<void>(
                            context: context,
                            backgroundColor: AppTheme.cardBg,
                            showDragHandle: true,
                            builder: (context) => const SafeArea(
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(22, 0, 22, 28),
                                child: Text(
                                  'Gift concierge\n\n1. Choose the occasion\n2. Set a budget\n3. Pick their style\n4. Receive a curated artisan shortlist',
                                ),
                              ),
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.bone,
                            foregroundColor: AppTheme.indigo,
                          ),
                          child: const Text('Build a gift'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(
                    width: 110,
                    height: 120,
                    child: ClipRRect(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                      child: _MediaArtwork(kind: CraftKind.gift),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            sliver: SliverGrid.builder(
              itemCount: liveProducts.isEmpty
                  ? demoProducts.length
                  : liveProducts.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: .67,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              itemBuilder: (context, index) {
                if (liveProducts.isNotEmpty) {
                  final product = liveProducts[index];
                  return _ProductCard(
                    name: product.title,
                    price: _priceLabel(product.price),
                    kind: _kindForIndex(index),
                    imageUrl: product.primaryImage,
                    shopName: product.shopName,
                    productId: product.id,
                    reason: index == 0
                        ? 'Recommended from your live catalogue'
                        : null,
                  );
                }
                final product = demoProducts[index];
                return _ProductCard(
                  name: product.$1,
                  price: product.$2,
                  kind: product.$3,
                  reason: index == 0 ? 'Because you liked brass' : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.name,
    required this.price,
    required this.kind,
    this.reason,
    this.imageUrl,
    this.shopName,
    this.productId,
  });

  final String name;
  final String price;
  final CraftKind kind;
  final String? reason;
  final String? imageUrl;
  final String? shopName;
  final String? productId;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: productId == null
          ? null
          : () => context.push('/home/product/$productId'),
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.clay),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _MediaArtwork(imageUrl: imageUrl, kind: kind),
                    Positioned(
                      right: 9,
                      top: 9,
                      child: CircleAvatar(
                        radius: 17,
                        backgroundColor: AppTheme.cardBg.withValues(alpha: .92),
                        child: const Icon(
                          Icons.favorite_border,
                          size: 19,
                          color: AppTheme.terracotta,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (reason != null) ...[
                      Text(
                        reason!,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.baobab,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                    ],
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.textPrimary,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      price,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (shopName != null) ...[
                      Text(
                        shopName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      const SizedBox(height: 3),
                    ],
                    Row(
                      children: [
                        const Icon(
                          Icons.verified,
                          color: AppTheme.baobab,
                          size: 13,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            'Verified artisan',
                            style: Theme.of(context).textTheme.labelSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CreatorConcept extends StatelessWidget {
  const CreatorConcept({
    super.key,
    required this.catalog,
    required this.onBack,
    required this.onCreate,
    required this.onAiStudio,
  });

  final CreatorCommerceCatalog catalog;
  final VoidCallback onBack;
  final VoidCallback onCreate;
  final VoidCallback onAiStudio;

  @override
  Widget build(BuildContext context) {
    final shop = catalog.creatorShop;
    final product = catalog.artisanProduct;
    final shopProducts = catalog.products
        .where((entry) => entry.shopId == (shop?.id ?? product?.shopId))
        .take(6)
        .toList(growable: false);
    final shopPosts = catalog.posts
        .where((entry) => entry.shopId == (shop?.id ?? product?.shopId))
        .take(6)
        .toList(growable: false);
    final galleryUrls = <String>[
      ...shopPosts.expand((entry) => entry.mediaUrls.take(1)),
      ...shopProducts.map((entry) => entry.primaryImage),
    ].where((url) => url.trim().isNotEmpty).take(6).toList(growable: false);
    final shopName = shop?.name ?? product?.shopName ?? 'Thando Made';
    final shopLocation = shop?.location?.trim();
    final shopBio = shop?.bio?.trim().isNotEmpty == true
        ? shop!.bio!.trim()
        : shop?.brandStory?.trim().isNotEmpty == true
        ? shop!.brandStory!.trim()
        : 'Modern craft made slowly by hand. Small batches, local stories, pieces made to keep.';
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Stack(
              children: [
                SizedBox(
                  height: 228,
                  width: double.infinity,
                  child: _MediaArtwork(
                    imageUrl: shop?.coverImageUrl ?? product?.primaryImage,
                    kind: CraftKind.textile,
                  ),
                ),
                Positioned(
                  left: 14,
                  top: 10,
                  child: IconButton.filledTonal(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back),
                  ),
                ),
                Positioned(
                  right: 14,
                  top: 10,
                  child: Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: () =>
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '$shopName profile ready to share.',
                                ),
                              ),
                            ),
                        icon: const Icon(Icons.share_outlined),
                      ),
                      const SizedBox(width: 6),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_horiz),
                        tooltip: 'More profile actions',
                        onSelected: (value) => ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(value))),
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'Profile link copied.',
                            child: Text('Copy profile link'),
                          ),
                          PopupMenuItem(
                            value: 'Creator muted in this preview.',
                            child: Text('Mute creator'),
                          ),
                          PopupMenuItem(
                            value: 'Report flow opened in this preview.',
                            child: Text('Report profile'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.clay),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipOval(
                        child: SizedBox(
                          width: 64,
                          height: 64,
                          child: _MediaArtwork(
                            imageUrl: shop?.logoUrl ?? product?.shopLogoUrl,
                            kind: CraftKind.earrings,
                            compact: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    shopName,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.headlineMedium,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                const Icon(
                                  Icons.verified,
                                  color: AppTheme.baobab,
                                  size: 18,
                                ),
                              ],
                            ),
                            Text(
                              '${shop == null ? '@thandomade' : '@${shop.slug}'}${shopLocation?.isNotEmpty == true ? ' · $shopLocation' : ''}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 12,
                              runSpacing: 4,
                              children: [
                                _Stat(
                                  value: '${shopProducts.length}',
                                  label: 'live products',
                                ),
                                _Stat(
                                  value: '${shopPosts.length}',
                                  label: 'live posts',
                                ),
                                const _Stat(
                                  value: 'Preview',
                                  label: 'insights',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    shopBio,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: () =>
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Following $shopName')),
                              ),
                          child: const Text('Follow'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => showModalBottomSheet<void>(
                            context: context,
                            backgroundColor: AppTheme.cardBg,
                            showDragHandle: true,
                            builder: (context) => SafeArea(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  22,
                                  0,
                                  22,
                                  28,
                                ),
                                child: TextField(
                                  autofocus: true,
                                  decoration: InputDecoration(
                                    labelText:
                                        'Ask $shopName for a custom piece',
                                    hintText:
                                        'Describe colours, size and occasion…',
                                    suffixIcon: const Icon(Icons.send_outlined),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          child: const Text('Ask for custom'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.bone.withValues(alpha: .65),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.workspace_premium_outlined,
                          color: AppTheme.baobab,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            shop == null
                                ? 'DEMO SHOP · Preview profile and engagement data'
                                : 'LIVE SHOP · Marketplace details from Artisan Lane',
                            style: const TextStyle(fontSize: 11.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _CreatorTool(
                        icon: Icons.add_circle_outline,
                        title: 'Create post',
                        subtitle: 'Photo, video, story',
                        onTap: onCreate,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CreatorTool(
                        icon: Icons.auto_awesome,
                        title: 'AI studio',
                        subtitle: 'List & style products',
                        onTap: onAiStudio,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPersistentHeader(pinned: true, delegate: _TabsDelegate()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
            sliver: SliverGrid.builder(
              itemCount: galleryUrls.isEmpty ? 6 : galleryUrls.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemBuilder: (context, index) => _MediaArtwork(
                imageUrl: galleryUrls.isEmpty ? null : galleryUrls[index],
                kind: _kindForIndex(index),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreatorTool extends StatelessWidget {
  const _CreatorTool({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.clay),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.terracotta.withValues(alpha: .1),
              child: Icon(icon, color: AppTheme.terracotta, size: 19),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.labelSmall,
        children: [
          TextSpan(
            text: '$value ',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          TextSpan(text: label),
        ],
      ),
    );
  }
}

class _TabsDelegate extends SliverPersistentHeaderDelegate {
  @override
  double get minExtent => 48;
  @override
  double get maxExtent => 48;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: AppTheme.scaffoldBg,
      child: Row(
        children: [
          const Expanded(
            child: Center(child: _TabLabel(label: 'Posts', selected: true)),
          ),
          const Expanded(
            child: Center(child: _TabLabel(label: 'Shop')),
          ),
          const Expanded(
            child: Center(child: _TabLabel(label: 'About')),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      false;
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({required this.label, this.selected = false});
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: selected
            ? const Border(
                bottom: BorderSide(color: AppTheme.terracotta, width: 2),
              )
            : null,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: selected ? AppTheme.terracotta : AppTheme.textSecondary,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

class ComposeConcept extends StatefulWidget {
  const ComposeConcept({
    super.key,
    this.product,
    required this.onBack,
    required this.onAiStudio,
  });
  final Product? product;
  final VoidCallback onBack;
  final VoidCallback onAiStudio;

  @override
  State<ComposeConcept> createState() => _ComposeConceptState();
}

class _ComposeConceptState extends State<ComposeConcept> {
  final _picker = ImagePicker();
  late final TextEditingController _captionController;
  File? _selectedFile;
  bool _isPublishing = false;

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController(
      text:
          'A first look at the craft and story behind ${widget.product?.title ?? 'our new collection'}…',
    );
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final selected = await _picker.pickImage(
      source: source,
      maxWidth: 1800,
      maxHeight: 1800,
      imageQuality: 92,
    );
    if (selected != null && mounted) {
      setState(() => _selectedFile = File(selected.path));
    }
  }

  Future<void> _useDemoProductPhoto() async {
    final data = await rootBundle.load(
      'assets/preview/angel-bear-original.jpg',
    );
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}artisan-lane-demo-upload.jpg',
    );
    await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    if (!mounted) return;
    setState(() => _selectedFile = file);
  }

  void _showMediaPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.cardBg,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add product media',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _pickImage(ImageSource.camera);
                },
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Take a photo'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _pickImage(ImageSource.gallery);
                },
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Choose from gallery'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _useDemoProductPhoto();
                },
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Use demo product photo'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPreview() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardBg,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Post preview',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              AspectRatio(
                aspectRatio: 1.2,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: _selectedFile == null
                      ? _MediaArtwork(
                          imageUrl: widget.product?.primaryImage,
                          kind: CraftKind.earrings,
                        )
                      : Image.file(_selectedFile!, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 12),
              Text(_captionController.text),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _publish() async {
    if (_captionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a caption before sharing.')),
      );
      return;
    }
    setState(() => _isPublishing = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final service = SupabaseService(Supabase.instance.client);
      final shop = user == null ? null : await service.getVendorShop(user.id);
      if (user != null && shop != null) {
        final urls = <String>[];
        if (_selectedFile != null) {
          urls.add(
            await service.uploadShopImage(
              user.id,
              _selectedFile!,
              folder: 'posts',
            ),
          );
        } else if (widget.product != null) {
          urls.add(widget.product!.primaryImage);
        }
        await service.createShopPost(
          shop.id,
          caption: _captionController.text.trim(),
          mediaUrls: urls,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post published to your live shop.')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Preview saved locally. Sign in as an artisan to publish it.',
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not publish: $error')));
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.close),
              ),
              Expanded(
                child: Text(
                  'Create',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              TextButton(onPressed: _showPreview, child: const Text('Preview')),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'What are you sharing?',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _FormatChoice(
                icon: Icons.photo_camera_outlined,
                label: 'Photo',
                selected: true,
              ),
              _FormatChoice(
                icon: Icons.video_camera_back_outlined,
                label: 'Short video',
              ),
              _FormatChoice(
                icon: Icons.view_carousel_outlined,
                label: 'Carousel',
              ),
              _FormatChoice(icon: Icons.menu_book_outlined, label: 'Tutorial'),
              _FormatChoice(icon: Icons.poll_outlined, label: 'Poll'),
              _FormatChoice(icon: Icons.live_tv_outlined, label: 'Go live'),
            ],
          ),
          const SizedBox(height: 18),
          AspectRatio(
            aspectRatio: 1.45,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: _selectedFile == null
                  ? _MediaArtwork(
                      imageUrl: widget.product?.primaryImage,
                      kind: CraftKind.earrings,
                    )
                  : Image.file(_selectedFile!, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: _showMediaPicker,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Add media'),
              ),
              const Spacer(),
              Text(
                _selectedFile == null ? 'Live product photo' : '1 selected',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            minLines: 3,
            maxLines: 5,
            controller: _captionController,
            decoration: const InputDecoration(labelText: 'Tell the story'),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: widget.onAiStudio,
              icon: const Icon(Icons.auto_awesome, size: 17),
              label: const Text('Polish with AI'),
            ),
          ),
          const SizedBox(height: 8),
          _SectionCard(
            icon: Icons.shopping_bag_outlined,
            title: 'Link products',
            subtitle: 'People can shop without leaving your post.',
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.bone.withValues(alpha: .7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: _MediaArtwork(
                        imageUrl: widget.product?.primaryImage,
                        kind: CraftKind.earrings,
                        compact: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.product?.title ?? 'Sunburst brass earrings',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(color: AppTheme.textPrimary),
                        ),
                        Text(
                          widget.product == null
                              ? 'R 480'
                              : _priceLabel(widget.product!.price),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.check_circle, color: AppTheme.baobab),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const _SectionCard(
            icon: Icons.forum_outlined,
            title: 'Conversation',
            subtitle: 'Comments on · Hide like count off',
          ),
          const SizedBox(height: 12),
          const _SectionCard(
            icon: Icons.schedule_outlined,
            title: 'Publish now',
            subtitle: 'Or schedule for your best engagement time',
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _isPublishing ? null : _publish,
            icon: _isPublishing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: Text(_isPublishing ? 'Publishing…' : 'Share post'),
          ),
        ],
      ),
    );
  }
}

class _FormatChoice extends StatelessWidget {
  const _FormatChoice({
    required this.icon,
    required this.label,
    this.selected = false,
  });
  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 106,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: selected ? AppTheme.terracotta : AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? AppTheme.terracotta : AppTheme.clay,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 21,
            color: selected ? Colors.white : AppTheme.terracotta,
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: selected ? Colors.white : AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.child,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.clay),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.terracotta),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.textHint),
            ],
          ),
          if (child != null) ...[const SizedBox(height: 12), child!],
        ],
      ),
    );
  }
}

class AiStudioConcept extends StatefulWidget {
  const AiStudioConcept({super.key, this.product, required this.onBack});
  final Product? product;
  final VoidCallback onBack;

  @override
  State<AiStudioConcept> createState() => _AiStudioConceptState();
}

class _AiStudioConceptState extends State<AiStudioConcept> {
  final _picker = ImagePicker();
  final _promptController = TextEditingController(
    text:
        'Create a premium warm studio scene while keeping the real product unchanged.',
  );
  File? _selectedFile;
  int _selectedStyle = 0;
  bool _generated = true;
  bool _isGenerating = false;
  bool _isExporting = false;
  double _brightness = 0;
  double _warmth = .12;

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final selected = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 94,
    );
    if (selected != null && mounted) {
      setState(() {
        _selectedFile = File(selected.path);
        _generated = false;
      });
    }
  }

  Future<void> _useDemoUpload() async {
    final data = await rootBundle.load(
      'assets/preview/angel-bear-original.jpg',
    );
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}artisan-lane-ai-demo.jpg',
    );
    await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    if (!mounted) return;
    setState(() {
      _selectedFile = file;
      _generated = false;
    });
  }

  void _showHelp() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.cardBg,
      showDragHandle: true,
      builder: (context) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(22, 0, 22, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How the studio works',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 10),
              Text(
                '1. Choose or demo-load a real product photo.\n'
                '2. Crop it, choose a store style and adjust the look.\n'
                '3. Generate the preview, then export and upload only after approval.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cropImage() async {
    final file = _selectedFile;
    if (file == null) return;
    final cropped = await ImageCropper().cropImage(
      sourcePath: file.path,
      compressQuality: 94,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop product photo',
          toolbarColor: AppTheme.terracotta,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: AppTheme.terracotta,
          statusBarLight: false,
          navBarLight: false,
          lockAspectRatio: false,
        ),
      ],
    );
    if (cropped != null && mounted) {
      setState(() {
        _selectedFile = File(cropped.path);
        _generated = false;
      });
    }
  }

  Future<void> _generate() async {
    FocusScope.of(context).unfocus();
    setState(() => _isGenerating = true);
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    setState(() {
      _isGenerating = false;
      _generated = true;
      _brightness = .05;
      _warmth = _selectedStyle == 2 ? 0 : .12;
    });
  }

  Future<void> _exportAndUpload() async {
    if (!_generated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generate the edited image first.')),
      );
      return;
    }
    setState(() => _isExporting = true);
    try {
      final Uint8List sourceBytes;
      if (_selectedFile != null) {
        sourceBytes = await _selectedFile!.readAsBytes();
      } else {
        final data = await rootBundle.load(
          'assets/preview/angel-bear-ai-nursery.png',
        );
        sourceBytes = data.buffer.asUint8List();
      }

      final codec = await ui.instantiateImageCodec(sourceBytes);
      final frame = await codec.getNextFrame();
      final source = frame.image;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final paint = ui.Paint()
        ..colorFilter = ui.ColorFilter.matrix(
          _imageColorMatrix(_brightness, _warmth),
        );
      canvas.drawImage(source, ui.Offset.zero, paint);
      final rendered = await recorder.endRecording().toImage(
        source.width,
        source.height,
      );
      source.dispose();
      codec.dispose();
      final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
      rendered.dispose();
      if (bytes == null) throw Exception('Could not render image');
      final directory = await getTemporaryDirectory();
      final output = File(
        '${directory.path}${Platform.pathSeparator}artisan-lane-ai-${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await output.writeAsBytes(bytes.buffer.asUint8List(), flush: true);

      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final service = SupabaseService(Supabase.instance.client);
        await service.uploadProductImage(user.id, output);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Edited image exported and uploaded successfully.'),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Edited image saved to ${output.path}')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not export image: $error')));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final liveTags =
        widget.product?.tags
            .where((tag) => tag.trim().isNotEmpty)
            .take(4)
            .toList(growable: false) ??
        const <String>[];
    final productTitle = widget.product?.title.toLowerCase() ?? '';
    final suggestionTags = liveTags.isNotEmpty
        ? liveTags
        : productTitle.contains('mobile')
        ? const [
            'baby mobile',
            'nursery decor',
            'hand-sewn felt',
            'South African craft',
          ]
        : const [
            'brass jewellery',
            'handmade earrings',
            'South African design',
            'gift for her',
          ];
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'AI Listing Studio',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      'Your craft. Clearly presented.',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _showHelp,
                icon: const Icon(Icons.help_outline),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.terracotta.withValues(alpha: .1),
                  AppTheme.ochre.withValues(alpha: .12),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.sand),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 23,
                  backgroundColor: AppTheme.terracotta,
                  child: Icon(Icons.auto_awesome, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Add a few honest details. AI will draft the listing—you stay in control of every word and image.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(height: 1.45),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  '1. Product photos',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: const Text('Choose image'),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _useDemoUpload,
              icon: const Icon(Icons.science_outlined, size: 18),
              label: const Text('Load test photo'),
            ),
          ),
          SizedBox(
            height: 178,
            child: Row(
              children: [
                Expanded(
                  child: _AiPhoto(
                    label: _selectedFile == null
                        ? 'REAL LISTING'
                        : 'YOUR PHOTO',
                    kind: CraftKind.earrings,
                    imageFile: _selectedFile,
                    assetPath: _selectedFile == null
                        ? 'assets/preview/angel-bear-original.jpg'
                        : null,
                    imageUrl: _selectedFile == null
                        ? null
                        : widget.product?.primaryImage,
                    muted: true,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: AppTheme.terracotta,
                  ),
                ),
                Expanded(
                  child: _AiPhoto(
                    label: _isGenerating
                        ? 'GENERATING…'
                        : _generated
                        ? 'SHOWCASE RESULT'
                        : 'READY TO GENERATE',
                    kind: CraftKind.earrings,
                    imageFile: _selectedFile,
                    assetPath: _selectedFile == null && _generated
                        ? 'assets/preview/angel-bear-ai-nursery.png'
                        : _selectedFile == null
                        ? 'assets/preview/angel-bear-original.jpg'
                        : null,
                    imageUrl: _selectedFile == null
                        ? null
                        : widget.product?.primaryImage,
                    brightness: _generated ? _brightness : 0,
                    warmth: _generated ? _warmth : 0,
                    isLoading: _isGenerating,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Choose a consistent store look',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 70,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _StyleChoice(
                  label: 'Warm studio',
                  color: const Color(0xFFE7CDB4),
                  selected: _selectedStyle == 0,
                  onTap: () => setState(() => _selectedStyle = 0),
                ),
                _StyleChoice(
                  label: 'Natural linen',
                  color: const Color(0xFFEAE2D3),
                  selected: _selectedStyle == 1,
                  onTap: () => setState(() => _selectedStyle = 1),
                ),
                _StyleChoice(
                  label: 'Clean ivory',
                  color: const Color(0xFFF8F5EF),
                  selected: _selectedStyle == 2,
                  onTap: () => setState(() => _selectedStyle = 2),
                ),
                _StyleChoice(
                  label: 'Deep earth',
                  color: const Color(0xFF5A3728),
                  selected: _selectedStyle == 3,
                  onTap: () => setState(() => _selectedStyle = 3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _promptController,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Describe the new setting',
              prefixIcon: Icon(Icons.auto_awesome_outlined),
            ),
          ),
          if (_selectedFile != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _cropImage,
              icon: const Icon(Icons.crop),
              label: const Text('Crop and straighten'),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              const SizedBox(width: 82, child: Text('Brightness')),
              Expanded(
                child: Slider(
                  value: _brightness,
                  min: -.25,
                  max: .25,
                  onChanged: (value) => setState(() {
                    _brightness = value;
                    _generated = true;
                  }),
                ),
              ),
            ],
          ),
          Row(
            children: [
              const SizedBox(width: 82, child: Text('Warmth')),
              Expanded(
                child: Slider(
                  value: _warmth,
                  min: -.25,
                  max: .25,
                  onChanged: (value) => setState(() {
                    _warmth = value;
                    _generated = true;
                  }),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isGenerating ? null : _generate,
                  icon: _isGenerating
                      ? const SizedBox.square(
                          dimension: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(_isGenerating ? 'Generating…' : 'Generate image'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: 'Reset edits',
                onPressed: () => setState(() {
                  _brightness = 0;
                  _warmth = .12;
                  _generated = false;
                }),
                icon: const Icon(Icons.restart_alt),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppTheme.bone.withValues(alpha: .65),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  color: AppTheme.baobab,
                  size: 20,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Product integrity lock: improves background and lighting, but keeps the real colour, shape and materials.',
                    style: TextStyle(fontSize: 11.5, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '2. AI suggestions',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          _SuggestionCard(
            label: 'TITLE',
            value: widget.product == null
                ? 'Hand-finished sunburst brass earrings'
                : 'Handcrafted ${widget.product!.title}',
            confidence: 'AI preview draft · review before use',
          ),
          const SizedBox(height: 10),
          _SuggestionCard(
            label: 'PRICE GUIDANCE',
            value: widget.product == null
                ? 'R 450 – R 520'
                : '${_priceLabel(widget.product!.price * .9)} – ${_priceLabel(widget.product!.price * 1.1)}',
            confidence: 'Preview range based on the current listing price',
            accent: AppTheme.baobab,
          ),
          const SizedBox(height: 10),
          _SuggestionCard(
            label: 'DESCRIPTION',
            value: widget.product?.description?.trim().isNotEmpty == true
                ? '${widget.product!.description!.trim()} Carefully presented while preserving the artisan’s original product facts.'
                : 'A concise, customer-friendly draft highlighting the materials, process and story behind ${widget.product?.title ?? 'this handmade piece'}.',
            confidence: 'AI preview draft · edit before publishing',
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: suggestionTags.map(_MiniTag.new).toList(growable: false),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _isExporting ? null : _exportAndUpload,
            icon: _isExporting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            label: Text(
              _isExporting ? 'Exporting…' : 'Export & upload edited image',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Nothing publishes without your approval.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

List<double> _imageColorMatrix(double brightness, double warmth) {
  final offset = brightness * 170;
  final warmthOffset = warmth * 120;
  return [
    1,
    0,
    0,
    0,
    offset + warmthOffset,
    0,
    1,
    0,
    0,
    offset,
    0,
    0,
    1,
    0,
    offset - warmthOffset,
    0,
    0,
    0,
    1,
    0,
  ];
}

class _AiPhoto extends StatelessWidget {
  const _AiPhoto({
    required this.label,
    required this.kind,
    this.imageUrl,
    this.assetPath,
    this.imageFile,
    this.muted = false,
    this.brightness = 0,
    this.warmth = 0,
    this.isLoading = false,
  });
  final String label;
  final CraftKind kind;
  final String? imageUrl;
  final String? assetPath;
  final File? imageFile;
  final bool muted;
  final double brightness;
  final double warmth;
  final bool isLoading;

  Widget _buildArtwork({BoxFit fit = BoxFit.cover}) {
    Widget artwork;
    if (imageFile != null) {
      artwork = Image.file(imageFile!, fit: fit);
    } else if (assetPath != null) {
      artwork = Image.asset(assetPath!, fit: fit);
    } else {
      artwork = _MediaArtwork(
        imageUrl: imageUrl,
        kind: kind,
        muted: muted,
        fit: fit,
      );
    }

    return ColorFiltered(
      colorFilter: ColorFilter.matrix(_imageColorMatrix(brightness, warmth)),
      child: artwork,
    );
  }

  Future<void> _openPreview(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .92),
      builder: (dialogContext) => Dialog.fullscreen(
        backgroundColor: AppTheme.indigo,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: .8,
                maxScale: 5,
                boundaryMargin: const EdgeInsets.all(100),
                child: SizedBox(
                  width: viewport.width,
                  height: viewport.height,
                  child: _buildArtwork(fit: BoxFit.contain),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: Theme.of(dialogContext).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    IconButton.filled(
                      key: const Key('close-ai-photo-preview'),
                      tooltip: 'Close image',
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: .16),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            ),
            const SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.only(bottom: 18),
                  child: _Badge(
                    label: 'PINCH TO ZOOM · DRAG TO INSPECT',
                    icon: Icons.zoom_in,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final artwork = _buildArtwork();

    return Semantics(
      button: true,
      label: 'Enlarge $label',
      child: GestureDetector(
        key: ValueKey('enlarge-$label'),
        onTap: isLoading ? null : () => _openPreview(context),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: muted ? AppTheme.clay : AppTheme.terracotta,
              width: muted ? 1 : 2,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              artwork,
              if (isLoading)
                Container(
                  color: AppTheme.indigo.withValues(alpha: .38),
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(color: Colors.white),
                ),
              if (!isLoading)
                Positioned(
                  right: 8,
                  top: 8,
                  child: IgnorePointer(
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppTheme.indigo.withValues(alpha: .72),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.open_in_full,
                        size: 17,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 8,
                bottom: 8,
                child: _Badge(
                  label: label,
                  icon: muted ? Icons.photo_outlined : Icons.auto_awesome,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StyleChoice extends StatelessWidget {
  const _StyleChoice({
    required this.label,
    required this.color,
    this.selected = false,
    this.onTap,
  });
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 86,
        margin: const EdgeInsets.only(right: 8),
        child: Column(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppTheme.terracotta : AppTheme.sand,
                  width: selected ? 3 : 1,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: selected ? AppTheme.terracotta : AppTheme.textSecondary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.label,
    required this.value,
    required this.confidence,
    this.accent = AppTheme.terracotta,
  });
  final String label;
  final String value;
  final String confidence;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.clay),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 46,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textPrimary,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 5),
                Text(confidence, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.edit_outlined, size: 19),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.terracotta : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected ? AppTheme.terracotta : AppTheme.sand,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: selected ? Colors.white : AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, this.icon});
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.indigo.withValues(alpha: .86),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: AppTheme.bone, size: 12),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: .4,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.bone,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.sand),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: AppTheme.textPrimary),
      ),
    );
  }
}

String _priceLabel(double price) {
  final hasCents = price != price.truncateToDouble();
  return 'R ${price.toStringAsFixed(hasCents ? 2 : 0)}';
}

CraftKind _kindForIndex(int index) {
  const kinds = [
    CraftKind.earrings,
    CraftKind.ceramic,
    CraftKind.basket,
    CraftKind.textile,
    CraftKind.gift,
  ];
  return kinds[index % kinds.length];
}

class _MediaArtwork extends StatelessWidget {
  const _MediaArtwork({
    required this.kind,
    this.imageUrl,
    this.compact = false,
    this.muted = false,
    this.fit = BoxFit.cover,
  });

  final CraftKind kind;
  final String? imageUrl;
  final bool compact;
  final bool muted;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final fallbackAsset = switch (kind) {
      CraftKind.basket ||
      CraftKind.textile => 'assets/preview/foldaway-tote.jpg',
      CraftKind.logo || CraftKind.earrings => 'assets/preview/nerd-no1.jpg',
      CraftKind.ceramic ||
      CraftKind.gift => 'assets/preview/angel-bear-original.jpg',
    };
    Widget fallback() => Image.asset(fallbackAsset, fit: fit);
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty) {
      return fallback();
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 180),
      placeholder: (context, _) => fallback(),
      errorWidget: (context, _, _) => fallback(),
    );
  }
}

enum CraftKind { logo, earrings, ceramic, basket, textile, gift }

class CraftArtwork extends StatelessWidget {
  const CraftArtwork({
    super.key,
    required this.kind,
    this.compact = false,
    this.muted = false,
  });

  final CraftKind kind;
  final bool compact;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CraftPainter(kind: kind, compact: compact, muted: muted),
      child: const SizedBox.expand(),
    );
  }
}

class _CraftPainter extends CustomPainter {
  _CraftPainter({
    required this.kind,
    required this.compact,
    required this.muted,
  });
  final CraftKind kind;
  final bool compact;
  final bool muted;

  Color _tone(Color color) =>
      muted ? Color.lerp(color, Colors.grey, .26)! : color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()..isAntiAlias = true;
    final palettes = {
      CraftKind.logo: [AppTheme.bone, AppTheme.clay],
      CraftKind.earrings: [const Color(0xFFE8CEB1), const Color(0xFFCFA77E)],
      CraftKind.ceramic: [const Color(0xFFD8B39A), const Color(0xFF9E664E)],
      CraftKind.basket: [const Color(0xFFE8D5AE), const Color(0xFFB99158)],
      CraftKind.textile: [const Color(0xFF233C4B), const Color(0xFF8F3C31)],
      CraftKind.gift: [const Color(0xFFB45B46), const Color(0xFF5B7C51)],
    };
    final colors = palettes[kind]!;
    paint.shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: colors.map(_tone).toList(),
    ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);

    paint.shader = null;
    paint.color = Colors.white.withValues(alpha: muted ? .12 : .18);
    canvas.drawCircle(Offset(w * .18, h * .18), w * .24, paint);
    paint.color = AppTheme.indigo.withValues(alpha: .08);
    canvas.drawCircle(Offset(w * .88, h * .84), w * .35, paint);

    switch (kind) {
      case CraftKind.logo:
        _drawLogo(canvas, size, paint);
      case CraftKind.earrings:
        _drawEarrings(canvas, size, paint);
      case CraftKind.ceramic:
        _drawCeramic(canvas, size, paint);
      case CraftKind.basket:
        _drawBasket(canvas, size, paint);
      case CraftKind.textile:
        _drawTextile(canvas, size, paint);
      case CraftKind.gift:
        _drawGift(canvas, size, paint);
    }
  }

  void _drawLogo(Canvas canvas, Size size, Paint paint) {
    final center = Offset(size.width / 2, size.height / 2);
    paint.color = _tone(AppTheme.terracotta);
    canvas.drawCircle(center, size.shortestSide * .18, paint);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = size.shortestSide * .04;
    paint.color = _tone(AppTheme.ochre);
    canvas.drawCircle(center, size.shortestSide * .26, paint);
    paint.style = PaintingStyle.fill;
  }

  void _drawEarrings(Canvas canvas, Size size, Paint paint) {
    final unit = size.shortestSide;
    final y = size.height * .46;
    for (final x in [size.width * .36, size.width * .64]) {
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = unit * .035;
      paint.color = _tone(const Color(0xFF8D5A18));
      canvas.drawCircle(Offset(x, y), unit * .14, paint);
      canvas.drawLine(
        Offset(x, y - unit * .22),
        Offset(x, y - unit * .12),
        paint,
      );
      paint.style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y - unit * .24), unit * .025, paint);
      for (var i = 0; i < 9; i++) {
        final angle = i * .785;
        final from = Offset(
          x + unit * .15 * _cos(angle),
          y + unit * .15 * _sin(angle),
        );
        final to = Offset(
          x + unit * .22 * _cos(angle),
          y + unit * .22 * _sin(angle),
        );
        canvas.drawLine(from, to, paint);
      }
    }
    paint.style = PaintingStyle.fill;
  }

  void _drawCeramic(Canvas canvas, Size size, Paint paint) {
    final w = size.width;
    final h = size.height;
    final bowl = Path()
      ..moveTo(w * .23, h * .43)
      ..quadraticBezierTo(w * .5, h * .58, w * .77, h * .43)
      ..quadraticBezierTo(w * .72, h * .78, w * .5, h * .81)
      ..quadraticBezierTo(w * .28, h * .78, w * .23, h * .43)
      ..close();
    paint.color = _tone(const Color(0xFFEAD6C0));
    canvas.drawPath(bowl, paint);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = size.shortestSide * .025;
    paint.color = _tone(const Color(0xFF7A3D2C));
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * .5, h * .43),
        width: w * .54,
        height: h * .16,
      ),
      paint,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(w * .5, h * .58),
        width: w * .36,
        height: h * .24,
      ),
      .2,
      2.7,
      false,
      paint,
    );
    paint.style = PaintingStyle.fill;
  }

  void _drawBasket(Canvas canvas, Size size, Paint paint) {
    final w = size.width;
    final h = size.height;
    final body = Path()
      ..moveTo(w * .24, h * .38)
      ..lineTo(w * .76, h * .38)
      ..lineTo(w * .69, h * .78)
      ..quadraticBezierTo(w * .5, h * .86, w * .31, h * .78)
      ..close();
    paint.color = _tone(const Color(0xFFC99D58));
    canvas.drawPath(body, paint);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = size.shortestSide * .025;
    paint.color = _tone(const Color(0xFF7A5229));
    canvas.drawArc(
      Rect.fromLTWH(w * .34, h * .19, w * .32, h * .43),
      3.14,
      3.14,
      false,
      paint,
    );
    for (var i = 1; i < 6; i++) {
      final y = h * (.39 + i * .065);
      canvas.drawLine(Offset(w * .28, y), Offset(w * .72, y), paint);
    }
    for (var i = 0; i < 6; i++) {
      final x = w * (.31 + i * .075);
      canvas.drawLine(Offset(x, h * .4), Offset(x - w * .025, h * .77), paint);
    }
    paint.style = PaintingStyle.fill;
  }

  void _drawTextile(Canvas canvas, Size size, Paint paint) {
    final w = size.width;
    final h = size.height;
    paint.color = _tone(const Color(0xFFE5C17D));
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = size.shortestSide * .035;
    for (var row = 0; row < 5; row++) {
      final y = h * (.22 + row * .15);
      final path = Path()..moveTo(0, y);
      for (var col = 0; col < 7; col++) {
        path
          ..lineTo(w * (col / 6 + .08), y - h * .055)
          ..lineTo(w * (col / 6 + .16), y);
      }
      canvas.drawPath(path, paint);
    }
    paint.style = PaintingStyle.fill;
  }

  void _drawGift(Canvas canvas, Size size, Paint paint) {
    final w = size.width;
    final h = size.height;
    paint.color = _tone(AppTheme.bone);
    final box = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * .23, h * .37, w * .54, h * .42),
      Radius.circular(w * .04),
    );
    canvas.drawRRect(box, paint);
    paint.color = _tone(AppTheme.ochre);
    canvas.drawRect(Rect.fromLTWH(w * .46, h * .37, w * .08, h * .42), paint);
    canvas.drawRect(Rect.fromLTWH(w * .23, h * .5, w * .54, h * .07), paint);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = size.shortestSide * .045;
    canvas.drawArc(
      Rect.fromLTWH(w * .31, h * .21, w * .2, h * .24),
      .2,
      3.2,
      false,
      paint,
    );
    canvas.drawArc(
      Rect.fromLTWH(w * .49, h * .21, w * .2, h * .24),
      -.2,
      -3.2,
      false,
      paint,
    );
    paint.style = PaintingStyle.fill;
  }

  double _sin(double angle) => switch (angle) {
    0 => 0,
    _ when angle < 1 => .707,
    _ when angle < 2 => 1,
    _ when angle < 3 => .707,
    _ when angle < 4 => 0,
    _ when angle < 5 => -.707,
    _ when angle < 6 => -1,
    _ => -.707,
  };

  double _cos(double angle) => _sin(angle + 1.5708);

  @override
  bool shouldRepaint(covariant _CraftPainter oldDelegate) =>
      oldDelegate.kind != kind ||
      oldDelegate.compact != compact ||
      oldDelegate.muted != muted;
}
