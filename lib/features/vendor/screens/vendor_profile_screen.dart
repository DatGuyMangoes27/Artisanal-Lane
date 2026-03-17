import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/vendor_providers.dart';

class VendorProfileScreen extends ConsumerWidget {
  const VendorProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopAsync = ref.watch(vendorShopProvider);
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 8),
              // Avatar and name
              shopAsync.when(
                data: (shop) => Column(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: AppTheme.bone,
                      backgroundImage: shop?.logoUrl != null
                          ? NetworkImage(shop!.logoUrl!)
                          : null,
                      child: shop?.logoUrl == null
                          ? const Icon(
                              Icons.store_rounded,
                              size: 36,
                              color: AppTheme.terracotta,
                            )
                          : null,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      shop?.name ?? '',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (shop?.location != null)
                      Text(
                        shop!.location!,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    profileAsync.when(
                      data: (profile) => profile != null
                          ? Text(
                              profile.email ?? '',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppTheme.textHint,
                              ),
                            )
                          : const SizedBox.shrink(),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                ),
                loading: () => const CircularProgressIndicator(
                  color: AppTheme.terracotta,
                  strokeWidth: 2,
                ),
                error: (_, __) => const Icon(
                  Icons.store_rounded,
                  size: 48,
                  color: AppTheme.textHint,
                ),
              ),
              const SizedBox(height: 32),

              // Menu items
              _buildMenuItem(
                context,
                Icons.store_outlined,
                'Shop Settings',
                'Edit your shop profile and branding',
                () => context.push('/vendor/profile/shop'),
              ),
              _buildMenuItem(
                context,
                Icons.inventory_2_outlined,
                'Stationery Requests',
                'Track branded packaging orders and fulfilment',
                () => context.push('/vendor/profile/stationery'),
              ),
              _buildMenuItem(
                context,
                Icons.feed_outlined,
                'Shop Posts',
                'Manage your social feed',
                () => context.push('/vendor/profile/posts'),
              ),
              _buildMenuItem(
                context,
                Icons.settings_outlined,
                'Settings',
                'Notifications, language, and more',
                () => context.push('/vendor/profile/settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.terracotta.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: AppTheme.terracotta),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textHint,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textHint),
          ],
        ),
      ),
    );
  }
}
