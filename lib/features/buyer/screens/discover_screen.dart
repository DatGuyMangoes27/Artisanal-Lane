import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/pricing/price_format.dart';
import '../../../core/ui/friendly_error.dart';
import '../../../app/theme.dart';
import '../../../models/models.dart';
import '../../../widgets/cart_nav_icon.dart';
import '../../../widgets/skeleton.dart';
import '../providers/buyer_providers.dart';
import '../providers/favourite_actions.dart';
import '../utils/discovery_preferences.dart';
import '../utils/discovery_remote_store.dart';
import '../widgets/creator_commerce_header.dart';

final discoverProductsProvider = FutureProvider<List<Product>>((ref) async {
  final service = ref.read(supabaseServiceProvider);
  return service.getProducts(limit: 100);
});

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen>
    with WidgetsBindingObserver {
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;
  bool _isDismissing = false;
  bool _isUndoing = false;
  Product? _lastSwipedProduct;
  String? _restoreToFrontId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual(currentUserIdProvider, (previous, next) {
      if (previous != next && mounted) {
        setState(() {
          _dragOffset = Offset.zero;
          _isDragging = false;
          _lastSwipedProduct = null;
          _restoreToFrontId = null;
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !_isDismissing &&
        ref.read(discoverySyncEnabledProvider)) {
      ref.invalidate(discoveryPreferencesProvider);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _updateDrag(DragUpdateDetails details) {
    if (_isDismissing) return;
    setState(() {
      _isDragging = true;
      _dragOffset += Offset(details.delta.dx, details.delta.dy * .16);
    });
  }

  Future<void> _finishDrag(DragEndDetails details, Product product) async {
    if (_isDismissing) return;
    final velocity = details.velocity.pixelsPerSecond.dx;
    final passedDistance = _dragOffset.dx.abs() > 110;
    final passedVelocity = velocity.abs() > 700;
    if (!passedDistance && !passedVelocity) {
      setState(() {
        _isDragging = false;
        _dragOffset = Offset.zero;
      });
      return;
    }
    final direction = _dragOffset.dx == 0 ? velocity.sign : _dragOffset.dx.sign;
    await _dismiss(product, direction);
  }

  Future<void> _dismiss(Product product, double direction) async {
    if (_isDismissing) return;
    final liked = direction > 0;
    final decisionUserId = ref.read(currentUserIdProvider);
    HapticFeedback.lightImpact();
    setState(() {
      _isDragging = false;
      _isDismissing = true;
      _restoreToFrontId = null;
      _dragOffset = Offset(
        MediaQuery.sizeOf(context).width * 1.35 * direction,
        -24,
      );
    });
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;
    if (ref.read(currentUserIdProvider) != decisionUserId) {
      setState(() {
        _dragOffset = Offset.zero;
        _isDismissing = false;
      });
      _message('Your account changed before that choice could be saved.');
      return;
    }
    Product? savedProduct;
    try {
      await ref
          .read(discoveryPreferencesProvider.notifier)
          .recordDecision(product.id, liked: liked);
      if (!mounted || ref.read(currentUserIdProvider) != decisionUserId) return;
      savedProduct = product;
    } catch (_) {
      if (mounted) _message('Could not save that choice. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _dragOffset = Offset.zero;
          _isDismissing = false;
          if (savedProduct != null) _lastSwipedProduct = savedProduct;
        });
        // A loved item should be easy to find again: save it to favourites
        // too, best-effort, when the buyer is signed in. Guests aren't
        // interrupted with a sign-in prompt mid-swipe.
        if (savedProduct != null && liked) {
          final uid = ref.read(currentUserIdProvider);
          if (uid != null && !ref.read(isFavouriteProvider(product.id))) {
            unawaited(toggleFavourite(ref, context, product.id));
          }
        }
      }
    }
  }

  Future<void> _undo() async {
    final product = _lastSwipedProduct;
    if (product == null || _isUndoing) return;
    setState(() => _isUndoing = true);
    try {
      await ref
          .read(discoveryPreferencesProvider.notifier)
          .undoDecision(product.id);
      if (!mounted) return;
      setState(() {
        _restoreToFrontId = product.id;
        _lastSwipedProduct = null;
      });
      HapticFeedback.lightImpact();
    } catch (_) {
      if (mounted) _message("Couldn't undo that. Please try again.");
    } finally {
      if (mounted) setState(() => _isUndoing = false);
    }
  }

  void _message(String message) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );

  Future<void> _refresh() async {
    ref.invalidate(discoverProductsProvider);
    ref.invalidate(discoveryPreferencesProvider);
    await Future.wait([
      ref.read(discoverProductsProvider.future),
      ref.read(discoveryPreferencesProvider.future),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(discoverProductsProvider);
    final categories = ref.watch(categoriesProvider);
    final preferences = ref.watch(discoveryPreferencesProvider);
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(88),
        child: SafeArea(
          bottom: false,
          child: CreatorCommerceHeader(
            eyebrow: 'Find your favourites',
            title: 'Discover',
            subtitle: '',
            compact: true,
            cartCount: cartBadgeCount(
              ref.watch(cartItemsProvider).value ?? const [],
            ),
          ),
        ),
      ),
      body: products.when(
        loading: () => const _DiscoverSkeleton(),
        error: (error, __) => ErrorRetryView(
          error: error,
          title: 'Discover is unavailable',
          onRetry: () => ref.invalidate(discoverProductsProvider),
        ),
        data: (allProducts) => preferences.when(
          loading: () => const _DiscoverSkeleton(),
          error: (error, __) => ErrorRetryView(
            error: error,
            title: 'Preferences are unavailable',
            onRetry: () => ref.invalidate(discoveryPreferencesProvider),
          ),
          data: (prefs) {
            var ranked = rankDiscoverProducts(allProducts, prefs);
            // Undo just brought a card back: show it next rather than
            // wherever it happens to rank.
            if (_restoreToFrontId != null) {
              final idx = ranked.indexWhere(
                (product) => product.id == _restoreToFrontId,
              );
              if (idx > 0) {
                final restored = ranked.removeAt(idx);
                ranked = [restored, ...ranked];
              } else if (idx == -1) {
                _restoreToFrontId = null;
              }
            }
            final deckTotal = allProducts
                .where(
                  (product) =>
                      prefs.maxBudget == null ||
                      product.price <= prefs.maxBudget!,
                )
                .length;
            if (ranked.isEmpty) {
              return _DiscoverEmpty(
                onTune: () =>
                    _showPreferences(categories.value ?? const [], prefs),
                onBrowseShop: () => context.push('/home/shop-all'),
              );
            }
            final reviewedCount = (deckTotal - ranked.length).clamp(
              0,
              deckTotal,
            );
            final product = ranked.first;
            final nextProduct = ranked.length > 1 ? ranked[1] : null;
            final compact = MediaQuery.sizeOf(context).height < 640;
            final isFavourite = ref.watch(isFavouriteProvider(product.id));
            return SafeArea(
              top: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Choose what fits. Your category, budget and swipe choices shape this order.',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                              height: 1.4,
                            ),
                            maxLines: compact ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Undo last swipe',
                          visualDensity: VisualDensity.compact,
                          onPressed: _lastSwipedProduct == null || _isUndoing
                              ? null
                              : _undo,
                          icon: const Icon(Icons.undo_rounded, size: 20),
                          color: AppTheme.textSecondary,
                        ),
                        IconButton(
                          tooltip: 'Refresh',
                          visualDensity: VisualDensity.compact,
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh_rounded, size: 20),
                          color: AppTheme.textSecondary,
                        ),
                        Text(
                          '${reviewedCount + 1} of $deckTotal',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: LinearProgressIndicator(
                      value: deckTotal == 0
                          ? 0
                          : (reviewedCount + 1) / deckTotal,
                      minHeight: 5,
                      borderRadius: BorderRadius.circular(4),
                      backgroundColor: AppTheme.clay,
                      color: AppTheme.terracotta,
                    ),
                  ),
                  SizedBox(height: compact ? 8 : 14),
                  Expanded(
                    child: _DiscoveryCard(
                      key: ValueKey(product.id),
                      product: product,
                      nextProduct: nextProduct,
                      dragOffset: _dragOffset,
                      isDragging: _isDragging,
                      isFavourite: isFavourite,
                      onTap: () => context.push('/home/product/${product.id}'),
                      onDragUpdate: _updateDrag,
                      onDragEnd: (details) => _finishDrag(details, product),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      26,
                      compact ? 4 : 8,
                      26,
                      compact ? 4 : 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _DiscoverAction(
                          icon: Icons.close,
                          label: 'Not for me',
                          color: AppTheme.textSecondary,
                          compact: compact,
                          onTap: () => _dismiss(product, -1),
                        ),
                        _DiscoverAction(
                          icon: isFavourite
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                          label: 'Save',
                          color: AppTheme.ochre,
                          compact: compact,
                          onTap: () =>
                              toggleFavourite(ref, context, product.id),
                        ),
                        _DiscoverAction(
                          icon: Icons.favorite,
                          label: 'Love it',
                          color: AppTheme.terracotta,
                          large: true,
                          compact: compact,
                          onTap: () => _dismiss(product, 1),
                        ),
                      ],
                    ),
                  ),
                  if (!compact)
                    TextButton.icon(
                      onPressed: () =>
                          _showPreferences(categories.value ?? const [], prefs),
                      icon: const Icon(Icons.tune, size: 17),
                      label: const Text('Tune my preferences'),
                    )
                  else
                    Center(
                      child: IconButton(
                        tooltip: 'Tune my preferences',
                        onPressed: () => _showPreferences(
                          categories.value ?? const [],
                          prefs,
                        ),
                        icon: const Icon(Icons.tune),
                      ),
                    ),
                  SizedBox(height: compact ? 8 : 16),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _showPreferences(
    List<Category> categories,
    DiscoveryPreferences preferences,
  ) async {
    final chosen = {...preferences.categoryIds};
    double? budget = preferences.maxBudget;
    final syncEnabled = ref.read(discoverySyncEnabledProvider);
    final signedIn = ref.read(currentUserIdProvider) != null;
    final storageNote = !syncEnabled
        ? 'These choices are saved on this device.'
        : signedIn
        ? 'These choices are saved to your account, so they follow you to your other devices.'
        : 'These choices are saved on this device. Sign in to keep them across devices.';
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppTheme.cardBg,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tune Discover',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    storageNote,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Categories',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories
                        .map(
                          (category) => FilterChip(
                            label: Text(
                              category.name,
                              style: const TextStyle(fontSize: 13),
                            ),
                            selected: chosen.contains(category.id),
                            onSelected: (selected) => setSheetState(
                              () => selected
                                  ? chosen.add(category.id)
                                  : chosen.remove(category.id),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Maximum budget',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [null, 500.0, 1000.0, 2000.0]
                        .map(
                          (option) => ChoiceChip(
                            label: Text(
                              option == null
                                  ? 'Any price'
                                  : 'Up to R${option.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 13),
                            ),
                            selected: budget == option,
                            onSelected: (_) =>
                                setSheetState(() => budget = option),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          await ref
                              .read(discoveryPreferencesProvider.notifier)
                              .updateChoices(
                                categoryIds: chosen,
                                maxBudget: budget,
                              );
                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                          }
                        } catch (_) {
                          if (sheetContext.mounted) {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Could not save preferences. Please try again.',
                                ),
                              ),
                            );
                          }
                        }
                      },
                      child: const Text(
                        'Save preferences',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DiscoveryCard extends StatelessWidget {
  const _DiscoveryCard({
    super.key,
    required this.product,
    required this.nextProduct,
    required this.dragOffset,
    required this.isDragging,
    required this.isFavourite,
    required this.onTap,
    required this.onDragUpdate,
    required this.onDragEnd,
  });
  final Product product;
  final Product? nextProduct;
  final Offset dragOffset;
  final bool isDragging;
  final bool isFavourite;
  final VoidCallback onTap;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    // How far the top card has travelled toward its fling threshold (0-1),
    // used to grow the peeking next card as the top one is dragged away.
    final dragProgress = (dragOffset.dx.abs() / 140).clamp(0.0, 1.0);
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          left: 35,
          right: 35,
          top: 18,
          bottom: 16,
          child: Transform.rotate(
            angle: -.025,
            child: Transform.scale(
              scale: 0.94 + dragProgress * 0.06,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTheme.clay,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: nextProduct == null
                    ? null
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: Opacity(
                          opacity: 0.55 + dragProgress * 0.45,
                          child: CachedNetworkImage(
                            imageUrl: nextProduct!.primaryImage,
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                Container(color: AppTheme.bone),
                            errorWidget: (_, __, ___) =>
                                Container(color: AppTheme.bone),
                          ),
                        ),
                      ),
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
            onTap: onTap,
            onHorizontalDragUpdate: onDragUpdate,
            onHorizontalDragEnd: onDragEnd,
            child: AnimatedContainer(
              duration: isDragging
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              transformAlignment: Alignment.center,
              transform: Matrix4.translationValues(
                dragOffset.dx,
                dragOffset.dy,
                0,
              )..rotateZ(dragOffset.dx / 1450),
              clipBehavior: Clip.antiAlias,
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
              child: Column(
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: product.primaryImage,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(color: AppTheme.bone),
                          errorWidget: (_, __, ___) => Container(
                            color: AppTheme.bone,
                            child: const Icon(
                              Icons.image_outlined,
                              color: AppTheme.textHint,
                              size: 42,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 16,
                          top: 16,
                          child: _Badge(
                            label: (product.categoryName ?? 'Handmade')
                                .toUpperCase(),
                          ),
                        ),
                        if (isFavourite)
                          const Positioned(
                            right: 16,
                            top: 16,
                            child: _Badge(label: 'SAVED', icon: Icons.bookmark),
                          ),
                        Positioned(
                          left: 18,
                          top: 76,
                          child: Opacity(
                            opacity: (dragOffset.dx / 110).clamp(0, 1),
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
                            opacity: (-dragOffset.dx / 110).clamp(0, 1),
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
                                product.title,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineMedium,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              formatBrowsePrice(product.price),
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(color: AppTheme.terracotta),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${product.shopName ?? 'Local maker'} · ${product.categoryName ?? 'Handmade'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (product.tags.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 7,
                            runSpacing: 7,
                            children: product.tags
                                .take(3)
                                .map((tag) => _Tag(tag))
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, this.icon});
  final String label;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: AppTheme.cardBg.withValues(alpha: .9),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 11, color: AppTheme.terracotta),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    ),
  );
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: AppTheme.bone,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      label,
      style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textSecondary),
    ),
  );
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
  Widget build(BuildContext context) => Transform.rotate(
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

class _DiscoverAction extends StatelessWidget {
  const _DiscoverAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.large = false,
    this.compact = false,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool large;
  final bool compact;
  @override
  Widget build(BuildContext context) => InkWell(
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
          ),
          child: Icon(icon, color: large ? Colors.white : color),
        ),
        if (!compact) ...[
          const SizedBox(height: 5),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    ),
  );
}

class _DiscoverSkeleton extends StatelessWidget {
  const _DiscoverSkeleton();
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Skeleton(
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: SkeletonBox(height: 14, radius: 8)),
                const SizedBox(width: 12),
                const SkeletonBox(width: 48, height: 14, radius: 8),
              ],
            ),
            const SizedBox(height: 14),
            const SkeletonBox(height: 5, radius: 4),
            const SizedBox(height: 18),
            Expanded(child: SkeletonBox(radius: 28)),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: const [
                SkeletonBox(width: 54, height: 54, circle: true),
                SkeletonBox(width: 62, height: 62, circle: true),
                SkeletonBox(width: 54, height: 54, circle: true),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _DiscoverEmpty extends StatelessWidget {
  const _DiscoverEmpty({required this.onTune, required this.onBrowseShop});
  final VoidCallback onTune;
  final VoidCallback onBrowseShop;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.sand, width: 1.5),
            ),
            child: const Icon(
              Icons.celebration_outlined,
              size: 48,
              color: AppTheme.terracotta,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "You're all caught up",
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Try a higher budget, different categories, or check back after new pieces arrive.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: onTune,
              child: const Text('Adjust preferences'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: onBrowseShop,
              child: const Text('Browse the shop'),
            ),
          ),
        ],
      ),
    ),
  );
}
