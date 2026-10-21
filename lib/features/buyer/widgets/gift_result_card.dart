import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../core/pricing/price_format.dart';
import '../providers/gift_finder_providers.dart';
import '../utils/shop_discovery_gift.dart';

/// A gift idea card: square photo, maker, title, price and a short
/// "why it fits" line. Grows with text scale instead of clipping.
class GiftResultCard extends StatelessWidget {
  const GiftResultCard({super.key, required this.recommendation});

  final GiftRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final product = recommendation.product;
    final maker = product.shopName?.trim();
    // Same price the finder filtered the budget on, so they always agree.
    final price = giftPrice(product);
    final compareAt = giftCompareAtPrice(product);
    return Semantics(
      button: true,
      label:
          '${product.title}, ${formatBrowsePrice(price)}. '
          '${recommendation.reason}',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/home/product/${product.id}'),
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.sand.withValues(alpha: .45)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .05),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _photo(product.images),
                          if (compareAt != null)
                            Positioned(
                              left: 8,
                              top: 8,
                              child: _badge('Sale', AppTheme.terracotta),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (maker != null && maker.isNotEmpty)
                          Text(
                            maker,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        const SizedBox(height: 2),
                        Text(
                          product.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            height: 1.3,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.end,
                          children: [
                            Text(
                              formatBrowsePrice(price),
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.terracotta,
                              ),
                            ),
                            if (compareAt != null)
                              Text(
                                formatBrowsePrice(compareAt),
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppTheme.textHint,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 1),
                              child: Icon(
                                Icons.auto_awesome_outlined,
                                size: 14,
                                color: AppTheme.baobab,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                recommendation.reason,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  height: 1.3,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.baobab,
                                ),
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

  Widget _photo(List<String> images) {
    const placeholder = ColoredBox(
      color: AppTheme.bone,
      child: Center(
        child: Icon(
          Icons.card_giftcard_outlined,
          color: AppTheme.textHint,
          size: 28,
        ),
      ),
    );
    if (images.isEmpty) return placeholder;
    return CachedNetworkImage(
      imageUrl: images.first,
      fit: BoxFit.cover,
      placeholder: (_, __) => const ColoredBox(color: AppTheme.bone),
      errorWidget: (_, __, ___) => placeholder,
    );
  }

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
  );
}
