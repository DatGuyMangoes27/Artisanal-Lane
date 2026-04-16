import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme.dart';
import '../../../widgets/gradient_button.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/vendor_providers.dart';

class VendorOrderDetailScreen extends ConsumerStatefulWidget {
  final String orderId;

  const VendorOrderDetailScreen({super.key, required this.orderId});

  @override
  ConsumerState<VendorOrderDetailScreen> createState() =>
      _VendorOrderDetailScreenState();
}

class _VendorOrderDetailScreenState
    extends ConsumerState<VendorOrderDetailScreen> {
  final _trackingController = TextEditingController();
  final _trackingUrlController = TextEditingController();
  bool _isShipping = false;

  @override
  void dispose() {
    _trackingController.dispose();
    _trackingUrlController.dispose();
    super.dispose();
  }

  Future<void> _markShipped() async {
    setState(() => _isShipping = true);
    try {
      final service = ref.read(supabaseServiceProvider);
      await service.updateOrderStatus(
        widget.orderId,
        'shipped',
        trackingNumber: _trackingController.text.trim().isNotEmpty
            ? _trackingController.text.trim()
            : null,
        trackingUrl: _trackingUrlController.text.trim().isNotEmpty
            ? _trackingUrlController.text.trim()
            : null,
      );
      ref.invalidate(vendorOrdersProvider);
      ref.invalidate(vendorOrdersStreamProvider);
      ref.invalidate(vendorOrderDetailProvider(widget.orderId));
      ref.invalidate(vendorOrderDetailStreamProvider(widget.orderId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Order marked as shipped',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: AppTheme.baobab,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isShipping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(
      vendorOrderDetailStreamProvider(widget.orderId),
    );

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Order Details',
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w600),
        ),
      ),
      body: orderAsync.when(
        data: (order) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Order header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Order #${order.shortId}',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      _StatusBadge(status: order.status),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _infoRow('Total', 'R${order.grandTotal.toStringAsFixed(2)}'),
                  _infoRow('Shipping', order.shippingMethodDisplay),
                  if (order.trackingNumber != null)
                    _infoRow('Tracking', order.trackingNumber!),
                  if (order.trackingUrl != null &&
                      order.trackingUrl!.isNotEmpty)
                    _infoRow('Tracking URL', order.trackingUrl!),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Items
            Text(
              'Items',
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ...?order.items?.map(
              (item) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.sand.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productTitle ?? 'Product',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (item.variantName != null)
                            Text(
                              'Option: ${item.variantName}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          Text(
                            'Qty: ${item.quantity} × R${item.unitPrice.toStringAsFixed(0)}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'R${item.lineTotal.toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Gift details
            if (order.isGift) ...[
              Text(
                'Gift Details',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.terracotta.withValues(alpha: 0.08),
                      AppTheme.baobab.withValues(alpha: 0.06),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.terracotta.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.terracotta.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.card_giftcard_outlined,
                            size: 16,
                            color: AppTheme.terracotta,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'This is a gift order',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.terracotta,
                          ),
                        ),
                      ],
                    ),
                    if (order.giftRecipient != null &&
                        order.giftRecipient!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'RECIPIENT',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textHint,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        order.giftRecipient!,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                    if (order.giftMessage != null &&
                        order.giftMessage!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'GIFT MESSAGE',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textHint,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '"${order.giftMessage!}"',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                            fontStyle: FontStyle.italic,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Shipping address
            if (order.shippingAddress != null) ...[
              Text(
                'Shipping Address',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.sand.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  [
                        order.shippingAddress!['name'],
                        order.shippingAddress!['street'],
                        order.shippingAddress!['city'],
                        order.shippingAddress!['province'],
                        order.shippingAddress!['postal_code'],
                      ]
                      .where((s) => s != null && s.toString().isNotEmpty)
                      .join('\n'),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Mark as shipped action
            if (order.status == 'paid') ...[
              Text(
                'Fulfillment',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.sand.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tracking Number (optional)',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _trackingController,
                      decoration: const InputDecoration(
                        hintText: 'Enter tracking number',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tracking URL (optional)',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _trackingUrlController,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        hintText: 'Paste tracking link',
                      ),
                    ),
                    const SizedBox(height: 16),
                    GradientButton(
                      label: 'Mark as Shipped',
                      icon: Icons.local_shipping_outlined,
                      isLoading: _isShipping,
                      onPressed: _isShipping ? null : _markShipped,
                      verticalPadding: 16,
                      borderRadius: 14,
                    ),
                  ],
                ),
              ),
            ],
            if (order.status == 'disputed') ...[
              GradientButton(
                label: 'Open Dispute Conversation',
                icon: Icons.forum_outlined,
                onPressed: () =>
                    context.push('/vendor/orders/${order.id}/dispute'),
                verticalPadding: 16,
                borderRadius: 14,
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: AppTheme.terracotta,
            strokeWidth: 2,
          ),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textHint),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  static const _gradientStatuses = {'shipped', 'delivered'};

  @override
  Widget build(BuildContext context) {
    final useGradient = _gradientStatuses.contains(status);
    if (useGradient) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.terracotta, AppTheme.baobab],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          status.toUpperCase(),
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.getStatusColor(status).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.getStatusColor(status),
        ),
      ),
    );
  }
}
