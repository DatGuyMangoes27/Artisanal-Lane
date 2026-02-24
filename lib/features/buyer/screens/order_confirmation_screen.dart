import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme.dart';
import '../providers/buyer_providers.dart';

class OrderConfirmationScreen extends ConsumerWidget {
  final String? orderId;

  const OrderConfirmationScreen({super.key, this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (orderId == null) return _buildFallback(context);

    final orderAsync = ref.watch(orderDetailProvider(orderId!));

    return orderAsync.when(
      data: (order) => _buildContent(context, order),
      loading: () => const Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
        body: Center(child: CircularProgressIndicator(color: AppTheme.terracotta, strokeWidth: 2)),
      ),
      error: (_, __) => _buildFallback(context),
    );
  }

  Widget _buildFallback(BuildContext context) {
    return _buildContent(context, null);
  }

  Widget _buildContent(BuildContext context, dynamic order) {
    final orderNumber = order != null ? '#${order.shortId}' : '#---';
    final itemCount = order?.items != null ? '${order.items.length} items' : '--';
    final totalPaid = order != null ? 'R${order.grandTotal.toStringAsFixed(2)}' : '--';
    final shippingDisplay = order?.shippingMethodDisplay ?? '--';
    final deliveryEstimate = _estimateDelivery(order?.shippingMethod);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppTheme.baobab.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: const BoxDecoration(color: AppTheme.baobab, shape: BoxShape.circle),
                      child: const Icon(Icons.check_rounded, size: 32, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Order Confirmed',
                  style: GoogleFonts.playfairDisplay(fontSize: 32, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 16),
                Text(
                  'Thank you for supporting local artisans.\nYour order has been placed successfully.',
                  style: GoogleFonts.poppins(fontSize: 15, color: AppTheme.textSecondary, height: 1.6),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                    border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      _detailRow('Order Number', orderNumber),
                      const SizedBox(height: 16),
                      _detailRow('Items', itemCount),
                      const SizedBox(height: 16),
                      _detailRow('Total Paid', totalPaid, isBold: true),
                      const SizedBox(height: 16),
                      const Divider(height: 1, color: Color(0xFFEEEEEE)),
                      const SizedBox(height: 16),
                      _detailRow('Shipping', shippingDisplay),
                      const SizedBox(height: 16),
                      _detailRow('Est. Delivery', deliveryEstimate),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.terracotta.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.terracotta.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.shield_outlined, size: 20, color: AppTheme.terracotta),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your payment is held safely in escrow until you confirm receipt of your order.',
                          style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.terracotta, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.go('/profile/orders'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.baobab,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      'View My Orders',
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => context.go('/home'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      'Continue Shopping',
                      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _estimateDelivery(String? method) {
    switch (method) {
      case 'courier_guy':
        return '2-4 business days';
      case 'pargo':
        return '3-5 business days';
      case 'paxi':
        return '4-7 business days';
      case 'market_pickup':
        return 'Collect at next market';
      default:
        return '3-5 business days';
    }
  }

  static Widget _detailRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textSecondary)),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w500,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
