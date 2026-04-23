import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/theme.dart';
import '../utils/help_support_contact.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  int? _expandedIndex;

  static const _faqs = [
    {
      'q': 'How does the escrow payment work?',
      'a':
          'When you place an order, your payment is held securely in escrow. '
          'The artisan is notified and ships your item. Once you receive it and '
          'confirm delivery, the funds are released to the maker. This protects '
          'both buyers and sellers. TradeSafe may also charge an escrow processing fee during checkout, and its integrated checkout fees can vary depending on the payment method selected.',
    },
    {
      'q': 'What shipping options are available?',
      'a':
          'We offer The Courier Guy (door-to-door or locker-to-locker, 2-4 days), Pargo pick-up points, '
          'and Market Pickup where you collect directly '
          'from the artisan.',
    },
    {
      'q': 'How do I return or exchange an item?',
      'a':
          'Since every item is handcrafted and unique, returns are handled on a '
          'case-by-case basis. If your item arrives damaged or significantly different '
          'from the listing, you can raise a dispute from your order details page.',
    },
    {
      'q': 'How do I raise a dispute?',
      'a':
          'Go to My Orders, tap the order in question, then select "Raise Dispute". '
          'Describe the issue and our team will investigate. While a dispute is open, '
          'funds remain in escrow.',
    },
    {
      'q': 'How long does shipping take?',
      'a':
          'Delivery times depend on the shipping method chosen at checkout. '
          'The Courier Guy typically delivers in 2-4 business days, Pargo in 3-5 days, '
          'and Market Pickup depends on the next available market date. '
          'Some made-to-order or special-order items may also have an additional lead time before dispatch.',
    },
    {
      'q': 'Are all products handmade?',
      'a':
          'Yes! Every product on Artisan Lane is crafted by verified South African artisans. '
          'We vet each maker through our application process to ensure authenticity.',
    },
  ];

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
          'Help & Support',
          style: GoogleFonts.playfairDisplay(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Frequently Asked Questions',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              ...List.generate(_faqs.length, (i) => _faqTile(i)),
              const SizedBox(height: 40),
              Text(
                'Contact Us',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              _contactTile(
                icon: Icons.email_outlined,
                title: 'Email Support',
                subtitle: helpSupportEmail,
                onTap: () => launchUrl(helpSupportEmailLaunchUri),
              ),
              const SizedBox(height: 16),
              _contactTile(
                icon: Icons.chat_outlined,
                title: 'WhatsApp',
                subtitle: helpSupportWhatsappDisplay,
                onTap: () => launchUrl(helpSupportWhatsappLaunchUri),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _faqTile(int index) {
    final faq = _faqs[index];
    final isExpanded = _expandedIndex == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => setState(() => _expandedIndex = isExpanded ? null : index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isExpanded
                  ? AppTheme.terracotta.withValues(alpha: 0.3)
                  : AppTheme.sand.withValues(alpha: 0.3),
            ),
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      faq['q']!,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.textHint,
                    size: 22,
                  ),
                ],
              ),
              if (isExpanded) ...[
                const SizedBox(height: 12),
                Text(
                  faq['a']!,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    height: 1.6,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _contactTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.terracotta.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppTheme.terracotta, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: AppTheme.textHint,
            ),
          ],
        ),
      ),
    );
  }
}
