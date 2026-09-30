import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../models/shop_post.dart';

/// Tells a maker their post was taken down by Artisan Lane, and why.
class RemovedPostBanner extends StatelessWidget {
  RemovedPostBanner({super.key, required ShopPost post, this.compact = false})
    : message = post.removedMessage;

  const RemovedPostBanner.message(
    this.message, {
    super.key,
    this.compact = false,
  });

  final String message;

  /// Tighter copy and margins for grid tiles.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: message,
      child: Container(
        margin: compact
            ? EdgeInsets.zero
            : const EdgeInsets.fromLTRB(14, 0, 14, 12),
        padding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: compact ? 8 : 10,
        ),
        decoration: BoxDecoration(
          color: AppTheme.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(compact ? 12 : 16),
          border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.block_outlined, size: 18, color: AppTheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                maxLines: compact ? 3 : null,
                overflow: compact ? TextOverflow.ellipsis : null,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
