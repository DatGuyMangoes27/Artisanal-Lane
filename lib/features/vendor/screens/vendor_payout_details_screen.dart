import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../widgets/gradient_button.dart';
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
    _accountNumberController.text = payoutProfile?.accountNumber as String? ?? '';
    _branchCodeController.text = payoutProfile?.branchCode as String? ?? '';
    final savedAccountType = payoutProfile?.accountType as String?;
    _accountType = supportedTradeSafeAccountTypes.any(
      (option) => option.value == savedAccountType,
    )
        ? savedAccountType
        : null;
    _phoneController.text =
        payoutProfile?.registeredPhone as String? ?? profile?.phone as String? ?? '';

    _didHydrate = true;
  }

  Future<bool> _confirmSave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Confirm payout details',
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Please make sure every payout detail is correct. Artisan Lane will use these details for your payouts.',
          style: GoogleFonts.poppins(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirm & save'),
          ),
        ],
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
        title: Text(
          'Payout Details',
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w600),
        ),
      ),
      body: userId == null
          ? const Center(child: Text('Please sign in again.'))
          : profileAsync.when(
              data: (profile) => payoutAsync.when(
                data: (payoutProfile) {
                  _hydrateForm(profile: profile, payoutProfile: payoutProfile);
                  final status = payoutProfile?.verificationStatus ?? 'not_started';

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Payout details',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Complete the bank details Artisan Lane should use for your TradeSafe-linked payouts. We use your registered email automatically, and your phone number can be updated here if needed.',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _buildStatusCard(
                            status: status,
                            maskedAccountNumber: payoutProfile?.maskedAccountNumber,
                            statusNotes: payoutProfile?.statusNotes,
                          ),
                          const SizedBox(height: 24),
                          _buildSectionTitle('Banking details'),
                          const SizedBox(height: 12),
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
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
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
                              setState(() => _selectedBankName = value);
                            },
                            validator: (value) => value == null || value.isEmpty
                                ? 'Select your bank.'
                                : null,
                            decoration: _inputDecoration(label: 'Bank'),
                          ),
                          const SizedBox(height: 12),
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
                            validator: (value) => value == null || value.isEmpty
                                ? 'Select the account type.'
                                : null,
                            decoration: _inputDecoration(label: 'Account type'),
                          ),
                          const SizedBox(height: 24),
                          _buildSectionTitle('Contact details'),
                          const SizedBox(height: 12),
                          _buildReadOnlyField(
                            label: 'Registered email address',
                            value: profile?.email ?? 'No email available',
                          ),
                          _buildTextField(
                            controller: _phoneController,
                            label: 'Phone number for payouts',
                            keyboardType: TextInputType.phone,
                            validator: _requiredField,
                          ),
                          const SizedBox(height: 24),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppTheme.sand.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              'Confirm these payout details carefully. Incorrect details can delay or block your payouts.',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                                height: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          GradientButton(
                            label: _isSaving
                                ? 'Saving details...'
                                : 'Save payout details',
                            icon: Icons.account_balance_rounded,
                            isLoading: _isSaving,
                            onPressed: _isSaving || profile?.email == null
                                ? null
                                : () => _save(
                                      userId: userId,
                                      registeredEmail: profile!.email!,
                                    ),
                          ),
                        ],
                      ),
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
          if (maskedAccountNumber != null && maskedAccountNumber.isNotEmpty) ...[
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

  Widget _buildSectionTitle(String value) {
    return Text(
      value,
      style: GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppTheme.textPrimary,
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

  Widget _buildReadOnlyField({
    required String label,
    required String value,
  }) {
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
        borderSide: BorderSide(
          color: AppTheme.sand.withValues(alpha: 0.3),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: AppTheme.sand.withValues(alpha: 0.3),
        ),
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
