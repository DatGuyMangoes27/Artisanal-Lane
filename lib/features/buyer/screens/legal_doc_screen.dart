import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme.dart';

class LegalDocScreen extends StatelessWidget {
  final String title;
  final String type;

  const LegalDocScreen({super.key, required this.title, required this.type});

  @override
  Widget build(BuildContext context) {
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
          onPressed: () => context.pop(),
        ),
        title: Text(
          title,
          style: GoogleFonts.playfairDisplay(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Last updated: February 2026',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.textHint,
                  ),
                ),
                const SizedBox(height: 20),
                ..._getSections().map(
                  (section) => Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section['heading']!,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          section['body']!,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                            height: 1.7,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Map<String, String>> _getSections() {
    if (type == 'terms') {
      return [
        {
          'heading': '1. Acceptance of Terms',
          'body':
              'By accessing and using Artisan Lane, you accept and agree to be bound by these terms and conditions. '
              'If you do not agree to these terms, please do not use our platform.',
        },
        {
          'heading': '2. Marketplace Platform',
          'body':
              'Artisan Lane acts as a marketplace connecting buyers with independent artisans and craftspeople. '
              'We are not the seller of any products listed on our platform. Each artisan is responsible for the quality, '
              'accuracy of descriptions, and fulfilment of their products.',
        },
        {
          'heading': '3. Escrow Payment System',
          'body':
              'All payments are processed through our escrow system. Funds are held securely until the buyer confirms '
              'receipt of the order. If a dispute arises, our team will investigate and determine the appropriate resolution. '
              'TradeSafe may apply its own escrow processing fee during checkout. Those fees are set by TradeSafe and may vary depending on the payment method used.',
        },
        {
          'heading': '4. Orders and Shipping',
          'body':
              'Once an order is placed, the artisan is notified and will prepare your item for shipping. Delivery times '
              'vary based on the shipping method selected. Tracking information will be provided where available.',
        },
        {
          'heading': '5. Disputes and Returns',
          'body':
              'If you receive an item that is significantly different from the listing or damaged during transit, you may '
              'raise a dispute within 7 days of delivery. Our team will review the case and determine whether a refund, '
              'partial refund, or other resolution is appropriate.',
        },
        {
          'heading': '6. User Conduct',
          'body':
              'Users agree to provide accurate information, use the platform for lawful purposes only, and treat all '
              'community members with respect. Artisan Lane reserves the right to suspend accounts that violate these terms.',
        },
      ];
    } else {
      return [
        {
          'heading': '1. Information We Collect',
          'body':
              'We collect information you provide directly, such as your name, email address, shipping address, '
              'and phone number when you create an account or place an order. We also collect usage data to improve our services.',
        },
        {
          'heading': '2. How We Use Your Information',
          'body':
              'Your information is used to process orders, facilitate communication between buyers and artisans, '
              'improve our platform, and send relevant notifications about your orders and account.',
        },
        {
          'heading': '3. Payment Security',
          'body':
              'Payment processing is handled by PayFast, a PCI-DSS compliant payment gateway. We do not store your '
              'credit card details on our servers. All transactions are encrypted with 256-bit SSL.',
        },
        {
          'heading': '4. Information Sharing',
          'body':
              'We share your shipping details with artisans to fulfil orders and with shipping providers for delivery. '
              'We do not sell your personal information to third parties.',
        },
        {
          'heading': '5. Data Protection',
          'body':
              'We comply with the Protection of Personal Information Act (POPIA) of South Africa. You have the right '
              'to access, correct, or delete your personal information at any time.',
        },
        {
          'heading': '6. Contact Us',
          'body':
              'For any privacy-related concerns, please contact us at privacy@artisanallane.co.za.',
        },
      ];
    }
  }
}
