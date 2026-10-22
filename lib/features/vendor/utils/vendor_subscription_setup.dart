import '../../../models/vendor_subscription.dart';

/// Founders offer price for new sign-ups (first 100 shops, locked for 12 months).
const artisanSubscriptionAmount = 199.0;
const artisanSubscriptionStandardAmount = 299.0;
const artisanSubscriptionPlanLabel = 'Artisan Subscription';
const vendorSubscriptionGateMessage =
    'Start your free first month now. After that, your artisan subscription is R199/month, locked in for 12 months (founders offer, first 100 shops), before listing products or receiving new buyer checkouts.';

String formatSubscriptionAmount(double amount) {
  return amount == amount.roundToDouble()
      ? amount.toStringAsFixed(0)
      : amount.toStringAsFixed(2);
}

/// Price line for a shop's own subscription. Uses the subscription's actual
/// amount when one exists, otherwise the offer copy for new sign-ups.
String vendorSubscriptionPriceLine(VendorSubscription? subscription) {
  if (subscription != null &&
      subscription.amount > 0 &&
      isVendorSubscriptionActive(subscription)) {
    return 'R${formatSubscriptionAmount(subscription.amount)} / month';
  }
  return 'First month free, then R${formatSubscriptionAmount(artisanSubscriptionAmount)} / month for 12 months';
}

/// Days a recurring subscription stays usable after its paid-through date
/// while PayFast retries a failed card or a renewal notice arrives. Mirrors
/// public.vendor_subscription_is_active and the website.
const vendorSubscriptionGracePeriod = Duration(days: 5);

bool isVendorSubscriptionActive(VendorSubscription? subscription) {
  if (subscription == null) return false;
  final status = subscription.status;
  final currentPeriodEnd = subscription.currentPeriodEnd;
  if (status == 'active' || status == 'past_due') {
    return currentPeriodEnd == null ||
        currentPeriodEnd
            .add(vendorSubscriptionGracePeriod)
            .isAfter(DateTime.now());
  }
  if (status == 'cancelled') {
    return currentPeriodEnd != null && currentPeriodEnd.isAfter(DateTime.now());
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

VendorSubscription? preferredVendorSubscription({
  required VendorSubscription? streamValue,
  required VendorSubscription? futureValue,
}) {
  if (streamValue == null) return futureValue;
  if (futureValue == null) return streamValue;

  final futureIsActive = isVendorSubscriptionActive(futureValue);
  final streamIsActive = isVendorSubscriptionActive(streamValue);
  if (futureIsActive && !streamIsActive) return futureValue;
  if (streamIsActive && !futureIsActive) return streamValue;

  if (futureValue.updatedAt.isAfter(streamValue.updatedAt)) return futureValue;
  return streamValue;
}

/// Shown when an artisan without an active subscription tries to publish a
/// feed post. The database refuses the post either way
/// (guard_unsubscribed_post_publishing); this explains it.
const subscribeToPostTitle = 'Subscribe to post to the feed';
const subscribeToPostMessage =
    'Feed posts are part of your Artisan Lane subscription. Subscribe to share '
    'posts with buyers and to show your shop and products in the marketplace.';

bool isSubscriptionRequiredToPostError(Object? error) {
  final text = error?.toString().toLowerCase() ?? '';
  return text.contains('subscription_required_to_post') ||
      text.contains('subscribe to post to the feed');
}

bool isVendorSubscriptionAlreadyActiveError(Object error) {
  return error.toString().toLowerCase().contains(
    'artisan subscription is already active',
  );
}

String vendorSubscriptionStatusTitle(
  String status, {
  bool cancelledStillAccessible = false,
}) {
  switch (status) {
    case 'active':
      return 'Subscription active';
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

String vendorSubscriptionCtaLabel({
  required String status,
  required bool isSubscriptionLoading,
  required bool isActivating,
  required bool isCancelledButAccessible,
  Object? subscriptionError,
}) {
  if (isSubscriptionLoading) {
    return 'Checking subscription status…';
  }
  if (subscriptionError != null) {
    return 'Could not load subscription';
  }
  if (status == 'active') {
    return 'Subscription Active';
  }
  if (isCancelledButAccessible) {
    return 'Start 2-Month Free Trial';
  }
  if (isActivating) {
    return 'Activating subscription…';
  }
  return 'Start 2-Month Free Trial';
}
