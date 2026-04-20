import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';

const List<Map<String, String>> vendorTermsSections = [
  {
    'heading': '1. Marketplace & listings',
    'body':
        'Artisan Lane is a marketplace that connects your shop with buyers. You remain the seller of record for your products and are responsible for accurate descriptions, pricing, stock, and quality.',
  },
  {
    'heading': '2. Vendor subscription',
    'body':
        'A monthly Artisan Lane vendor subscription is required to keep your storefront live and listings visible to buyers. If your subscription lapses, new purchases will be paused until it is renewed. You can cancel at any time — your store remains active through the end of the paid period.',
  },
  {
    'heading': '3. Payments & TradeSafe escrow',
    'body':
        'All buyer payments are held in TradeSafe escrow and released to your nominated bank account once the order is completed. Valid South African banking details are compulsory for receiving payouts. Platform commission and TradeSafe fees are deducted from the buyer payment before release.',
  },
  {
    'heading': '4. Fulfilment & turnaround',
    'body':
        'You agree to honour the delivery method and turnaround time you advertise. Orders must be marked shipped with tracking (where available) and delivered to the buyer within a reasonable window.',
  },
  {
    'heading': '5. Disputes & refunds',
    'body':
        'Buyers may raise a dispute within 7 days of delivery for damaged, missing or misrepresented items. Artisan Lane mediates disputes and may issue full or partial refunds from escrow where appropriate.',
  },
  {
    'heading': '6. Conduct & account status',
    'body':
        'You agree to provide accurate information, comply with South African law, and treat buyers and support staff respectfully. Artisan Lane may suspend or remove shops that violate these terms.',
  },
];

void showVendorTermsSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.sand,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 8, 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.gavel_rounded,
                    color: AppTheme.terracotta,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Vendor Terms & Conditions',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            Divider(color: AppTheme.sand.withValues(alpha: 0.5), height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Please read these terms carefully. Submitting a vendor application confirms your agreement to each section below.',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 18),
                    for (final section in vendorTermsSections) ...[
                      Text(
                        section['heading']!,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        section['body']!,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          height: 1.65,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.ochre.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.ochre.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.support_agent_rounded,
                            size: 18,
                            color: AppTheme.ochre,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Questions about these terms? Reach out to nicky@artisanlanesa.com before submitting your application.',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.terracotta,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Close',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
  );
}

class VendorTermsAcceptance extends StatefulWidget {
  final bool accepted;
  final ValueChanged<bool> onChanged;
  final VoidCallback onOpenTerms;

  const VendorTermsAcceptance({
    super.key,
    required this.accepted,
    required this.onChanged,
    required this.onOpenTerms,
  });

  @override
  State<VendorTermsAcceptance> createState() => _VendorTermsAcceptanceState();
}

class _VendorTermsAcceptanceState extends State<VendorTermsAcceptance> {
  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _subscriptionRecognizer;
  late final TapGestureRecognizer _bankRecognizer;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () => widget.onOpenTerms();
    _subscriptionRecognizer = TapGestureRecognizer()
      ..onTap = () => widget.onOpenTerms();
    _bankRecognizer = TapGestureRecognizer()
      ..onTap = () => widget.onOpenTerms();
  }

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _subscriptionRecognizer.dispose();
    _bankRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accepted = widget.accepted;
    final linkStyle = GoogleFonts.poppins(
      fontSize: 12,
      color: AppTheme.terracotta,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: AppTheme.terracotta.withValues(alpha: 0.6),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accepted ? AppTheme.baobab.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accepted
              ? AppTheme.baobab.withValues(alpha: 0.4)
              : AppTheme.sand.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: Checkbox(
                  value: accepted,
                  onChanged: (v) => widget.onChanged(v ?? false),
                  activeColor: AppTheme.baobab,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      height: 1.5,
                    ),
                    children: [
                      const TextSpan(
                        text: 'I have read and agree to the Artisan Lane ',
                      ),
                      TextSpan(
                        text: 'Vendor Terms & Conditions',
                        style: linkStyle,
                        recognizer: _termsRecognizer,
                      ),
                      const TextSpan(text: '. I understand that an active '),
                      TextSpan(
                        text: 'monthly subscription',
                        style: linkStyle,
                        recognizer: _subscriptionRecognizer,
                      ),
                      const TextSpan(
                        text:
                            ' is required to keep my storefront live once approved, and that valid ',
                      ),
                      TextSpan(
                        text: 'bank details for TradeSafe',
                        style: linkStyle,
                        recognizer: _bankRecognizer,
                      ),
                      const TextSpan(
                        text:
                            ' are compulsory for receiving payouts from buyer orders.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.onOpenTerms,
              icon: const Icon(
                Icons.menu_book_rounded,
                size: 16,
                color: AppTheme.terracotta,
              ),
              label: Text(
                'Read the full Vendor Terms & Conditions',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.terracotta,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 4,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
