import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme.dart';
import '../../../models/models.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/gradient_fab.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/vendor_providers.dart';

class VendorProductsScreen extends ConsumerWidget {
  const VendorProductsScreen({super.key});

  Future<void> _markSoldOut(
    BuildContext context,
    WidgetRef ref,
    Product product,
  ) async {
    try {
      final service = ref.read(supabaseServiceProvider);
      final updates = <String, dynamic>{'stock_qty': 0};

      if (product.variants.isNotEmpty) {
        updates['variants'] = product.variants
            .map((variant) => {...variant.toJson(), 'stock_qty': 0})
            .toList();
      }

      await service.updateProduct(product.id, updates);
      ref.invalidate(vendorProductsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${product.title} marked as sold out.',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            backgroundColor: AppTheme.baobab,
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not update product: $error',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(vendorProductsProvider);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      floatingActionButton: GradientFabExtended(
        label: 'Add Product',
        icon: Icons.add_rounded,
        onTap: () => context.push('/vendor/products/new'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              child: Text(
                'My Products',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            Expanded(
              child: productsAsync.when(
                data: (products) {
                  if (products.isEmpty) return _buildEmpty(context);
                  return RefreshIndicator(
                    color: AppTheme.terracotta,
                    onRefresh: () async =>
                        ref.invalidate(vendorProductsProvider),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                      itemCount: products.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) =>
                          _buildProductTile(context, ref, products[i]),
                    ),
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.terracotta,
                    strokeWidth: 2,
                  ),
                ),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductTile(
    BuildContext context,
    WidgetRef ref,
    Product product,
  ) {
    final optionCount = product.variants.length;
    final stockLabel = product.stockQty <= 0
        ? 'Sold out'
        : 'Stock: ${product.stockQty}';

    return GestureDetector(
      onTap: () => context.push('/vendor/products/${product.id}'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 64,
                height: 64,
                child: CachedNetworkImage(
                  imageUrl: product.primaryImage,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: AppTheme.bone),
                  errorWidget: (_, __, ___) => Container(
                    color: AppTheme.bone,
                    child: const Icon(
                      Icons.image_outlined,
                      color: AppTheme.textHint,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'R${product.price.toStringAsFixed(0)} · $stockLabel${optionCount > 0 ? ' · $optionCount option(s)' : ''}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (product.isOnSale)
                        _productTag('On Sale', AppTheme.terracotta),
                      if (optionCount > 0)
                        _productTag('Options', AppTheme.ochre),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: product.isPublished
                        ? AppTheme.baobab.withValues(alpha: 0.1)
                        : AppTheme.textHint.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    product.isPublished ? 'Live' : 'Draft',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: product.isPublished
                          ? AppTheme.baobab
                          : AppTheme.textHint,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: product.stockQty <= 0
                      ? null
                      : () => _markSoldOut(context, ref, product),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.terracotta,
                    side: BorderSide(
                      color: product.stockQty <= 0
                          ? AppTheme.textHint.withValues(alpha: 0.3)
                          : AppTheme.terracotta.withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    product.stockQty <= 0 ? 'Sold Out' : 'Sold',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _productTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 56,
              color: AppTheme.textHint,
            ),
            const SizedBox(height: 16),
            Text(
              'No Products Yet',
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first handcrafted product to start selling',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            GradientButton(
              label: 'Add Product',
              icon: Icons.add_rounded,
              onPressed: () => context.push('/vendor/products/new'),
            ),
          ],
        ),
      ),
    );
  }
}
