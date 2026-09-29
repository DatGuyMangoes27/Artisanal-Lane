import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../app/theme.dart';
import '../../../core/ui/friendly_error.dart';
import '../../../models/order.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/african_patterns.dart';
import '../../../widgets/skeleton.dart';
import '../../../widgets/status_badge.dart';
import '../providers/buyer_providers.dart';
import '../utils/order_history_filters.dart';
import '../utils/receipt_reminders.dart';

class OrdersHistoryScreen extends ConsumerStatefulWidget {
  const OrdersHistoryScreen({super.key});

  @override
  ConsumerState<OrdersHistoryScreen> createState() =>
      _OrdersHistoryScreenState();
}

class _OrdersHistoryScreenState extends ConsumerState<OrdersHistoryScreen> {
  bool _hideCancelledOrders = true;

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(ordersStreamProvider);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Custom Header ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                children: [
                  _BackButton(onTap: () => context.pop()),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Orders',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your purchase history',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: AppTheme.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ───────────────────────────────────────────────
            Expanded(
              child: orders.when(
                data: (items) {
                  final visibleItems = visibleOrderHistoryItems(
                    items,
                    hideCancelledOrders: _hideCancelledOrders,
                  );

                  if (items.isEmpty) {
                    return _EmptyOrdersState(
                      onStartShopping: () => context.go('/home'),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                    itemCount: visibleItems.length + 2,
                    separatorBuilder: (_, __) => const SizedBox(height: 20),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _OrderFilterChips(
                          hideCancelled: _hideCancelledOrders,
                          onChanged: (value) =>
                              setState(() => _hideCancelledOrders = value),
                        );
                      }

                      if (index == visibleItems.length + 1) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 24, bottom: 8),
                          child: Center(child: TripleDot()),
                        );
                      }

                      final order = visibleItems[index - 1];
                      return _OrderCard(
                        order: order,
                        onTap: () =>
                            context.push('/profile/orders/${order.id}'),
                      );
                    },
                  );
                },
                loading: () => const _OrdersSkeleton(),
                error: (error, _) => ErrorRetryView(
                  error: error,
                  title: "Couldn't load your orders",
                  onRetry: () => ref.invalidate(ordersStreamProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Back Button
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

class _OrderFilterChips extends StatelessWidget {
  final bool hideCancelled;
  final ValueChanged<bool> onChanged;

  const _OrderFilterChips({
    required this.hideCancelled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          _FilterChip(
            label: 'All orders',
            selected: !hideCancelled,
            onTap: () => onChanged(false),
          ),
          const SizedBox(width: 10),
          _FilterChip(
            label: 'Hide cancelled',
            selected: hideCancelled,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.terracotta : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? AppTheme.terracotta
                  : AppTheme.sand.withValues(alpha: 0.5),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppTheme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _OrdersSkeleton extends StatelessWidget {
  const _OrdersSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 20),
      itemBuilder: (context, __) => Skeleton(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const SkeletonBox(width: 56, height: 56, radius: 14),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SkeletonBox(width: 140, height: 14),
                    const SizedBox(height: 10),
                    const SkeletonBox(width: 90, height: 12),
                    const SizedBox(height: 14),
                    SkeletonBox(width: double.infinity, height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Empty State
// ═══════════════════════════════════════════════════════════════════

class _EmptyOrdersState extends StatelessWidget {
  final VoidCallback onStartShopping;

  const _EmptyOrdersState({required this.onStartShopping});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon circle
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
              ),
              child: Center(
                child: Icon(
                  Icons.receipt_long_outlined,
                  size: 48,
                  color: AppTheme.textHint.withValues(alpha: 0.5),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'No Orders Yet',
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your order history will appear here once you make your first purchase.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: AppTheme.textHint,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            GradientButton(label: 'Start Shopping', onPressed: onStartShopping),
            const SizedBox(height: 32),
            const TripleDot(),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Order Card
// ═══════════════════════════════════════════════════════════════════

class _OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback onTap;

  const _OrderCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd MMM yyyy').format(order.createdAt);
    final items = order.items ?? const [];
    final thumbUrl = items.isNotEmpty ? items.first.productImage : null;
    final itemLabel = items.isEmpty
        ? 'Order'
        : items.length == 1
        ? (items.first.productTitle ?? 'Order')
        : '${items.first.productTitle ?? 'Item'} +${items.length - 1} more';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: thumbUrl != null
                        ? CachedNetworkImage(
                            imageUrl: thumbUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                Container(color: const Color(0xFFFAFAFA)),
                            errorWidget: (_, __, ___) => Container(
                              color: const Color(0xFFFAFAFA),
                              child: Icon(
                                Icons.image_outlined,
                                size: 20,
                                color: AppTheme.textHint.withValues(alpha: 0.6),
                              ),
                            ),
                          )
                        : Container(
                            color: const Color(0xFFFAFAFA),
                            child: Icon(
                              Icons.storefront_outlined,
                              size: 20,
                              color: AppTheme.textHint.withValues(alpha: 0.6),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              order.shopName ?? 'Shop',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusBadge(status: order.status),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        itemLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Order #${order.shortId} · $dateStr',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppTheme.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(height: 1, color: AppTheme.sand.withValues(alpha: 0.2)),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '${items.length} item${items.length == 1 ? '' : 's'}',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  'R${order.grandTotal.toStringAsFixed(2)}',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            if (shouldPromptReceiptReminder(order)) ...[
              const SizedBox(height: 14),
              const _ReceiptReminderPill(),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReceiptReminderPill extends StatelessWidget {
  const _ReceiptReminderPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.ochre.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.ochre.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            size: 18,
            color: AppTheme.ochre,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Reminder: mark as received once it arrives',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.ochre,
              ),
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: AppTheme.ochre,
          ),
        ],
      ),
    );
  }
}
