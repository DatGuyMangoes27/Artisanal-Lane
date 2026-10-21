import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/ui/share_origin.dart';
import '../../../core/pricing/price_format.dart';
import '../../../core/ui/friendly_error.dart';
import '../../../app/theme.dart';
import '../../../services/content_view_session.dart';
import '../../../services/meta_app_events_service.dart';
import '../../../widgets/cart_nav_icon.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/product_card.dart';
import '../../../widgets/skeleton.dart';
import '../../../widgets/sign_in_prompt_sheet.dart';
import '../../../models/models.dart';
import '../providers/favourite_actions.dart';
import '../utils/product_detail_actions.dart';
import '../utils/product_image_zoom.dart';
import '../utils/cart_stock_guard.dart';
import '../widgets/review_widgets.dart';
import '../../safety/community_guidelines_gate.dart';
import '../../safety/content_filter.dart';
import '../../safety/review_safety.dart';
import '../providers/blocking_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/buyer_providers.dart';

final madeToOrderOpenUnitsProvider = FutureProvider.family<int, String>((
  ref,
  productId,
) async {
  final service = ref.read(supabaseServiceProvider);
  return service.getMadeToOrderOpenUnits(productId);
});

class ProductDetailScreen extends ConsumerStatefulWidget {
  final String productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  int _currentImageIndex = 0;
  bool _isAddingToCart = false;
  bool _showAllReviews = false;
  final Map<int, String> _selectedOptionValues = {};
  late final PageController _pageController;
  final _customNoteController = TextEditingController();
  String? _lastTrackedViewKey;
  bool _contentViewRecorded = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _customNoteController.dispose();
    super.dispose();
  }

  List<ProductOptionGroup> _resolveOptionGroups(Product product) {
    if (product.optionGroups.isNotEmpty) {
      return product.optionGroups;
    }

    if (product.variants.isEmpty) {
      return const [];
    }

    final maxOptions = product.variants.fold<int>(
      0,
      (max, variant) =>
          variant.optionValues.length > max ? variant.optionValues.length : max,
    );

    return List.generate(maxOptions, (index) {
      final values = <String>{};
      for (final variant in product.variants) {
        final value = variant.optionValueAt(index)?.trim();
        if (value != null && value.isNotEmpty) {
          values.add(value);
        }
      }
      return ProductOptionGroup(
        name: index == 0 ? 'Option' : 'Option ${index + 1}',
        values: values.toList(growable: false),
      );
    }).where((group) => group.values.isNotEmpty).toList(growable: false);
  }

  bool _variantMatchesSelections(
    ProductVariant variant,
    Map<int, String> selectedValues, {
    int? ignoreIndex,
  }) {
    for (final entry in selectedValues.entries) {
      if (entry.key == ignoreIndex) continue;
      if (variant.optionValueAt(entry.key) != entry.value) {
        return false;
      }
    }
    return true;
  }

  ProductVariant? _findSelectedVariant(
    Product product,
    List<ProductOptionGroup> optionGroups,
  ) {
    if (optionGroups.isEmpty ||
        _selectedOptionValues.length < optionGroups.length) {
      return null;
    }

    for (final variant in product.variants) {
      if (_variantMatchesSelections(variant, _selectedOptionValues)) {
        return variant;
      }
    }
    return null;
  }

  ProductVariant? _findPreviewVariant(
    Product product,
    List<ProductOptionGroup> optionGroups,
  ) {
    final selectedVariant = _findSelectedVariant(product, optionGroups);
    if (selectedVariant != null) {
      return selectedVariant;
    }

    if (_selectedOptionValues.isNotEmpty) {
      for (final variant in product.variants) {
        if (_variantMatchesSelections(variant, _selectedOptionValues)) {
          return variant;
        }
      }
    }

    return product.defaultVariant;
  }

  List<String> _valuesForGroup(
    Product product,
    List<ProductOptionGroup> optionGroups,
    int groupIndex,
  ) {
    if (groupIndex < optionGroups.length &&
        optionGroups[groupIndex].values.isNotEmpty) {
      return optionGroups[groupIndex].values;
    }

    final values = <String>{};
    for (final variant in product.variants) {
      final value = variant.optionValueAt(groupIndex)?.trim();
      if (value != null && value.isNotEmpty) {
        values.add(value);
      }
    }
    return values.toList(growable: false);
  }

  bool _isValueAvailableForGroup(
    Product product,
    int groupIndex,
    String value,
  ) {
    for (final variant in product.variants) {
      if (variant.optionValueAt(groupIndex) != value) {
        continue;
      }
      if (!_variantMatchesSelections(
        variant,
        _selectedOptionValues,
        ignoreIndex: groupIndex,
      )) {
        continue;
      }
      if (variant.isInStock) {
        return true;
      }
    }
    return false;
  }

  Future<void> _addToCart(
    Product product, {
    ProductVariant? variant,
    bool isMadeToOrder = false,
    String? customNote,
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (requiresSignInForCart(userId)) {
      await showSignInPromptSheet(
        context,
        title: 'Sign in to add to basket',
        message:
            'Create an account or sign in to add this item to your basket and continue to checkout.',
      );
      return;
    }

    setState(() => _isAddingToCart = true);
    try {
      final service = ref.read(supabaseServiceProvider);
      await service.addToCart(
        userId!,
        product.id,
        variantId: variant?.id,
        isMadeToOrder: isMadeToOrder,
        customNote: customNote,
      );
      await ref
          .read(metaAppEventsServiceProvider)
          .logAddToCart(product, variant: variant);
      ref.invalidate(cartItemsProvider);
      HapticFeedback.mediumImpact();
      if (mounted) {
        final thumb = (variant?.images.isNotEmpty ?? false)
            ? variant!.images.first
            : product.primaryImage;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: _AddedToBasketToast(imageUrl: thumb, title: product.title),
            backgroundColor: AppTheme.textPrimary,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            duration: const Duration(seconds: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            action: SnackBarAction(
              label: 'View basket',
              textColor: AppTheme.ochre,
              onPressed: () => context.push('/cart'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final message = e is StateError
            ? e.message.toString()
            : friendlyErrorMessage(e, fallback: 'Failed to add to basket');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message,
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAddingToCart = false);
    }
  }

  void _trackProductView(Product product, {ProductVariant? variant}) {
    final viewKey = '${product.id}:${variant?.id ?? 'default'}';
    if (_lastTrackedViewKey == viewKey) return;
    _lastTrackedViewKey = viewKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(metaAppEventsServiceProvider)
          .logViewedProduct(product, variant: variant);
    });
    if (_contentViewRecorded) return;
    _contentViewRecorded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      recordContentView(ref, 'product', product.id);
    });
  }

  Future<void> _shareProduct(Product product, {ProductVariant? variant}) async {
    final sharePrice = variant?.price ?? product.price;
    try {
      await Share.share(
        buildProductShareText(
          productId: product.id,
          title: product.title,
          price: sharePrice,
        ),
        subject: 'Artisan Lane product share',
        sharePositionOrigin: shareOriginFor(context),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not open the share sheet right now.',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _openImageZoom({
    required List<String> images,
    required int initialIndex,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ProductImageZoomScreen(
          images: images,
          initialIndex: initialIndex.clamp(0, images.length - 1),
        ),
      ),
    );
  }

  Future<void> _contactArtisan(Product product) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      await showSignInPromptSheet(
        context,
        title: 'Sign in to message artisans',
        message:
            'Create an account or sign in to start a conversation with ${product.shopName ?? 'this artisan'}.',
      );
      return;
    }

    try {
      final thread = await ref
          .read(supabaseServiceProvider)
          .getOrCreateThread(shopId: product.shopId, buyerId: user.id);
      if (mounted) {
        context.push('/profile/messages/${thread.id}');
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyErrorMessage(error, fallback: 'Could not open chat.'),
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openProductReviewSheet(
    Product product, {
    ProductReview? existingReview,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      await showSignInPromptSheet(
        context,
        title: 'Sign in to leave a review',
        message:
            'Create an account or sign in to review ${product.title} after your order is delivered.',
      );
      return;
    }

    final isEligible = await ref.read(
      canReviewProductProvider(product.id).future,
    );
    if (!isEligible && existingReview == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reviews unlock after a delivered or completed order.',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!mounted) return;
    if (!await ensureCommunityGuidelinesAccepted(context, ref)) return;
    if (!mounted) return;
    var rating = existingReview?.rating ?? 5;
    final draft = await composeCleanReview<ReviewDraft>(
      context,
      initialText: existingReview?.reviewText ?? '',
      textOf: (draft) {
        rating = draft.rating;
        return draft.reviewText;
      },
      openComposer: (text) => showReviewComposerSheet(
        context,
        title: existingReview != null
            ? 'Edit product review'
            : 'Review this product',
        subtitle: product.title,
        initialRating: rating,
        initialReviewText: text,
      ),
    );

    if (draft == null) {
      return;
    }

    try {
      await ref
          .read(supabaseServiceProvider)
          .submitProductReview(
            productId: product.id,
            buyerId: user.id,
            rating: draft.rating,
            reviewText: draft.reviewText,
          );

      ref.invalidate(productReviewsProvider(product.id));
      ref.invalidate(productReviewSummaryProvider(product.id));
      ref.invalidate(canReviewProductProvider(product.id));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existingReview != null
                ? 'Your product review was updated.'
                : 'Thanks for reviewing this product.',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: AppTheme.baobab,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ugcErrorMessage(error) ??
                friendlyErrorMessage(error, fallback: 'Could not save review.'),
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(productDetailProvider(widget.productId));
    final screenWidth = MediaQuery.of(context).size.width;
    final cartItems = ref.watch(cartItemsProvider).value ?? const <CartItem>[];

    final reviewSummaryAsync = ref.watch(
      productReviewSummaryProvider(widget.productId),
    );
    final productReviewsAsync = ref.watch(
      productReviewsProvider(widget.productId),
    );
    final canReviewAsync = ref.watch(
      canReviewProductProvider(widget.productId),
    );
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return productAsync.when(
      data: (product) {
        final isFav = ref.watch(isFavouriteProvider(product.id));
        final shopAsync = ref.watch(shopDetailProvider(product.shopId));
        final shop = shopAsync.asData?.value;
        final shopOffline = shop?.isOffline ?? false;
        final backToWork = shop?.backToWorkDate;
        final optionGroups = _resolveOptionGroups(product);
        final selectedVariant = _findSelectedVariant(product, optionGroups);
        final previewVariant =
            _findPreviewVariant(product, optionGroups) ??
            product.defaultVariant;
        _trackProductView(product, variant: previewVariant);
        final displayImages = (previewVariant?.images.isNotEmpty ?? false)
            ? previewVariant!.images
            : product.images;
        final displayPrice = previewVariant?.price ?? product.price;
        final displayCompareAtPrice =
            previewVariant?.compareAtPrice ?? product.compareAtPrice;
        final displayStock = previewVariant?.stockQty ?? product.stockQty;
        final requiresVariantSelection =
            product.hasVariants && optionGroups.isNotEmpty;
        final canEvaluateCartStock =
            !requiresVariantSelection || selectedVariant != null;
        final hasReachedCartStockLimit =
            canEvaluateCartStock &&
            !canAddSelectionToCart(
              cartItems,
              product,
              variant: selectedVariant,
            );
        final mtoEnabled = product.isMadeToOrderEnabled;
        final isMtoMode =
            mtoEnabled && (product.isMadeToOrderOnly || displayStock <= 0);
        final openMtoUnits = (mtoEnabled && product.madeToOrderCapacity != null)
            ? (ref.watch(madeToOrderOpenUnitsProvider(product.id)).value ?? 0)
            : 0;
        final capacityFull =
            isMtoMode &&
            product.madeToOrderCapacity != null &&
            openMtoUnits >= product.madeToOrderCapacity!;
        final mtoPrice = product.effectiveMtoPrice;
        final canPurchase =
            !_isAddingToCart &&
            (!requiresVariantSelection || selectedVariant != null) &&
            (isMtoMode
                ? !capacityFull
                : (displayStock > 0 && !hasReachedCartStockLimit));
        final imageCount = displayImages.isEmpty ? 1 : displayImages.length;
        final loadedReviews =
            productReviewsAsync.value ?? const <ProductReview>[];
        ProductReview? myReview;
        if (currentUserId != null) {
          for (final review in loadedReviews) {
            if (review.buyerId == currentUserId) {
              myReview = review;
              break;
            }
          }
        }

        return Scaffold(
          backgroundColor: AppTheme.scaffoldBg, // White background
          body: Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    // ── Image Carousel ───────────────────────────────
                    SliverAppBar(
                      expandedHeight: screenWidth * 1.1,
                      backgroundColor: AppTheme.scaffoldBg,
                      elevation: 0,
                      pinned: true,
                      leading: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: _floatingIconButton(
                          icon: Icons.arrow_back_rounded,
                          onTap: () => context.pop(),
                        ),
                      ),
                      actions: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              _floatingIconButton(
                                icon: Icons.share_outlined,
                                onTap: () => _shareProduct(
                                  product,
                                  variant: previewVariant,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _floatingIconButton(
                                icon: isFav
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_outline_rounded,
                                iconColor: isFav
                                    ? AppTheme.error
                                    : AppTheme.textPrimary,
                                onTap: () =>
                                    toggleFavourite(ref, context, product.id),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => context.push('/cart'),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.1,
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: CartNavIcon(
                                    count: cartBadgeCount(cartItems),
                                    isActive: false,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      flexibleSpace: FlexibleSpaceBar(
                        background: Stack(
                          children: [
                            PageView.builder(
                              controller: _pageController,
                              itemCount: imageCount,
                              onPageChanged: (i) =>
                                  setState(() => _currentImageIndex = i),
                              itemBuilder: (context, index) {
                                final url = displayImages.isNotEmpty
                                    ? displayImages[index]
                                    : product.primaryImage;
                                return GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _openImageZoom(
                                    images: productZoomImages(
                                      displayImages: displayImages,
                                      fallbackImage: product.primaryImage,
                                    ),
                                    initialIndex: index,
                                  ),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      CachedNetworkImage(
                                        imageUrl: url,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                        placeholder: (_, __) => Skeleton(
                                          child: SkeletonBox(
                                            width: double.infinity,
                                            height: double.infinity,
                                            radius: 0,
                                          ),
                                        ),
                                        errorWidget: (_, __, ___) => Container(
                                          color: AppTheme.clay.withValues(
                                            alpha: 0.1,
                                          ),
                                          child: const Icon(
                                            Icons.image_outlined,
                                            size: 64,
                                            color: AppTheme.textHint,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            // Gradient overlay for text readability if needed,
                            // but keeping it clean for now.

                            // Indicators
                            if (imageCount > 1)
                              Positioned(
                                bottom: 16,
                                left: 0,
                                right: 0,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(
                                    imageCount,
                                    (i) => AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      width: i == _currentImageIndex ? 24 : 8,
                                      height: 8,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: i == _currentImageIndex
                                            ? Colors.white
                                            : Colors.white.withValues(
                                                alpha: 0.5,
                                              ),
                                        borderRadius: BorderRadius.circular(4),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.1,
                                            ),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                            // Sale Badge
                            if ((displayCompareAtPrice ?? 0) > displayPrice)
                              Positioned(
                                bottom: 16,
                                left: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.terracotta,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '-${(((displayCompareAtPrice! - displayPrice) / displayCompareAtPrice) * 100).toStringAsFixed(0)}%',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // ── Product Info ─────────────────────────────────
                    SliverToBoxAdapter(
                      child: Container(
                        decoration: const BoxDecoration(
                          color: AppTheme.scaffoldBg,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Category & Rating Row
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  if (product.categoryName != null)
                                    Text(
                                      product.categoryName!.toUpperCase(),
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.terracotta,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  reviewSummaryAsync.when(
                                    data: (summary) => Row(
                                      children: [
                                        if (summary.hasReviews) ...[
                                          const Icon(
                                            Icons.star_rounded,
                                            size: 18,
                                            color: AppTheme.ochre,
                                          ),
                                          const SizedBox(width: 4),
                                        ],
                                        Text(
                                          summary.hasReviews
                                              ? '${summary.averageRating.toStringAsFixed(1)} (${summary.reviewCount} reviews)'
                                              : 'No reviews yet',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    loading: () => Text(
                                      'Loading reviews...',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                    error: (_, __) => Text(
                                      'Reviews unavailable',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Title
                              Text(
                                product.title,
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Price
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    formatBrowsePrice(displayPrice),
                                    style: GoogleFonts.playfairDisplay(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.sienna,
                                    ),
                                  ),
                                  if ((displayCompareAtPrice ?? 0) >
                                      displayPrice) ...[
                                    const SizedBox(width: 12),
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Text(
                                        formatBrowsePrice(
                                          displayCompareAtPrice!,
                                        ),
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          color: AppTheme.textHint,
                                          decoration:
                                              TextDecoration.lineThrough,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (_shippingSummary(product) != null) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.local_shipping_outlined,
                                      size: 15,
                                      color: AppTheme.textSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        _shippingSummary(product)!,
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 24),

                              if (product.hasVariants) ...[
                                ...optionGroups.asMap().entries.map((entry) {
                                  final groupIndex = entry.key;
                                  final group = entry.value;
                                  final values = _valuesForGroup(
                                    product,
                                    optionGroups,
                                    groupIndex,
                                  );

                                  return Padding(
                                    padding: EdgeInsets.only(
                                      bottom:
                                          groupIndex == optionGroups.length - 1
                                          ? 0
                                          : 18,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            'Choose ${group.name}',
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.textSecondary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Wrap(
                                          spacing: 10,
                                          runSpacing: 10,
                                          children: values.map((value) {
                                            final isSelected =
                                                _selectedOptionValues[groupIndex] ==
                                                value;
                                            final isAvailable =
                                                _isValueAvailableForGroup(
                                                  product,
                                                  groupIndex,
                                                  value,
                                                );
                                            return ChoiceChip(
                                              label: Text(
                                                value,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 12,
                                                  color: isSelected
                                                      ? Colors.white
                                                      : AppTheme.textPrimary,
                                                ),
                                              ),
                                              selected: isSelected,
                                              onSelected: isAvailable
                                                  ? (_) {
                                                      setState(() {
                                                        _selectedOptionValues[groupIndex] =
                                                            value;
                                                        final keysToClear =
                                                            _selectedOptionValues
                                                                .keys
                                                                .where(
                                                                  (key) =>
                                                                      key >
                                                                      groupIndex,
                                                                )
                                                                .toList();
                                                        for (final key
                                                            in keysToClear) {
                                                          _selectedOptionValues
                                                              .remove(key);
                                                        }
                                                        _currentImageIndex = 0;
                                                      });
                                                      if (_pageController
                                                          .hasClients) {
                                                        _pageController
                                                            .jumpToPage(0);
                                                      }
                                                    }
                                                  : null,
                                              selectedColor:
                                                  AppTheme.terracotta,
                                              disabledColor: AppTheme.bone,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(24),
                                              ),
                                              side: BorderSide(
                                                color: isAvailable
                                                    ? (isSelected
                                                          ? AppTheme.terracotta
                                                          : AppTheme.sand
                                                                .withValues(
                                                                  alpha: 0.5,
                                                                ))
                                                    : AppTheme.textHint
                                                          .withValues(
                                                            alpha: 0.3,
                                                          ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                const SizedBox(height: 10),
                                if (selectedVariant == null)
                                  Text(
                                    optionGroups.length > 1
                                        ? 'Select each option to add this item to your basket.'
                                        : 'Select an option to add this item to your basket.',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: AppTheme.textHint,
                                    ),
                                  ),
                                const SizedBox(height: 14),
                              ],

                              // Stock Status
                              _buildStockIndicator(
                                stockQty: displayStock,
                                madeToOrder: product.isMadeToOrderEnabled,
                              ),
                              const SizedBox(height: 16),

                              // Made-to-order details
                              if (isMtoMode) ...[
                                _buildMadeToOrderCard(
                                  product,
                                  capacityFull: capacityFull,
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Out of Office banner
                              if (shopOffline) _buildOfflineBanner(backToWork),

                              const SizedBox(height: 24),
                              const Divider(
                                height: 1,
                                color: Color(0xFFEEEEEE),
                              ),
                              const SizedBox(height: 24),

                              // Description
                              Text(
                                'Description',
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                product.description ??
                                    'No description available.',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  color: AppTheme.textSecondary,
                                  height: 1.8,
                                ),
                              ),
                              const SizedBox(height: 32),

                              // Care Instructions
                              if (product.careInstructions != null &&
                                  product.careInstructions!.isNotEmpty) ...[
                                const SizedBox(height: 32),
                                _buildCareCard(product.careInstructions!),
                              ],

                              // Fragrance Options
                              if (product.fragranceDescription != null &&
                                  product.fragranceDescription!.isNotEmpty) ...[
                                const SizedBox(height: 32),
                                _buildFragranceCard(
                                  product.fragranceDescription!,
                                ),
                              ],

                              // Artisan Card
                              if (product.shopName != null)
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: AppTheme.sand.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.03,
                                        ),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 28,
                                        backgroundColor: AppTheme.terracotta
                                            .withValues(alpha: 0.1),
                                        backgroundImage:
                                            product.shopLogoUrl != null
                                            ? CachedNetworkImageProvider(
                                                product.shopLogoUrl!,
                                              )
                                            : null,
                                        child: product.shopLogoUrl == null
                                            ? Text(
                                                product.shopName![0],
                                                style:
                                                    GoogleFonts.playfairDisplay(
                                                      color:
                                                          AppTheme.terracotta,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 20,
                                                    ),
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Crafted by',
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                color: AppTheme.textHint,
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    product.shopName!,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style:
                                                        GoogleFonts.playfairDisplay(
                                                          fontSize: 18,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: AppTheme
                                                              .textPrimary,
                                                        ),
                                                  ),
                                                ),
                                                if (product.shopIsVerified) ...[
                                                  const SizedBox(width: 6),
                                                  Tooltip(
                                                    message: 'Verified artisan',
                                                    child: Semantics(
                                                      label: 'Verified artisan',
                                                      child: const Icon(
                                                        Icons.verified_rounded,
                                                        size: 17,
                                                        color: AppTheme.baobab,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        children: [
                                          OutlinedButton(
                                            onPressed: () => context.push(
                                              '/home/shop/${product.shopId}',
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor:
                                                  AppTheme.terracotta,
                                              side: const BorderSide(
                                                color: AppTheme.terracotta,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 8,
                                                  ),
                                            ),
                                            child: Text(
                                              'Visit',
                                              style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          ElevatedButton(
                                            onPressed: () =>
                                                _contactArtisan(product),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppTheme.terracotta,
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 8,
                                                  ),
                                            ),
                                            child: Text(
                                              'Message',
                                              style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              _MoreFromMakerSection(
                                shopId: product.shopId,
                                excludeProductId: product.id,
                              ),
                              if (product.categoryId != null)
                                _YouMayAlsoLikeSection(
                                  categoryId: product.categoryId!,
                                  excludeProductId: product.id,
                                  excludeShopId: product.shopId,
                                ),
                              const SizedBox(height: 32),
                              Text(
                                'Reviews',
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              reviewSummaryAsync.when(
                                data: (summary) => ReviewSummaryCard(
                                  summary: summary,
                                  emptyLabel: 'No reviews yet',
                                ),
                                loading: () => const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: CircularProgressIndicator(
                                      color: AppTheme.terracotta,
                                    ),
                                  ),
                                ),
                                error: (_, __) => const SizedBox.shrink(),
                              ),
                              const SizedBox(height: 16),
                              if (currentUserId == null)
                                _productReviewActionCard(
                                  title: 'Sign in to leave a review',
                                  subtitle:
                                      'Delivered orders unlock buyer reviews for this product.',
                                  buttonLabel: 'Sign In To Review',
                                  onTap: () => _openProductReviewSheet(product),
                                )
                              else if (myReview != null ||
                                  (canReviewAsync.value ?? false))
                                _productReviewActionCard(
                                  title: myReview != null
                                      ? 'Update your review'
                                      : 'Share your experience',
                                  subtitle: myReview != null
                                      ? 'You can update your product review anytime.'
                                      : 'Help other buyers with your honest feedback.',
                                  buttonLabel: myReview != null
                                      ? 'Edit Review'
                                      : 'Write Review',
                                  onTap: () => _openProductReviewSheet(
                                    product,
                                    existingReview: myReview,
                                  ),
                                )
                              else if (canReviewAsync.isLoading)
                                const SizedBox.shrink()
                              else
                                _productReviewStatusNote(
                                  'Reviews unlock after a delivered or completed order.',
                                ),
                              const SizedBox(height: 16),
                              productReviewsAsync.when(
                                data: (allReviews) {
                                  final reviews = withoutBlockedAuthors(
                                    allReviews,
                                    ref.watch(blockedUserIdsProvider).value ??
                                        const <String>{},
                                    (ProductReview review) => review.buyerId,
                                  );
                                  if (reviews.isEmpty) {
                                    return const EmptyReviewsCard(
                                      title: 'No reviews yet',
                                      subtitle:
                                          'Once buyers receive their orders, product reviews will appear here.',
                                    );
                                  }

                                  final visibleReviews = _showAllReviews
                                      ? reviews
                                      : reviews.take(3).toList();
                                  return Column(
                                    children: [
                                      ...visibleReviews.map(
                                        (review) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 12,
                                          ),
                                          child: Column(
                                            children: [
                                              BuyerReviewCard(
                                                avatarUrl:
                                                    review.buyerAvatarUrl,
                                                authorName:
                                                    review.buyerDisplayName ??
                                                    'Verified buyer',
                                                rating: review.rating,
                                                reviewText: review.reviewText,
                                                createdAt: review.createdAt,
                                              ),
                                              ReviewSafetyActions(
                                                reviewId: review.id,
                                                authorId: review.buyerId,
                                                authorName:
                                                    review.buyerDisplayName ??
                                                    'this buyer',
                                                isProductReview: true,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (!_showAllReviews &&
                                          reviews.length > 3)
                                        Center(
                                          child: TextButton(
                                            onPressed: () => setState(
                                              () => _showAllReviews = true,
                                            ),
                                            child: Text(
                                              'See all ${reviews.length} reviews',
                                              style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: AppTheme.terracotta,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                                loading: () => const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: AppTheme.terracotta,
                                    ),
                                  ),
                                ),
                                error: (error, _) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: Text(
                                    'Could not load reviews right now.',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 100), // Bottom padding
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: GradientButton(
                      label: requiresVariantSelection && selectedVariant == null
                          ? (optionGroups.length > 1
                                ? 'Choose Options'
                                : 'Choose ${optionGroups.first.name}')
                          : isMtoMode
                          ? (capacityFull
                                ? 'Fully Booked'
                                : 'Made to Order • ${formatBrowsePrice(mtoPrice)}')
                          : displayStock <= 0
                          ? 'Sold Out'
                          : hasReachedCartStockLimit
                          ? 'Max In Basket'
                          : shopOffline
                          ? 'Pre-order • ${formatBrowsePrice(displayPrice)}'
                          : 'Add to Basket • ${formatBrowsePrice(displayPrice)}',
                      onPressed: canPurchase
                          ? () => _addToCart(
                              product,
                              variant: selectedVariant,
                              isMadeToOrder: isMtoMode,
                              customNote: isMtoMode
                                  ? _customNoteController.text
                                  : null,
                            )
                          : null,
                      isLoading: _isAddingToCart,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
        body: SafeArea(child: _ProductDetailSkeleton(screenWidth: screenWidth)),
      ),
      error: (error, _) => Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppTheme.textPrimary,
            ),
            onPressed: () => context.pop(),
          ),
        ),
        body: ErrorRetryView(
          error: error,
          title: "Couldn't load this product",
          onRetry: () =>
              ref.invalidate(productDetailProvider(widget.productId)),
        ),
      ),
    );
  }

  Widget _buildCareCard(String instructions) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.terracotta, AppTheme.baobab],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.spa_outlined,
              color: Colors.white,
              size: 18,
            ),
          ),
          title: Text(
            'How to Care',
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          subtitle: Text(
            'From the artisan',
            style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textHint),
          ),
          children: [
            Text(
              instructions,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFragranceCard(String description) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.terracotta, AppTheme.baobab],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.local_florist_outlined,
              color: Colors.white,
              size: 18,
            ),
          ),
          title: Text(
            'Fragrance Options',
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          subtitle: Text(
            'From the artisan',
            style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textHint),
          ),
          children: [
            Text(
              description,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineBanner(DateTime? backToWork) {
    final fmt = DateFormat('d MMMM yyyy');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.terracotta.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.terracotta.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.do_not_disturb_on_outlined,
            size: 18,
            color: AppTheme.terracotta,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This shop is currently out of office',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.terracotta,
                  ),
                ),
                if (backToWork != null)
                  Text(
                    'Back ${fmt.format(backToWork)} · You can still pre-order',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  )
                else
                  Text(
                    'Return date not yet set · You can still pre-order',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _productReviewActionCard({
    required String title,
    required String subtitle,
    required String buttonLabel,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.bone,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.terracotta,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              buttonLabel,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _productReviewStatusNote(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bone,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        message,
        style: GoogleFonts.poppins(
          fontSize: 12,
          color: AppTheme.textSecondary,
          height: 1.5,
        ),
      ),
    );
  }

  /// A short, honest delivery line built only from shipping options the
  /// artisan has actually configured. Returns null when nothing is known,
  /// rather than inventing a delivery promise.
  String? _shippingSummary(Product product) {
    final enabled = product.shippingOptions
        .where((option) => option.enabled)
        .toList(growable: false);
    if (enabled.isEmpty) return null;

    double? cheapest;
    var hasPickup = false;
    var hasCourier = false;
    for (final option in enabled) {
      if (cheapest == null || option.price < cheapest) {
        cheapest = option.price;
      }
      if (option.key == 'market_pickup') {
        hasPickup = true;
      } else {
        hasCourier = true;
      }
    }

    final parts = <String>[];
    if (cheapest != null) {
      parts.add(
        cheapest <= 0
            ? 'Free delivery'
            : 'Delivery from ${formatBrowsePrice(cheapest)}',
      );
    }
    if (hasPickup && hasCourier) {
      parts.add('collect or courier');
    } else if (hasPickup) {
      parts.add('collection available');
    } else if (hasCourier) {
      parts.add('courier delivery');
    }
    return parts.join(' · ');
  }

  Widget _floatingIconButton({
    required IconData icon,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 22, color: iconColor ?? AppTheme.textPrimary),
      ),
    );
  }

  Widget _buildMadeToOrderCard(Product product, {required bool capacityFull}) {
    final lead = product.leadTimeLabel;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.terracotta.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.terracotta.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.handyman_outlined,
                color: AppTheme.terracotta,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Made to order',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.terracotta,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            capacityFull
                ? 'This maker is fully booked for custom orders right now. Check back soon.'
                : lead != null
                ? 'Hand-made just for you — ships in $lead.'
                : 'Hand-made to order just for you.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
          if (!capacityFull && product.allowCustomNote) ...[
            const SizedBox(height: 14),
            Text(
              'Custom request (optional)',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _customNoteController,
              maxLines: 3,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Colours, sizing, personalisation…',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStockIndicator({
    required int stockQty,
    bool madeToOrder = false,
  }) {
    // A made-to-order piece at zero stock is still buyable.
    if (stockQty <= 0 && madeToOrder) {
      return Row(
        children: [
          const Icon(
            Icons.handyman_outlined,
            color: AppTheme.terracotta,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            'Made to order',
            style: GoogleFonts.poppins(
              color: AppTheme.terracotta,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }
    if (stockQty <= 0) {
      return Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppTheme.error,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            'Out of Stock',
            style: GoogleFonts.poppins(
              color: AppTheme.error,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }
    if (stockQty <= 5) {
      return Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppTheme.ochre,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            'Only $stockQty left in stock',
            style: GoogleFonts.poppins(
              color: AppTheme.ochre,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        const Icon(
          Icons.check_circle_outline_rounded,
          color: AppTheme.baobab,
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(
          'In Stock',
          style: GoogleFonts.poppins(
            color: AppTheme.baobab,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ProductImageZoomScreen extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _ProductImageZoomScreen({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_ProductImageZoomScreen> createState() =>
      _ProductImageZoomScreenState();
}

class _ProductImageZoomScreenState extends State<_ProductImageZoomScreen> {
  late final PageController _controller;
  late int _currentIndex;
  bool _isZoomed = false;
  double _dismissDrag = 0;
  bool _isDismissDragging = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDismissDragUpdate(DragUpdateDetails details) {
    if (_isZoomed) return;
    setState(() {
      _isDismissDragging = true;
      _dismissDrag = (_dismissDrag + details.delta.dy).clamp(-200.0, 200.0);
    });
  }

  void _handleDismissDragEnd(DragEndDetails details) {
    if (_isZoomed) return;
    if (_dismissDrag.abs() > 110 ||
        details.velocity.pixelsPerSecond.dy.abs() > 800) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _isDismissDragging = false;
      _dismissDrag = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dragProgress = (_dismissDrag.abs() / 200).clamp(0.0, 1.0);
    final backgroundOpacity = _isDismissDragging
        ? 1 - (dragProgress * 0.6)
        : 1.0;
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: backgroundOpacity),
      body: SafeArea(
        child: Stack(
          children: [
            AnimatedContainer(
              duration: _isDismissDragging
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              transform: Matrix4.translationValues(0, _dismissDrag, 0),
              child: GestureDetector(
                onVerticalDragUpdate: _handleDismissDragUpdate,
                onVerticalDragEnd: _handleDismissDragEnd,
                child: PageView.builder(
                  controller: _controller,
                  physics: _isZoomed
                      ? const NeverScrollableScrollPhysics()
                      : const BouncingScrollPhysics(),
                  itemCount: widget.images.length,
                  onPageChanged: (index) =>
                      setState(() => _currentIndex = index),
                  itemBuilder: (context, index) {
                    return _ZoomableProductImage(
                      imageUrl: widget.images[index],
                      onZoomChanged: (zoomed) {
                        if (index != _currentIndex) return;
                        setState(() => _isZoomed = zoomed);
                      },
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 22,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ),
            if (widget.images.length > 1)
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      widget.images.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: i == _currentIndex ? 20 : 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: i == _currentIndex
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A single zoomable image: double-tap to zoom in/out at the tap point,
/// pinch to zoom, and reports its zoom state so the enclosing [PageView]
/// can stop fighting for swipe gestures while zoomed in.
class _ZoomableProductImage extends StatefulWidget {
  final String imageUrl;
  final ValueChanged<bool> onZoomChanged;

  const _ZoomableProductImage({
    required this.imageUrl,
    required this.onZoomChanged,
  });

  @override
  State<_ZoomableProductImage> createState() => _ZoomableProductImageState();
}

class _ZoomableProductImageState extends State<_ZoomableProductImage>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformController =
      TransformationController();
  TapDownDetails? _doubleTapDetails;
  bool _zoomed = false;

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _setZoomed(bool zoomed) {
    if (_zoomed == zoomed) return;
    _zoomed = zoomed;
    widget.onZoomChanged(zoomed);
  }

  void _handleDoubleTap() {
    if (_transformController.value != Matrix4.identity()) {
      _transformController.value = Matrix4.identity();
      _setZoomed(false);
      return;
    }
    final position = _doubleTapDetails?.localPosition ?? Offset.zero;
    final zoomed = Matrix4.identity()
      ..translateByDouble(-position.dx * 1.8, -position.dy * 1.8, 0, 1)
      ..scaleByDouble(2.8, 2.8, 2.8, 1);
    _transformController.value = zoomed;
    _setZoomed(true);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (details) => _doubleTapDetails = details,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _transformController,
        minScale: 1,
        maxScale: 4,
        onInteractionEnd: (_) {
          final scale = _transformController.value.getMaxScaleOnAxis();
          _setZoomed(scale > 1.02);
        },
        child: Center(
          child: CachedNetworkImage(
            imageUrl: widget.imageUrl,
            fit: BoxFit.contain,
            placeholder: (_, __) => const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white54,
              ),
            ),
            errorWidget: (_, __, ___) => const Icon(
              Icons.image_outlined,
              size: 64,
              color: Colors.white54,
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact "Added to basket" confirmation shown in the SnackBar so buyers
/// can see what was added without leaving the product page.
class _AddedToBasketToast extends StatelessWidget {
  final String imageUrl;
  final String title;

  const _AddedToBasketToast({required this.imageUrl, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => Container(
              width: 40,
              height: 40,
              color: Colors.white24,
              child: const Icon(
                Icons.image_outlined,
                size: 18,
                color: Colors.white70,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Added to basket',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Horizontal row of other products from the same maker, so buyers can keep
/// browsing without leaving the product page. Hides itself entirely when
/// the maker only has this one product listed (or the data is unavailable).
class _MoreFromMakerSection extends ConsumerWidget {
  final String shopId;
  final String excludeProductId;

  const _MoreFromMakerSection({
    required this.shopId,
    required this.excludeProductId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(shopProductsProvider(shopId));
    return productsAsync.when(
      data: (products) {
        final others = products
            .where((p) => p.id != excludeProductId)
            .toList(growable: false);
        if (others.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'More from this maker',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 240,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: others.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) => SizedBox(
                    width: 150,
                    child: ProductCard(
                      product: others[index],
                      showShopName: false,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// Horizontal row of same-category products, so buyers can keep browsing
/// related pieces. Skips this product and this maker's own items (already
/// covered by "More from this maker") and shows in-stock pieces first.
/// Hides itself when nothing else fits.
class _YouMayAlsoLikeSection extends ConsumerWidget {
  final String categoryId;
  final String excludeProductId;
  final String excludeShopId;

  const _YouMayAlsoLikeSection({
    required this.categoryId,
    required this.excludeProductId,
    required this.excludeShopId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(
      categoryProductsProvider(CategoryProductFilter(categoryId: categoryId)),
    );
    return productsAsync.when(
      data: (products) {
        final others = products
            .where((p) => p.id != excludeProductId && p.shopId != excludeShopId)
            .toList();
        others.sort((a, b) {
          final byStock = (b.isInStock ? 1 : 0).compareTo(a.isInStock ? 1 : 0);
          if (byStock != 0) return byStock;
          return b.createdAt.compareTo(a.createdAt);
        });
        if (others.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You may also like',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 240,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: others.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) => SizedBox(
                    width: 150,
                    child: ProductCard(product: others[index]),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// Skeleton placeholder shown while the product page's data loads, so the
/// screen never sits on a bare spinner.
class _ProductDetailSkeleton extends StatelessWidget {
  final double screenWidth;

  const _ProductDetailSkeleton({required this.screenWidth});

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(width: double.infinity, height: screenWidth, radius: 0),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkeletonBox(width: 120, height: 14),
                  const SizedBox(height: 16),
                  const SkeletonBox(width: 220, height: 26),
                  const SizedBox(height: 12),
                  const SkeletonBox(width: 100, height: 28),
                  const SizedBox(height: 24),
                  const SkeletonBox(width: double.infinity, height: 14),
                  const SizedBox(height: 8),
                  const SkeletonBox(width: double.infinity, height: 14),
                  const SizedBox(height: 8),
                  SkeletonBox(width: screenWidth * 0.6, height: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
