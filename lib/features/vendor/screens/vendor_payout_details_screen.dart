import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/vendor_providers.dart';
import '../utils/vendor_onboarding_flow.dart';
import '../utils/vendor_payout_setup.dart';

class VendorPayoutDetailsScreen extends ConsumerStatefulWidget {
  const VendorPayoutDetailsScreen({super.key});

  @override
  ConsumerState<VendorPayoutDetailsScreen> createState() =>
      _VendorPayoutDetailsScreenState();
}

class _VendorPayoutDetailsScreenState
    extends ConsumerState<VendorPayoutDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _accountHolderController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _branchCodeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _identityNumberController = TextEditingController();

  String? _selectedBankName;
  String? _accountType;
  bool _didHydrate = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _accountHolderController.dispose();
    _accountNumberController.dispose();
    _branchCodeController.dispose();
    _phoneController.dispose();
    _identityNumberController.dispose();
    super.dispose();
  }

  void _hydrateForm({
    required dynamic profile,
    required dynamic payoutProfile,
  }) {
    if (_didHydrate) return;

    _accountHolderController.text =
        payoutProfile?.accountHolderName as String? ??
        profile?.displayName as String? ??
        '';
    final savedBankName = payoutProfile?.bankName as String?;
    _selectedBankName = supportedTradeSafeBanks.contains(savedBankName)
        ? savedBankName
        : (savedBankName?.trim().isNotEmpty == true ? 'Other' : null);
    _accountNumberController.text =
        payoutProfile?.accountNumber as String? ?? '';
    _branchCodeController.text = payoutProfile?.branchCode as String? ?? '';
    final savedAccountType = payoutProfile?.accountType as String?;
    _accountType =
        supportedTradeSafeAccountTypes.any(
          (option) => option.value == savedAccountType,
        )
        ? savedAccountType
        : null;
    _phoneController.text =
        payoutProfile?.registeredPhone as String? ??
        profile?.phone as String? ??
        '';
    _identityNumberController.text =
        payoutProfile?.identityNumber as String? ?? '';

    _didHydrate = true;
  }

  Future<bool> _confirmSave() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Confirm payout details',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Please make sure every payout detail is correct. Artisan Lane '
                'will use these details for your payouts, kept secure with '
                'TradeSafe.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.terracotta,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                  child: Text(
                    'Confirm & save',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: BorderSide(
                      color: AppTheme.sand.withValues(alpha: 0.6),
                    ),
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  onPressed: () => Navigator.of(sheetContext).pop(false),
                  child: Text(
                    'Go back and check',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _save({
    required String userId,
    required String registeredEmail,
  }) async {
    if (!_formKey.currentState!.validate()) return;
    if (!await _confirmSave()) return;

    setState(() => _isSaving = true);
    try {
      final service = ref.read(supabaseServiceProvider);
      final phone = _phoneController.text.trim();

      await service.updateProfile(userId, {'phone': phone});
      await service.saveVendorPayoutProfile(
        vendorId: userId,
        accountHolderName: _accountHolderController.text.trim(),
        bankName: _selectedBankName!,
        accountNumber: _accountNumberController.text.trim(),
        branchCode: _branchCodeController.text.trim(),
        accountType: _accountType!,
        registeredPhone: phone,
        registeredEmail: registeredEmail,
        identityNumber: _identityNumberController.text.trim(),
      );
      ref.invalidate(currentProfileProvider);
      ref.invalidate(vendorPayoutProfileProvider);
      ref.invalidate(vendorPayoutProfileStreamProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payout details saved. You can now add products.'),
          backgroundColor: AppTheme.baobab,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save payout details: $error'),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    final profileAsync = ref.watch(currentProfileProvider);
    final payoutAsync = ref.watch(vendorPayoutProfileStreamProvider);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppTheme.textPrimary,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Payout Details',
          style: GoogleFonts.playfairDisplay(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: userId == null
          ? const Center(child: Text('Please sign in again.'))
          : profileAsync.when(
              data: (profile) => payoutAsync.when(
                data: (payoutProfile) {
                  _hydrateForm(profile: profile, payoutProfile: payoutProfile);
                  final status =
                      payoutProfile?.verificationStatus ?? 'not_started';

                  return SafeArea(
                    child: Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Get paid safely',
                                    style: GoogleFonts.playfairDisplay(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'These details go straight to TradeSafe, our secure '
                                    'payments partner, so your payouts land safely in your '
                                    'own account.',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: AppTheme.textSecondary,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  _buildStatusCard(
                                    status: status,
                                    maskedAccountNumber:
                                        payoutProfile?.maskedAccountNumber,
                                    statusNotes: payoutProfile?.statusNotes,
                                  ),
                                  const SizedBox(height: 20),
                                  _FormSectionCard(
                                    title: 'Banking details',
                                    icon: Icons.account_balance_outlined,
                                    children: [
                                      _buildTextField(
                                        controller: _accountHolderController,
                                        label: 'Account holder name',
                                        validator: _requiredField,
                                      ),
                                      _buildTextField(
                                        controller: _accountNumberController,
                                        label: 'Account number',
                                        keyboardType: TextInputType.number,
                                        validator: _requiredField,
                                      ),
                                      _buildTextField(
                                        controller: _branchCodeController,
                                        label: 'Branch code',
                                        keyboardType: TextInputType.number,
                                        validator: _requiredField,
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: DropdownButtonFormField<String>(
                                          initialValue: _selectedBankName,
                                          items: supportedTradeSafeBanks
                                              .map(
                                                (value) => DropdownMenuItem(
                                                  value: value,
                                                  child: Text(value),
                                                ),
                                              )
                                              .toList(),
                                          onChanged: (value) {
                                            setState(
                                              () => _selectedBankName = value,
                                            );
                                          },
                                          validator: (value) =>
                                              value == null || value.isEmpty
                                              ? 'Select your bank.'
                                              : null,
                                          decoration: _inputDecoration(
                                            label: 'Bank',
                                          ),
                                        ),
                                      ),
                                      DropdownButtonFormField<String>(
                                        initialValue: _accountType,
                                        items: supportedTradeSafeAccountTypes
                                            .map(
                                              (option) => DropdownMenuItem(
                                                value: option.value,
                                                child: Text(option.label),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (value) {
                                          if (value == null) return;
                                          setState(() => _accountType = value);
                                        },
                                        validator: (value) =>
                                            value == null || value.isEmpty
                                            ? 'Select the account type.'
                                            : null,
                                        decoration: _inputDecoration(
                                          label: 'Account type',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _FormSectionCard(
                                    title: 'Identity details',
                                    icon: Icons.badge_outlined,
                                    children: [
                                      _buildTextField(
                                        controller: _identityNumberController,
                                        label: 'South African ID number',
                                        keyboardType: TextInputType.number,
                                        validator: _requiredField,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _FormSectionCard(
                                    title: 'Contact details',
                                    icon: Icons.call_outlined,
                                    children: [
                                      _buildReadOnlyField(
                                        label: 'Registered email address',
                                        value:
                                            profile?.email ??
                                            'No email available',
                                      ),
                                      _buildTextField(
                                        controller: _phoneController,
                                        label: 'Phone number for payouts',
                                        keyboardType: TextInputType.phone,
                                        validator: _requiredField,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: AppTheme.bone.withValues(
                                        alpha: 0.6,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: AppTheme.sand.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.lock_outline_rounded,
                                          size: 18,
                                          color: AppTheme.terracotta,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'Your details are encrypted and only used to '
                                            'set up payouts. Double-check them carefully — '
                                            'incorrect details can delay a payout.',
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
                                  const SizedBox(height: 12),
                                ],
                              ),
                            ),
                          ),
                        ),
                        _StickySaveBar(
                          isSaving: _isSaving,
                          enabled: profile?.email != null,
                          onSave: () => _save(
                            userId: userId,
                            registeredEmail: profile!.email!,
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.terracotta,
                    strokeWidth: 2,
                  ),
                ),
                error: (error, _) => Center(child: Text('Error: $error')),
              ),
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: AppTheme.terracotta,
                  strokeWidth: 2,
                ),
              ),
              error: (error, _) => Center(child: Text('Error: $error')),
            ),
    );
  }

  Widget _buildStatusCard({
    required String status,
    String? maskedAccountNumber,
    String? statusNotes,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.shield_outlined,
                color: AppTheme.terracotta,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Status: ${status.replaceAll('_', ' ')}',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            vendorPayoutBannerMessage(status),
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
          if (maskedAccountNumber != null &&
              maskedAccountNumber.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Current account: $maskedAccountNumber',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppTheme.textHint,
              ),
            ),
          ],
          if (statusNotes != null && statusNotes.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              statusNotes.trim(),
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppTheme.textHint,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        decoration: _inputDecoration(label: label),
      ),
    );
  }

  Widget _buildReadOnlyField({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: value,
        enabled: false,
        decoration: _inputDecoration(label: label),
      ),
    );
  }

  InputDecoration _inputDecoration({String? label}) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppTheme.sand.withValues(alpha: 0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppTheme.sand.withValues(alpha: 0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppTheme.terracotta),
      ),
    );
  }

  String? _requiredField(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required.';
    }
    return null;
  }
}

class _FormSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _FormSectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.terracotta),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _StickySaveBar extends StatelessWidget {
  final bool isSaving;
  final bool enabled;
  final VoidCallback onSave;

  const _StickySaveBar({
    required this.isSaving,
    required this.enabled,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: AppTheme.scaffoldBg,
        border: Border(
          top: BorderSide(color: AppTheme.sand.withValues(alpha: 0.3)),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: FilledButton.icon(
          onPressed: isSaving || !enabled ? null : onSave,
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.terracotta,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppTheme.terracotta.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
          ),
          icon: isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.account_balance_rounded, size: 18),
          label: Text(
            isSaving ? 'Saving details...' : 'Save payout details',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
