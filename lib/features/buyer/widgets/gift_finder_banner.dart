import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';

/// Route of the gift finder (gift concierge) flow.
const giftFinderRoute = '/home/gift-concierge';

/// Card that opens the gift finder. Same look as the Shop tab's banner
/// (`_GiftFinderBanner` in `creator_shop_screen.dart`, which can switch to
/// this widget with no visual change). Callers own the outer padding.
class GiftFinderBanner extends StatelessWidget {
  const GiftFinderBanner({super.key, this.inkKey});

  /// Key for the tappable area (tests and analytics find it by this).
  final Key? inkKey;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.terracotta.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: inkKey,
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push(giftFinderRoute),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.terracotta,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.card_giftcard_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Find a gift they'll love",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Answer 3 quick questions for handmade ideas.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.terracotta,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
