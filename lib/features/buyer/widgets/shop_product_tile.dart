import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme.dart';
import '../../../core/pricing/price_format.dart';
import '../../../models/product.dart';
import 'product_favourite_button.dart';

enum ShopProductView { rows, twoCards, oneCard }

const shopQuietInk = Color(0xFF435951);

/// Extra height reserved for the "Because you liked …" reason line when a
/// layout shows it, so every tile in that layout stays the same height
/// whether or not that particular product has a reason to show.
double _reasonLineHeight(TextScaler scaler) => scaler.scale(11) * 1.3 + 5;

double shopProductDetailsHeight(
  TextScaler scaler, {
  bool reserveReason = false,
}) =>
    scaler.scale(12) * 1.3 +
    scaler.scale(15) * 2.6 +
    scaler.scale(13) * 1.4 +
    34 +
    (reserveReason ? _reasonLineHeight(scaler) : 0);

class ShopProductTile extends StatelessWidget {
  const ShopProductTile({
    super.key,
    required this.product,
    this.row = false,
    this.reason,
    this.reserveReasonSpace = false,
  });
  final Product product;
  final bool row;

  /// A short "Because you liked …" line for the For You view. Null hides
  /// the line for this tile (space is still reserved when
  /// [reserveReasonSpace] is true, so tiles stay aligned).
  final String? reason;

  /// Whether this layout reserves space for the reason line at all. Set
  /// this the same for every tile in a given list/grid so heights match.
  final bool reserveReasonSpace;

  @override
  Widget build(BuildContext context) {
    final detailsHeight = shopProductDetailsHeight(
      MediaQuery.textScalerOf(context),
      reserveReason: reserveReasonSpace,
    );
    final photo = Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: CachedNetworkImage(
              imageUrl: product.primaryImage,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              placeholder: (_, __) => Container(color: AppTheme.bone),
              errorWidget: (_, __, ___) => Container(
                color: AppTheme.bone,
                alignment: Alignment.center,
                child: const Icon(Icons.image_outlined, color: shopQuietInk),
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: ProductFavouriteButton(productId: product.id),
        ),
        if (product.compareAtPrice != null &&
            product.compareAtPrice! > product.price)
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.terracotta,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Sale',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
    final details = SizedBox(
      height: detailsHeight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 10, 2, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (reserveReasonSpace)
              SizedBox(
                height: _reasonLineHeight(MediaQuery.textScalerOf(context)),
                child: reason == null
                    ? null
                    : Text(
                        reason!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.baobab,
                        ),
                      ),
              ),
            Row(
              children: [
                Flexible(
                  child: Text(
                    product.shopName?.trim().isNotEmpty == true
                        ? product.shopName!
                        : 'Independent maker',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      height: 1.3,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                if (product.shopIsVerified) ...[
                  const SizedBox(width: 4),
                  Tooltip(
                    message: 'Verified artisan',
                    child: Semantics(
                      label: 'Verified artisan',
                      child: const Icon(
                        Icons.verified_rounded,
                        size: 13,
                        color: AppTheme.baobab,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 5),
            SizedBox(
              height: MediaQuery.textScalerOf(context).scale(15) * 2.6,
              child: Text(
                product.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 15,
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Flexible(
                  child: Text(
                    formatBrowsePrice(product.price),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                      color: shopQuietInk,
                    ),
                  ),
                ),
                if (product.compareAtPrice != null &&
                    product.compareAtPrice! > product.price) ...[
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      formatBrowsePrice(product.compareAtPrice!),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        height: 1.4,
                        color: AppTheme.textHint,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/home/product/${product.id}'),
        child: row
            ? SizedBox(
                height: math.max(112, detailsHeight),
                child: Row(
                  children: [
                    SizedBox(width: 104, height: 104, child: photo),
                    const SizedBox(width: 16),
                    Expanded(child: details),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: photo),
                  details,
                ],
              ),
      ),
    );
  }
}
