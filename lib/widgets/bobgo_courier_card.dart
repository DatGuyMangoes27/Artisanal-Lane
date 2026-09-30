import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app/theme.dart';
import '../models/bobgo_status.dart';
import '../models/order.dart';

/// Courier booking + tracking summary for Bob Go orders. Renders nothing for
/// any other delivery method. Buyers see progress and tracking; vendors also
/// get the waybill and a retry when the booking failed.
class BobGoCourierCard extends StatelessWidget {
  const BobGoCourierCard({
    super.key,
    required this.order,
    this.isVendor = false,
    this.isBusy = false,
    this.onDownloadWaybill,
    this.onRetryBooking,
    this.onOpenTracking,
  });

  final Order order;
  final bool isVendor;
  final bool isBusy;
  final VoidCallback? onDownloadWaybill;
  final VoidCallback? onRetryBooking;
  final VoidCallback? onOpenTracking;

  @override
  Widget build(BuildContext context) {
    if (!order.isBobGo) return const SizedBox.shrink();

    final group = bobGoStatusGroup(order.bobgoStatus);
    final problem =
        order.bobgoBookingState == 'cancelled' ||
        (order.bobgoIsBooked && group == BobGoStatusGroup.exception);
    final canRetry =
        isVendor &&
        order.status == 'paid' &&
        (order.bobgoBookingState == 'failed' ||
            order.bobgoBookingState == 'not_requested');
    final trackingUrl = order.trackingUrl?.trim();

    return Container(
      key: const ValueKey('bobgo-courier-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.sand.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.local_shipping_outlined,
                size: 22,
                color: AppTheme.terracotta,
              ),
              const SizedBox(width: 10),
              Text(
                'Courier delivery',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: (problem ? AppTheme.error : AppTheme.baobab).withValues(
                alpha: 0.10,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              order.bobgoCourierSummary ?? '',
              key: const ValueKey('bobgo-courier-status'),
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: problem ? AppTheme.error : AppTheme.baobab,
              ),
            ),
          ),
          if (order.bobgoIsBooked &&
              (order.bobgoStatusDetail ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              order.bobgoStatusDetail!.trim(),
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
          if (order.bobgoIsBooked && order.trackingNumber != null) ...[
            const SizedBox(height: 12),
            Text(
              isVendor ? 'Waybill / tracking' : 'Tracking number',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppTheme.textHint,
              ),
            ),
            SelectableText(
              order.trackingNumber!,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
          if (order.bobgoIsBooked &&
              trackingUrl != null &&
              trackingUrl.isNotEmpty &&
              onOpenTracking != null) ...[
            const SizedBox(height: 12),
            _PillButton(
              key: const ValueKey('bobgo-open-tracking'),
              label: 'Track parcel',
              icon: Icons.open_in_new_rounded,
              onPressed: onOpenTracking,
            ),
          ],
          if (isVendor && order.bobgoIsBooked) ...[
            const SizedBox(height: 12),
            _PillButton(
              key: const ValueKey('bobgo-download-waybill'),
              label: 'Download waybill',
              icon: Icons.picture_as_pdf_outlined,
              onPressed: isBusy ? null : onDownloadWaybill,
            ),
            const SizedBox(height: 8),
            Text(
              'Print it, attach it to the parcel and have it ready for the courier.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
          if (canRetry) ...[
            const SizedBox(height: 12),
            Text(
              order.bobgoBookingState == 'failed'
                  ? 'The courier booking did not go through.'
                  : 'The courier has not been booked yet.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            _PillButton(
              key: const ValueKey('bobgo-retry-booking'),
              label: 'Book courier again',
              icon: Icons.refresh_rounded,
              onPressed: isBusy ? null : onRetryBooking,
            ),
          ],
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.terracotta,
          side: const BorderSide(color: AppTheme.terracotta),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
      ),
    );
  }
}
