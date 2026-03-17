import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../models/models.dart';
import '../providers/vendor_providers.dart';

class VendorStationeryRequestsScreen extends ConsumerStatefulWidget {
  const VendorStationeryRequestsScreen({super.key});

  @override
  ConsumerState<VendorStationeryRequestsScreen> createState() =>
      _VendorStationeryRequestsScreenState();
}

class _VendorStationeryRequestsScreenState
    extends ConsumerState<VendorStationeryRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _tabs = ['All', 'Active', 'Shipped', 'Delivered', 'Cancelled'];

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

  List<StationeryRequest> _filter(
    List<StationeryRequest> requests,
    int tabIndex,
  ) {
    switch (tabIndex) {
      case 1:
        return requests.where((request) => request.isActive).toList();
      case 2:
        return requests
            .where((request) => request.status == 'shipped')
            .toList();
      case 3:
        return requests
            .where((request) => request.status == 'delivered')
            .toList();
      case 4:
        return requests
            .where((request) => request.status == 'cancelled')
            .toList();
      default:
        return requests;
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(vendorStationeryRequestsStreamProvider);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Text(
                'Stationery Requests',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Track branded packaging requests and admin fulfilment updates.',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 16),
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
              tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
            ),
            Expanded(
              child: requestsAsync.when(
                data: (requests) => TabBarView(
                  controller: _tabController,
                  children: List.generate(_tabs.length, (index) {
                    final filtered = _filter(requests, index);
                    if (filtered.isEmpty) {
                      return _buildEmptyState();
                    }

                    return RefreshIndicator(
                      color: AppTheme.terracotta,
                      onRefresh: () async => ref.invalidate(
                        vendorStationeryRequestsStreamProvider,
                      ),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                        itemBuilder: (_, i) => _buildRequestCard(filtered[i]),
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemCount: filtered.length,
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
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 48, color: AppTheme.textHint),
          const SizedBox(height: 12),
          Text(
            'No stationery requests',
            style: GoogleFonts.poppins(color: AppTheme.textHint),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(StationeryRequest request) {
    return Container(
      padding: const EdgeInsets.all(16),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Request #${request.id.substring(0, 8)}',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${request.totalQuantity} item(s) · ${_formatDate(request.createdAt)}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textHint,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusChip(request.status),
            ],
          ),
          const SizedBox(height: 14),
          _buildLabeledText(
            'Items',
            request.items
                .map((item) => '${item.quantity} x ${item.name}')
                .join(', '),
          ),
          if (request.deliveryAddress?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            _buildLabeledText('Delivery address', request.deliveryAddress!),
          ],
          if (request.notes?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            _buildLabeledText('Your notes', request.notes!),
          ],
          if (request.adminNotes?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            _buildLabeledText('Admin notes', request.adminNotes!),
          ],
          if (request.courierName?.isNotEmpty == true ||
              request.trackingNumber?.isNotEmpty == true ||
              request.fulfilledAt != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.bone.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fulfilment',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  if (request.courierName?.isNotEmpty == true) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Courier: ${request.courierName}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                  if (request.trackingNumber?.isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Tracking: ${request.trackingNumber}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                  if (request.fulfilledAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Updated: ${_formatDateTime(request.fulfilledAt!)}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLabeledText(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textPrimary),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'processing':
        return AppTheme.ochre;
      case 'shipped':
        return AppTheme.statusShipped;
      case 'delivered':
        return AppTheme.statusDelivered;
      case 'cancelled':
        return AppTheme.statusCancelled;
      default:
        return AppTheme.statusPending;
    }
  }

  String _formatDate(DateTime value) {
    return '${value.day}/${value.month}/${value.year}';
  }

  String _formatDateTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.day}/${value.month}/${value.year} $hour:$minute';
  }
}
