import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../utils/forgot_password_validation.dart';
import '../../../widgets/gradient_button.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.sendReset});

  final Future<void> Function(String email)? sendReset;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final email = normalizeForgotPasswordEmail(_emailController.text);
      // Auth handles recovery without exposing the profile directory to guests.
      // RLS-protected profiles must never determine whether recovery is sent.
      if (widget.sendReset != null) {
        await widget.sendReset!(email);
      } else {
        await Supabase.instance.client.auth.resetPasswordForEmail(
          email,
          redirectTo: AppConstants.authRedirectUrl,
        );
      }
      if (mounted) setState(() => _emailSent = true);
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage =
              'Could not request a reset link. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.sand),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 16,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 100,
                      height: 100,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Reset\nPassword',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 38,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _emailSent
                      ? 'Check your inbox for the reset link'
                      : 'Enter your email and we\'ll send a reset link',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 40),
                if (_emailSent) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.baobab.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.baobab.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.mark_email_read_outlined,
                          size: 48,
                          color: AppTheme.baobab,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Check your email',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.baobab,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'If an account exists for ${_emailController.text.trim()}, you will receive a password reset link.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  GradientButton(
                    label: 'Back to Sign In',
                    borderRadius: 28,
                    onPressed: () => context.go('/login'),
                  ),
                ] else ...[
                  if (_errorMessage != null) ...[
                    _ErrorBanner(message: _errorMessage!),
                    const SizedBox(height: 20),
                  ],
                  Text(
                    'Email',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _resetPassword(),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Email is required';
                      }
                      if (!v.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                    decoration: const InputDecoration(
                      hintText: 'you@example.com',
                      prefixIcon: Icon(
                        Icons.email_outlined,
                        color: AppTheme.textHint,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  GradientButton(
                    label: 'Send Reset Link',
                    borderRadius: 28,
                    isLoading: _isLoading,
                    onPressed: _isLoading ? null : _resetPassword,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Calm, warm error banner used across the auth screens.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
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
              message,
              style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
