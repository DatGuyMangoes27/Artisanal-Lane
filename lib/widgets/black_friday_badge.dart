import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app/theme.dart';
import '../core/promotions/black_friday.dart';

const _bfBlack = Color(0xFF111111);

/// The black "Black Friday Deal" sticker. Drawn from widgets only (no image
/// asset), so it can ship in an over-the-air patch.
class BlackFridaySticker extends StatelessWidget {
  const BlackFridaySticker({super.key, this.compact = false});

  /// A one-line tag for small spaces (e.g. the feed's product chip).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        key: const Key('black-friday-sticker'),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: _bfBlack,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'BLACK FRIDAY',
          style: GoogleFonts.poppins(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: AppTheme.ochre,
            letterSpacing: 0.4,
          ),
        ),
      );
    }
    return Transform.rotate(
      angle: -6 * math.pi / 180,
      child: Container(
        key: const Key('black-friday-sticker'),
        padding: const EdgeInsets.fromLTRB(9, 6, 9, 6),
        decoration: BoxDecoration(
          color: _bfBlack,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.ochre, width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'BLACK',
              style: GoogleFonts.poppins(
                fontSize: 11,
                height: 1,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.6,
              ),
            ),
            Text(
              'FRIDAY',
              style: GoogleFonts.poppins(
                fontSize: 11,
                height: 1.1,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'DEAL',
              style: GoogleFonts.poppins(
                fontSize: 9,
                height: 1,
                fontWeight: FontWeight.w800,
                color: AppTheme.ochre,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows the Black Friday sticker instead of [child] (the normal "Sale"
/// badge) while Black Friday is on. Only use it where the product is on
/// sale.
class SaleOrBlackFridayBadge extends ConsumerWidget {
  const SaleOrBlackFridayBadge({
    super.key,
    required this.child,
    this.compact = false,
  });

  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(blackFridayActiveProvider)) return child;
    return BlackFridaySticker(compact: compact);
  }
}

/// Shows the compact sticker only while Black Friday is on and [onSale].
class BlackFridayTag extends ConsumerWidget {
  const BlackFridayTag({super.key, required this.onSale, this.compact = true});

  final bool onSale;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!onSale || !ref.watch(blackFridayActiveProvider)) {
      return const SizedBox.shrink();
    }
    return BlackFridaySticker(compact: compact);
  }
}

/// "Black Friday Specials Now Live" banner for Home and Shop. Draws nothing
/// outside the Black Friday window.
class BlackFridayBanner extends ConsumerWidget {
  const BlackFridayBanner({super.key, this.onTap, this.margin});

  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(blackFridayActiveProvider)) return const SizedBox.shrink();
    return Padding(
      padding: margin ?? const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Material(
        color: _bfBlack,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('black-friday-banner'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BLACK FRIDAY · 27–30 NOV',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                          color: AppTheme.ochre,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Black Friday Specials Now Live',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 21,
                          height: 1.15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      if (onTap != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Shop the deals',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white70,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const BlackFridaySticker(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
