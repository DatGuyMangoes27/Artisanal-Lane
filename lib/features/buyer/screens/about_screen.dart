import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'About',
          style: GoogleFonts.playfairDisplay(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 24),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.bone,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    'AL',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.terracotta,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Artisan Lane',
                style: GoogleFonts.playfairDisplay(fontSize: 28, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'Version 1.0.0',
                style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textHint),
              ),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Our Mission',
                      style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.w600, color: AppTheme.sienna),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Artisan Lane connects you directly with talented South African artisans '
                      'and craftspeople. Every purchase supports local makers, preserves traditional '
                      'craft techniques, and brings unique handmade treasures to your doorstep.\n\n'
                      'Our escrow-protected marketplace ensures that both buyers and makers '
                      'can transact with confidence. From hand-woven textiles to contemporary '
                      'ceramics, every piece tells a story of skill, tradition, and creativity.',
                      style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textSecondary, height: 1.7),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _linkTile(
                context,
                icon: Icons.description_outlined,
                title: 'Terms of Service',
                onTap: () => context.push('/profile/about/terms'),
              ),
              const SizedBox(height: 12),
              _linkTile(
                context,
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                onTap: () => context.push('/profile/about/privacy'),
              ),
              const SizedBox(height: 40),
              Text(
                'Made with care in South Africa',
                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textHint),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _linkTile(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppTheme.terracotta.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: AppTheme.terracotta, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(title, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.textPrimary))),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textHint),
          ],
        ),
      ),
    );
  }
}
