import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app/theme.dart';
import '../../../widgets/gradient_button.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/vendor_providers.dart';
import '../utils/vendor_fulfillment_options.dart';
import '../utils/vendor_onboarding_flow.dart';
import '../widgets/vendor_terms.dart';

class VendorOnboardingScreen extends ConsumerStatefulWidget {
  const VendorOnboardingScreen({super.key});

  @override
  ConsumerState<VendorOnboardingScreen> createState() =>
      _VendorOnboardingScreenState();
}

class _VendorOnboardingScreenState
    extends ConsumerState<VendorOnboardingScreen> {
  static const _turnaroundOptions = <String>[
    '1-3 business days',
    '3-5 business days',
    '5-7 business days',
    '7-10 business days',
    '10-14 business days',
    '14+ days / made to order',
  ];

  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _motivationController = TextEditingController();
  final _locationController = TextEditingController();
  final _portfolioController = TextEditingController();
  final _deliveryController = TextEditingController();
  final _turnaroundController = TextEditingController();
  final List<String> _proofImageUrls = [];
  final List<File> _proofPendingFiles = [];
  final Set<String> _selectedFulfillmentMethods = {};
  final ImagePicker _picker = ImagePicker();
  bool _acceptedTcs = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _selectedTurnaroundOption;

  final GlobalKey _errorBannerKey = GlobalKey();
  final GlobalKey _businessNameKey = GlobalKey();
  final GlobalKey _portfolioKey = GlobalKey();
  final GlobalKey _fulfillmentKey = GlobalKey();
  final GlobalKey _turnaroundKey = GlobalKey();
  final GlobalKey _termsKey = GlobalKey();

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

  Future<void> _pickProofImages() async {
    try {
      final remainingSlots =
          3 - (_proofImageUrls.length + _proofPendingFiles.length);
      if (remainingSlots <= 0) {
        setState(() {
          _errorMessage = 'You can upload up to 3 proof photos.';
        });
        return;
      }

      final images = await _picker.pickMultiImage(
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );

      if (images.isEmpty) {
        return;
      }

      setState(() {
        _proofPendingFiles.addAll(
          images.take(remainingSlots).map((image) => File(image.path)),
        );
        _errorMessage = null;
      });
    } catch (error) {
      setState(() {
        _errorMessage = 'Could not add proof photos: $error';
      });
    }
  }

  Future<void> _uploadProofImages(String userId) async {
    if (_proofPendingFiles.isEmpty) {
      return;
    }

    final service = ref.read(supabaseServiceProvider);
    for (final file in _proofPendingFiles) {
      final url = await service.uploadVendorApplicationImage(userId, file);
      _proofImageUrls.add(url);
    }
    _proofPendingFiles.clear();
  }

  void _scrollToSection(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = key.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
        alignment: 0.1,
      );
    });
  }

  bool _flagIssue(String message, GlobalKey key) {
    setState(() => _errorMessage = message);
    _scrollToSection(key);
    return false;
  }

  bool _validateOnboardingForm() {
    final formValid = _formKey.currentState?.validate() ?? false;
    if (!formValid) {
      // The only TextFormField with a validator is Business Name.
      return _flagIssue(
        'Please enter your business or brand name.',
        _businessNameKey,
      );
    }

    if (_portfolioController.text.trim().isEmpty &&
        _proofImageUrls.isEmpty &&
        _proofPendingFiles.isEmpty) {
      return _flagIssue(
        'Either a social/portfolio link OR at least one work photo is required so we can verify your craft.',
        _portfolioKey,
      );
    }

    if (_selectedFulfillmentMethods.isEmpty) {
      return _flagIssue(
        'Please select at least one fulfilment method.',
        _fulfillmentKey,
      );
    }

    if (_selectedTurnaroundOption == null ||
        _selectedTurnaroundOption!.isEmpty) {
      return _flagIssue(
        'Please select a typical turnaround time.',
        _turnaroundKey,
      );
    }

    if (!_acceptedTcs) {
      return _flagIssue(
        'Please accept the Terms & Conditions to continue.',
        _termsKey,
      );
    }

    return true;
  }

  Future<void> _submit() async {
    if (!_validateOnboardingForm()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final service = ref.read(supabaseServiceProvider);
      await _uploadProofImages(userId);

      final deliveryInfo = [
        _selectedFulfillmentMethods.join(', '),
        if (_deliveryController.text.trim().isNotEmpty)
          _deliveryController.text.trim(),
      ].join(' | ');

      final turnaroundTime = [
        _selectedTurnaroundOption,
        if (_turnaroundController.text.trim().isNotEmpty)
          _turnaroundController.text.trim(),
      ].whereType<String>().join(' | ');

      await service.submitVendorOnboarding(
        userId: userId,
        businessName: _businessNameController.text.trim(),
        motivation: _motivationController.text.trim().isNotEmpty
            ? _motivationController.text.trim()
            : null,
        portfolioUrl: _portfolioController.text.trim().isNotEmpty
            ? _portfolioController.text.trim()
            : null,
        proofImageUrls: _proofImageUrls,
        location: _locationController.text.trim().isNotEmpty
            ? _locationController.text.trim()
            : null,
        deliveryInfo: deliveryInfo.isNotEmpty ? deliveryInfo : null,
        turnaroundTime: turnaroundTime.isNotEmpty ? turnaroundTime : null,
      );
      ref.invalidate(vendorApplicationProvider);
      ref.invalidate(vendorApplicationStreamProvider);

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.baobab,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Text(
                  'Submitted!',
                  style: GoogleFonts.playfairDisplay(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            content: Text(
              'Thank you. Your application has been submitted and our team is now reviewing it.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'OK',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.terracotta,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(
        () => _errorMessage = e.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _activateAccount(dynamic application) async {
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final service = ref.read(supabaseServiceProvider);
      await service.markVendorApprovalSeen(userId);
      ref.invalidate(currentProfileProvider);
      final profile = await service.getProfile(userId);
      if (profile.role == 'vendor') {
        ref.invalidate(vendorShopProvider);
        if (mounted) GoRouter.of(context).go('/vendor');
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Your approved seller account is still being provisioned by an admin.',
            ),
            backgroundColor: AppTheme.ochre,
          ),
        );
      }
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
    final appAsync = ref.watch(vendorApplicationStreamProvider);
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: SafeArea(
        child: profileAsync.when(
          data: (profile) => appAsync.when(
            data: (application) {
              if (application == null) return _buildApplicationForm();
              if (application.isApproved &&
                  shouldShowVendorApprovalCelebration(
                    isApproved: true,
                    hasSeenVendorApproval: profile?.hasSeenVendorApproval ?? false,
                  )) {
                return _buildApproved(application);
              }
              if (application.isApproved) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) GoRouter.of(context).go('/vendor');
                });
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.terracotta,
                    strokeWidth: 2,
                  ),
                );
              }
              if (application.isPending) return _buildPending(application);
              return _buildRejected(application);
            },
            loading: () => const Center(
              child: CircularProgressIndicator(
                color: AppTheme.terracotta,
                strokeWidth: 2,
              ),
            ),
            error: (_, __) => _buildApplicationForm(),
          ),
          loading: () => const Center(
            child: CircularProgressIndicator(
              color: AppTheme.terracotta,
              strokeWidth: 2,
            ),
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
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Progress indicator
            _buildStepIndicator(1),
            const SizedBox(height: 32),

            if (_errorMessage != null) ...[
              Container(
                key: _errorBannerKey,
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 18,
                      color: AppTheme.error,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppTheme.error,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            Column(
              key: _businessNameKey,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('Business / Brand Name'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _businessNameController,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Ndlovu Ceramics',
                    prefixIcon: Icon(
                      Icons.store_outlined,
                      color: AppTheme.textHint,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            _buildLabel('What handmade products do you make?'),
            const SizedBox(height: 4),
            Text(
              'Tell us what you make, where it is made, and anything that helps us understand it is handmade.',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: AppTheme.textHint,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _motivationController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText:
                    'e.g. I hand-build ceramic tableware in Cape Town and finish each piece myself in small batches...',
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
                prefixIcon: Icon(
                  Icons.location_on_outlined,
                  color: AppTheme.textHint,
                ),
              ),
            ),
            const SizedBox(height: 20),

            Column(
              key: _portfolioKey,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildLabel('Proof of your work'),
                    const SizedBox(width: 8),
                    _buildRequiredBadge(),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.terracotta.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.terracotta.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.verified_user_outlined,
                        size: 16,
                        color: AppTheme.terracotta,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You must provide at least one of the following so our team can verify your craft: a social/portfolio link OR 1–3 photos of your work.',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppTheme.textPrimary,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _buildSubLabel('Option 1 — Social / portfolio link'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _portfolioController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    hintText: 'Instagram, website, or portfolio link',
                    prefixIcon: Icon(Icons.link, color: AppTheme.textHint),
                  ),
                ),
                const SizedBox(height: 14),
                _buildSubLabel('Option 2 — Upload 1–3 photos of your work'),
                const SizedBox(height: 6),
                _buildProofPhotosCard(),
              ],
            ),
            const SizedBox(height: 20),

            Container(
              key: _fulfillmentKey,
              width: double.infinity,
            ),
            _buildLabel('How will you fulfil orders?'),
            const SizedBox(height: 4),
            Text(
              vendorFulfillmentDescription,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: AppTheme.textHint,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: vendorFulfillmentOptions.map((option) {
                final selected = _selectedFulfillmentMethods.contains(option);
                return FilterChip(
                  label: Text(
                    option,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: selected ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                  selected: selected,
                  onSelected: (value) {
                    setState(() {
                      if (value) {
                        _selectedFulfillmentMethods.add(option);
                      } else {
                        _selectedFulfillmentMethods.remove(option);
                      }
                    });
                  },
                  selectedColor: AppTheme.terracotta,
                  checkmarkColor: Colors.white,
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: selected
                        ? AppTheme.terracotta
                        : AppTheme.sand.withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _deliveryController,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: vendorFulfillmentDetailsHint,
              ),
            ),
            const SizedBox(height: 20),

            Container(
              key: _turnaroundKey,
              width: double.infinity,
            ),
            _buildLabel('Typical turnaround time?'),
            const SizedBox(height: 4),
            Text(
              'How long from order placed to ready-to-ship? Include made-to-order time if applicable.',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: AppTheme.textHint,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedTurnaroundOption,
              onChanged: (value) {
                setState(() => _selectedTurnaroundOption = value);
              },
              decoration: const InputDecoration(
                hintText: 'Select typical turnaround',
                prefixIcon: Icon(
                  Icons.schedule_outlined,
                  color: AppTheme.textHint,
                ),
              ),
              items: _turnaroundOptions
                  .map(
                    (option) => DropdownMenuItem<String>(
                      value: option,
                      child: Text(
                        option,
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _turnaroundController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText:
                    'Optional notes, e.g. custom work takes longer during peak seasons',
              ),
            ),
            const SizedBox(height: 28),

            VendorTermsAcceptance(
              key: _termsKey,
              accepted: _acceptedTcs,
              onChanged: (value) => setState(() => _acceptedTcs = value),
              onOpenTerms: () => showVendorTermsSheet(context),
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
                    fontSize: 13,
                    color: AppTheme.textHint,
                  ),
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
            child: const Icon(
              Icons.hourglass_top_rounded,
              size: 36,
              color: AppTheme.ochre,
            ),
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
              fontSize: 14,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
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
                Text(
                  'Your Application',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
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
                Text(
                  'What happens next?',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
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
              label: Text(
                'Refresh Status',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.terracotta,
                side: const BorderSide(color: AppTheme.terracotta, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'This just refreshes this page to check whether your application status has changed.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppTheme.textHint,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _logout,
              child: Text(
                'Sign out',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppTheme.textHint,
                ),
              ),
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
            child: const Icon(
              Icons.celebration_rounded,
              size: 36,
              color: AppTheme.baobab,
            ),
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
            'Congratulations! Your application has been approved. Once admin provisioning finishes, you can continue straight to your dashboard.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 36),
          GradientButton(
            label: _isLoading ? 'Checking Access...' : 'Continue to Dashboard',
            icon: Icons.storefront_rounded,
            isLoading: _isLoading,
            onPressed: _isLoading ? null : () => _activateAccount(application),
          ),
          const SizedBox(height: 12),
          Text(
            'Admin approval now provisions your seller role and shop automatically.',
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
            child: const Icon(
              Icons.cancel_rounded,
              size: 36,
              color: AppTheme.error,
            ),
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
              fontSize: 14,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
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
              child: Text(
                'Sign out',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppTheme.terracotta,
                  fontWeight: FontWeight.w500,
                ),
              ),
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
                  : Text(
                      '$step',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textHint,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: completed
                    ? AppTheme.textPrimary
                    : AppTheme.textSecondary,
                fontWeight: completed ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
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
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textHint),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProofPhotosCard() {
    final totalImages = _proofImageUrls.length + _proofPendingFiles.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.sand.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.photo_library_outlined,
                size: 18,
                color: AppTheme.textHint,
              ),
              const SizedBox(width: 8),
              Text(
                'Work photos',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '$totalImages/3',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppTheme.textHint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (totalImages > 0)
            SizedBox(
              height: 84,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ..._proofImageUrls.asMap().entries.map(
                    (entry) => _ProofImageTile(
                      key: ValueKey('proof-url-${entry.key}'),
                      onRemove: () {
                        setState(() => _proofImageUrls.removeAt(entry.key));
                      },
                      child: Image.network(entry.value, fit: BoxFit.cover),
                    ),
                  ),
                  ..._proofPendingFiles.asMap().entries.map(
                    (entry) => _ProofImageTile(
                      key: ValueKey('proof-file-${entry.key}'),
                      onRemove: () {
                        setState(() => _proofPendingFiles.removeAt(entry.key));
                      },
                      isPending: true,
                      child: Image.file(entry.value, fit: BoxFit.cover),
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              'Upload clear photos of your handmade work if you do not have a social link yet.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppTheme.textSecondary,
                height: 1.45,
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: totalImages >= 3 ? null : _pickProofImages,
            icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
            label: Text(
              totalImages == 0 ? 'Upload Photos' : 'Add More Photos',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.terracotta,
              side: BorderSide(
                color: AppTheme.terracotta.withValues(alpha: 0.4),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
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
        color: AppTheme.textPrimary,
      ),
    );
  }

  Widget _buildSubLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary,
      ),
    );
  }

  Widget _buildRequiredBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.terracotta.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.terracotta.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        'Required',
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppTheme.terracotta,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _ProofImageTile extends StatelessWidget {
  final Widget child;
  final VoidCallback onRemove;
  final bool isPending;

  const _ProofImageTile({
    super.key,
    required this.child,
    required this.onRemove,
    this.isPending = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      margin: const EdgeInsets.only(right: 10),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox.expand(child: child),
          ),
          if (isPending)
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'New',
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 12, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
