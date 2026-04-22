import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../models/vendor_subscription.dart';
import '../../../widgets/gradient_button.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/vendor_providers.dart';
import '../utils/vendor_subscription_setup.dart';
import 'payfast_subscription_checkout_screen.dart';

class VendorSubscriptionScreen extends ConsumerStatefulWidget {
  final String? paymentStatus;

  const VendorSubscriptionScreen({super.key, this.paymentStatus});

  @override
  ConsumerState<VendorSubscriptionScreen> createState() =>
      _VendorSubscriptionScreenState();
}

class _VendorSubscriptionScreenState
    extends ConsumerState<VendorSubscriptionScreen> {
  bool _startingCheckout = false;
  bool _cancelling = false;
  Timer? _activationPollTimer;
  DateTime? _activationPollStartedAt;

  @override
  void initState() {
    super.initState();
    if (widget.paymentStatus == 'success') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _beginActivationPolling();
      });
    }
  }

  @override
  void dispose() {
    _activationPollTimer?.cancel();
    super.dispose();
  }

  void _beginActivationPolling() {
    _activationPollTimer?.cancel();
    _activationPollStartedAt = DateTime.now();
    ref.invalidate(vendorSubscriptionProvider);
    ref.invalidate(vendorSubscriptionStreamProvider);

    _activationPollTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final subscription =
          ref.read(vendorSubscriptionStreamProvider).value ??
          ref.read(vendorSubscriptionProvider).value;
      if (isVendorSubscriptionActive(subscription)) {
        timer.cancel();
        return;
      }

      final startedAt = _activationPollStartedAt;
      if (startedAt != null &&
          DateTime.now().difference(startedAt) > const Duration(seconds: 45)) {
        timer.cancel();
        return;
      }

      ref.invalidate(vendorSubscriptionProvider);
    });
  }

  bool get _isWaitingForActivation {
    if (widget.paymentStatus != 'success') return false;
    final startedAt = _activationPollStartedAt;
    if (startedAt == null) return false;
    return DateTime.now().difference(startedAt) <= const Duration(seconds: 45);
  }

  Future<void> _startSubscription() async {
    setState(() => _startingCheckout = true);

    try {
      final session = await ref
          .read(supabaseServiceProvider)
          .createVendorSubscriptionCheckout();
      final checkoutUri = Uri.tryParse(session.checkoutUrl);
      if (checkoutUri == null) {
        throw Exception('PayFast returned an invalid checkout URL.');
      }

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PayfastSubscriptionCheckoutScreen(
            checkoutUri: checkoutUri,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$error',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _startingCheckout = false);
      }
    }
  }

  Future<void> _confirmAndCancelSubscription(
    VendorSubscription subscription,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Cancel subscription?',
          style: GoogleFonts.playfairDisplay(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        content: Text(
          subscription.currentPeriodEnd != null
              ? 'Your subscription will stay active until '
                    '${_formatDialogDate(subscription.currentPeriodEnd!)}. '
                    'PayFast will not bill you again, and after that date your '
                    'shop listings will be paused until you resubscribe.'
              : 'PayFast will stop future billing and your shop listings will '
                    'be paused until you resubscribe.',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: AppTheme.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Keep subscription',
              style: GoogleFonts.poppins(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Cancel subscription',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);

    try {
      await ref.read(supabaseServiceProvider).cancelVendorSubscription();
      ref.invalidate(vendorSubscriptionProvider);
      ref.invalidate(vendorSubscriptionStreamProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Subscription cancelled. You will not be billed again.',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: AppTheme.baobab,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$error',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _cancelling = false);
      }
    }
  }

  static String _formatDialogDate(DateTime value) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final day = value.day.toString();
    final month = months[value.month - 1];
    final year = value.year.toString();
    return '$day $month $year';
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionStreamAsync = ref.watch(vendorSubscriptionStreamProvider);
    final subscriptionFutureAsync = ref.watch(vendorSubscriptionProvider);
    final subscription =
        subscriptionStreamAsync.value ?? subscriptionFutureAsync.value;
    final subscriptionError =
        subscriptionStreamAsync.error ?? subscriptionFutureAsync.error;
    final isSubscriptionLoading =
        subscription == null &&
        subscriptionError == null &&
        (subscriptionStreamAsync.isLoading || subscriptionFutureAsync.isLoading);
    final status = subscription?.status ?? 'inactive';
    final isActive = isVendorSubscriptionActive(subscription);
    final isCancelledButAccessible =
        isVendorSubscriptionCancelledButAccessible(subscription);
    final canCancel = status == 'active' && isActive;
    final isActivating = _isWaitingForActivation && !isActive;
    final canStartSubscription =
        !isSubscriptionLoading &&
        subscriptionError == null &&
        status != 'active' &&
        !isActivating;

    if (isActive && _activationPollTimer?.isActive == true) {
      _activationPollTimer?.cancel();
    }

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Artisan Subscription',
          style: GoogleFonts.playfairDisplay(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.terracotta,
          onRefresh: () async {
            ref.invalidate(vendorSubscriptionProvider);
            ref.invalidate(vendorSubscriptionStreamProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (widget.paymentStatus != null) ...[
                _ReturnStatusCard(
                  status: widget.paymentStatus!,
                  isActivating: isActivating,
                  isActive: isActive,
                ),
                const SizedBox(height: 16),
              ],
              _SubscriptionHeroCard(
                subscription: subscription,
                isActive: isActive,
                isCancelledButAccessible: isCancelledButAccessible,
                isLoading: isSubscriptionLoading,
                errorMessage: subscriptionError?.toString(),
              ),
              const SizedBox(height: 20),
              _FeatureCard(
                title: 'What this unlocks',
                items: const [
                  'Keep product listings available to buyers',
                  'Allow new buyer checkouts for your shop',
                  'Manage your subscription status inside Artisan Lane',
                ],
              ),
              const SizedBox(height: 20),
              _FeatureCard(
                title: 'Billing',
                items: const [
                  'First month free',
                  'R349 per month after your free month',
                  'Secure recurring card billing through PayFast',
                  'Add your card now, with the first charge starting in one month',
                ],
              ),
              const SizedBox(height: 24),
              GradientButton(
                label: vendorSubscriptionCtaLabel(
                  status: status,
                  isSubscriptionLoading: isSubscriptionLoading,
                  isActivating: isActivating,
                  isCancelledButAccessible: isCancelledButAccessible,
                  subscriptionError: subscriptionError,
                ),
                onPressed: canStartSubscription ? _startSubscription : null,
                isLoading:
                    (!isSubscriptionLoading && _startingCheckout) || isActivating,
                fontSize: 15,
              ),
              if (canCancel && subscription != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _cancelling
                      ? null
                      : () => _confirmAndCancelSubscription(subscription),
                  icon: _cancelling
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.error,
                          ),
                        )
                      : const Icon(
                          Icons.cancel_outlined,
                          color: AppTheme.error,
                          size: 18,
                        ),
                  label: Text(
                    _cancelling
                        ? 'Cancelling…'
                        : 'Cancel Subscription',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.error,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: AppTheme.error.withValues(alpha: 0.4),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'PayFast will stop future billing. Your listings stay live '
                  'until the end of the current period.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.textHint,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SubscriptionHeroCard extends StatelessWidget {
  final VendorSubscription? subscription;
  final bool isActive;
  final bool isCancelledButAccessible;
  final bool isLoading;
  final String? errorMessage;

  const _SubscriptionHeroCard({
    required this.subscription,
    required this.isActive,
    this.isCancelledButAccessible = false,
    this.isLoading = false,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final status = subscription?.status ?? 'inactive';
    final statusColor = isLoading
        ? AppTheme.ochre
        : errorMessage != null
        ? AppTheme.error
        : switch (status) {
      'active' => AppTheme.baobab,
      'pending' => AppTheme.ochre,
      'past_due' => AppTheme.error,
      'cancelled' =>
        isCancelledButAccessible ? AppTheme.ochre : AppTheme.textHint,
      _ => AppTheme.terracotta,
    };
    final statusLabel = isLoading
        ? 'Checking subscription'
        : errorMessage != null
        ? 'Subscription unavailable'
        : vendorSubscriptionStatusTitle(
            status,
            cancelledStillAccessible: isCancelledButAccessible,
          );
    final statusMessage = isLoading
        ? 'Checking your subscription status...'
        : errorMessage != null
        ? 'We could not load your subscription right now. Pull to refresh and try again.'
        : vendorSubscriptionStatusMessage(subscription);

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              statusLabel,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            artisanSubscriptionPlanLabel,
            style: GoogleFonts.playfairDisplay(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'First month free, then R${artisanSubscriptionAmount.toStringAsFixed(0)} / month',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (isLoading) ...[
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.ochre,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    statusMessage,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ] else
            Text(
              statusMessage,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          if (isActive && subscription?.currentPeriodEnd != null) ...[
            const SizedBox(height: 12),
            Text(
              isCancelledButAccessible
                  ? 'Shop unlocked until ${_formatDate(subscription!.currentPeriodEnd!)}'
                  : 'Current period ends ${_formatDate(subscription!.currentPeriodEnd!)}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppTheme.textHint,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

class _FeatureCard extends StatelessWidget {
  final String title;
  final List<String> items;

  const _FeatureCard({
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Icon(
                      Icons.check_circle_outline_rounded,
                      size: 16,
                      color: AppTheme.terracotta,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReturnStatusCard extends StatelessWidget {
  final String status;
  final bool isActivating;
  final bool isActive;

  const _ReturnStatusCard({
    required this.status,
    required this.isActivating,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final isSuccess = status == 'success';
    final Color color;
    final String message;
    final IconData icon;

    if (isSuccess && isActive) {
      color = AppTheme.baobab;
      icon = Icons.verified_outlined;
      message =
          'Subscription activated. Your shop is fully unlocked — start listing and selling.';
    } else if (isSuccess && isActivating) {
      color = AppTheme.ochre;
      icon = Icons.hourglass_bottom_rounded;
      message =
          'Payment received. Activating your subscription with PayFast — this usually takes a few seconds.';
    } else if (isSuccess) {
      color = AppTheme.baobab;
      icon = Icons.check_circle_outline;
      message =
          'PayFast sent you back to Artisan Lane. Pull to refresh if the status does not update shortly.';
    } else {
      color = AppTheme.ochre;
      icon = Icons.info_outline;
      message =
          'PayFast checkout was cancelled or interrupted. You can restart it below anytime.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isSuccess && isActivating)
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            )
          else
            Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
