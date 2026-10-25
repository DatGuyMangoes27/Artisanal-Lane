import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app/theme.dart';
import '../../../models/models.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/unread_messages_fab.dart';
import '../../auth/providers/auth_providers.dart';
import '../../buyer/providers/buyer_providers.dart'
    show notificationsStreamProvider;
import '../widgets/seller_hub.dart';
import '../widgets/stationery_sheet_header.dart';
import '../widgets/workspace/workspace_header.dart';
import '../widgets/workspace/workspace_stat_tile.dart';
import '../providers/vendor_providers.dart';
import '../utils/vendor_onboarding_flow.dart';
import '../utils/vendor_payout_setup.dart';
import '../utils/vendor_subscription_setup.dart';
import 'payfast_subscription_checkout_screen.dart';

class VendorDashboardScreen extends ConsumerWidget {
  const VendorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopAsync = ref.watch(vendorShopProvider);
    final profile = ref.watch(currentProfileProvider).value;

    return shopAsync.when(
      loading: () => Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
        body: const Center(
          child: CircularProgressIndicator(
            color: AppTheme.terracotta,
            strokeWidth: 2,
          ),
        ),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
        body: Center(child: Text('Error: $e')),
      ),
      data: (shop) {
        if (shop == null) {
          if (profile?.hasSeenVendorApproval != true) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                GoRouter.of(context).go('/vendor/onboarding');
              }
            });
            return Scaffold(
              backgroundColor: AppTheme.scaffoldBg,
              body: const Center(
                child: CircularProgressIndicator(
                  color: AppTheme.terracotta,
                  strokeWidth: 2,
                ),
              ),
            );
          }
          return const _VendorSetupContent();
        }
        return _DashboardContent(shop: shop);
      },
    );
  }
}

class _VendorSetupContent extends ConsumerWidget {
  const _VendorSetupContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final payoutProfile =
        ref.watch(vendorPayoutProfileStreamProvider).value ??
        ref.watch(vendorPayoutProfileProvider).value;
    final payoutStatus = payoutProfile?.verificationStatus ?? 'not_started';
    final payoutReady = isVendorPayoutSetupComplete(payoutProfile);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              profileAsync.when(
                data: (profile) => Text(
                  'Welcome back, Artisan',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                loading: () => Text(
                  'Welcome back, Artisan',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                error: (_, __) => Text(
                  'Welcome back, Artisan',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Finish your vendor setup so payouts and fulfilment run smoothly from the start.',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              _PayoutBanner(status: payoutStatus),
              const SizedBox(height: 20),
              _SetupChecklistCard(
                payoutStatus: payoutStatus,
                payoutReady: payoutReady,
                onOpenPayouts: () => context.push('/vendor/profile/payouts'),
                onOpenShop: () => context.push('/vendor/profile/shop'),
                onOpenStationery: () =>
                    context.push('/vendor/profile/stationery'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardContent extends ConsumerWidget {
  final Shop shop;
  const _DashboardContent({required this.shop});

  void _showSubscriptionRequiredDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Start your artisan subscription',
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w600),
        ),
        content: Text(
          vendorSubscriptionGateMessage,
          style: GoogleFonts.poppins(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.push('/vendor/profile/subscription');
            },
            child: const Text('Open subscription'),
          ),
        ],
      ),
    );
  }

  void _showPayoutRequiredDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Complete payout details',
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w600),
        ),
        content: Text(
          vendorPayoutGateMessage,
          style: GoogleFonts.poppins(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.push('/vendor/profile/payouts');
            },
            child: const Text('Open payout details'),
          ),
        ],
      ),
    );
  }

  void _handleAddProductTap(
    BuildContext context,
    bool payoutReady,
    bool subscriptionActive, {
    String targetRoute = '/vendor/products/new',
  }) {
    if (!subscriptionActive) {
      _showSubscriptionRequiredDialog(context);
      return;
    }
    if (payoutReady) {
      context.push(targetRoute);
      return;
    }
    _showPayoutRequiredDialog(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(vendorOrdersProvider);
    final productsAsync = ref.watch(vendorProductsProvider);
    final earningsAsync = ref.watch(vendorEarningsProvider);
    final unreadMessages = ref.watch(vendorUnreadThreadsCountProvider);
    final payoutProfile =
        ref.watch(vendorPayoutProfileStreamProvider).value ??
        ref.watch(vendorPayoutProfileProvider).value;
    final payoutReady = isVendorPayoutSetupComplete(payoutProfile);
    final subscription = preferredVendorSubscription(
      streamValue: ref.watch(vendorSubscriptionStreamProvider).value,
      futureValue: ref.watch(vendorSubscriptionProvider).value,
    );
    final subscriptionActive = isVendorSubscriptionActive(subscription);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      floatingActionButton: unreadMessages > 0
          ? UnreadMessagesFab(count: unreadMessages, route: '/vendor/messages')
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.terracotta,
          onRefresh: () async {
            ref.invalidate(vendorShopProvider);
            ref.invalidate(vendorOrdersProvider);
            ref.invalidate(vendorProductsProvider);
            ref.invalidate(vendorEarningsProvider);
            ref.invalidate(vendorThreadsProvider);
            ref.invalidate(vendorThreadsStreamProvider);
            ref.invalidate(vendorPayoutProfileProvider);
            ref.invalidate(vendorPayoutProfileStreamProvider);
            ref.invalidate(vendorSubscriptionProvider);
            ref.invalidate(vendorSubscriptionStreamProvider);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: WorkspaceHeader(
                  eyebrow: 'Your studio',
                  title: 'Welcome back',
                  subtitle: shop.name,
                  actions: [
                    _NotificationsBell(
                      onTap: () => context.push('/vendor/notifications'),
                    ),
                  ],
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // To-do card: only what's incomplete today.
                      _DashboardTodoCard(
                        subscriptionActive: subscriptionActive,
                        payoutReady: payoutReady,
                        hasFirstProduct:
                            (productsAsync.value?.isNotEmpty ?? false),
                        onOpenSubscription: () =>
                            context.push('/vendor/profile/subscription'),
                        onOpenPayouts: () =>
                            context.push('/vendor/profile/payouts'),
                        onAddProduct: () => _handleAddProductTap(
                          context,
                          payoutReady,
                          subscriptionActive,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Create & grow: the same seller tools as the You
                      // tab's Selling hub, so they are easy to find here too.
                      Text(
                        'Create & grow',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SellerToolTiles(
                        onAddProduct: () => _handleAddProductTap(
                          context,
                          payoutReady,
                          subscriptionActive,
                          targetRoute: '/create/product',
                        ),
                        onPhotoEnhancer: () => _handleAddProductTap(
                          context,
                          payoutReady,
                          subscriptionActive,
                          targetRoute: '/create/product',
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Stats
                      earningsAsync.when(
                        data: (earnings) => _buildStatsRow(
                          context,
                          productsAsync.value?.length ?? 0,
                          ordersAsync.value
                                  ?.where((o) => o.status == 'paid')
                                  .length ??
                              0,
                          earnings['released'] ?? 0,
                        ),
                        loading: () => _buildStatsRow(context, 0, 0, 0),
                        error: (_, __) => _buildStatsRow(context, 0, 0, 0),
                      ),
                      const SizedBox(height: 24),

                      // Earnings card
                      earningsAsync.when(
                        data: (earnings) =>
                            _buildEarningsCard(context, earnings),
                        loading: () => _buildLoadingCard(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 28),

                      // More tools
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionCard(
                              context,
                              Icons.edit_note_rounded,
                              'My posts',
                              AppTheme.ochre,
                              () => context.push('/vendor/profile/posts'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: _buildStationeryActionCard(context)),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // Recent orders
                      WorkspaceSectionHeader(
                        title: 'Recent orders',
                        onAction: () => context.go('/vendor/orders'),
                      ),
                      const SizedBox(height: 12),
                      ordersAsync.when(
                        data: (orders) {
                          if (orders.isEmpty) {
                            return _buildEmptyCard(
                              Icons.receipt_long_outlined,
                              'No orders yet',
                              'Orders will appear here when customers purchase your products',
                            );
                          }
                          final recent = orders.take(5).toList();
                          return Column(
                            children: recent
                                .map((o) => _buildOrderTile(context, o))
                                .toList(),
                          );
                        },
                        loading: () => _buildLoadingCard(),
                        error: (e, _) => _buildErrorCard(e.toString()),
                      ),
                      const SizedBox(height: 28),

                      _buildContactActionCard(context, fullWidth: true),
                      const SizedBox(height: 12),
                      _buildMessagesActionCard(context, unreadMessages),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(
    BuildContext context,
    int products,
    int ordersToShip,
    double released,
  ) {
    return Row(
      children: [
        Expanded(
          child: WorkspaceStatTile(
            value: '$products',
            label: 'Products',
            icon: Icons.inventory_2_outlined,
            color: AppTheme.baobab,
            onTap: () => context.go('/vendor/products'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: WorkspaceStatTile(
            value: '$ordersToShip',
            label: 'To ship',
            icon: Icons.local_shipping_outlined,
            color: AppTheme.ochre,
            onTap: () => context.go('/vendor/orders'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: WorkspaceStatTile(
            value: 'R${released.toStringAsFixed(0)}',
            label: 'Earnings',
            icon: Icons.account_balance_wallet_outlined,
            color: AppTheme.terracotta,
            onTap: () => context.go('/vendor/earnings'),
          ),
        ),
      ],
    );
  }

  Widget _buildEarningsCard(
    BuildContext context,
    Map<String, double> earnings,
  ) {
    return GestureDetector(
      onTap: () => context.go('/vendor/earnings'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.terracotta, AppTheme.baobab],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.terracotta.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Earnings Overview',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.white54,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'R${(earnings['released'] ?? 0).toStringAsFixed(2)}',
              style: GoogleFonts.poppins(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              'Released to you',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildEarningsPill(
                  'Held',
                  'R${(earnings['held'] ?? 0).toStringAsFixed(0)}',
                ),
                const SizedBox(width: 10),
                _buildEarningsPill(
                  'TradeSafe',
                  'R${(earnings['fees'] ?? 0).toStringAsFixed(0)}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEarningsPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label: $value',
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildOrderTile(BuildContext context, dynamic order) {
    return GestureDetector(
      onTap: () => context.push('/vendor/orders/${order.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.getStatusColor(
                  order.status,
                ).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.receipt_outlined,
                size: 18,
                color: AppTheme.getStatusColor(order.status),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#${order.shortId}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    '${order.items?.length ?? 0} items',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textHint,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'R${order.grandTotal.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.getStatusColor(
                      order.status,
                    ).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    order.status.toString().toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.getStatusColor(order.status),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStationeryActionCard(BuildContext context) {
    return GestureDetector(
      onTap: () => _showStationerySheet(context),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.terracotta, AppTheme.baobab],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.card_giftcard_outlined,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Order\nStationery',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesActionCard(BuildContext context, int unreadMessages) {
    return GestureDetector(
      onTap: () => context.push('/vendor/messages'),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.baobab.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: AppTheme.baobab,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Customer Messages',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    unreadMessages > 0
                        ? '$unreadMessages unread conversation${unreadMessages == 1 ? '' : 's'}'
                        : 'Reply to buyers and manage chats',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textHint,
                    ),
                  ),
                ],
              ),
            ),
            if (unreadMessages > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: const BoxDecoration(
                  color: AppTheme.terracotta,
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
                child: Text(
                  unreadMessages > 9 ? '9+' : '$unreadMessages',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textHint),
          ],
        ),
      ),
    );
  }

  Widget _buildContactActionCard(
    BuildContext context, {
    bool fullWidth = false,
  }) {
    return GestureDetector(
      onTap: () => _showContactSheet(context),
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
        ),
        child: fullWidth
            ? Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.terracotta.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.support_agent_outlined,
                      color: AppTheme.terracotta,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Contact Artisan Lane',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.textHint,
                  ),
                ],
              )
            : Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.terracotta.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.support_agent_outlined,
                      color: AppTheme.terracotta,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Contact\nArtisan Lane',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _showStationerySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StationeryOrderSheet(shop: shop),
    );
  }

  void _showContactSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ContactSheet(shop: shop),
    );
  }

  Widget _buildEmptyCard(IconData icon, String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppTheme.textHint),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textHint),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: AppTheme.terracotta,
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        'Error: $error',
        style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.error),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Stationery Order Bottom Sheet
// ═══════════════════════════════════════════════════════════════════

class _StationeryItem {
  final String key;
  final String name;
  final String description;
  final IconData icon;
  final double unitPrice;
  int quantity = 0;

  _StationeryItem({
    required this.key,
    required this.name,
    required this.description,
    required this.icon,
    required this.unitPrice,
  });
}

class _StationeryOrderSheet extends ConsumerStatefulWidget {
  final Shop shop;
  const _StationeryOrderSheet({required this.shop});

  @override
  ConsumerState<_StationeryOrderSheet> createState() =>
      _StationeryOrderSheetState();
}

class _StationeryOrderSheetState extends ConsumerState<_StationeryOrderSheet> {
  final _notesController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isSubmitting = false;

  final List<_StationeryItem> _items = [
    _StationeryItem(
      key: 'gift_tag',
      name: 'Gift Tag',
      description: '50 x 80 mm branded tag — R7 each',
      icon: Icons.style_outlined,
      unitPrice: 7,
    ),
    _StationeryItem(
      key: 'wrap_sheet',
      name: 'Wrap Sheet',
      description: '500 x 700 mm branded wrap sheet — R15 each',
      icon: Icons.inventory_2_outlined,
      unitPrice: 15,
    ),
    _StationeryItem(
      key: 'sticker',
      name: 'Sticker',
      description: 'Branded sticker — R4 each',
      icon: Icons.local_offer_outlined,
      unitPrice: 4,
    ),
  ];

  @override
  void dispose() {
    _notesController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  bool get _hasItems => _items.any((i) => i.quantity > 0);

  double get _totalAmount =>
      _items.fold(0, (sum, item) => sum + (item.quantity * item.unitPrice));

  Future<void> _submit() async {
    if (!_hasItems) return;
    setState(() => _isSubmitting = true);
    try {
      final service = ref.read(supabaseServiceProvider);
      final checkoutSession = await service.createStationeryCheckout(
        shopId: widget.shop.id,
        items: _items
            .where((i) => i.quantity > 0)
            .map((i) => {'key': i.key, 'name': i.name, 'quantity': i.quantity})
            .toList(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        deliveryAddress: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
      );
      final checkoutUri = Uri.tryParse(checkoutSession.checkoutUrl);
      if (checkoutUri == null) {
        throw Exception('PayFast returned an invalid checkout URL.');
      }

      if (mounted) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => PayfastSubscriptionCheckoutScreen(
              checkoutUri: checkoutUri,
              title: 'Pay for Stationery',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to submit: $e',
              style: GoogleFonts.poppins(fontSize: 13),
            ),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.scaffoldBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.sand,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              StationerySheetHeader(
                title: 'Order Stationery',
                subtitle: 'Artisan Lane branded materials',
                onBackTap: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 24),

              // Items
              Text(
                'Select Items',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.sand.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: _items.asMap().entries.map((entry) {
                    final i = entry.key;
                    final item = entry.value;
                    return Column(
                      children: [
                        if (i > 0)
                          Divider(
                            height: 1,
                            color: AppTheme.sand.withValues(alpha: 0.3),
                            indent: 16,
                            endIndent: 16,
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: AppTheme.bone,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  item.icon,
                                  size: 18,
                                  color: AppTheme.terracotta,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      item.description,
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: AppTheme.textHint,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Qty stepper
                              Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.scaffoldBg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppTheme.sand.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _SheetStepperBtn(
                                      icon: Icons.remove_rounded,
                                      onTap: item.quantity > 0
                                          ? () =>
                                                setState(() => item.quantity--)
                                          : null,
                                    ),
                                    SizedBox(
                                      width: 28,
                                      child: Text(
                                        '${item.quantity}',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: item.quantity > 0
                                              ? AppTheme.terracotta
                                              : AppTheme.textHint,
                                        ),
                                      ),
                                    ),
                                    _SheetStepperBtn(
                                      icon: Icons.add_rounded,
                                      onTap: () =>
                                          setState(() => item.quantity++),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 20),

              // Delivery address
              Text(
                'Delivery Address',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _addressController,
                maxLines: 2,
                style: GoogleFonts.poppins(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Where should we send the stationery?',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppTheme.textHint,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppTheme.sand.withValues(alpha: 0.4),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppTheme.sand.withValues(alpha: 0.4),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.terracotta),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Notes
              Text(
                'Special Notes',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                maxLines: 2,
                style: GoogleFonts.poppins(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Any specific requests…',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppTheme.textHint,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppTheme.sand.withValues(alpha: 0.4),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppTheme.sand.withValues(alpha: 0.4),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.terracotta),
                  ),
                ),
              ),

              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.info_outline, size: 13, color: AppTheme.textHint),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'You will pay securely with PayFast before the request is sent to fulfilment.',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppTheme.textHint,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.sand.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total due',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Text(
                      'R${_totalAmount.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              GradientButton(
                label: 'Continue to PayFast',
                onPressed: _hasItems && !_isSubmitting ? _submit : null,
                isLoading: _isSubmitting,
                icon: Icons.lock_outline_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetStepperBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _SheetStepperBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: Icon(
          icon,
          size: 14,
          color: onTap != null ? AppTheme.textPrimary : AppTheme.textHint,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Contact Artisan Lane Bottom Sheet
// ═══════════════════════════════════════════════════════════════════

class _ContactSheet extends ConsumerStatefulWidget {
  final Shop shop;
  const _ContactSheet({required this.shop});

  @override
  ConsumerState<_ContactSheet> createState() => _ContactSheetState();
}

class _ContactSheetState extends ConsumerState<_ContactSheet> {
  final _messageController = TextEditingController();
  String _selectedSubject = 'General Inquiry';
  bool _isSubmitting = false;
  bool _hasMessage = false;

  static const _subjects = [
    'General Inquiry',
    'Payment / Earnings Issue',
    'Order Problem',
    'Account Help',
    'Stationery Order',
    'Technical Issue',
    'Other',
  ];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final msg = _messageController.text.trim();
    if (msg.isEmpty) return;
    setState(() => _isSubmitting = true);
    try {
      final service = ref.read(supabaseServiceProvider);
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await service.submitSupportTicket(
        userId: userId,
        shopId: widget.shop.id,
        subject: _selectedSubject,
        message: msg,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Message sent! We\'ll get back to you soon.',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
            ),
            backgroundColor: AppTheme.terracotta,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to send: $e',
              style: GoogleFonts.poppins(fontSize: 13),
            ),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.scaffoldBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.sand,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.terracotta.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.support_agent_outlined,
                      color: AppTheme.terracotta,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Contact Artisan Lane',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'We typically respond within 24 hours',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppTheme.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Subject
              Text(
                'Subject',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.sand.withValues(alpha: 0.4),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedSubject,
                    isExpanded: true,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    borderRadius: BorderRadius.circular(12),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppTheme.textPrimary,
                    ),
                    dropdownColor: Colors.white,
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppTheme.textHint,
                    ),
                    onChanged: (v) => setState(() => _selectedSubject = v!),
                    items: _subjects
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Message
              Text(
                'Message',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _messageController,
                maxLines: 5,
                onChanged: (v) =>
                    setState(() => _hasMessage = v.trim().isNotEmpty),
                style: GoogleFonts.poppins(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Describe your issue or question…',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppTheme.textHint,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppTheme.sand.withValues(alpha: 0.4),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppTheme.sand.withValues(alpha: 0.4),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.terracotta),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              GradientButton(
                label: 'Send Message',
                onPressed: _hasMessage && !_isSubmitting ? _submit : null,
                isLoading: _isSubmitting,
                icon: Icons.send_outlined,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PayoutBanner extends StatelessWidget {
  final String status;

  const _PayoutBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, size: 20, color: AppTheme.ochre),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TradeSafe payout status',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  vendorPayoutBannerMessage(status),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dashboard "to do" card: setup steps that still need attention today
/// (subscription, payout details, first product). Only shown when at least
/// one step is incomplete; each step reuses the existing gated actions so
/// gating/validation logic is untouched.
class _DashboardTodoCard extends StatelessWidget {
  final bool subscriptionActive;
  final bool payoutReady;
  final bool hasFirstProduct;
  final VoidCallback onOpenSubscription;
  final VoidCallback onOpenPayouts;
  final VoidCallback onAddProduct;

  const _DashboardTodoCard({
    required this.subscriptionActive,
    required this.payoutReady,
    required this.hasFirstProduct,
    required this.onOpenSubscription,
    required this.onOpenPayouts,
    required this.onAddProduct,
  });

  @override
  Widget build(BuildContext context) {
    if (subscriptionActive && payoutReady && hasFirstProduct) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.sand.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Finish setting up your shop',
            style: GoogleFonts.playfairDisplay(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'A few quick steps and you\'re ready to sell.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          _TodoStep(
            done: subscriptionActive,
            label: 'Start your subscription',
            onTap: onOpenSubscription,
          ),
          _TodoStep(
            done: payoutReady,
            label: 'Add payout details',
            onTap: onOpenPayouts,
          ),
          _TodoStep(
            done: hasFirstProduct,
            label: 'Add your first product',
            onTap: onAddProduct,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _TodoStep extends StatelessWidget {
  final bool done;
  final String label;
  final VoidCallback onTap;
  final bool isLast;

  const _TodoStep({
    required this.done,
    required this.label,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: done ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.only(top: 4, bottom: isLast ? 0 : 10),
        child: Row(
          children: [
            Icon(
              done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              size: 20,
              color: done ? AppTheme.baobab : AppTheme.ochre,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: done ? AppTheme.textHint : AppTheme.textPrimary,
                  decoration: done ? TextDecoration.lineThrough : null,
                  decorationColor: AppTheme.textHint,
                ),
              ),
            ),
            if (!done)
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppTheme.textHint,
              ),
          ],
        ),
      ),
    );
  }
}

class _SetupChecklistCard extends StatelessWidget {
  final String payoutStatus;
  final bool payoutReady;
  final VoidCallback onOpenPayouts;
  final VoidCallback onOpenShop;
  final VoidCallback onOpenStationery;

  const _SetupChecklistCard({
    required this.payoutStatus,
    required this.payoutReady,
    required this.onOpenPayouts,
    required this.onOpenShop,
    required this.onOpenStationery,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
            'Setup checklist',
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          _ChecklistRow(
            title: 'Payout details',
            subtitle: payoutReady
                ? 'TradeSafe payouts are active.'
                : vendorPayoutBannerMessage(payoutStatus),
            isComplete: payoutReady,
            onTap: onOpenPayouts,
          ),
          const SizedBox(height: 12),
          _ChecklistRow(
            title: 'Shop details',
            subtitle: 'Add your shop branding and profile details.',
            isComplete: false,
            onTap: onOpenShop,
          ),
          const SizedBox(height: 12),
          _ChecklistRow(
            title: 'Stationery information',
            subtitle: 'Review bank details and packaging-request updates.',
            isComplete: false,
            onTap: onOpenStationery,
          ),
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isComplete;
  final VoidCallback onTap;

  const _ChecklistRow({
    required this.title,
    required this.subtitle,
    required this.isComplete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.bone.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isComplete
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked,
              color: isComplete ? AppTheme.baobab : AppTheme.ochre,
            ),
            const SizedBox(width: 12),
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
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textHint),
          ],
        ),
      ),
    );
  }
}

class _NotificationsBell extends ConsumerWidget {
  final VoidCallback onTap;

  const _NotificationsBell({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasUnread =
        ref
            .watch(notificationsStreamProvider)
            .value
            ?.any((notification) => notification.isUnread) ??
        false;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(
              Icons.notifications_outlined,
              size: 22,
              color: AppTheme.textPrimary,
            ),
            if (hasUnread)
              Positioned(
                top: 10,
                right: 11,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: AppTheme.terracotta,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
