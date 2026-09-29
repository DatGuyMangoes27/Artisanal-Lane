import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app/theme.dart';
import '../models/product.dart';
import '../features/buyer/providers/favourite_actions.dart';

/// ═══════════════════════════════════════════════════════════════
/// ProductCard – Clean, elegant item display
/// ═══════════════════════════════════════════════════════════════
///
/// When [onFavouriteToggle] is not supplied, the heart wires itself up to
/// the shared favourite state (`isFavouriteProvider` / `toggleFavourite`) so
/// it works instantly on any screen without each caller having to plumb it
/// through. Pass [isFavourite]/[onFavouriteToggle] explicitly to keep a
/// caller's existing custom behaviour.
class ProductCard extends ConsumerWidget {
  final Product product;
  final bool? isFavourite;
  final VoidCallback? onFavouriteToggle;
  final bool showShopName;

  const ProductCard({
    super.key,
    required this.product,
    this.isFavourite,
    this.onFavouriteToggle,
    this.showShopName = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool resolvedIsFavourite =
        isFavourite ?? ref.watch(isFavouriteProvider(product.id));
    final resolvedOnToggle =
        onFavouriteToggle ?? () => toggleFavourite(ref, context, product.id);
    return GestureDetector(
      onTap: () => context.push('/home/product/${product.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: AppTheme.sand.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image ──────────────────────────────────
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(15),
                    ),
                    child: SizedBox.expand(
                      child: CachedNetworkImage(
                        imageUrl: product.primaryImage,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: AppTheme.bone,
                          child: Center(
                            child: Icon(
                              Icons.auto_awesome,
                              color: AppTheme.sand,
                              size: 28,
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: AppTheme.bone,
                          child: const Icon(
                            Icons.image_outlined,
                            color: AppTheme.textHint,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Sale badge – elegant pill
                  if (product.isOnSale)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'SALE',
                          style: GoogleFonts.poppins(
                            color: AppTheme.terracotta,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  // Favourite
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: resolvedOnToggle,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          resolvedIsFavourite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 16,
                          color: resolvedIsFavourite
                              ? AppTheme.terracotta
                              : AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ── Info ───────────────────────────────────
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showShopName && product.shopName != null)
                      Text(
                        product.shopName!.toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          color: AppTheme.textHint,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Text(
                      product.title,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    // Price row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'R${product.price.toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: product.isOnSale
                                ? AppTheme.terracotta
                                : AppTheme.textPrimary,
                          ),
                        ),
                        if (product.isOnSale) ...[
                          const SizedBox(width: 6),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 1),
                            child: Text(
                              'R${product.compareAtPrice!.toStringAsFixed(0)}',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: AppTheme.textHint,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: AppTheme.textHint,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Featured product card for larger horizontal carousels.
class FeaturedProductCard extends StatelessWidget {
  final Product product;

  const FeaturedProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/home/product/${product.id}'),
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: SizedBox(
                height: 180,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: product.primaryImage,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: AppTheme.bone),
                      errorWidget: (_, __, ___) =>
                          Container(color: AppTheme.bone),
                    ),
                    if (product.isOnSale)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'SALE',
                            style: GoogleFonts.poppins(
                              color: AppTheme.terracotta,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Details
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (product.shopName != null)
                    Text(
                      product.shopName!.toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        color: AppTheme.textHint,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 4),
                  Text(
                    product.title,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'R${product.price.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: product.isOnSale
                          ? AppTheme.terracotta
                          : AppTheme.textPrimary,
                    ),
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
