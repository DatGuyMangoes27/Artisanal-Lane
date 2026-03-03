import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../app/theme.dart';
import '../../../widgets/gradient_button.dart';
import '../../../models/product.dart';
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

  Future<void> _addToCart(String productId) async {
    setState(() => _isAddingToCart = true);
    try {
      final service = ref.read(supabaseServiceProvider);
      await service.addToCart(Supabase.instance.client.auth.currentUser!.id, productId);
      ref.invalidate(cartItemsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added to basket', style: GoogleFonts.poppins(color: Colors.white)),
            backgroundColor: AppTheme.baobab,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add to basket', style: GoogleFonts.poppins(color: Colors.white)),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAddingToCart = false);
    }
  }

  void _shareProduct(Product product) {
    Share.share('Check out ${product.title} on Artisan Lane! R${product.price.toStringAsFixed(0)}');
  }

  Future<void> _toggleFavourite(String productId, bool currentlyFav) async {
    final service = ref.read(supabaseServiceProvider);
    try {
      if (currentlyFav) {
        await service.removeFavourite(Supabase.instance.client.auth.currentUser!.id, productId);
      } else {
        await service.addFavourite(Supabase.instance.client.auth.currentUser!.id, productId);
      }
      ref.invalidate(favouriteIdsProvider);
      ref.invalidate(favouriteProductsProvider);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(productDetailProvider(widget.productId));
    final screenWidth = MediaQuery.of(context).size.width;

    final favIdsAsync = ref.watch(favouriteIdsProvider);
    final favIds = favIdsAsync.value ?? [];

    return productAsync.when(
      data: (product) {
        final isFav = favIds.contains(product.id);
        final shopAsync = ref.watch(shopDetailProvider(product.shopId));
        final shop = shopAsync.asData?.value;
        final shopOffline = shop?.isOffline ?? false;
        final backToWork = shop?.backToWorkDate;
        final imageCount =
            product.images.isEmpty ? 1 : product.images.length;

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
                                onTap: () => _shareProduct(product),
                              ),
                              const SizedBox(width: 8),
                              _floatingIconButton(
                                icon: isFav
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_outline_rounded,
                                iconColor: isFav
                                    ? AppTheme.error
                                    : AppTheme.textPrimary,
                                onTap: () => _toggleFavourite(product.id, isFav),
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
                                final url = product.images.isNotEmpty
                                    ? product.images[index]
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
                                        color: AppTheme.terracotta
                                            .withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ),
                                  errorWidget: (_, __, ___) => Container(
                                    color: AppTheme.clay.withValues(alpha: 0.1),
                                    child: const Icon(Icons.image_outlined,
                                        size: 64, color: AppTheme.textHint),
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
                                      duration:
                                          const Duration(milliseconds: 300),
                                      width:
                                          i == _currentImageIndex ? 24 : 8,
                                      height: 8,
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 4),
                                      decoration: BoxDecoration(
                                        color: i == _currentImageIndex
                                            ? Colors.white
                                            : Colors.white
                                                .withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(4),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.1),
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
                            if (product.isOnSale)
                              Positioned(
                                bottom: 16,
                                left: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.terracotta,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '-${product.discountPercent.toStringAsFixed(0)}%',
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
                              top: Radius.circular(24)),
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
                                      const Icon(Icons.star_rounded,
                                          size: 18, color: AppTheme.ochre),
                                      const SizedBox(width: 4),
                                      Text(
                                        '4.8 (124 reviews)', // Mock data
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: AppTheme.textSecondary,
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
                                    'R${product.price.toStringAsFixed(0)}',
                                    style: GoogleFonts.playfairDisplay(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.sienna,
                                    ),
                                  ),
                                  if (product.isOnSale) ...[
                                    const SizedBox(width: 12),
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 6),
                                      child: Text(
                                        'R${product.compareAtPrice!.toStringAsFixed(0)}',
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

                              // Stock Status
                              _buildStockIndicator(product),
                              const SizedBox(height: 16),

                              // Out of Office banner
                              if (shopOffline)
                                _buildOfflineBanner(backToWork),

                              const SizedBox(height: 24),
                              const Divider(
                                  height: 1, color: Color(0xFFEEEEEE)),
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
                                      color: AppTheme.sand
                                          .withValues(alpha: 0.3),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.03),
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
                                                    product.shopLogoUrl!)
                                                : null,
                                        child: product.shopLogoUrl == null
                                            ? Text(
                                                product.shopName![0],
                                                style: GoogleFonts
                                                    .playfairDisplay(
                                                  color: AppTheme.terracotta,
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
                                              style: GoogleFonts.playfairDisplay(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w700,
                                                color: AppTheme.textPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      OutlinedButton(
                                        onPressed: () => context.push(
                                            '/home/shop/${product.shopId}'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppTheme.terracotta,
                                          side: const BorderSide(
                                              color: AppTheme.terracotta),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          padding: const EdgeInsets
                                              .symmetric(
                                              horizontal: 16, vertical: 8),
                                        ),
                                        child: Text(
                                          'Visit',
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
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
                      label: !product.isInStock
                          ? 'Sold Out'
                          : shopOffline
                              ? 'Pre-order • R${product.price.toStringAsFixed(0)}'
                              : 'Add to Basket • R${product.price.toStringAsFixed(0)}',
                      onPressed: product.isInStock && !_isAddingToCart
                          ? () => _addToCart(product.id)
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
          child: CircularProgressIndicator(
            color: AppTheme.terracotta,
          ),
        ),
      ),
      error: (error, _) => Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded,
                color: AppTheme.textPrimary),
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
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding:
              const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
            child: const Icon(Icons.spa_outlined,
                color: Colors.white, size: 18),
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
            style: GoogleFonts.poppins(
                fontSize: 11, color: AppTheme.textHint),
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
          Icon(Icons.do_not_disturb_on_outlined,
              size: 18, color: AppTheme.terracotta),
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

  Widget _buildStockIndicator(dynamic product) {
    if (!product.isInStock) {
      return Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppTheme.error, size: 18),
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
    if (product.isLowStock) {
      return Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppTheme.ochre, size: 18),
          const SizedBox(width: 8),
          Text(
            'Only ${product.stockQty} left in stock',
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
        const Icon(Icons.check_circle_outline_rounded,
            color: AppTheme.baobab, size: 18),
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
