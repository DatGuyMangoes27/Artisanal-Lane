import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme.dart';
import '../../../core/pricing/price_format.dart';
import '../../../core/ui/friendly_error.dart';
import '../../../models/models.dart';
import '../providers/vendor_providers.dart';
import '../widgets/workspace/workspace_header.dart';
import '../widgets/workspace/workspace_stat_tile.dart';

class VendorOrdersScreen extends ConsumerStatefulWidget {
  const VendorOrdersScreen({super.key});

  @override
  ConsumerState<VendorOrdersScreen> createState() => _VendorOrdersScreenState();
}

class _VendorOrdersScreenState extends ConsumerState<VendorOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _tabs = ['All', 'To ship', 'Shipped', 'Completed', 'Disputed'];
  static const _statusFilters = [
    '',
    'paid',
    'shipped',
    'completed',
    'disputed',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Order> _filter(List<Order> orders, int tabIndex) {
    if (tabIndex == 0) return orders;
    final status = _statusFilters[tabIndex];
    return orders.where((o) => o.status == status).toList();
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(vendorOrdersStreamProvider);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const WorkspaceHeader(eyebrow: 'Your shop', title: 'Orders'),
            const SizedBox(height: 4),
            TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: AppTheme.terracotta,
              unselectedLabelColor: AppTheme.textHint,
              labelStyle: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13),
              indicatorColor: AppTheme.terracotta,
              indicatorSize: TabBarIndicatorSize.label,
              tabAlignment: TabAlignment.start,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              tabs: _tabs.map((t) => Tab(text: t)).toList(),
            ),
            Expanded(
              child: ordersAsync.when(
                data: (orders) => TabBarView(
                  controller: _tabController,
                  children: List.generate(_tabs.length, (i) {
                    final filtered = _filter(orders, i);
                    if (filtered.isEmpty) {
                      return WorkspaceEmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'No orders here yet',
                        message: i == 0
                            ? 'Orders will appear here as soon as buyers check out.'
                            : 'Nothing in this tab right now.',
                      );
                    }
                    return RefreshIndicator(
                      color: AppTheme.terracotta,
                      onRefresh: () async =>
                          ref.invalidate(vendorOrdersStreamProvider),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, idx) =>
                            _buildOrderCard(context, filtered[idx]),
                      ),
                    );
                  }),
                ),
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.terracotta,
                    strokeWidth: 2,
                  ),
                ),
                error: (e, _) => ErrorRetryView(
                  error: e,
                  title: "Couldn't load your orders",
                  onRetry: () => ref.invalidate(vendorOrdersStreamProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, Order order) {
    final buyerName =
        order.shippingAddress?['name'] as String? ??
        order.buyerDisplayName ??
        'Buyer';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/vendor/orders/${order.id}'),
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(18),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Order #${order.shortId}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  WorkspaceStatusPill(
                    label: order.status.toUpperCase(),
                    color: AppTheme.getStatusColor(order.status),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                buyerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${order.items?.length ?? 0} item(s) · ${formatBrowsePrice(order.grandTotal)}',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (order.shippingMethod != null) ...[
                const SizedBox(height: 4),
                Text(
                  order.shippingMethodDisplay,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.textHint,
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
