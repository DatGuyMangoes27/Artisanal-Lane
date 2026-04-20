import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/theme.dart';
import '../../../core/pricing/pricing.dart';
import '../../../models/order.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/african_patterns.dart';
import '../../../widgets/sign_in_prompt_sheet.dart';
import '../../../widgets/status_badge.dart';
import '../providers/buyer_providers.dart';
import '../widgets/review_widgets.dart';

class OrderDetailScreen extends ConsumerWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  static Uri? _trackingUri(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final normalized = trimmed.contains('://') ? trimmed : 'https://$trimmed';
    return Uri.tryParse(normalized);
  }

  Future<void> _copyTrackingNumber(
    BuildContext context,
    String trackingNumber,
  ) async {
    await Clipboard.setData(ClipboardData(text: trackingNumber));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tracking number copied', style: GoogleFonts.poppins()),
      ),
    );
  }

  Future<void> _openTrackingUrl(
    BuildContext context,
    String trackingUrl,
  ) async {
    final uri = _trackingUri(trackingUrl);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Tracking link is invalid',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    final launched = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    if (launched || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Could not open tracking link',
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: AppTheme.error,
      ),
    );
  }

  Future<void> _openOrderItemReviewSheet(
    BuildContext context,
    WidgetRef ref,
    OrderItem item,
  ) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      await showSignInPromptSheet(
        context,
        title: 'Sign in to leave a review',
        message:
            'Create an account or sign in to review ${item.productTitle ?? 'this item'} after your order is completed.',
      );
      return;
    }

    final isEligible = await ref.read(canReviewProductProvider(item.productId).future);
    if (!isEligible) {
      if (!context.mounted) return;
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

    if (!context.mounted) return;
    final draft = await showReviewComposerSheet(
      context,
      title: 'Review this item',
      subtitle: item.productTitle ?? 'Product',
    );
    if (draft == null) {
      return;
    }

    try {
      await ref
          .read(supabaseServiceProvider)
          .submitProductReview(
            productId: item.productId,
            buyerId: userId,
            rating: draft.rating,
            reviewText: draft.reviewText,
          );

      ref.invalidate(productReviewsProvider(item.productId));
      ref.invalidate(productReviewSummaryProvider(item.productId));
      ref.invalidate(canReviewProductProvider(item.productId));

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Thanks for reviewing this product.',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: AppTheme.baobab,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
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
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailStreamProvider(orderId));

    return orderAsync.when(
      data: (order) {
        final dateStr = DateFormat(
          'dd MMM yyyy, HH:mm',
        ).format(order.createdAt);

        return Scaffold(
          backgroundColor: AppTheme.scaffoldBg,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Custom Header ──────────────────────────────
                  Row(
                    children: [
                      _BackButton(onTap: () => context.pop()),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order #${order.shortId}',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dateStr,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: AppTheme.textHint,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // ── Status Section ─────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.sand.withValues(alpha: 0.3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Status',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            StatusBadge(status: order.status, fontSize: 13),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _StatusTimeline(currentStatus: order.status),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Items Section ──────────────────────────
                  _SectionTitle(title: 'Items'),
                  const SizedBox(height: 16),
                  if (order.items != null)
                    ...order.items!.map((item) => _ItemCard(item: item)),

                  const SizedBox(height: 32),

                  // ── Shipping Section ───────────────────────
                  _SectionTitle(title: 'Shipping'),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.sand.withValues(alpha: 0.3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _ShippingInfoRow(
                          icon: Icons.local_shipping_outlined,
                          text: order.shippingMethodDisplay,
                        ),
                        if (order.trackingNumber != null) ...[
                          const SizedBox(height: 16),
                          _Divider(),
                          const SizedBox(height: 16),
                          _ShippingInfoRow(
                            icon: Icons.qr_code,
                            text: 'Tracking: ${order.trackingNumber}',
                            actionLabel: 'Copy',
                            onAction: () => _copyTrackingNumber(
                              context,
                              order.trackingNumber!,
                            ),
                          ),
                        ],
                        if (order.trackingUrl != null &&
                            order.trackingUrl!.trim().isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _Divider(),
                          const SizedBox(height: 16),
                          _ShippingInfoRow(
                            icon: Icons.link_outlined,
                            text: order.trackingUrl!,
                            actionLabel: 'Open Link',
                            onAction: () =>
                                _openTrackingUrl(context, order.trackingUrl!),
                          ),
                        ],
                        if (order.shippingAddress != null) ...[
                          const SizedBox(height: 16),
                          _Divider(),
                          const SizedBox(height: 16),
                          _ShippingInfoRow(
                            icon: Icons.location_on_outlined,
                            text:
                                '${order.shippingAddress!['street']}, ${order.shippingAddress!['city']} ${order.shippingAddress!['postal_code']}',
                          ),
                          if ((order.shippingAddress!['pickup_point'] ?? '')
                              .toString()
                              .trim()
                              .isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _Divider(),
                            const SizedBox(height: 16),
                            _ShippingInfoRow(
                              icon: Icons.pin_drop_outlined,
                              text:
                                  'Pickup point: ${order.shippingAddress!['pickup_point']}',
                            ),
                          ],
                        ],
                        if (order.shippingMethod == 'market_pickup') ...[
                          const SizedBox(height: 16),
                          _Divider(),
                          const SizedBox(height: 16),
                          const _ShippingInfoRow(
                            icon: Icons.chat_bubble_outline_rounded,
                            text:
                                'Message the seller to confirm which market, date, and collection time applies to this order.',
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Payment Section ────────────────────────
                  _SectionTitle(title: 'Payment'),
                  const SizedBox(height: 16),
                  _PaymentCard(
                    subtotal: order.total,
                    giftFee: order.giftFee,
                    shippingCost: order.shippingCost,
                    grandTotal: order.grandTotal,
                  ),

                  if (order.status == 'completed' &&
                      order.items != null &&
                      order.items!.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    _SectionTitle(title: 'Reviews'),
                    const SizedBox(height: 16),
                    _CompletedOrderReviewSection(
                      items: order.items!,
                      onReviewTap: (item) =>
                          _openOrderItemReviewSheet(context, ref, item),
                    ),
                  ],

                  const SizedBox(height: 40),

                  // ── Action Buttons ─────────────────────────
                  if (order.status == 'shipped' ||
                      order.status == 'delivered') ...[
                    GradientButton(
                      label: 'Confirm Receipt',
                      onPressed: () =>
                          context.push('/profile/orders/${order.id}/confirm'),
                      verticalPadding: 16,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (order.status == 'delivered' ||
                      order.status == 'shipped') ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () =>
                            context.push('/profile/orders/${order.id}/dispute'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.error,
                          side: BorderSide(
                            color: AppTheme.error.withValues(alpha: 0.5),
                            width: 1,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: const Text('Raise Dispute'),
                      ),
                    ),
                  ] else if (order.status == 'disputed') ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () =>
                            context.push('/profile/orders/${order.id}/dispute'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.error,
                          side: BorderSide(
                            color: AppTheme.error.withValues(alpha: 0.5),
                            width: 1,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: const Text('Open Dispute'),
                      ),
                    ),
                  ],

                  const SizedBox(height: 40),

                  // ── TripleDot footer accent ────────────────
                  const Center(child: TripleDot()),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.terracotta),
        ),
      ),
      error: (error, _) => Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BackButton(onTap: () => context.pop()),
                const Spacer(),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 48,
                        color: AppTheme.error.withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading order',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$error',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: AppTheme.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Private Widgets
// ═══════════════════════════════════════════════════════════════════

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.playfairDisplay(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: AppTheme.textPrimary,
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final dynamic item;

  const _ItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Product image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 70,
              height: 70,
              child: item.productImage != null
                  ? CachedNetworkImage(
                      imageUrl: item.productImage!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: const Color(0xFFFAFAFA),
                        child: Icon(
                          Icons.image_outlined,
                          size: 24,
                          color: AppTheme.textPrimary.withValues(alpha: 0.2),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: const Color(0xFFFAFAFA),
                        child: Icon(
                          Icons.broken_image_outlined,
                          size: 24,
                          color: AppTheme.textPrimary.withValues(alpha: 0.2),
                        ),
                      ),
                    )
                  : Container(
                      color: const Color(0xFFFAFAFA),
                      child: Icon(
                        Icons.image_outlined,
                        size: 24,
                        color: AppTheme.textPrimary.withValues(alpha: 0.2),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 16),

          // Title + qty
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productTitle ?? 'Product',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
                const SizedBox(height: 4),
                Text(
                  'Qty: ${item.quantity} × R${item.unitPrice.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppTheme.textHint,
                  ),
                ),
              ],
            ),
          ),

          // Line total
          Text(
            'R${item.lineTotal.toStringAsFixed(0)}',
            style: GoogleFonts.playfairDisplay(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletedOrderReviewSection extends ConsumerWidget {
  final List<OrderItem> items;
  final Future<void> Function(OrderItem item) onReviewTap;

  const _CompletedOrderReviewSection({
    required this.items,
    required this.onReviewTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(currentUserIdProvider);
    if (currentUserId == null) {
      return _ReviewActionCard(
        title: 'Sign in to leave a review',
        subtitle:
            'Completed orders let you share feedback for the items you received.',
        buttonLabel: 'Sign In To Review',
        onTap: () => onReviewTap(items.first),
      );
    }

    var isLoading = false;
    final reviewableItems = <OrderItem>[];
    for (final item in items) {
      final canReviewAsync = ref.watch(canReviewProductProvider(item.productId));
      if (canReviewAsync.isLoading) {
        isLoading = true;
      }
      if (canReviewAsync.value ?? false) {
        reviewableItems.add(item);
      }
    }

    if (reviewableItems.isEmpty) {
      if (isLoading) {
        return const SizedBox.shrink();
      }
      return const _ReviewStatusNote(
        message: 'Reviews appear here once each completed item is ready.',
      );
    }

    return Column(
      children: [
        const _ReviewStatusNote(
          message:
              'Your order is complete. Leave a review for the items you received.',
        ),
        const SizedBox(height: 12),
        ...reviewableItems.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ReviewActionCard(
              title: item.productTitle ?? 'Product',
              subtitle: item.variantName != null
                  ? 'Option: ${item.variantName}'
                  : 'Share what you loved about this item.',
              buttonLabel: 'Leave a Review',
              onTap: () => onReviewTap(item),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReviewActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onTap;

  const _ReviewActionCard({
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
}

class _ReviewStatusNote extends StatelessWidget {
  final String message;

  const _ReviewStatusNote({required this.message});

  @override
  Widget build(BuildContext context) {
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
}

class _ShippingInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _ShippingInfoRow({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.textPrimary),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(width: 12),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.terracotta,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              textStyle: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Text(actionLabel!),
          ),
        ],
      ],
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final double subtotal;
  final double giftFee;
  final double shippingCost;
  final double grandTotal;

  const _PaymentCard({
    required this.subtotal,
    required this.giftFee,
    required this.shippingCost,
    required this.grandTotal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          _row('Subtotal', 'R${subtotal.toStringAsFixed(0)}'),
          if (giftFee > 0) ...[
            const SizedBox(height: 12),
            _row(giftServiceLabel, 'R${giftFee.toStringAsFixed(0)}'),
          ],
          const SizedBox(height: 12),
          _row('Shipping', 'R${shippingCost.toStringAsFixed(0)}'),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Divider(
              color: AppTheme.sand.withValues(alpha: 0.2),
              thickness: 1,
              height: 1,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                'R${grandTotal.toStringAsFixed(0)}',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: AppTheme.textSecondary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: AppTheme.sand.withValues(alpha: 0.2),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Status Timeline
// ═══════════════════════════════════════════════════════════════════

class _StatusTimeline extends StatelessWidget {
  final String currentStatus;

  const _StatusTimeline({required this.currentStatus});

  static const _steps = [
    'pending',
    'paid',
    'shipped',
    'delivered',
    'completed',
  ];
  static const _labels = [
    'Pending',
    'Paid',
    'Shipped',
    'Delivered',
    'Completed',
  ];

  @override
  Widget build(BuildContext context) {
    int currentIdx = _steps.indexOf(currentStatus);
    if (currentStatus == 'disputed') currentIdx = 3;
    if (currentStatus == 'cancelled') currentIdx = -1;

    return Row(
      children: List.generate(_steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          // ── Connector line ──
          final stepIdx = i ~/ 2;
          final isActive = stepIdx < currentIdx;
          return Expanded(
            child: Container(
              height: 2,
              color: isActive
                  ? AppTheme.terracotta
                  : AppTheme.sand.withValues(alpha: 0.3),
            ),
          );
        }

        // ── Step dot ──
        final stepIdx = i ~/ 2;
        final isActive = stepIdx <= currentIdx;
        final isCurrent = stepIdx == currentIdx;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: isActive ? AppTheme.terracotta : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive
                      ? AppTheme.terracotta
                      : AppTheme.sand.withValues(alpha: 0.5),
                  width: 2,
                ),
                boxShadow: isCurrent
                    ? [
                        BoxShadow(
                          color: AppTheme.terracotta.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _labels[stepIdx],
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? AppTheme.textPrimary : AppTheme.textHint,
              ),
            ),
          ],
        );
      }),
    );
  }
}
