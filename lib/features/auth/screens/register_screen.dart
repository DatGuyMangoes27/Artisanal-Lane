import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../services/meta_app_events_service.dart';
import '../providers/auth_providers.dart';
import '../../../widgets/gradient_button.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isVendor = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      const role = 'buyer';
      final res = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        data: {
          'display_name': _nameController.text.trim(),
          'role': role,
          'requested_role': _isVendor ? 'vendor' : 'buyer',
        },
      );

      if (res.user != null) {
        await Supabase.instance.client.from('profiles').upsert({
          'id': res.user!.id,
          'role': role,
          'display_name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
        });
        await ref
            .read(metaAppEventsServiceProvider)
            .logCompletedRegistration(
              registrationMethod: 'email',
              requestedRole: _isVendor ? 'vendor' : 'buyer',
            );
      }

      if (mounted) {
        if (res.session != null) {
          final service = ref.read(supabaseServiceProvider);
          final profile = await service.syncCurrentUserProfile();
          final route = await service.getPostAuthRoute(profile: profile);
          if (mounted) context.go(route);
        } else {
          _showVerificationDialog();
        }
      }
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithOAuth(OAuthProvider provider) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        provider,
        redirectTo: AppConstants.authRedirectUrl,
      );
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Unable to start social sign-up');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (kIsWeb) {
        await _signInWithOAuth(OAuthProvider.google);
        return;
      }

      await ref
          .read(supabaseServiceProvider)
          .signInWithGoogleNative(
            requestedRole: _isVendor ? 'vendor' : 'buyer',
            displayName: _nameController.text.trim(),
          );
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _errorMessage = e.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showVerificationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Verify Your Email',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        content: Text(
          'We\'ve sent a verification link to ${_emailController.text.trim()}. Please check your inbox and verify your email before signing in.',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: AppTheme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go('/login');
            },
            child: Text(
              'Go to Sign In',
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
                _buildBackButton(context),
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
                  'Create\nAccount',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 38,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isVendor
                      ? 'Start selling your handmade goods'
                      : 'Join the artisan marketplace',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),

                // Account type selector
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.sand),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Expanded(
                        child: _AccountTypeTab(
                          label: 'Buyer',
                          icon: Icons.shopping_bag_outlined,
                          isSelected: !_isVendor,
                          onTap: () => setState(() => _isVendor = false),
                        ),
                      ),
                      Expanded(
                        child: _AccountTypeTab(
                          label: 'Artisan',
                          icon: Icons.storefront_outlined,
                          isSelected: _isVendor,
                          onTap: () => setState(() => _isVendor = true),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (_isVendor)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 14,
                          color: AppTheme.baobab,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Artisan accounts require approval before you can start selling',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppTheme.baobab,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),
                if (_errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppTheme.error,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                _buildLabel(_isVendor ? 'Your Name' : 'Display Name'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    hintText: 'Your name',
                    prefixIcon: Icon(
                      Icons.person_outline,
                      color: AppTheme.textHint,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildLabel('Email'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
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
                const SizedBox(height: 20),
                _buildLabel('Password'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _signUp(),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (v.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: 'Min 6 characters',
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                      color: AppTheme.textHint,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppTheme.textHint,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                GradientButton(
                  label: _isVendor
                      ? 'Create Artisan Account'
                      : 'Create Account',
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _signUp,
                ),
                const SizedBox(height: 24),
                _buildDivider(),
                const SizedBox(height: 24),
                _OAuthButton(
                  icon: Icons.g_mobiledata_rounded,
                  label: 'Continue with Google',
                  onTap: _isLoading ? null : _signInWithGoogle,
                ),
                if (Platform.isIOS) ...[
                  const SizedBox(height: 12),
                  _OAuthButton(
                    icon: Icons.apple_rounded,
                    label: 'Continue with Apple',
                    onTap: _isLoading
                        ? null
                        : () => _signInWithOAuth(OAuthProvider.apple),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/login'),
                      child: Text(
                        'Sign In',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.terracotta,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return GestureDetector(
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

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppTheme.sand)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or continue with',
            style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textHint),
          ),
        ),
        const Expanded(child: Divider(color: AppTheme.sand)),
      ],
    );
  }
}

class _AccountTypeTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _AccountTypeTab({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isArtisan = label == 'Artisan';
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected && !isArtisan ? AppTheme.terracotta : null,
          gradient: isSelected && isArtisan
              ? const LinearGradient(
                  colors: [AppTheme.terracotta, AppTheme.baobab],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : AppTheme.textHint,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppTheme.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OAuthButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _OAuthButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 22),
        label: Text(
          label,
          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.textPrimary,
          side: BorderSide(color: AppTheme.sand.withValues(alpha: 0.8)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.white,
        ),
      ),
    );
  }
}
