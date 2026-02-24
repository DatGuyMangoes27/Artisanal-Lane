import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app/theme.dart';
import '../../../widgets/african_patterns.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _orderNotifications = true;
  bool _promotionNotifications = false;
  bool _darkMode = false;
  String _selectedLanguage = 'English';
  String _selectedCurrency = 'ZAR';

  void _showLanguagePicker() {
    final languages = ['English', 'Afrikaans', 'isiZulu', 'isiXhosa', 'Sesotho', 'Setswana'];
    _showPickerSheet('Language', languages, _selectedLanguage, (val) {
      setState(() => _selectedLanguage = val);
    });
  }

  void _showCurrencyPicker() {
    final currencies = ['ZAR', 'USD', 'EUR', 'GBP'];
    _showPickerSheet('Currency', currencies, _selectedCurrency, (val) {
      setState(() => _selectedCurrency = val);
    });
  }

  void _showPickerSheet(String title, List<String> options, String current, ValueChanged<String> onSelect) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.scaffoldBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.sand, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Text(title, style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const SizedBox(height: 20),
              ...options.map((opt) {
                final isSelected = opt == current;
                return ListTile(
                  onTap: () {
                    onSelect(opt);
                    Navigator.pop(ctx);
                  },
                  leading: Icon(
                    isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    color: isSelected ? AppTheme.terracotta : AppTheme.textHint,
                    size: 22,
                  ),
                  title: Text(
                    opt,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? AppTheme.terracotta : AppTheme.textPrimary,
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Custom Header ──────────────────────────────────────
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.maybePop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppTheme.sand.withValues(alpha: 0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Settings',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // ── Notifications Section ──────────────────────────────
              const _SectionTitle(title: 'Notifications'),
              const SizedBox(height: 16),
              _SettingsGroup(
                children: [
                  _SettingsTile(
                    icon: Icons.local_shipping_outlined,
                    title: 'Order Updates',
                    trailing: Switch(
                      value: _orderNotifications,
                      onChanged: (v) => setState(() => _orderNotifications = v),
                      activeTrackColor: AppTheme.terracotta,
                    ),
                  ),
                  _Divider(),
                  _SettingsTile(
                    icon: Icons.campaign_outlined,
                    title: 'Promotions',
                    trailing: Switch(
                      value: _promotionNotifications,
                      onChanged: (v) =>
                          setState(() => _promotionNotifications = v),
                      activeTrackColor: AppTheme.terracotta,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // ── Appearance Section ─────────────────────────────────
              const _SectionTitle(title: 'Appearance'),
              const SizedBox(height: 16),
              _SettingsGroup(
                children: [
                  _SettingsTile(
                    icon: Icons.dark_mode_outlined,
                    title: 'Dark Mode',
                    trailing: Switch(
                      value: _darkMode,
                      onChanged: (v) => setState(() => _darkMode = v),
                      activeTrackColor: AppTheme.terracotta,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // ── General Section ────────────────────────────────────
              const _SectionTitle(title: 'General'),
              const SizedBox(height: 16),
              _SettingsGroup(
                children: [
                  _SettingsTile(
                    icon: Icons.language_outlined,
                    title: 'Language',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _selectedLanguage,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: AppTheme.textHint,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: AppTheme.textHint,
                        ),
                      ],
                    ),
                    onTap: _showLanguagePicker,
                  ),
                  _Divider(),
                  _SettingsTile(
                    icon: Icons.attach_money,
                    title: 'Currency',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _selectedCurrency,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: AppTheme.textHint,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: AppTheme.textHint,
                        ),
                      ],
                    ),
                    onTap: _showCurrencyPicker,
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // ── Legal Section ──────────────────────────────────────
              const _SectionTitle(title: 'Legal'),
              const SizedBox(height: 16),
              _SettingsGroup(
                children: [
                  _SettingsTile(
                    icon: Icons.description_outlined,
                    title: 'Terms of Service',
                    trailing: const Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: AppTheme.textHint,
                    ),
                    onTap: () => context.push('/profile/about/terms'),
                  ),
                  _Divider(),
                  _SettingsTile(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy Policy',
                    trailing: const Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: AppTheme.textHint,
                    ),
                    onTap: () => context.push('/profile/about/privacy'),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // ── Log Out Button ─────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        title: Text(
                          'Log Out',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        content: Text(
                          'Are you sure you want to log out?',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textSecondary,
                              ),
                            ),
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
                            child: Text(
                              'Log Out',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                          color: AppTheme.error.withValues(alpha: 0.2)),
                    ),
                    backgroundColor: AppTheme.error.withValues(alpha: 0.05),
                  ),
                  child: Text(
                    'Log Out',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.error,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // ── App Version ────────────────────────────────────────
              const Center(child: TripleDot()),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Artisan Lane v1.0.0',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.textHint,
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Private Helper Widgets
// ═══════════════════════════════════════════════════════════════════

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.playfairDisplay(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: AppTheme.textPrimary,
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;

  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
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
      child: Column(
        children: children,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppTheme.textPrimary),
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
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: AppTheme.sand.withValues(alpha: 0.2),
      indent: 58,
      endIndent: 20,
    );
  }
}
