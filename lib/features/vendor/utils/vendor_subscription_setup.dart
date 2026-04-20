import '../../../models/vendor_subscription.dart';

const artisanSubscriptionAmount = 349.0;
const artisanSubscriptionPlanLabel = 'Artisan Subscription';
const vendorSubscriptionGateMessage =
    'Start your R349/month artisan subscription before listing products or receiving new buyer checkouts.';

bool isVendorSubscriptionActive(VendorSubscription? subscription) {
  if (subscription == null) return false;
  final status = subscription.status;
  final currentPeriodEnd = subscription.currentPeriodEnd;
  if (status == 'active') {
    return currentPeriodEnd == null || currentPeriodEnd.isAfter(DateTime.now());
  }
  if (status == 'cancelled') {
    return currentPeriodEnd != null &&
        currentPeriodEnd.isAfter(DateTime.now());
  }
  return false;
}

bool isVendorSubscriptionCancelledButAccessible(
  VendorSubscription? subscription,
) {
  if (subscription == null) return false;
  if (subscription.status != 'cancelled') return false;
  final currentPeriodEnd = subscription.currentPeriodEnd;
  return currentPeriodEnd != null && currentPeriodEnd.isAfter(DateTime.now());
}

String vendorSubscriptionStatusTitle(
  String status, {
  bool cancelledStillAccessible = false,
}) {
  switch (status) {
    case 'active':
      return 'Subscription active';
    case 'pending':
      return 'Subscription pending';
    case 'past_due':
      return 'Payment action required';
    case 'cancelled':
      return cancelledStillAccessible
          ? 'Cancelled • access until period end'
          : 'Subscription cancelled';
    default:
      return 'Subscription inactive';
  }
}

String _formatCurrentPeriodEnd(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String vendorSubscriptionStatusMessage(VendorSubscription? subscription) {
  final status = subscription?.status ?? 'inactive';
  switch (status) {
    case 'active':
      final periodEnd = subscription?.currentPeriodEnd;
      if (periodEnd == null) {
        return 'Your artisan subscription is active and your listings can keep selling.';
      }
      return 'Your artisan subscription is active through '
          '${_formatCurrentPeriodEnd(periodEnd)}.';
    case 'pending':
      return 'We are waiting for PayFast to confirm your subscription payment.';
    case 'past_due':
      return subscription?.statusReason ??
          'Your last PayFast subscription payment needs attention before new sales can continue.';
    case 'cancelled':
      final periodEnd = subscription?.currentPeriodEnd;
      if (periodEnd != null && periodEnd.isAfter(DateTime.now())) {
        return 'Your subscription is cancelled. PayFast will not bill you again, '
            'but your shop stays fully unlocked until '
            '${_formatCurrentPeriodEnd(periodEnd)}. Resubscribe any time to '
            'keep selling beyond that date.';
      }
      return 'Your PayFast subscription is cancelled. Restart it to keep selling.';
    default:
      return vendorSubscriptionGateMessage;
  }
}
