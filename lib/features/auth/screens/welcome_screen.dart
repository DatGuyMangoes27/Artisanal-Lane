import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/buyer_routes.dart';
import '../../../app/theme.dart';
import '../../../widgets/gradient_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: 160,
                          height: 160,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Artisan Lane',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'A curated marketplace for\nSouth African handmade goods',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          color: AppTheme.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 28),
                      // Short value props — what makes this a craft brand, not a
                      // generic storefront.
                      const _ValueProps(),
                      const Spacer(),
                      // Decorative divider
                      Row(
                        children: [
                          Expanded(
                            child: Container(height: 1, color: AppTheme.sand),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Icon(
                              Icons.diamond_outlined,
                              size: 14,
                              color: AppTheme.ochre,
                            ),
                          ),
                          Expanded(
                            child: Container(height: 1, color: AppTheme.sand),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      GradientButton(
                        label: 'Sign In',
                        borderRadius: 28,
                        onPressed: () => context.push('/login'),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => context.push('/register'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.terracotta,
                            side: const BorderSide(
                              color: AppTheme.terracotta,
                              width: 1.5,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: Text(
                            'Create Account',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () => context.go(buyerLandingRoute),
                        child: Text(
                          'Browse as Guest',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: AppTheme.textHint,
                            decoration: TextDecoration.underline,
                            decorationColor: AppTheme.textHint,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Column(
                        children: [
                          Text(
                            'By continuing, you agree to our',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppTheme.textHint,
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.push('/terms'),
                            style: TextButton.styleFrom(
                              minimumSize: Size.zero,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Terms of Service',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.terracotta,
                                decoration: TextDecoration.underline,
                                decorationColor: AppTheme.terracotta,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Three short, calm value props for a first-time visitor — not a sales
/// pitch, just what this app is for.
class _ValueProps extends StatelessWidget {
  const _ValueProps();

  static const _items = [
    (Icons.handshake_outlined, 'Bought directly from the maker'),
    (Icons.verified_user_outlined, 'Every order protected by escrow'),
    (Icons.local_shipping_outlined, 'Shipped from workshops across SA'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final item in _items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(item.$1, size: 18, color: AppTheme.terracotta),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.$2,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
