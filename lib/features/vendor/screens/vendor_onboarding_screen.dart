import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app/theme.dart';
import '../../../widgets/gradient_button.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/vendor_providers.dart';

class VendorOnboardingScreen extends ConsumerStatefulWidget {
  const VendorOnboardingScreen({super.key});

  @override
  ConsumerState<VendorOnboardingScreen> createState() =>
      _VendorOnboardingScreenState();
}

class _VendorOnboardingScreenState
    extends ConsumerState<VendorOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _motivationController = TextEditingController();
  final _locationController = TextEditingController();
  final _portfolioController = TextEditingController();
  final _deliveryController = TextEditingController();
  final _turnaroundController = TextEditingController();
  bool _acceptedTcs = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _businessNameController.dispose();
    _motivationController.dispose();
    _locationController.dispose();
    _portfolioController.dispose();
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

      await service.submitVendorOnboarding(
        userId: userId,
        businessName: _businessNameController.text.trim(),
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
    } catch (e) {
      setState(
          () => _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _activateAccount(dynamic application) async {
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final service = ref.read(supabaseServiceProvider);
      await service.activateVendorAccount(
        userId: userId,
        businessName: application.businessName,
        location: application.location,
      );
      ref.invalidate(vendorShopProvider);
      if (mounted) GoRouter.of(context).go('/vendor');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
    if (mounted) GoRouter.of(context).go('/welcome');
  }

  @override
  Widget build(BuildContext context) {
    final appAsync = ref.watch(vendorApplicationProvider);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: SafeArea(
        child: appAsync.when(
          data: (application) {
            if (application == null) return _buildApplicationForm();
            if (application.isApproved) return _buildApproved(application);
            if (application.isPending) return _buildPending(application);
            return _buildRejected(application);
          },
          loading: () => const Center(
            child: CircularProgressIndicator(
                color: AppTheme.terracotta, strokeWidth: 2),
          ),
          error: (_, __) => _buildApplicationForm(),
        ),
      ),
    );
  }

  // ── Application form (step 1) ──────────────────────────────────
  Widget _buildApplicationForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 80,
                  height: 80,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'Welcome, Maker!',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Tell us about your craft so we can set up\nyour shop on Artisan Lane',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 14, color: AppTheme.textSecondary, height: 1.5),
              ),
            ),
            const SizedBox(height: 32),

            // Progress indicator
            _buildStepIndicator(1),
            const SizedBox(height: 32),

            if (_errorMessage != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                ),
                child: Text(_errorMessage!,
                    style:
                        GoogleFonts.poppins(fontSize: 13, color: AppTheme.error)),
              ),
              const SizedBox(height: 20),
            ],

            _buildLabel('Business / Brand Name'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _businessNameController,
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
              decoration: const InputDecoration(
                hintText: 'e.g. Ndlovu Ceramics',
                prefixIcon:
                    Icon(Icons.store_outlined, color: AppTheme.textHint),
              ),
            ),
            const SizedBox(height: 20),

            _buildLabel('What do you make?'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _motivationController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText:
                    'Tell us about your craft, what inspires you, and what you plan to sell...',
              ),
            ),
            const SizedBox(height: 20),

            _buildLabel('Where are you based?'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _locationController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'e.g. Cape Town, South Africa',
                prefixIcon:
                    Icon(Icons.location_on_outlined, color: AppTheme.textHint),
              ),
            ),
            const SizedBox(height: 20),

            _buildLabel('Portfolio / Social Link (optional)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _portfolioController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                hintText: 'Instagram, website, or portfolio link',
                prefixIcon: Icon(Icons.link, color: AppTheme.textHint),
              ),
            ),
            const SizedBox(height: 20),

            _buildLabel('How will you fulfil orders?'),
            const SizedBox(height: 4),
            Text(
              'Courier, self-delivery, click & collect — tell us how you\'ll get orders to buyers.',
              style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textHint, height: 1.4),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _deliveryController,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) => v == null || v.trim().isEmpty ? 'Please describe your fulfilment method' : null,
              decoration: const InputDecoration(
                hintText: 'e.g. Courier Guy nationwide, or local drop-offs in Cape Town',
              ),
            ),
            const SizedBox(height: 20),

            _buildLabel('Typical turnaround time?'),
            const SizedBox(height: 4),
            Text(
              'How long from order placed to ready-to-ship? Include made-to-order time if applicable.',
              style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textHint, height: 1.4),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _turnaroundController,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) => v == null || v.trim().isEmpty ? 'Please provide your turnaround time' : null,
              decoration: const InputDecoration(
                hintText: 'e.g. 3–5 business days, or 10–14 days for custom orders',
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
              label: 'Submit for Review',
              isLoading: _isLoading,
              onPressed: _isLoading ? null : _submit,
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: _logout,
                child: Text(
                  'Sign out',
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: AppTheme.textHint),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Pending review (step 2) ────────────────────────────────────
  Widget _buildPending(dynamic application) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/images/logo.png',
                width: 80,
                height: 80,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 32),
          _buildStepIndicator(2),
          const SizedBox(height: 32),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.ochre.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.hourglass_top_rounded,
                size: 36, color: AppTheme.ochre),
          ),
          const SizedBox(height: 24),
          Text(
            'Application Under Review',
            style: GoogleFonts.playfairDisplay(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Thanks for applying, ${application.businessName}! Our team is reviewing your application. This usually takes 1-3 business days.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                fontSize: 14, color: AppTheme.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 32),

          // Application summary
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your Application',
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 12),
                _detailRow('Business', application.businessName),
                if (application.location != null)
                  _detailRow('Location', application.location!),
                _detailRow('Status', 'Pending Review'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // What happens next
          Container(
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
                Text('What happens next?',
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 16),
                _stepRow(1, 'Application submitted', true),
                _stepRow(2, 'Team review (1-3 business days)', false),
                _stepRow(3, 'Approval notification', false),
                _stepRow(4, 'Set up your shop & start selling', false),
              ],
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => ref.invalidate(vendorApplicationProvider),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text('Check Status',
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.terracotta,
                side:
                    const BorderSide(color: AppTheme.terracotta, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _logout,
              child: Text('Sign out',
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: AppTheme.textHint)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Approved (step 3) ──────────────────────────────────────────
  Widget _buildApproved(dynamic application) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/images/logo.png',
                width: 80,
                height: 80,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 32),
          _buildStepIndicator(3),
          const SizedBox(height: 32),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.baobab.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.celebration_rounded,
                size: 36, color: AppTheme.baobab),
          ),
          const SizedBox(height: 24),
          Text(
            'You\'re Approved!',
            style: GoogleFonts.playfairDisplay(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Congratulations! Your application to sell on Artisan Lane has been approved. Activate your shop below to start your journey.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                fontSize: 14, color: AppTheme.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 36),
          GradientButton(
            label: _isLoading ? 'Setting up your shop...' : 'Open My Shop',
            icon: Icons.storefront_rounded,
            isLoading: _isLoading,
            onPressed: _isLoading ? null : () => _activateAccount(application),
          ),
          const SizedBox(height: 12),
          Text(
            'This will create your shop and take you to\nyour vendor dashboard.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textHint),
          ),
        ],
      ),
    );
  }

  // ── Rejected ───────────────────────────────────────────────────
  Widget _buildRejected(dynamic application) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const SizedBox(height: 60),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.error.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.cancel_rounded,
                size: 36, color: AppTheme.error),
          ),
          const SizedBox(height: 24),
          Text(
            'Application Not Approved',
            style: GoogleFonts.playfairDisplay(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Unfortunately your application was not approved at this time. Please contact us if you have questions or would like to reapply.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                fontSize: 14, color: AppTheme.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 32),
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
                _detailRow('Business', application.businessName),
                if (application.location != null)
                  _detailRow('Location', application.location!),
                _detailRow('Status', 'Not Approved'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: TextButton(
              onPressed: _logout,
              child: Text('Sign out',
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppTheme.terracotta,
                      fontWeight: FontWeight.w500)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────
  Widget _buildStepIndicator(int currentStep) {
    return Row(
      children: [
        _stepDot(1, currentStep, 'Apply'),
        _stepLine(currentStep >= 2),
        _stepDot(2, currentStep, 'Review'),
        _stepLine(currentStep >= 3),
        _stepDot(3, currentStep, 'Activate'),
      ],
    );
  }

  Widget _stepDot(int step, int current, String label) {
    final isActive = step <= current;
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isActive ? AppTheme.baobab : AppTheme.sand,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isActive && step < current
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : Text(
                      '$step',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isActive ? Colors.white : AppTheme.textHint,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: isActive ? AppTheme.textPrimary : AppTheme.textHint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepLine(bool active) {
    return Container(
      height: 2,
      width: 30,
      margin: const EdgeInsets.only(bottom: 20),
      color: active ? AppTheme.baobab : AppTheme.sand,
    );
  }

  Widget _stepRow(int step, String label, bool completed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: completed
                  ? AppTheme.baobab
                  : AppTheme.sand.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: completed
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : Text('$step',
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textHint)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: completed
                      ? AppTheme.textPrimary
                      : AppTheme.textSecondary,
                  fontWeight: completed ? FontWeight.w500 : FontWeight.w400,
                )),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 13, color: AppTheme.textHint)),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary),
    );
  }
}
