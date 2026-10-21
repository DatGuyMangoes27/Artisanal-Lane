import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme.dart';
import '../../../core/pricing/pricing.dart';
import '../../../core/ui/friendly_error.dart';
import '../../../models/cart_item.dart';
import '../providers/buyer_providers.dart';
import '../utils/cart_stock_guard.dart';
import '../utils/multi_shop_checkout.dart';
import '../../../widgets/skeleton.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  bool _isGift = false;
  final _recipientController = TextEditingController();
  final _messageController = TextEditingController();

  /// Ids removed optimistically (via swipe or tap) but not yet confirmed by
  /// the server. Filtered out of the displayed list immediately so
  /// Dismissible's item count stays in sync.
  final Set<String> _pendingRemovalIds = {};

  @override
  void initState() {
    super.initState();
    final giftOptions = ref.read(giftOptionsProvider);
    _isGift = giftOptions.isGift;
    _recipientController.text = giftOptions.recipient;
    _messageController.text = giftOptions.message;
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  /// Removes [item] immediately (optimistic) and shows a "Removed · Undo"
  /// snackbar. Undo re-adds the same product/variant/quantity. On failure,
  /// the item reappears and a friendly error is shown.
  Future<void> _removeItemWithUndo(CartItem item) async {
    HapticFeedback.lightImpact();
    setState(() => _pendingRemovalIds.add(item.id));
    final service = ref.read(supabaseServiceProvider);
    try {
      await service.removeCartItem(item.id);
      ref.invalidate(cartItemsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Removed',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            backgroundColor: AppTheme.textPrimary,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Undo',
              textColor: AppTheme.ochre,
              onPressed: () => _undoRemove(item),
            ),
          ),
        );
    } catch (error) {
      if (!mounted) return;
      setState(() => _pendingRemovalIds.remove(item.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyErrorMessage(
              error,
              fallback: "Couldn't remove that item. Please try again.",
            ),
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _undoRemove(CartItem item) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final service = ref.read(supabaseServiceProvider);
    try {
      await service.addToCart(
        userId,
        item.productId,
        variantId: item.variantId,
        quantity: item.quantity,
      );
      setState(() => _pendingRemovalIds.remove(item.id));
      ref.invalidate(cartItemsProvider);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyErrorMessage(
              error,
              fallback: "Couldn't bring that item back. Please try again.",
            ),
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _updateQuantity(String cartItemId, int newQty) async {
    final service = ref.read(supabaseServiceProvider);
    try {
      await service.updateCartItemQuantity(cartItemId, newQty);
      ref.invalidate(cartItemsProvider);
    } catch (error) {
      if (!mounted) return;
      final message = error is StateError
          ? error.message.toString()
          : 'Could not update quantity';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
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
    final cartItems = ref.watch(cartItemsProvider);
    final canPop = context.canPop();

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: cartItems.when(
        data: (items) {
          final visibleItems = items
              .where((i) => !_pendingRemovalIds.contains(i.id))
              .toList(growable: false);
          if (visibleItems.isEmpty) {
            return RefreshIndicator(
              color: AppTheme.terracotta,
              onRefresh: () => ref.refresh(cartItemsProvider.future),
              child: _buildEmptyState(context, canPop: canPop),
            );
          }
          return _buildCartContent(context, visibleItems, canPop: canPop);
        },
        loading: () => Column(
          children: [
            if (canPop) _buildBackRow(context),
            Expanded(child: _buildLoadingSkeleton(canPop: canPop)),
          ],
        ),
        error: (error, _) => Column(
          children: [
            if (canPop) _buildBackRow(context),
            Expanded(
              child: ErrorRetryView(
                error: error,
                title: "Couldn't load your basket",
                onRetry: () => ref.invalidate(cartItemsProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Back Row (shown only when this screen was pushed) ────────────
  Widget _buildBackRow(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: _BackButton(onTap: () => context.pop()),
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────
  Widget _buildHeader({bool canPop = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canPop) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: _BackButton(onTap: () => context.pop()),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            'YOUR BASKET',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.3,
              color: AppTheme.terracotta,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Ready to check out',
            style: GoogleFonts.playfairDisplay(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Handcrafted items awaiting checkout',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Loading skeleton ───────────────────────────────────────────
  Widget _buildLoadingSkeleton({bool canPop = false}) {
    return Skeleton(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        children: [
          SkeletonBox(width: 140, height: 12, radius: 6),
          const SizedBox(height: 12),
          SkeletonBox(width: 200, height: 26, radius: 8),
          const SizedBox(height: 24),
          for (int i = 0; i < 3; i++) ...[
            Container(
              height: 112,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  SkeletonBox(width: 80, height: 80, radius: 12),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: double.infinity, height: 16),
                        const SizedBox(height: 10),
                        SkeletonBox(width: 100, height: 12),
                        const Spacer(),
                        SkeletonBox(width: 60, height: 14),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  // ── Empty State ─────────────────────────────────────────────────
  Widget _buildEmptyState(BuildContext context, {bool canPop = false}) {
    return SafeArea(
      child: Column(
        children: [
          if (canPop)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _BackButton(onTap: () => context.pop()),
              ),
            ),
          Expanded(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.12),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.bone.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.shopping_bag_outlined,
                          size: 32,
                          color: AppTheme.textHint,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Your Basket is Empty',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Add handcrafted items to get started',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    OutlinedButton(
                      onPressed: () => context.go('/home'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.terracotta,
                        side: const BorderSide(color: AppTheme.terracotta),
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                      child: Text(
                        'Start Shopping',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Cart Content ────────────────────────────────────────────────
  Widget _buildCartContent(
    BuildContext context,
    List<CartItem> items, {
    bool canPop = false,
  }) {
    final subtotal = items.fold<double>(0, (sum, item) => sum + item.lineTotal);
    final groups = groupCartItemsByShop(items);
    // Gift wrap is charged per shop: each shop wraps its own parcel.
    final giftFee = giftFeeForSelection(isGift: _isGift) * groups.length;
    final expiringSoonCount = items.where((i) => i.isExpiringSoon).length;
    final rows = <Widget Function()>[
      () => _buildHeader(canPop: canPop),
      for (final group in groups) ...[
        () => _buildShopHeader(group, shopCount: groups.length),
        for (final item in group.items) () => _buildCartItem(item),
      ],
      _buildGiftCard,
    ];

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          if (expiringSoonCount > 0)
            _buildExpiryWarningBanner(expiringSoonCount),
          Expanded(
            child: RefreshIndicator(
              color: AppTheme.terracotta,
              onRefresh: () => ref.refresh(cartItemsProvider.future),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) => rows[index](),
              ),
            ),
          ),
          _buildSummaryBar(
            context,
            subtotal,
            giftFee,
            shopCount: groups.length,
          ),
        ],
      ),
    );
  }

  // ── Shop Header ─────────────────────────────────────────────────
  Widget _buildShopHeader(CartShopGroup group, {required int shopCount}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Row(
        children: [
          const Icon(
            Icons.storefront_outlined,
            size: 18,
            color: AppTheme.terracotta,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              group.shopName,
              style: GoogleFonts.playfairDisplay(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            shopCount > 1
                ? 'Subtotal R${group.subtotal.toStringAsFixed(0)}'
                : '${group.itemCount} item${group.itemCount == 1 ? '' : 's'}',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiryWarningBanner(int count) {
    return Container(
      width: double.infinity,
      color: AppTheme.ochre.withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, size: 16, color: AppTheme.ochre),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              count == 1
                  ? '1 item in your basket is expiring soon — checkout before it\'s released'
                  : '$count items in your basket are expiring soon — checkout before they\'re released',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.ochre,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Cart Item Card ──────────────────────────────────────────────
  Widget _buildCartItem(CartItem item) {
    final product = item.product;
    final availableStock = availableStockForCartItem(item);
    final hasReachedStockLimit = item.quantity >= availableStock;
    final expiringSoon = item.isExpiringSoon;
    final borderColor = expiringSoon
        ? AppTheme.ochre.withValues(alpha: 0.6)
        : AppTheme.sand.withValues(alpha: 0.3);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Dismissible(
        key: ValueKey('cart-item-${item.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          margin: const EdgeInsets.only(bottom: 0),
          decoration: BoxDecoration(
            color: AppTheme.error,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
        ),
        onDismissed: (_) => _removeItemWithUndo(item),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
            border: Border.all(color: borderColor),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: CachedNetworkImage(
                    imageUrl: item.displayImage,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: AppTheme.bone),
                    errorWidget: (_, __, ___) =>
                        Container(color: AppTheme.bone),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            product?.title ?? 'Product',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Semantics(
                          button: true,
                          label:
                              'Remove ${product?.title ?? 'item'} from basket',
                          child: InkResponse(
                            onTap: () => _removeItemWithUndo(item),
                            radius: 22,
                            child: const SizedBox(
                              width: 44,
                              height: 44,
                              child: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: AppTheme.textHint,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (item.variantName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Option: ${item.variantName}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    _ExpiryChip(item: item),
                    const SizedBox(height: 8),
                    if (hasReachedStockLimit) ...[
                      Text(
                        stockLimitMessage(availableStock),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppTheme.ochre,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'R${((item.variant?.price ?? product?.price) ?? 0).toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.scaffoldBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.sand.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _StepperButton(
                                icon: Icons.remove_rounded,
                                onTap: item.quantity > 1
                                    ? () => _updateQuantity(
                                        item.id,
                                        item.quantity - 1,
                                      )
                                    : null,
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: Text(
                                  '${item.quantity}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              _StepperButton(
                                icon: Icons.add_rounded,
                                onTap: canIncreaseCartItemQuantity(item)
                                    ? () => _updateQuantity(
                                        item.id,
                                        item.quantity + 1,
                                      )
                                    : null,
                              ),
                            ],
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

  // ── Gift Options Card ───────────────────────────────────────────
  Widget _buildGiftCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isGift
                ? AppTheme.terracotta.withValues(alpha: 0.4)
                : AppTheme.sand.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Toggle row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: _isGift
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [AppTheme.terracotta, AppTheme.baobab],
                            )
                          : null,
                      color: _isGift ? null : AppTheme.bone,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.card_giftcard_rounded,
                      size: 20,
                      color: _isGift ? Colors.white : AppTheme.textHint,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Send as a Gift',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Add a personal message for the recipient',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppTheme.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isGift,
                    onChanged: (val) {
                      setState(() => _isGift = val);
                      ref
                          .read(giftOptionsProvider.notifier)
                          .update(
                            ref.read(giftOptionsProvider).copyWith(isGift: val),
                          );
                    },
                    activeThumbColor: AppTheme.terracotta,
                    activeTrackColor: AppTheme.terracotta.withValues(
                      alpha: 0.2,
                    ),
                    inactiveThumbColor: AppTheme.textHint,
                    inactiveTrackColor: AppTheme.bone,
                  ),
                ],
              ),
            ),

            // Expandable fields
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 280),
              crossFadeState: _isGift
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Column(
                children: [
                  Divider(
                    height: 1,
                    color: AppTheme.sand.withValues(alpha: 0.5),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: TextField(
                      controller: _recipientController,
                      onChanged: (v) => ref
                          .read(giftOptionsProvider.notifier)
                          .update(
                            ref
                                .read(giftOptionsProvider)
                                .copyWith(recipient: v),
                          ),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                      ),
                      decoration: InputDecoration(
                        labelText: "Recipient's name",
                        labelStyle: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppTheme.textHint,
                        ),
                        prefixIcon: const Icon(
                          Icons.person_outline_rounded,
                          size: 20,
                          color: AppTheme.textHint,
                        ),
                        filled: true,
                        fillColor: AppTheme.scaffoldBg,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppTheme.terracotta.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: TextField(
                      controller: _messageController,
                      onChanged: (v) => ref
                          .read(giftOptionsProvider.notifier)
                          .update(
                            ref.read(giftOptionsProvider).copyWith(message: v),
                          ),
                      maxLines: 4,
                      maxLength: 200,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Gift message',
                        alignLabelWithHint: true,
                        labelStyle: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppTheme.textHint,
                        ),
                        hintText:
                            'Write something meaningful for the recipient…',
                        hintStyle: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppTheme.textHint,
                        ),
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(bottom: 60),
                          child: Icon(
                            Icons.edit_note_rounded,
                            size: 20,
                            color: AppTheme.textHint,
                          ),
                        ),
                        filled: true,
                        fillColor: AppTheme.scaffoldBg,
                        contentPadding: const EdgeInsets.fromLTRB(
                          16,
                          14,
                          16,
                          14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppTheme.terracotta.withValues(alpha: 0.5),
                          ),
                        ),
                        counterStyle: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppTheme.textHint,
                        ),
                      ),
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

  // ── Bottom Summary Bar ──────────────────────────────────────────
  Widget _buildSummaryBar(
    BuildContext context,
    double subtotal,
    double giftFee, {
    int shopCount = 1,
  }) {
    final total = subtotal + giftFee;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        border: Border(
          top: BorderSide(color: AppTheme.sand.withValues(alpha: 0.35)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Subtotal',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text(
                  'R${subtotal.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            if (giftFee > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    shopCount > 1
                        ? '$giftServiceLabel ($shopCount shops)'
                        : giftServiceLabel,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  Text(
                    'R${giftFee.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Shipping',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text(
                  'Calculated at checkout',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.textHint,
                  ),
                ),
              ],
            ),
            if (giftFee > 0) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total before shipping',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    'R${total.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
            if (shopCount > 1) ...[
              const SizedBox(height: 12),
              Text(
                'Items from $shopCount shops. Each shop sends its own parcel, '
                'and you pay once for everything.',
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  color: AppTheme.textHint,
                  height: 1.45,
                ),
              ),
            ],
            const SizedBox(height: 20),
            // Primary pill checkout button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => context.push('/cart/checkout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.terracotta,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                // One line, shrunk to fit: wrapping hid the price below the
                // pill's fixed height.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Proceed to Checkout · R${total.toStringAsFixed(0)}',
                    maxLines: 1,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.3,
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

// ── Expiry Chip ───────────────────────────────────────────────────
class _ExpiryChip extends StatelessWidget {
  final CartItem item;
  const _ExpiryChip({required this.item});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final IconData icon;

    if (item.isExpiringSoon) {
      bg = AppTheme.ochre.withValues(alpha: 0.12);
      fg = AppTheme.ochre;
      icon = Icons.timer_outlined;
    } else {
      bg = AppTheme.baobab.withValues(alpha: 0.08);
      fg = AppTheme.baobab;
      icon = Icons.schedule_outlined;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 11, color: fg),
              const SizedBox(width: 4),
              Text(
                'Reserved ${item.expiryLabel}',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Back Button ──────────────────────────────────────────────────
class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.arrow_back_rounded,
            size: 20,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}

// ── Stepper Button ────────────────────────────────────────────────
class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _StepperButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        child: Icon(
          icon,
          size: 14,
          color: isEnabled ? AppTheme.textPrimary : AppTheme.textHint,
        ),
      ),
    );
  }
}
