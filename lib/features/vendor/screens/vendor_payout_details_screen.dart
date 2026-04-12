import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../widgets/gradient_button.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/vendor_providers.dart';
import '../utils/vendor_onboarding_flow.dart';

class VendorPayoutDetailsScreen extends ConsumerStatefulWidget {
  const VendorPayoutDetailsScreen({super.key});

  @override
  ConsumerState<VendorPayoutDetailsScreen> createState() =>
      _VendorPayoutDetailsScreenState();
}

class _VendorPayoutDetailsScreenState
    extends ConsumerState<VendorPayoutDetailsScreen> {
  static const _accountTypes = <String>[
    'cheque',
    'savings',
    'business',
  ];

  final _formKey = GlobalKey<FormState>();
  final _accountHolderController = TextEditingController();
  final _bankNameController = TextEditingController(text: 'Standard Bank');
  final _accountNumberController = TextEditingController();
  final _branchCodeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _identityNumberController = TextEditingController();
  final _businessRegistrationController = TextEditingController();

  String _accountType = _accountTypes.first;
  bool _didHydrate = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _accountHolderController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _branchCodeController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _identityNumberController.dispose();
    _businessRegistrationController.dispose();
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
    _bankNameController.text = payoutProfile?.bankName as String? ?? 'Standard Bank';
    _accountNumberController.text = payoutProfile?.accountNumber as String? ?? '';
    _branchCodeController.text = payoutProfile?.branchCode as String? ?? '';
    _accountType = payoutProfile?.accountType as String? ?? _accountTypes.first;
    _phoneController.text =
        payoutProfile?.registeredPhone as String? ?? profile?.phone as String? ?? '';
    _emailController.text =
        payoutProfile?.registeredEmail as String? ?? profile?.email as String? ?? '';
    _identityNumberController.text =
        payoutProfile?.identityNumber as String? ?? '';
    _businessRegistrationController.text =
        payoutProfile?.businessRegistrationNumber as String? ?? '';

    _didHydrate = true;
  }

  Future<void> _save(String userId) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final service = ref.read(supabaseServiceProvider);
      await service.saveVendorPayoutProfile(
        vendorId: userId,
        accountHolderName: _accountHolderController.text.trim(),
        bankName: _bankNameController.text.trim(),
        accountNumber: _accountNumberController.text.trim(),
        branchCode: _branchCodeController.text.trim(),
        accountType: _accountType,
        registeredPhone: _phoneController.text.trim(),
        registeredEmail: _emailController.text.trim(),
        identityNumber: _identityNumberController.text.trim().isEmpty
            ? null
            : _identityNumberController.text.trim(),
        businessRegistrationNumber:
            _businessRegistrationController.text.trim().isEmpty
            ? null
            : _businessRegistrationController.text.trim(),
      );
      ref.invalidate(vendorPayoutProfileProvider);
      ref.invalidate(vendorPayoutProfileStreamProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payout details submitted for TradeSafe review.'),
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
                            'TradeSafe payout setup',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Enter the bank details Artisan Lane should use for your TradeSafe-linked payouts. You can manage the details here without leaving the app.',
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
                            controller: _bankNameController,
                            label: 'Bank name',
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
                          Text(
                            'Account type',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _accountType,
                            items: _accountTypes
                                .map(
                                  (value) => DropdownMenuItem(
                                    value: value,
                                    child: Text(value),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _accountType = value);
                            },
                            decoration: _inputDecoration(),
                          ),
                          const SizedBox(height: 24),
                          _buildSectionTitle('Verification details'),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _phoneController,
                            label: 'Registered phone number',
                            keyboardType: TextInputType.phone,
                            validator: _requiredField,
                          ),
                          _buildTextField(
                            controller: _emailController,
                            label: 'Registered email address',
                            keyboardType: TextInputType.emailAddress,
                            validator: _requiredEmail,
                          ),
                          _buildTextField(
                            controller: _identityNumberController,
                            label: 'South African ID number',
                          ),
                          _buildTextField(
                            controller: _businessRegistrationController,
                            label: 'Business registration number',
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
                              'Payout details required before payouts can be completed. Once submitted, our team reviews them and updates your TradeSafe payout readiness in the app.',
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
                            onPressed: _isSaving ? null : () => _save(userId),
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

  String? _requiredEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required.';
    }
    if (!value.contains('@')) {
      return 'Enter a valid email address.';
    }
    return null;
  }
}
