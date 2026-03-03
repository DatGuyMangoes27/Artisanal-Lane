import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app/theme.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/vendor_providers.dart';

class VendorSettingsScreen extends ConsumerStatefulWidget {
  const VendorSettingsScreen({super.key});

  @override
  ConsumerState<VendorSettingsScreen> createState() =>
      _VendorSettingsScreenState();
}

class _VendorSettingsScreenState extends ConsumerState<VendorSettingsScreen> {
  bool _orderNotifications = true;
  bool _newFollowerNotifications = true;

  bool _isOffline = false;
  DateTime? _backToWorkDate;
  bool _isSavingOffline = false;

  bool _initialized = false;

  void _initFromShop(shop) {
    if (_initialized || shop == null) return;
    _initialized = true;
    _isOffline = shop.isOffline;
    _backToWorkDate = shop.backToWorkDate;
  }

  Future<void> _pickBackToWorkDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _backToWorkDate ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppTheme.terracotta,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: AppTheme.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _backToWorkDate = picked);
    }
  }

  Future<void> _saveOfflineMode(String shopId) async {
    setState(() => _isSavingOffline = true);
    try {
      final service = ref.read(supabaseServiceProvider);
      await service.setShopOfflineMode(
        shopId,
        isOffline: _isOffline,
        backToWorkDate: _backToWorkDate,
      );
      ref.invalidate(vendorShopProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isOffline ? 'Shop set to Out of Office' : 'Shop is back online',
              style: GoogleFonts.poppins(fontSize: 13),
            ),
            backgroundColor:
                _isOffline ? AppTheme.terracotta : AppTheme.baobab,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Failed to update: $e', style: GoogleFonts.poppins(fontSize: 13)),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingOffline = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shopAsync = ref.watch(vendorShopProvider);

    return shopAsync.when(
      data: (shop) {
        _initFromShop(shop);
        return _buildContent(shop?.id);
      },
      loading: () => _buildContent(null, loading: true),
      error: (_, __) => _buildContent(null),
    );
  }

  Widget _buildContent(String? shopId, {bool loading = false}) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Settings',
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w600),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // ── Notifications ──────────────────────────────────
                _sectionTitle('Notifications'),
                const SizedBox(height: 12),
                _buildSettingsGroup([
                  _buildSwitchTile(
                    icon: Icons.receipt_long_outlined,
                    title: 'New Orders',
                    subtitle: 'Get notified when you receive a new order',
                    value: _orderNotifications,
                    onChanged: (v) =>
                        setState(() => _orderNotifications = v),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _buildSwitchTile(
                    icon: Icons.person_add_outlined,
                    title: 'New Followers',
                    subtitle:
                        'Get notified when someone follows your shop',
                    value: _newFollowerNotifications,
                    onChanged: (v) =>
                        setState(() => _newFollowerNotifications = v),
                  ),
                ]),

                const SizedBox(height: 32),

                // ── Shop Availability ─────────────────────────────
                _sectionTitle('Shop Availability'),
                const SizedBox(height: 12),
                _buildSettingsGroup([
                  _buildSwitchTile(
                    icon: Icons.do_not_disturb_on_outlined,
                    title: 'Out of Office / Offline Mode',
                    subtitle: _isOffline
                        ? 'Your shop is hidden from buyers'
                        : 'Your shop is visible to buyers',
                    value: _isOffline,
                    onChanged: shopId == null
                        ? null
                        : (v) async {
                            setState(() {
                              _isOffline = v;
                              if (!v) _backToWorkDate = null;
                            });
                            await _saveOfflineMode(shopId);
                          },
                  ),
                  if (_isOffline) ...[
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _buildDateTile(shopId),
                  ],
                ]),

                if (_isOffline)
                  Padding(
                    padding: const EdgeInsets.only(top: 10, left: 4, right: 4),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.terracotta.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.terracotta.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline,
                              size: 18, color: AppTheme.terracotta),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Buyers will see your shop as offline. If you set a back-to-work date, they can place a pre-order to be fulfilled when you return.',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 40),

                // ── Log Out ────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => _showLogoutDialog(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                            color: AppTheme.error.withValues(alpha: 0.2)),
                      ),
                      backgroundColor:
                          AppTheme.error.withValues(alpha: 0.05),
                    ),
                    child: Text(
                      'Log Out',
                      style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.error),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    'Artisan Lane v1.0.0',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppTheme.textHint),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildDateTile(String? shopId) {
    final fmt = DateFormat('d MMMM yyyy');
    return InkWell(
      onTap: shopId == null
          ? null
          : () async {
              await _pickBackToWorkDate();
              if (shopId != null) await _saveOfflineMode(shopId);
            },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        child: Row(
          children: [
            Icon(Icons.event_available_outlined,
                size: 22, color: AppTheme.textPrimary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Back to Work Date',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    _backToWorkDate != null
                        ? fmt.format(_backToWorkDate!)
                        : 'Tap to set a date',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: _backToWorkDate != null
                          ? AppTheme.baobab
                          : AppTheme.textHint,
                    ),
                  ),
                ],
              ),
            ),
            _isSavingOffline
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.terracotta,
                    ),
                  )
                : Icon(Icons.chevron_right,
                    size: 20, color: AppTheme.textHint),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.playfairDisplay(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppTheme.textPrimary,
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
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
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeTrackColor: AppTheme.terracotta,
        secondary: Icon(icon, size: 22, color: AppTheme.textPrimary),
        title: Text(
          title,
          style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textHint),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Log Out',
          style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary),
        ),
        content: Text(
          'Are you sure you want to log out?',
          style: GoogleFonts.poppins(
              fontSize: 14, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await Supabase.instance.client.auth.signOut();
              } catch (_) {}
              if (context.mounted) {
                GoRouter.of(context).go('/welcome');
              }
            },
            child: Text('Log Out',
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.error)),
          ),
        ],
      ),
    );
  }
}
