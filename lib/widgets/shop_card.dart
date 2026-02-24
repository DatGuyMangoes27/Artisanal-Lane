import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app/theme.dart';
import '../models/shop.dart';

class ShopCard extends StatelessWidget {
  final Shop shop;

  const ShopCard({super.key, required this.shop});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/home/shop/${shop.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
              child: SizedBox(
                height: 100,
                width: double.infinity,
                child: shop.coverImageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: shop.coverImageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: AppTheme.bone),
                        errorWidget: (_, __, ___) => Container(
                          color: AppTheme.bone,
                          child: const Icon(Icons.storefront,
                              color: AppTheme.textHint),
                        ),
                      )
                    : Container(
                        color: AppTheme.bone,
                        child: const Icon(Icons.storefront,
                            color: AppTheme.terracotta, size: 40),
                      ),
              ),
            ),
            // Logo and info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppTheme.bone,
                    backgroundImage: shop.logoUrl != null
                        ? CachedNetworkImageProvider(shop.logoUrl!)
                        : null,
                    child: shop.logoUrl == null
                        ? Text(
                            shop.name.isNotEmpty ? shop.name[0] : 'S',
                            style: GoogleFonts.playfairDisplay(
                              color: AppTheme.terracotta,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shop.name,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (shop.location != null) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined,
                                  size: 13, color: AppTheme.terracotta),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  shop.location!,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: AppTheme.textHint,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      color: AppTheme.textHint, size: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
