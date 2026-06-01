import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme.dart';
import '../../../widgets/african_patterns.dart';
import '../../auth/providers/auth_providers.dart' show currentProfileProvider;
import '../providers/buyer_providers.dart';

class BuyerProfileScreen extends ConsumerStatefulWidget {
  const BuyerProfileScreen({super.key});

  @override
  ConsumerState<BuyerProfileScreen> createState() => _BuyerProfileScreenState();
}

class _BuyerProfileScreenState extends ConsumerState<BuyerProfileScreen> {
  final _picker = ImagePicker();
  bool _isUploadingAvatar = false;

  String _imagePickerErrorMessage(ImageSource source) {
    return source == ImageSource.camera
        ? 'Camera access is blocked. Please allow camera access in your phone settings, or choose a photo from your gallery.'
        : 'Could not access your photos. Please allow photo access in your phone settings and try again.';
  }

  Future<void> _showAvatarSourceSheet() async {
    if (_isUploadingAvatar) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.sand,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Update Profile Photo',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              _avatarSourceTile(
                icon: Icons.camera_alt_rounded,
                iconColor: AppTheme.terracotta,
                title: 'Take Photo',
                subtitle: 'Use your camera',
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadAvatar(ImageSource.camera);
                },
              ),
              _avatarSourceTile(
                icon: Icons.photo_library_rounded,
                iconColor: AppTheme.baobab,
                title: 'Choose from Gallery',
                subtitle: 'Pick from your photos',
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadAvatar(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarSourceTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textHint),
      ),
      onTap: onTap,
    );
  }

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    try {
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) {
        throw Exception('Please sign in again to update your profile photo.');
      }

      final image = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (image == null) return;

      setState(() => _isUploadingAvatar = true);
      final service = ref.read(supabaseServiceProvider);
      final avatarUrl = await service.uploadProfileAvatar(
        userId,
        File(image.path),
      );
      await service.updateProfile(userId, {'avatar_url': avatarUrl});
      ref.invalidate(profileProvider);
      ref.invalidate(currentProfileProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Profile photo updated.',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: AppTheme.baobab,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _imagePickerErrorMessage(source),
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final unreadMessages = ref.watch(buyerUnreadThreadsCountProvider);
    final disputedOrders = ref.watch(buyerDisputedOrdersProvider);
    final orders = ref.watch(ordersProvider).value ?? const [];
    final favouriteIds = ref.watch(currentFavouriteIdsProvider);
    final cartItems = ref.watch(cartItemsProvider).value ?? const [];
    final orderCount = orders.length;
    final favouriteCount = favouriteIds.length;
    final cartCount = cartItems.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: profileAsync.when(
        data: (profile) => _buildBody(
          context,
          profile,
          _showAvatarSourceSheet,
          _isUploadingAvatar,
          unreadMessages,
          disputedOrders.length,
          orderCount,
          favouriteCount,
          cartCount,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _buildErrorBody(
          context,
          unreadMessages,
          disputedOrders.length,
          orderCount,
          favouriteCount,
          cartCount,
        ),
      ),
    );
  }

  // ── Data-loaded body ──────────────────────────────────────────
  Widget _buildBody(
    BuildContext context,
    dynamic profile,
    VoidCallback onEditAvatar,
    bool isUploadingAvatar,
    int unreadMessages,
    int disputeCount,
    int orderCount,
    int favouriteCount,
    int cartCount,
  ) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeader(context, profile, onEditAvatar, isUploadingAvatar),
          const SizedBox(height: 32),
          _buildStatsRow(orderCount, favouriteCount, cartCount),
          const SizedBox(height: 32),
          _buildMenuSection(context, unreadMessages, disputeCount),
          const SizedBox(height: 40),
          const TripleDot(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Error / demo body ─────────────────────────────────────────
  Widget _buildErrorBody(
    BuildContext context,
    int unreadMessages,
    int disputeCount,
    int orderCount,
    int favouriteCount,
    int cartCount,
  ) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildPlaceholderHeader(context),
          const SizedBox(height: 32),
          _buildStatsRow(orderCount, favouriteCount, cartCount),
          const SizedBox(height: 32),
          _buildMenuSection(context, unreadMessages, disputeCount),
          const SizedBox(height: 40),
          const TripleDot(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Header section with profile data ────────────────────────────
  Widget _buildHeader(
    BuildContext context,
    dynamic profile,
    VoidCallback onEditAvatar,
    bool isUploadingAvatar,
  ) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 20,
            bottom: 20,
          ),
          child: Column(
            children: [
              // Avatar with camera button
              Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.white,
                      child: CircleAvatar(
                        radius: 56,
                        backgroundColor: const Color(0xFFFAFAFA),
                        backgroundImage: profile.avatarUrl != null
                            ? CachedNetworkImageProvider(profile.avatarUrl!)
                            : null,
                        child: profile.avatarUrl == null
                            ? Text(
                                (profile.displayName ?? 'U')[0].toUpperCase(),
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 4,
                    child: GestureDetector(
                      onTap: isUploadingAvatar ? null : onEditAvatar,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.terracotta,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.terracotta.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: isUploadingAvatar
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt_outlined,
                                size: 16,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Name
              Text(
                profile.displayName ?? 'User',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              // Email
              Text(
                profile.email ?? '',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppTheme.textHint,
                ),
              ),
            ],
          ),
        ),
        // Settings button – top right
        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          right: 20,
          child: IconButton(
            icon: const Icon(
              Icons.settings_outlined,
              color: AppTheme.textPrimary,
            ),
            onPressed: () => context.push('/profile/settings'),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.all(12),
              side: BorderSide(color: AppTheme.sand.withValues(alpha: 0.3)),
            ),
          ),
        ),
      ],
    );
  }

  // ── Placeholder header for error/demo state ─────────────────────
  Widget _buildPlaceholderHeader(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 20,
            bottom: 20,
          ),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.white,
                  child: CircleAvatar(
                    radius: 56,
                    backgroundColor: const Color(0xFFFAFAFA),
                    child: Icon(
                      Icons.person_outline,
                      size: 48,
                      color: AppTheme.textPrimary.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Demo Profile',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Connect Supabase to load profile data',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppTheme.textHint,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          right: 20,
          child: IconButton(
            icon: const Icon(
              Icons.settings_outlined,
              color: AppTheme.textPrimary,
            ),
            onPressed: () => context.push('/profile/settings'),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.all(12),
              side: BorderSide(color: AppTheme.sand.withValues(alpha: 0.3)),
            ),
          ),
        ),
      ],
    );
  }

  // ── Stats row ─────────────────────────────────────────────────
  Widget _buildStatsRow(int orderCount, int favouriteCount, int cartCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _statItem('$orderCount', 'Orders'),
            _verticalDivider(),
            _statItem('$favouriteCount', 'Favourites'),
            _verticalDivider(),
            _statItem('$cartCount', 'In Cart'),
          ],
        ),
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(
      height: 30,
      width: 1,
      color: AppTheme.sand.withValues(alpha: 0.3),
    );
  }

  Widget _statItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.playfairDisplay(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: AppTheme.textHint,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ── Menu section ──────────────────────────────────────────────
  Widget _buildMenuSection(
    BuildContext context,
    int unreadMessages,
    int disputeCount,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          _MenuItem(
            icon: Icons.receipt_long_outlined,
            title: 'My Orders',
            onTap: () => context.push('/profile/orders'),
          ),
          const SizedBox(height: 16),
          _MenuItem(
            icon: Icons.location_on_outlined,
            title: 'Saved Addresses',
            onTap: () => context.push('/profile/addresses'),
          ),
          const SizedBox(height: 16),
          _MenuItem(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Messages',
            badgeCount: unreadMessages,
            onTap: () => context.push('/profile/messages'),
          ),
          const SizedBox(height: 16),
          _MenuItem(
            icon: Icons.gavel_rounded,
            title: 'Disputes',
            badgeCount: disputeCount,
            onTap: () => context.push('/profile/disputes'),
          ),
          const SizedBox(height: 16),
          _MenuItem(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            onTap: () => context.push('/profile/notifications'),
          ),
          const SizedBox(height: 16),
          _MenuItem(
            icon: Icons.help_outline,
            title: 'Help & Support',
            onTap: () => context.push('/profile/help'),
          ),
          const SizedBox(height: 16),
          _MenuItem(
            icon: Icons.info_outline,
            title: 'About Artisan Lane',
            onTap: () => context.push('/profile/about'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Private widget class for menu items
// ═══════════════════════════════════════════════════════════════════
class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final int badgeCount;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: AppTheme.terracotta),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            if (badgeCount > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: const BoxDecoration(
                  color: AppTheme.terracotta,
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
                child: Text(
                  badgeCount > 9 ? '9+' : '$badgeCount',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            const Icon(Icons.chevron_right, size: 20, color: AppTheme.textHint),
          ],
        ),
      ),
    );
  }
}
