import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../models/product.dart';

/// Default copy for the editorial banner.
const artisanEditEyebrow = 'THE ARTISAN EDIT';
const artisanEditHeadline = 'Made slowly.\nLoved for years.';

/// The "Artisan edit" editorial banner: a dark panel with copy on the left
/// and a maker's product photo bleeding in from the right. Tapping opens the
/// product.
///
/// The front page uses it as its hero, styled per season through
/// [eyebrow], [headline], [background] and [accent] (see
/// `FrontPageSeason`). The Shop tab has its own private copy of this
/// layout (`_ShopEditorial` in `creator_shop_screen.dart`); it can switch to
/// this widget with no visual change.
class ArtisanEditBanner extends StatelessWidget {
  const ArtisanEditBanner({
    super.key,
    required this.product,
    this.eyebrow = artisanEditEyebrow,
    this.headline = artisanEditHeadline,
    this.background = AppTheme.indigo,
    this.accent = AppTheme.ochre,
    this.height = 174,
    this.onTap,
  });

  final Product product;
  final String eyebrow;
  final String headline;
  final Color background;
  final Color accent;
  final double height;

  /// Defaults to opening the product page.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final maker = product.shopName?.trim().isNotEmpty == true
        ? product.shopName!.trim()
        : null;
    return Semantics(
      button: true,
      label: 'Explore ${product.title} by ${maker ?? 'a local maker'}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap ?? () => context.push('/home/product/${product.id}'),
          borderRadius: BorderRadius.circular(24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              height: height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: background),
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: 190,
                    child: CachedNetworkImage(
                      imageUrl: product.primaryImage,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          ColoredBox(color: background.withValues(alpha: .8)),
                      errorWidget: (_, __, ___) =>
                          const ColoredBox(color: AppTheme.baobab),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          background,
                          background.withValues(alpha: .9),
                          background.withValues(alpha: 0),
                        ],
                        stops: const [0, .42, 1],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          eyebrow.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            letterSpacing: 1.6,
                            fontWeight: FontWeight.w600,
                            color: accent,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            headline,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 25,
                              height: 1.05,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                maker ?? 'Meet the maker',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            CircleAvatar(
                              radius: 15,
                              backgroundColor: Colors.white,
                              child: Icon(
                                Icons.arrow_outward_rounded,
                                size: 16,
                                color: background,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
