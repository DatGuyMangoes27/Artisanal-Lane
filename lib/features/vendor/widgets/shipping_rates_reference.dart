import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';

/// Collapsible reference card that surfaces the latest public courier rates
/// so vendors have a sensible anchor when setting their own shipping prices.
/// These are informational only — vendors are free to set any price.
class ShippingRatesReferenceCard extends StatefulWidget {
  const ShippingRatesReferenceCard({super.key, this.initiallyExpanded = false});

  final bool initiallyExpanded;

  @override
  State<ShippingRatesReferenceCard> createState() =>
      _ShippingRatesReferenceCardState();
}

class _ShippingRatesReferenceCardState
    extends State<ShippingRatesReferenceCard> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.ochre.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.ochre.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.ochre.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.local_shipping_rounded,
                      size: 18,
                      color: AppTheme.ochre,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reference courier rates',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _expanded
                              ? 'Informational only — set your own price per method below.'
                              : 'Tap to view The Courier Guy rates as a guide.',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.ochre,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Divider(
              color: AppTheme.ochre.withValues(alpha: 0.25),
              height: 1,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeading('The Courier Guy'),
                  const SizedBox(height: 8),
                  _subHeading('Locker to Locker (by parcel size)'),
                  const SizedBox(height: 6),
                  _rateTable(const [
                    _RateRow('XS', '60 × 17 × 8 cm · ≤ 2 kg', 'R49'),
                    _RateRow('S', '60 × 41 × 8 cm · ≤ 5 kg', 'R59'),
                    _RateRow('M', '60 × 41 × 19 cm · ≤ 10 kg', 'R69'),
                    _RateRow('L', '60 × 41 × 41 cm · ≤ 15 kg', 'R89'),
                    _RateRow('XL', '60 × 41 × 69 cm · ≤ 20 kg', 'R119'),
                  ]),
                  const SizedBox(height: 14),
                  _subHeading('Locker to Door / Door to Locker'),
                  const SizedBox(height: 6),
                  _rateTable(const [
                    _RateRow('XS', null, 'R77,28'),
                    _RateRow('S', null, 'R88,48'),
                    _RateRow('M', null, 'R122,08'),
                    _RateRow('L', null, 'R174,72'),
                    _RateRow('XL', null, 'R234,08'),
                  ]),
                  const SizedBox(height: 14),
                  _subHeading('Door to Door · 2–3 business days'),
                  const SizedBox(height: 6),
                  _simpleRow('Same province', 'R85'),
                  const SizedBox(height: 4),
                  _simpleRow('Cross province', 'R110'),
                  const SizedBox(height: 10),
                  _note(
                    'Locker ↔ Kiosk pricing matches Locker ↔ Locker. Kiosk ↔ Door matches Door ↔ Locker. A 12% fuel surcharge applies to any shipment touching a door (effective 1 Apr 2026).',
                  ),
                  const SizedBox(height: 14),
                  _note(
                    'Rates sourced from The Courier Guy (effective 1 Oct 2025). Confirm current pricing with the carrier before quoting a buyer.',
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeading(String text) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: AppTheme.terracotta,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.playfairDisplay(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _subHeading(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppTheme.textPrimary,
      ),
    );
  }

  Widget _rateTable(List<_RateRow> rows) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.sand.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      rows[i].size,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.terracotta,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      rows[i].dims ?? '',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    rows[i].price,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            if (i != rows.length - 1)
              Divider(
                height: 1,
                color: AppTheme.sand.withValues(alpha: 0.4),
              ),
          ],
        ],
      ),
    );
  }

  Widget _simpleRow(String label, String price) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          price,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _note(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 10.5,
        color: AppTheme.textHint,
        height: 1.45,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}

class _RateRow {
  final String size;
  final String? dims;
  final String price;
  const _RateRow(this.size, this.dims, this.price);
}
