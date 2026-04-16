import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme.dart';
import '../../../widgets/gradient_button.dart';
import '../providers/buyer_providers.dart';
import 'tradesafe_checkout_screen.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? checkoutData;

  const PaymentScreen({super.key, this.checkoutData});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  bool _processing = false;

  double get _total => (widget.checkoutData?['total'] as num?)?.toDouble() ?? 0;

  Future<void> _processPayment() async {
    setState(() => _processing = true);

    try {
      final service = ref.read(supabaseServiceProvider);
      final data = widget.checkoutData!;
      final gift = ref.read(giftOptionsProvider);
      debugPrint(
        '[checkout-debug] PaymentScreen._processPayment total=$_total shippingMethod=${data['shippingMethod']} shippingCost=${data['shippingCost']} addressKeys=${(data['address'] as Map<String, dynamic>).keys.toList()} isGift=${gift.isGift}',
      );

      final checkoutSession = await service.createCheckout(
        shippingAddress: data['address'] as Map<String, dynamic>,
        shippingMethod: data['shippingMethod'] as String,
        shippingCost: (data['shippingCost'] as num).toDouble(),
        isGift: gift.isGift,
        giftRecipient: gift.recipient,
        giftMessage: gift.message,
      );

      // Reset gift state after order is placed
      ref.read(giftOptionsProvider.notifier).reset();

      ref.invalidate(ordersProvider);

      final checkoutUri = Uri.tryParse(checkoutSession.checkoutUrl);
      if (checkoutUri == null) {
        throw Exception('TradeSafe returned an invalid checkout URL.');
      }
      debugPrint(
        '[checkout-debug] checkout created orderId=${checkoutSession.orderId} checkoutUrl=${checkoutSession.checkoutUrl}',
      );

      if (mounted) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => TradeSafeCheckoutScreen(
              checkoutUri: checkoutUri,
              orderId: checkoutSession.orderId,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('[checkout-debug] PaymentScreen._processPayment error=$e');
      if (mounted) {
        setState(() => _processing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payment failed: $e',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: _processing
          ? null
          : AppBar(
              backgroundColor: AppTheme.scaffoldBg,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppTheme.textPrimary,
                ),
                onPressed: () => context.pop(),
              ),
              title: Text(
                'Payment',
                style: GoogleFonts.playfairDisplay(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 24,
                ),
              ),
              centerTitle: true,
            ),
      body: SafeArea(
        child: _processing ? _buildProcessingState() : _buildPaymentForm(),
      ),
    );
  }

  Widget _buildProcessingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(
              color: AppTheme.terracotta,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Processing Payment',
            style: GoogleFonts.playfairDisplay(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Please do not close this page',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentForm() {
    final totalStr = 'R${_total.toStringAsFixed(2)}';

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTradeSafeCard(),
                const SizedBox(height: 24),
                _buildAmountCard(totalStr),
                const SizedBox(height: 32),
                Center(child: _buildSecurityNote()),
              ],
            ),
          ),
        ),
        Container(
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
              children: [
                GradientButton(
                  label: 'Pay $totalStr',
                  onPressed: _processPayment,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => context.pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      'Cancel Payment',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTradeSafeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF2D5B2F),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'TradeSafe',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Secure Payment Gateway',
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'TradeSafe checkout will open securely inside Artisan Lane so you can complete your escrow payment without leaving the app. TradeSafe may add its own escrow processing fee at checkout depending on the payment method used.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _paymentIcon(Icons.credit_card, 'Visa'),
              const SizedBox(width: 24),
              _paymentIcon(Icons.credit_card, 'Mastercard'),
              const SizedBox(width: 24),
              _paymentIcon(Icons.shield_outlined, 'Escrow'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmountCard(String totalStr) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      decoration: BoxDecoration(
        color: AppTheme.scaffoldBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.sand.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total Amount',
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            totalStr,
            style: GoogleFonts.playfairDisplay(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppTheme.sienna,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityNote() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.lock_outline_rounded,
          size: 16,
          color: AppTheme.baobab,
        ),
        const SizedBox(width: 8),
        Text(
          'Secured with 256-bit encryption',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: AppTheme.baobab,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _paymentIcon(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.scaffoldBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.sand.withValues(alpha: 0.5)),
          ),
          child: Icon(icon, size: 24, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: AppTheme.textHint,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
