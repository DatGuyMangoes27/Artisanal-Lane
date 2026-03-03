import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme.dart';
import '../../../models/cart_item.dart';
import '../providers/buyer_providers.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  bool _isGift = false;
  final _recipientController = TextEditingController();
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _recipientController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _removeItem(String cartItemId) async {
    final service = ref.read(supabaseServiceProvider);
    await service.removeCartItem(cartItemId);
    ref.invalidate(cartItemsProvider);
  }

  Future<void> _updateQuantity(String cartItemId, int newQty) async {
    final service = ref.read(supabaseServiceProvider);
    await service.updateCartItemQuantity(cartItemId, newQty);
    ref.invalidate(cartItemsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final cartItems = ref.watch(cartItemsProvider);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: cartItems.when(
        data: (items) {
          if (items.isEmpty) return _buildEmptyState(context);
          return _buildCartContent(context, items);
        },
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: AppTheme.terracotta,
            strokeWidth: 2,
          ),
        ),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Basket',
            style: GoogleFonts.playfairDisplay(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
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

  // ── Empty State ─────────────────────────────────────────────────
  Widget _buildEmptyState(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Column(
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
                child: Icon(Icons.shopping_bag_outlined,
                    size: 32, color: AppTheme.textHint),
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
                  fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 32),
            OutlinedButton(
              onPressed: () => context.go('/home'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.terracotta,
                side: const BorderSide(color: AppTheme.terracotta),
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Start Shopping',
                style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Cart Content ────────────────────────────────────────────────
  Widget _buildCartContent(BuildContext context, List<CartItem> items) {
    final subtotal =
        items.fold<double>(0, (sum, item) => sum + item.lineTotal);
    final expiringSoonCount = items.where((i) => i.isExpiringSoon).length;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          if (expiringSoonCount > 0)
            _buildExpiryWarningBanner(expiringSoonCount),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: items.length + 2, // +1 header, +1 gift card
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                if (index == 0) return _buildHeader();
                if (index == items.length + 1) return _buildGiftCard();
                return _buildCartItem(items[index - 1]);
              },
            ),
          ),
          _buildSummaryBar(context, subtotal),
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
    final expiringSoon = item.isExpiringSoon;
    final borderColor = expiringSoon
        ? AppTheme.ochre.withValues(alpha: 0.6)
        : AppTheme.sand.withValues(alpha: 0.3);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
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
                  imageUrl: product?.primaryImage ?? '',
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
                      GestureDetector(
                        onTap: () => _removeItem(item.id),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8, bottom: 8),
                          child: const Icon(Icons.close_rounded,
                              size: 18, color: AppTheme.textHint),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    product?.shopName ?? '',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppTheme.textHint),
                  ),
                  const SizedBox(height: 8),
                  _ExpiryChip(item: item),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'R${(product?.price ?? 0).toStringAsFixed(0)}',
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
                              color: AppTheme.sand.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _StepperButton(
                              icon: Icons.remove_rounded,
                              onTap: item.quantity > 1
                                  ? () => _updateQuantity(
                                      item.id, item.quantity - 1)
                                  : null,
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                '${item.quantity}',
                                style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            _StepperButton(
                              icon: Icons.add_rounded,
                              onTap: () => _updateQuantity(
                                  item.id, item.quantity + 1),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isGift
                ? AppTheme.terracotta.withValues(alpha: 0.4)
                : AppTheme.sand.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
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
                      ref.read(giftOptionsProvider.notifier).update(
                          ref.read(giftOptionsProvider).copyWith(isGift: val));
                    },
                    activeColor: AppTheme.terracotta,
                    activeTrackColor:
                        AppTheme.terracotta.withValues(alpha: 0.2),
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
                      height: 1, color: AppTheme.sand.withValues(alpha: 0.5)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: TextField(
                      controller: _recipientController,
                      onChanged: (v) => ref.read(giftOptionsProvider.notifier).update(
                          ref.read(giftOptionsProvider).copyWith(recipient: v)),
                      style: GoogleFonts.poppins(
                          fontSize: 14, color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        labelText: "Recipient's name",
                        labelStyle: GoogleFonts.poppins(
                            fontSize: 13, color: AppTheme.textHint),
                        prefixIcon: const Icon(Icons.person_outline_rounded,
                            size: 20, color: AppTheme.textHint),
                        filled: true,
                        fillColor: AppTheme.scaffoldBg,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: AppTheme.terracotta.withValues(alpha: 0.5)),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: TextField(
                      controller: _messageController,
                      onChanged: (v) => ref.read(giftOptionsProvider.notifier).update(
                          ref.read(giftOptionsProvider).copyWith(message: v)),
                      maxLines: 4,
                      maxLength: 200,
                      style: GoogleFonts.poppins(
                          fontSize: 14, color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Gift message',
                        alignLabelWithHint: true,
                        labelStyle: GoogleFonts.poppins(
                            fontSize: 13, color: AppTheme.textHint),
                        hintText:
                            'Write something meaningful for the recipient…',
                        hintStyle: GoogleFonts.poppins(
                            fontSize: 13, color: AppTheme.textHint),
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(bottom: 60),
                          child: Icon(Icons.edit_note_rounded,
                              size: 20, color: AppTheme.textHint),
                        ),
                        filled: true,
                        fillColor: AppTheme.scaffoldBg,
                        contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: AppTheme.terracotta.withValues(alpha: 0.5)),
                        ),
                        counterStyle: GoogleFonts.poppins(
                            fontSize: 11, color: AppTheme.textHint),
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
  Widget _buildSummaryBar(BuildContext context, double subtotal) {
    return Container(
      padding: const EdgeInsets.all(24),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Subtotal',
                    style: GoogleFonts.poppins(
                        fontSize: 14, color: AppTheme.textSecondary)),
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
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Shipping',
                    style: GoogleFonts.poppins(
                        fontSize: 14, color: AppTheme.textSecondary)),
                Text('Calculated at checkout',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppTheme.textHint)),
              ],
            ),
            const SizedBox(height: 24),
            // Gradient checkout button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [AppTheme.terracotta, AppTheme.baobab],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.terracotta.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => context.push('/cart/checkout'),
                    borderRadius: BorderRadius.circular(16),
                    child: Center(
                      child: Text(
                        'Proceed to Checkout',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
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
