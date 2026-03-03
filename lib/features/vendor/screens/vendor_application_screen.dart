import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app/theme.dart';
import '../../../widgets/gradient_button.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/vendor_providers.dart';

class VendorApplicationScreen extends ConsumerStatefulWidget {
  const VendorApplicationScreen({super.key});

  @override
  ConsumerState<VendorApplicationScreen> createState() =>
      _VendorApplicationScreenState();
}

class _VendorApplicationScreenState
    extends ConsumerState<VendorApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _inviteCodeController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _motivationController = TextEditingController();
  final _portfolioController = TextEditingController();
  final _locationController = TextEditingController();
  final _deliveryController = TextEditingController();
  final _turnaroundController = TextEditingController();
  bool _acceptedTcs = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _inviteCodeController.dispose();
    _businessNameController.dispose();
    _motivationController.dispose();
    _portfolioController.dispose();
    _locationController.dispose();
    _deliveryController.dispose();
    _turnaroundController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedTcs) {
      setState(() => _errorMessage = 'Please accept the Terms & Conditions to continue.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final service = ref.read(supabaseServiceProvider);
      await service.submitVendorApplication(
        userId: userId,
        businessName: _businessNameController.text.trim(),
        inviteCode: _inviteCodeController.text.trim(),
        motivation: _motivationController.text.trim().isNotEmpty
            ? _motivationController.text.trim()
            : null,
        portfolioUrl: _portfolioController.text.trim().isNotEmpty
            ? _portfolioController.text.trim()
            : null,
        location: _locationController.text.trim().isNotEmpty
            ? _locationController.text.trim()
            : null,
        deliveryInfo: _deliveryController.text.trim().isNotEmpty
            ? _deliveryController.text.trim()
            : null,
        turnaroundTime: _turnaroundController.text.trim().isNotEmpty
            ? _turnaroundController.text.trim()
            : null,
      );
      ref.invalidate(vendorApplicationProvider);

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppTheme.baobab, size: 28),
                const SizedBox(width: 10),
                Text('Submitted!', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w600)),
              ],
            ),
            content: Text(
              'Your vendor application has been submitted. We\'ll review it and get back to you soon.',
              style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.pop();
                },
                child: Text('OK', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppTheme.terracotta)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appAsync = ref.watch(vendorApplicationProvider);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.pop(),
        ),
        title: Text('Become a Vendor', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w600)),
      ),
      body: appAsync.when(
        data: (existing) {
          if (existing != null) return _buildExistingApplication(existing);
          return _buildApplicationForm();
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.terracotta, strokeWidth: 2)),
        error: (_, __) => _buildApplicationForm(),
      ),
    );
  }

  bool _isActivating = false;

  Future<void> _activateVendorAccount(dynamic application) async {
    setState(() => _isActivating = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final service = ref.read(supabaseServiceProvider);
      await service.activateVendorAccount(
        userId: userId,
        businessName: application.businessName,
        location: application.location,
      );

      if (mounted) {
        GoRouter.of(context).go('/vendor');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isActivating = false);
    }
  }

  Widget _buildExistingApplication(dynamic application) {
    final isPending = application.isPending;
    final isApproved = application.isApproved;
    final isRejected = !isPending && !isApproved;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: isPending
                  ? AppTheme.ochre.withValues(alpha: 0.12)
                  : isApproved
                      ? AppTheme.baobab.withValues(alpha: 0.12)
                      : AppTheme.error.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPending
                  ? Icons.hourglass_top_rounded
                  : isApproved
                      ? Icons.celebration_rounded
                      : Icons.cancel_rounded,
              size: 36,
              color: isPending ? AppTheme.ochre : isApproved ? AppTheme.baobab : AppTheme.error,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isPending
                ? 'Application Under Review'
                : isApproved
                    ? 'You\'re Approved!'
                    : 'Application Not Approved',
            style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 12),
          Text(
            isPending
                ? 'Our team is reviewing your application. This usually takes 1-3 business days. We\'ll notify you once a decision has been made.'
                : isApproved
                    ? 'Congratulations! Your application to sell on Artisan Lane has been approved. Activate your vendor account below to start setting up your shop.'
                    : 'Unfortunately your application was not approved at this time. You may contact us for more details.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 24),

          // Application details card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow('Business', application.businessName),
                if (application.location != null) _infoRow('Location', application.location!),
                _infoRow('Status', isPending ? 'PENDING REVIEW' : isApproved ? 'APPROVED' : 'REJECTED'),
              ],
            ),
          ),

          // Activate button for approved applications
          if (isApproved) ...[
            const SizedBox(height: 32),
            GradientButton(
              label: _isActivating ? 'Setting up your shop...' : 'Activate Vendor Account',
              icon: Icons.storefront_rounded,
              isLoading: _isActivating,
              onPressed: _isActivating ? null : () => _activateVendorAccount(application),
            ),
            const SizedBox(height: 12),
            Text(
              'This will create your shop and switch you to the vendor dashboard.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textHint),
            ),
          ],

          // Pending progress steps
          if (isPending) ...[
            const SizedBox(height: 32),
            _buildProgressSteps(),
          ],

          // Rejected - option to contact
          if (isRejected) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.terracotta,
                  side: const BorderSide(color: AppTheme.terracotta, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text('Go Back', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressSteps() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.ochre.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.ochre.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What happens next?',
            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 16),
          _progressStep(1, 'Application submitted', true),
          _progressStep(2, 'Team review (1-3 business days)', false),
          _progressStep(3, 'Approval notification', false),
          _progressStep(4, 'Activate your vendor account', false),
        ],
      ),
    );
  }

  Widget _progressStep(int step, String label, bool completed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: completed ? AppTheme.baobab : AppTheme.sand.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: completed
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : Text(
                      '$step',
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textHint),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: completed ? AppTheme.textPrimary : AppTheme.textSecondary,
                fontWeight: completed ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textHint)),
          Text(value, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildApplicationForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.ochre.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.ochre.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.star_rounded, color: AppTheme.ochre, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Invite-Only Marketplace', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                      const SizedBox(height: 4),
                      Text(
                        'You need a valid invite code to apply as a vendor. Contact us or ask an existing vendor for a code.',
                        style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (_errorMessage != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
              ),
              child: Text(_errorMessage!, style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.error)),
            ),
            const SizedBox(height: 20),
          ],

          _buildLabel('Invite Code'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _inviteCodeController,
            textCapitalization: TextCapitalization.characters,
            validator: (v) => v == null || v.trim().isEmpty ? 'Invite code is required' : null,
            decoration: const InputDecoration(
              hintText: 'Enter your invite code',
              prefixIcon: Icon(Icons.vpn_key_outlined, color: AppTheme.textHint),
            ),
          ),
          const SizedBox(height: 20),

          _buildLabel('Business Name'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _businessNameController,
            textCapitalization: TextCapitalization.words,
            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            decoration: const InputDecoration(hintText: 'Your craft business name'),
          ),
          const SizedBox(height: 20),

          _buildLabel('Motivation'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _motivationController,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Why do you want to sell on Artisan Lane?'),
          ),
          const SizedBox(height: 20),

          _buildLabel('Portfolio URL (optional)'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _portfolioController,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(hintText: 'Link to your work'),
          ),
          const SizedBox(height: 20),

          _buildLabel('Location'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _locationController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'e.g. Cape Town, South Africa',
              prefixIcon: Icon(Icons.location_on_outlined, color: AppTheme.textHint),
            ),
          ),
          const SizedBox(height: 20),

          _buildLabel('How will you fulfil orders?'),
          const SizedBox(height: 4),
          Text(
            'Tell us about your delivery method — courier, self-delivery, click & collect, etc.',
            style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textHint, height: 1.4),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _deliveryController,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            validator: (v) => v == null || v.trim().isEmpty ? 'Please describe your fulfilment method' : null,
            decoration: const InputDecoration(
              hintText: 'e.g. I use Courier Guy for deliveries, or can do local drop-offs in Cape Town',
            ),
          ),
          const SizedBox(height: 20),

          _buildLabel('What is your typical turnaround time?'),
          const SizedBox(height: 4),
          Text(
            'How long from order placed to ready-to-ship? Include any made-to-order time.',
            style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textHint, height: 1.4),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _turnaroundController,
            textCapitalization: TextCapitalization.sentences,
            validator: (v) => v == null || v.trim().isEmpty ? 'Please provide your turnaround time' : null,
            decoration: const InputDecoration(
              hintText: 'e.g. 3–5 business days for ready stock, 10–14 days for custom orders',
              prefixIcon: Icon(Icons.schedule_outlined, color: AppTheme.textHint),
            ),
          ),
          const SizedBox(height: 28),

          // Terms & Conditions
          GestureDetector(
            onTap: () => setState(() => _acceptedTcs = !_acceptedTcs),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _acceptedTcs
                    ? AppTheme.baobab.withValues(alpha: 0.06)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _acceptedTcs
                      ? AppTheme.baobab.withValues(alpha: 0.4)
                      : AppTheme.sand.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: Checkbox(
                      value: _acceptedTcs,
                      onChanged: (v) => setState(() => _acceptedTcs = v ?? false),
                      activeColor: AppTheme.baobab,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary, height: 1.5),
                        children: const [
                          TextSpan(text: 'I have read and agree to the Artisan Lane '),
                          TextSpan(
                            text: 'Vendor Terms & Conditions',
                            style: TextStyle(color: AppTheme.terracotta, fontWeight: FontWeight.w600),
                          ),
                          TextSpan(text: ', including commission rates, listing policies, and fulfilment responsibilities.'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          GradientButton(
            label: 'Submit Application',
            isLoading: _isLoading,
            onPressed: _isLoading ? null : _submit,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
    );
  }
}
