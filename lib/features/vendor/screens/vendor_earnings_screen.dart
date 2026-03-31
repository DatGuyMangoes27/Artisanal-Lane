import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme.dart';
import '../providers/vendor_providers.dart';

class VendorEarningsScreen extends ConsumerWidget {
  const VendorEarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earningsAsync = ref.watch(vendorEarningsProvider);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: SafeArea(
        child: earningsAsync.when(
          data: (earnings) => RefreshIndicator(
            color: AppTheme.terracotta,
            onRefresh: () async => ref.invalidate(vendorEarningsProvider),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Earnings',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your sales and payout overview',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),

                // Total sales card
                _buildHighlightCard(
                  'Total Sales',
                  'R${(earnings['totalSales'] ?? 0).toStringAsFixed(2)}',
                  Icons.trending_up_rounded,
                  AppTheme.terracotta,
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        'Released',
                        'R${(earnings['released'] ?? 0).toStringAsFixed(2)}',
                        Icons.check_circle_outline,
                        AppTheme.baobab,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        'In Escrow',
                        'R${(earnings['held'] ?? 0).toStringAsFixed(2)}',
                        Icons.lock_clock_outlined,
                        AppTheme.ochre,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                _buildMetricCard(
                  'TradeSafe Fees',
                  'R${(earnings['fees'] ?? 0).toStringAsFixed(2)}',
                  Icons.receipt_outlined,
                  AppTheme.textSecondary,
                ),
                const SizedBox(height: 28),

                // Info card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.bone.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.sand.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 20,
                        color: AppTheme.ochre,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'How payouts work',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Funds are held in escrow until the buyer confirms receipt of the order. In this checkout flow, TradeSafe\'s escrow processing fee is charged at checkout rather than shown as an Artisan Lane commission taken from your payout. TradeSafe publishes integrated checkout fees as payment-method based charges, so the final fee can vary by how the buyer pays.',
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
                ),
              ],
            ),
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
    );
  }

  Widget _buildHighlightCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
          Icon(icon, size: 28, color: Colors.white.withValues(alpha: 0.8)),
          const SizedBox(height: 16),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textHint),
          ),
        ],
      ),
    );
  }
}
