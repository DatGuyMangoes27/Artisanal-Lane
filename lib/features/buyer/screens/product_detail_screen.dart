import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../app/theme.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/sign_in_prompt_sheet.dart';
import '../../../models/models.dart';
import '../utils/product_detail_actions.dart';
import '../widgets/review_widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/buyer_providers.dart';

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
  final Map<int, String> _selectedOptionValues = {};
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
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

  Future<void> _addToCart(Product product, {ProductVariant? variant}) async {
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
      );
      ref.invalidate(cartItemsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added to basket',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            backgroundColor: AppTheme.baobab,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to add to basket',
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

  Future<void> _shareProduct(Product product, {ProductVariant? variant}) async {
    final sharePrice = variant?.price ?? product.price;
    try {
      await Share.share(
        buildProductShareText(
          title: product.title,
          price: sharePrice,
        ),
        subject: 'Artisan Lane product share',
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

  Future<void> _toggleFavourite(String productId, bool currentlyFav) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (requiresSignInForFavourite(userId)) {
      await showSignInPromptSheet(
        context,
        title: 'Sign in to save favourites',
        message:
            'Create an account or sign in to save this item to your favourites.',
      );
      return;
    }

    final service = ref.read(supabaseServiceProvider);
    try {
      if (currentlyFav) {
        await service.removeFavourite(userId!, productId);
      } else {
        await service.addFavourite(userId!, productId);
      }
      ref.invalidate(favouriteIdsProvider);
      ref.invalidate(favouriteProductsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            currentlyFav ? 'Removed from favourites' : 'Saved to favourites',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: AppTheme.baobab,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not update favourites right now.',
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
            'Could not open chat: $error',
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
    final draft = await showReviewComposerSheet(
      context,
      title: existingReview != null
          ? 'Edit product review'
          : 'Review this product',
      subtitle: product.title,
      initialRating: existingReview?.rating ?? 5,
      initialReviewText: existingReview?.reviewText ?? '',
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
            'Could not save review: $error',
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

    final favIdsAsync = ref.watch(favouriteIdsProvider);
    final favIds = favIdsAsync.value ?? [];
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
        final isFav = favIds.contains(product.id);
        final shopAsync = ref.watch(shopDetailProvider(product.shopId));
        final shop = shopAsync.asData?.value;
        final shopOffline = shop?.isOffline ?? false;
        final backToWork = shop?.backToWorkDate;
        final optionGroups = _resolveOptionGroups(product);
        final selectedVariant = _findSelectedVariant(product, optionGroups);
        final previewVariant =
            _findPreviewVariant(product, optionGroups) ??
            product.defaultVariant;
        final displayImages = (previewVariant?.images.isNotEmpty ?? false)
            ? previewVariant!.images
            : product.images;
        final displayPrice = previewVariant?.price ?? product.price;
        final displayCompareAtPrice =
            previewVariant?.compareAtPrice ?? product.compareAtPrice;
        final displayStock = previewVariant?.stockQty ?? product.stockQty;
        final requiresVariantSelection =
            product.hasVariants && optionGroups.isNotEmpty;
        final canPurchase =
            displayStock > 0 &&
            !_isAddingToCart &&
            (!requiresVariantSelection || selectedVariant != null);
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
                                    _toggleFavourite(product.id, isFav),
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
                                return CachedNetworkImage(
                                  imageUrl: url,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  placeholder: (_, __) => Container(
                                    color: AppTheme.clay.withValues(alpha: 0.1),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppTheme.terracotta.withValues(
                                          alpha: 0.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                  errorWidget: (_, __, ___) => Container(
                                    color: AppTheme.clay.withValues(alpha: 0.1),
                                    child: const Icon(
                                      Icons.image_outlined,
                                      size: 64,
                                      color: AppTheme.textHint,
                                    ),
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
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.star_rounded,
                                        size: 18,
                                        color: AppTheme.ochre,
                                      ),
                                      const SizedBox(width: 4),
                                      reviewSummaryAsync.when(
                                        data: (summary) => Text(
                                          summary.hasReviews
                                              ? '${summary.averageRating.toStringAsFixed(1)} (${summary.reviewCount} reviews)'
                                              : 'No reviews yet',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: AppTheme.textSecondary,
                                          ),
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
                                    'R${displayPrice.toStringAsFixed(0)}',
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
                                        'R${displayCompareAtPrice!.toStringAsFixed(0)}',
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
                              _buildStockIndicator(stockQty: displayStock),
                              const SizedBox(height: 16),

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
                                            Text(
                                              product.shopName!,
                                              style:
                                                  GoogleFonts.playfairDisplay(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppTheme.textPrimary,
                                                  ),
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
                                data: (reviews) {
                                  if (reviews.isEmpty) {
                                    return const EmptyReviewsCard(
                                      title: 'No reviews yet',
                                      subtitle:
                                          'Once buyers receive their orders, product reviews will appear here.',
                                    );
                                  }

                                  final visibleReviews = reviews
                                      .take(3)
                                      .toList();
                                  return Column(
                                    children: visibleReviews
                                        .map(
                                          (review) => Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 12,
                                            ),
                                            child: BuyerReviewCard(
                                              avatarUrl: review.buyerAvatarUrl,
                                              authorName:
                                                  review.buyerDisplayName ??
                                                  'Verified buyer',
                                              rating: review.rating,
                                              reviewText: review.reviewText,
                                              createdAt: review.createdAt,
                                            ),
                                          ),
                                        )
                                        .toList(),
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
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
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
                      label: displayStock <= 0
                          ? 'Sold Out'
                          : requiresVariantSelection && selectedVariant == null
                          ? (optionGroups.length > 1
                                ? 'Choose Options'
                                : 'Choose ${optionGroups.first.name}')
                          : shopOffline
                          ? 'Pre-order • R${displayPrice.toStringAsFixed(0)}'
                          : 'Add to Basket • R${displayPrice.toStringAsFixed(0)}',
                      onPressed: canPurchase
                          ? () => _addToCart(product, variant: selectedVariant)
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
      loading: () => const Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.terracotta),
        ),
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
        body: Center(child: Text('Error: $error')),
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

  Widget _buildStockIndicator({required int stockQty}) {
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
