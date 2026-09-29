import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_providers.dart';
import '../../vendor/providers/vendor_providers.dart';
import '../../vendor/utils/vendor_payout_setup.dart';
import '../../vendor/utils/vendor_subscription_setup.dart';

/// Instagram-style "create" entry point. Available to every signed-in user:
/// sellers get Product/Post/Story, non-sellers get a single "Start selling"
/// item that routes into the vendor application flow instead.
class CreatorComposeButton extends ConsumerWidget {
  const CreatorComposeButton({super.key, required this.onFinished});
  final Future<void> Function() onFinished;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(currentUserIdProvider) == null) {
      return const SizedBox.shrink();
    }
    final shop = ref.watch(vendorShopProvider).value;
    if (shop != null) {
      // Load gating early so the sheet can show it without a false "blocked".
      ref.watch(vendorSubscriptionProvider);
      ref.watch(vendorPayoutProfileProvider);
    }

    return IconButton(
      tooltip: 'Create',
      icon: const Icon(Icons.add_circle_outline_rounded),
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      onPressed: () async {
        HapticFeedback.lightImpact();
        final choice = shop == null
            ? await _showStartSellingSheet(context)
            : await _showCreateSheet(context, ref);
        if (!context.mounted || choice == null) return;

        switch (choice) {
          case 'apply':
            await context.push('/vendor/apply');
          case 'story':
            await context.push('/create/story', extra: shop);
          case 'post':
            await context.push('/create/post');
          case 'product':
            await context.push('/create/product');
          case 'subscription':
            await context.push('/vendor/profile/subscription');
          case 'payouts':
            await context.push('/vendor/profile/payouts');
        }
        if (context.mounted) await onFinished();
      },
    );
  }

  Future<String?> _showStartSellingSheet(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  'What are you creating?',
                  style: Theme.of(ctx).textTheme.headlineSmall,
                ),
              ),
              ListTile(
                minVerticalPadding: 14,
                leading: const Icon(Icons.storefront_outlined),
                title: const Text('Start selling'),
                subtitle: const Text(
                  'Apply to open your own shop on Artisan Lane',
                ),
                onTap: () => Navigator.pop(ctx, 'apply'),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _showCreateSheet(BuildContext context, WidgetRef ref) {
    // Reuse the same gating ProductFormScreen relies on so sellers see the
    // requirement here instead of hitting a dead-end gate screen.
    // Until both are known, don't claim a block: the product form still
    // enforces the same gate.
    final payoutAsync = ref.read(vendorPayoutProfileProvider);
    final subscriptionAsync = ref.read(vendorSubscriptionProvider);
    final gatingKnown = payoutAsync.hasValue && subscriptionAsync.hasValue;
    final payoutProfile =
        ref.read(vendorPayoutProfileStreamProvider).value ?? payoutAsync.value;
    final payoutReady = isVendorPayoutSetupComplete(payoutProfile);
    final subscription = preferredVendorSubscription(
      streamValue: ref.read(vendorSubscriptionStreamProvider).value,
      futureValue: subscriptionAsync.value,
    );
    final subscriptionActive = isVendorSubscriptionActive(subscription);
    final productBlocked = gatingKnown && (!subscriptionActive || !payoutReady);
    final productBlockReason = !subscriptionActive
        ? 'Start your artisan subscription to list products'
        : 'Complete your payout details to list products';

    return showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  'What are you creating?',
                  style: Theme.of(ctx).textTheme.headlineSmall,
                ),
              ),
              ListTile(
                minVerticalPadding: 14,
                leading: Icon(
                  Icons.shopping_bag_outlined,
                  color: productBlocked ? Theme.of(ctx).disabledColor : null,
                ),
                title: const Text('Product'),
                subtitle: Text(
                  productBlocked
                      ? productBlockReason
                      : 'A new piece for your shop',
                ),
                onTap: () => Navigator.pop(
                  ctx,
                  productBlocked
                      ? (!subscriptionActive ? 'subscription' : 'payouts')
                      : 'product',
                ),
              ),
              ListTile(
                minVerticalPadding: 14,
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Post'),
                subtitle: const Text('Share your craft and link your products'),
                onTap: () => Navigator.pop(ctx, 'post'),
              ),
              ListTile(
                minVerticalPadding: 14,
                leading: const Icon(Icons.timelapse_rounded),
                title: const Text('24-hour story'),
                subtitle: const Text('A photo or short video from today'),
                onTap: () => Navigator.pop(ctx, 'story'),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
