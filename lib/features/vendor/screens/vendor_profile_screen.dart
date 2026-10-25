import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme.dart';
import '../../../core/constants/feature_flags.dart';
import '../../auth/providers/auth_providers.dart';
import '../../buyer/providers/buyer_providers.dart'
    show notificationsStreamProvider;
import '../providers/vendor_providers.dart';
import '../utils/vendor_subscription_setup.dart';
import '../widgets/workspace/workspace_header.dart';

class VendorProfileScreen extends ConsumerWidget {
  const VendorProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopAsync = ref.watch(vendorShopProvider);
    final profileAsync = ref.watch(currentProfileProvider);
    final unreadMessages = ref.watch(vendorUnreadThreadsCountProvider);
    final unreadNotifications =
        ref
            .watch(notificationsStreamProvider)
            .value
            ?.where((n) => n.isUnread)
            .length ??
        0;
    final subscription = preferredVendorSubscription(
      streamValue: ref.watch(vendorSubscriptionStreamProvider).value,
      futureValue: ref.watch(vendorSubscriptionProvider).value,
    );
    final subscriptionSubtitle = isVendorSubscriptionActive(subscription)
        ? vendorSubscriptionStatusMessage(subscription)
        : 'Manage your artisan subscription';

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const WorkspaceHeader(eyebrow: 'Your shop', title: 'You'),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: AppTheme.sand.withValues(alpha: 0.4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: shopAsync.when(
                    data: (shop) => Column(
                      children: [
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: AppTheme.bone,
                          backgroundImage: shop?.logoUrl != null
                              ? NetworkImage(shop!.logoUrl!)
                              : null,
                          child: shop?.logoUrl == null
                              ? const Icon(
                                  Icons.store_rounded,
                                  size: 36,
                                  color: AppTheme.terracotta,
                                )
                              : null,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          shop?.name ?? '',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        if (shop?.location != null)
                          Text(
                            shop!.location!,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        profileAsync.when(
                          data: (profile) => profile != null
                              ? Text(
                                  profile.email ?? '',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: AppTheme.textHint,
                                  ),
                                )
                              : const SizedBox.shrink(),
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                    loading: () => const CircularProgressIndicator(
                      color: AppTheme.terracotta,
                      strokeWidth: 2,
                    ),
                    error: (_, __) => const Icon(
                      Icons.store_rounded,
                      size: 48,
                      color: AppTheme.textHint,
                    ),
                  ),
                ),
              ),

              // Menu items
              if (creatorCommercePreviewEnabled)
                _buildMenuItem(
                  context,
                  Icons.auto_awesome_rounded,
                  'Creator Commerce Preview',
                  'Explore the new Feed, Shop and Photo enhancer',
                  () => context.push('/internal/creator-commerce'),
                ),
              _buildMenuItem(
                context,
                Icons.chat_bubble_outline_rounded,
                'Messages',
                unreadMessages > 0
                    ? '$unreadMessages unread conversation${unreadMessages == 1 ? '' : 's'}'
                    : 'Reply to buyers in one place',
                () => context.push('/vendor/messages'),
                badgeCount: unreadMessages,
              ),
              _buildMenuItem(
                context,
                Icons.workspace_premium_outlined,
                'Subscription',
                subscriptionSubtitle,
                () => context.push('/vendor/profile/subscription'),
              ),
              _buildMenuItem(
                context,
                Icons.account_balance_outlined,
                'Payout Details',
                'Manage your TradeSafe-linked bank details',
                () => context.push('/vendor/profile/payouts'),
              ),
              _buildMenuItem(
                context,
                Icons.store_outlined,
                'Shop Settings',
                'Edit your shop profile and branding',
                () => context.push('/vendor/profile/shop'),
              ),
              _buildMenuItem(
                context,
                Icons.sell_outlined,
                'Discount Codes',
                'Create shop-wide or product-specific offers',
                () => context.push('/vendor/coupons'),
              ),
              _buildMenuItem(
                context,
                Icons.inventory_2_outlined,
                'Stationery Requests',
                'Track branded packaging orders and fulfilment',
                () => context.push('/vendor/profile/stationery'),
              ),
              _buildMenuItem(
                context,
                Icons.feed_outlined,
                'Shop Posts',
                'Manage your social feed',
                () => context.push('/vendor/profile/posts'),
              ),
              _buildMenuItem(
                context,
                Icons.insights_outlined,
                'Insights',
                'Post views, followers and top posts',
                () => context.push('/vendor/insights'),
              ),
              _buildMenuItem(
                context,
                Icons.notifications_none_rounded,
                'Notifications',
                unreadNotifications > 0
                    ? '$unreadNotifications unread notification${unreadNotifications == 1 ? '' : 's'}'
                    : 'Order updates, messages and announcements',
                () => context.push('/vendor/notifications'),
                badgeCount: unreadNotifications,
              ),
              _buildMenuItem(
                context,
                Icons.settings_outlined,
                'Settings',
                'Account preferences and more',
                () => context.push('/vendor/profile/settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    int badgeCount = 0,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.sand.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.terracotta.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: AppTheme.terracotta),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textHint,
                    ),
                  ),
                ],
              ),
            ),
            if (badgeCount > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: const BoxDecoration(
                  color: AppTheme.terracotta,
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
                child: Text(
                  badgeCount > 9 ? '9+' : '$badgeCount',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textHint),
          ],
        ),
      ),
    );
  }
}
