import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme.dart';
import '../../../core/constants/feature_flags.dart';
import '../../../core/pricing/price_format.dart';
import '../../../models/models.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/gradient_fab.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/vendor_providers.dart';
import '../utils/vendor_payout_setup.dart';
import '../utils/vendor_subscription_setup.dart';
import '../widgets/workspace/workspace_header.dart';
import '../widgets/workspace/workspace_stat_tile.dart';

enum _ProductFilter { all, live, draft, soldOut }

/// Pure filter used by the widget.
List<Product> _filterVendorProducts(
  List<Product> products, {
  required String query,
  required _ProductFilter filter,
}) {
  final normalized = query.trim().toLowerCase();
  return products.where((product) {
    final matchesQuery =
        normalized.isEmpty || product.title.toLowerCase().contains(normalized);
    if (!matchesQuery) return false;
    switch (filter) {
      case _ProductFilter.all:
        return true;
      case _ProductFilter.live:
        return product.isPublished && product.stockQty > 0;
      case _ProductFilter.draft:
        return !product.isPublished;
      case _ProductFilter.soldOut:
        // Made-to-order pieces stay buyable at zero stock.
        return product.stockQty <= 0 && !product.isMadeToOrderEnabled;
    }
  }).toList();
}

class VendorProductsScreen extends ConsumerStatefulWidget {
  const VendorProductsScreen({super.key});

  @override
  ConsumerState<VendorProductsScreen> createState() =>
      _VendorProductsScreenState();
}

class _VendorProductsScreenState extends ConsumerState<VendorProductsScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  _ProductFilter _filter = _ProductFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showSubscriptionRequiredDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Start your artisan subscription',
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w600),
        ),
        content: Text(
          vendorSubscriptionGateMessage,
          style: GoogleFonts.poppins(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.push('/vendor/profile/subscription');
            },
            child: const Text('Open subscription'),
          ),
        ],
      ),
    );
  }

  void _showPayoutRequiredDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Complete payout details',
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w600),
        ),
        content: Text(
          vendorPayoutGateMessage,
          style: GoogleFonts.poppins(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.push('/vendor/profile/payouts');
            },
            child: const Text('Open payout details'),
          ),
        ],
      ),
    );
  }

  void _handleAddProductTap(
    BuildContext context,
    bool payoutReady,
    bool subscriptionActive,
    bool internalEditorTestMode,
  ) {
    if (internalEditorTestMode) {
      context.push('/vendor/products/new');
      return;
    }
    if (!subscriptionActive) {
      _showSubscriptionRequiredDialog(context);
      return;
    }
    if (payoutReady) {
      context.push('/vendor/products/new');
      return;
    }
    _showPayoutRequiredDialog(context);
  }

  Future<void> _confirmDeleteProduct(
    BuildContext context,
    WidgetRef ref,
    Product product,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(
              Icons.delete_forever_rounded,
              color: AppTheme.error,
              size: 26,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Delete ${product.title}?',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'The listing will be removed from your store and the marketplace. Any past orders containing this product stay intact for your records.',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppTheme.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final service = ref.read(supabaseServiceProvider);
      await service.deleteProduct(product.id);
      ref.invalidate(vendorProductsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${product.title} deleted.',
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
              'Could not delete product: $error',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

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
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(vendorProductsProvider);
    final payoutProfile =
        ref.watch(vendorPayoutProfileStreamProvider).value ??
        ref.watch(vendorPayoutProfileProvider).value;
    final payoutReady = isVendorPayoutSetupComplete(payoutProfile);
    final subscription = preferredVendorSubscription(
      streamValue: ref.watch(vendorSubscriptionStreamProvider).value,
      futureValue: ref.watch(vendorSubscriptionProvider).value,
    );
    final subscriptionActive = isVendorSubscriptionActive(subscription);
    final internalEditorTestMode = isInternalProductEditorTestMode(
      ref.watch(currentUserIdProvider),
    );

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      floatingActionButton: GradientFabExtended(
        label: 'Add Product',
        icon: Icons.add_rounded,
        onTap: () => _handleAddProductTap(
          context,
          payoutReady,
          subscriptionActive,
          internalEditorTestMode,
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const WorkspaceHeader(eyebrow: 'Your shop', title: 'Products'),
            Expanded(
              child: productsAsync.when(
                data: (products) {
                  if (products.isEmpty) {
                    return _buildEmpty(
                      context,
                      payoutReady,
                      subscriptionActive,
                      internalEditorTestMode,
                    );
                  }
                  final visible = _filterVendorProducts(
                    products,
                    query: _query,
                    filter: _filter,
                  );
                  return RefreshIndicator(
                    color: AppTheme.terracotta,
                    onRefresh: () async =>
                        ref.invalidate(vendorProductsProvider),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (value) =>
                                setState(() => _query = value),
                            decoration: InputDecoration(
                              hintText: 'Search your products',
                              prefixIcon: const Icon(Icons.search_rounded),
                              filled: true,
                              fillColor: AppTheme.cardBg,
                              suffixIcon: _query.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Clear search',
                                      icon: const Icon(Icons.close_rounded),
                                      onPressed: () => setState(() {
                                        _searchController.clear();
                                        _query = '';
                                      }),
                                    ),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 40,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            children: [
                              for (final entry in const [
                                (_ProductFilter.all, 'All'),
                                (_ProductFilter.live, 'Live'),
                                (_ProductFilter.draft, 'Draft'),
                                (_ProductFilter.soldOut, 'Sold out'),
                              ])
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: WorkspaceFilterChip(
                                    label: entry.$2,
                                    selected: _filter == entry.$1,
                                    onTap: () =>
                                        setState(() => _filter = entry.$1),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (visible.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 32,
                            ),
                            child: Center(
                              child: Text(
                                'No products match your search or filter.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              children: [
                                for (final product in visible) ...[
                                  _buildProductTile(context, ref, product),
                                  const SizedBox(height: 12),
                                ],
                              ],
                            ),
                          ),
                      ],
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
    // Made-to-order pieces stay buyable at zero stock, so they aren't sold out.
    final isSoldOut = product.stockQty <= 0 && !product.isMadeToOrderEnabled;
    final stockLabel = isSoldOut
        ? 'Sold out'
        : product.stockQty <= 0
        ? 'Made to order'
        : 'Stock: ${product.stockQty}';

    return GestureDetector(
      onTap: () => context.push('/vendor/products/${product.id}'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSoldOut
                ? AppTheme.error.withValues(alpha: 0.2)
                : AppTheme.sand.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Opacity(
              opacity: isSoldOut ? 0.75 : 1,
              child: ClipRRect(
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
                    '${formatBrowsePrice(product.price)} · $stockLabel${optionCount > 0 ? ' · $optionCount option(s)' : ''}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: isSoldOut
                          ? AppTheme.error
                          : AppTheme.textSecondary,
                      fontWeight: isSoldOut ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (isSoldOut) _productTag('Sold Out', AppTheme.error),
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    WorkspaceStatusPill(
                      label: product.isPublished ? 'Live' : 'Draft',
                      color: product.isPublished
                          ? AppTheme.baobab
                          : AppTheme.textHint,
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: PopupMenuButton<String>(
                        tooltip: 'More actions',
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.more_vert_rounded,
                          size: 18,
                          color: AppTheme.textSecondary,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onSelected: (value) {
                          switch (value) {
                            case 'edit':
                              context.push('/vendor/products/${product.id}');
                              break;
                            case 'delete':
                              _confirmDeleteProduct(context, ref, product);
                              break;
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem<String>(
                            value: 'edit',
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.edit_outlined,
                                  size: 18,
                                  color: AppTheme.textSecondary,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Edit',
                                  style: GoogleFonts.poppins(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                  color: AppTheme.error,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Delete product',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: AppTheme.error,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: isSoldOut
                      ? null
                      : () => _markSoldOut(context, ref, product),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.terracotta,
                    side: BorderSide(
                      color: isSoldOut
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
                    isSoldOut ? 'Sold Out' : 'Sold',
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

  Widget _buildEmpty(
    BuildContext context,
    bool payoutReady,
    bool subscriptionActive,
    bool internalEditorTestMode,
  ) {
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
              onPressed: () => _handleAddProductTap(
                context,
                payoutReady,
                subscriptionActive,
                internalEditorTestMode,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
