import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme.dart';
import '../../../widgets/african_patterns.dart';
import '../../auth/providers/auth_providers.dart' show currentProfileProvider;
import '../../../core/constants/feature_flags.dart';
import '../../vendor/providers/vendor_providers.dart'
    show vendorShopProvider, vendorPostsProvider, vendorProductsProvider;
import '../../vendor/screens/shop_insights_screen.dart'
    show shopInsightsProvider;
import '../providers/buyer_providers.dart';
import 'moderation_reports_screen.dart';

class BuyerProfileScreen extends ConsumerStatefulWidget {
  const BuyerProfileScreen({super.key});

  @override
  ConsumerState<BuyerProfileScreen> createState() => _BuyerProfileScreenState();
}

class _BuyerProfileScreenState extends ConsumerState<BuyerProfileScreen> {
  final _picker = ImagePicker();
  bool _isUploadingAvatar = false;
  // Buying/Selling switch (BATCH 5, "one app"): remembered in memory only
  // for this screen instance, per the "lightweight" scope of this feature.
  bool _sellingMode = false;

  String _imagePickerErrorMessage(ImageSource source) {
    return source == ImageSource.camera
        ? 'Camera access is blocked. Please allow camera access in your phone settings, or choose a photo from your gallery.'
        : 'Could not access your photos. Please allow photo access in your phone settings and try again.';
  }

  Future<void> _showAvatarSourceSheet() async {
    if (_isUploadingAvatar) return;

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
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
    final isVendor = ref.watch(currentProfileProvider).value?.isVendor == true;

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
          isVendor,
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
    bool isVendor,
  ) {
    final showSellingSwitch = creatorCommerceEnabled && isVendor;
    return SingleChildScrollView(
      child: SafeArea(
        top: creatorCommerceEnabled,
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context, profile, onEditAvatar, isUploadingAvatar),
            if (showSellingSwitch) ...[
              const SizedBox(height: 20),
              _buildModeSwitch(context),
            ],
            if (showSellingSwitch && _sellingMode) ...[
              const SizedBox(height: 24),
              _buildSellingShortcuts(context),
            ] else ...[
              const SizedBox(height: 32),
              _buildStatsRow(context, orderCount, favouriteCount, cartCount),
              const SizedBox(height: 32),
              _buildMenuSection(context, unreadMessages, disputeCount),
            ],
            const SizedBox(height: 40),
            const TripleDot(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Buying / Selling switch (item 9) ────────────────────────────
  Widget _buildModeSwitch(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.sand.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Expanded(
              child: _modeSwitchSegment('Buying', selected: !_sellingMode),
            ),
            Expanded(
              child: _modeSwitchSegment('Selling', selected: _sellingMode),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeSwitchSegment(String label, {required bool selected}) {
    return GestureDetector(
      onTap: () {
        if (selected) return;
        HapticFeedback.selectionClick();
        setState(() => _sellingMode = label == 'Selling');
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? AppTheme.terracotta : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildSellingShortcuts(BuildContext context) {
    final shortcuts =
        <({IconData icon, String title, String subtitle, String route})>[
          (
            icon: Icons.dashboard_outlined,
            title: 'Dashboard',
            subtitle: 'Your shop at a glance',
            route: '/vendor',
          ),
          (
            icon: Icons.inventory_2_outlined,
            title: 'Products',
            subtitle: 'Manage what you sell',
            route: '/vendor/products',
          ),
          (
            icon: Icons.receipt_long_outlined,
            title: 'Orders',
            subtitle: 'Track and fulfil orders',
            route: '/vendor/orders',
          ),
          (
            icon: Icons.dynamic_feed_outlined,
            title: 'My posts',
            subtitle: 'Craft stories and updates',
            route: '/vendor/profile/posts',
          ),
          (
            icon: Icons.account_balance_wallet_outlined,
            title: 'Earnings',
            subtitle: 'Payouts and balance',
            route: '/vendor/earnings',
          ),
          (
            icon: Icons.workspace_premium_outlined,
            title: 'Subscription',
            subtitle: 'Manage your plan',
            route: '/vendor/profile/subscription',
          ),
          (
            icon: Icons.storefront_outlined,
            title: 'Shop settings',
            subtitle: 'Name, bio and branding',
            route: '/vendor/profile/shop',
          ),
        ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          _buildCreatorMakerHeader(context),
          const SizedBox(height: 20),
          _buildCreatorTiles(context),
          const SizedBox(height: 24),
          for (final s in shortcuts) ...[
            _MenuItem(
              icon: s.icon,
              title: s.title,
              onTap: () => context.push(s.route),
            ),
            const SizedBox(height: 16),
          ],
          _MenuItem(
            icon: Icons.storefront,
            title: 'Open full artisan workspace',
            onTap: () => context.go('/vendor'),
          ),
        ],
      ),
    );
  }

  // ── Selling view: maker header (mirrors the "You" creator profile in
  // lib/concepts/creator_commerce/creator_commerce_mockup_app.dart) ──────
  Widget _buildCreatorMakerHeader(BuildContext context) {
    final shopAsync = ref.watch(vendorShopProvider);
    final postsCount = ref.watch(vendorPostsProvider).asData?.value.length;
    final productsCount = ref
        .watch(vendorProductsProvider)
        .asData
        ?.value
        .length;

    return shopAsync.when(
      data: (shop) {
        if (shop == null) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppTheme.bone,
                backgroundImage: shop.logoUrl != null
                    ? CachedNetworkImageProvider(shop.logoUrl!)
                    : null,
                child: shop.logoUrl == null
                    ? Text(
                        shop.name.isNotEmpty ? shop.name[0] : 'S',
                        style: GoogleFonts.playfairDisplay(
                          color: AppTheme.terracotta,
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            shop.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        if (shop.isVerified) ...[
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.verified,
                            size: 16,
                            color: AppTheme.baobab,
                          ),
                        ],
                      ],
                    ),
                    Text(
                      shop.handle,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textHint,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _creatorStat('${productsCount ?? 0}', 'products'),
                        const SizedBox(width: 16),
                        _creatorStat('${postsCount ?? 0}', 'posts'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(
        height: 76,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _creatorStat(String value, String label) {
    return RichText(
      text: TextSpan(
        style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
        children: [
          TextSpan(
            text: '$value ',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          TextSpan(text: label),
        ],
      ),
    );
  }

  Widget _buildCreatorTiles(BuildContext context) {
    final shopAsync = ref.watch(vendorShopProvider);
    final shop = shopAsync.asData?.value;
    final insightsAsync = shop == null
        ? null
        : ref.watch(shopInsightsProvider(30));
    final insights = insightsAsync?.asData?.value;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _CreatorToolTile(
                icon: Icons.add_circle_outline,
                title: 'Create post',
                subtitle: 'Photos and more',
                onTap: () => context.push('/create/post'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _CreatorToolTile(
                icon: Icons.auto_awesome_outlined,
                title: 'Add story',
                subtitle: 'Live for 24 hours',
                onTap: shop == null
                    ? null
                    : () => context.push('/create/story', extra: shop),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _CreatorToolTile(
                icon: Icons.inventory_2_outlined,
                title: 'Add product',
                subtitle: 'List a new piece',
                onTap: () => context.push('/create/product'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _CreatorToolTile(
                icon: Icons.auto_fix_high_outlined,
                title: 'AI studio',
                subtitle: 'Photo tools',
                onTap: () => context.push('/create/product'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _CreatorToolTile(
          icon: Icons.insights_outlined,
          title: 'Insights',
          subtitle: insights == null
              ? 'See how your shop is performing'
              : '${insights.postViews} post views · ${insights.followers} followers · last 30 days',
          onTap: () => context.push('/vendor/insights'),
          fullWidth: true,
        ),
      ],
    );
  }

  // ── Error body ────────────────────────────────────────────────
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
          _buildStatsRow(context, orderCount, favouriteCount, cartCount),
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
    if (creatorCommerceEnabled) {
      final name = (profile.displayName as String?)?.trim();
      return Container(
        margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.sand),
        ),
        child: Row(
          children: [
            InkWell(
              onTap: isUploadingAvatar ? null : onEditAvatar,
              borderRadius: BorderRadius.circular(32),
              child: CircleAvatar(
                radius: 30,
                backgroundColor: AppTheme.bone,
                backgroundImage: profile.avatarUrl != null
                    ? CachedNetworkImageProvider(profile.avatarUrl!)
                    : null,
                child: profile.avatarUrl == null
                    ? Text(
                        name?.isNotEmpty == true ? name!.characters.first : 'Y',
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name?.isNotEmpty == true ? name! : 'Your profile',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  // Email is private — it's shown in Settings, not here.
                  Text(
                    'Tap your photo to update it',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Semantics(
              label: 'Settings',
              button: true,
              child: IconButton(
                tooltip: 'Settings',
                onPressed: () => context.push('/profile/settings'),
                icon: const Icon(Icons.settings_outlined, size: 22),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              ),
            ),
          ],
        ),
      );
    }
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

  // ── Header when the profile fails to load ───────────────────────
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
                "Couldn't load your profile",
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Check your connection and try again.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppTheme.textHint,
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => ref.invalidate(profileProvider),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try again'),
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
  Widget _buildStatsRow(
    BuildContext context,
    int orderCount,
    int favouriteCount,
    int cartCount,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
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
            _statItemTappable(
              context,
              '$orderCount',
              'Orders',
              () => context.push('/profile/orders'),
            ),
            _verticalDivider(),
            _statItemTappable(
              context,
              '$favouriteCount',
              'Favourites',
              () => context.push('/favourites'),
            ),
            _verticalDivider(),
            _statItemTappable(
              context,
              '$cartCount',
              'In Cart',
              () => context.push('/cart'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItemTappable(
    BuildContext context,
    String value,
    String label,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: _statItem(value, label),
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
      key: ValueKey('profile-stat-$label'),
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
          if (creatorCommercePreviewEnabled) ...[
            _MenuItem(
              icon: Icons.auto_awesome_rounded,
              title: 'Creator Commerce Preview',
              onTap: () => context.push('/internal/creator-commerce'),
            ),
            const SizedBox(height: 16),
          ],
          if (creatorCommerceEnabled) ...[
            _MenuItem(
              icon: Icons.settings_outlined,
              title: 'Settings',
              onTap: () => context.push('/profile/settings'),
            ),
            const SizedBox(height: 16),
            _MenuItem(
              icon: Icons.favorite_border,
              title: 'Saved finds',
              onTap: () => context.push('/favourites'),
            ),
            const SizedBox(height: 16),
            _MenuItem(
              icon: Icons.bookmark_border_rounded,
              title: 'Saved posts',
              onTap: () => context.push('/profile/saved-posts'),
            ),
            const SizedBox(height: 16),
            if (ref.watch(currentProfileProvider).value?.isVendor == true) ...[
              _MenuItem(
                icon: Icons.storefront_outlined,
                title: 'Artisan workspace',
                onTap: () => context.go('/vendor'),
              ),
              const SizedBox(height: 16),
            ] else ...[
              _MenuItem(
                icon: Icons.storefront_outlined,
                title: 'Start selling',
                subtitle: 'Apply to open your own shop',
                onTap: () => context.push('/vendor/apply'),
              ),
              const SizedBox(height: 16),
            ],
          ],
          if (creatorSafetyEnabled &&
              ref.watch(currentProfileProvider).value?.isAdmin == true) ...[
            _MenuItem(
              icon: Icons.flag_outlined,
              title: 'Content reports',
              onTap: () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(
                  builder: (_) => const ModerationReportsScreen(),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
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
  final String? subtitle;
  final VoidCallback onTap;
  final int badgeCount;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ],
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

// ═══════════════════════════════════════════════════════════════════
// Creator profile tool tile (Create post / Add story / Insights, etc.)
// ═══════════════════════════════════════════════════════════════════
class _CreatorToolTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool fullWidth;

  const _CreatorToolTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.sand.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.terracotta.withValues(alpha: 0.1),
                child: Icon(icon, color: AppTheme.terracotta, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: fullWidth ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
