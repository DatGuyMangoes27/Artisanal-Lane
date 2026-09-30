import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../models/bobgo.dart';
import '../utils/bobgo_checkout.dart';

/// Door-to-door rate chooser shown inside the selected Bob Go shipping tile.
/// Purely presentational: the checkout screen owns the quote state.
class BobGoRatePicker extends StatelessWidget {
  const BobGoRatePicker({
    super.key,
    required this.status,
    required this.quote,
    required this.selectedRate,
    required this.isLoading,
    required this.errorMessage,
    required this.canRequest,
    required this.now,
    required this.onRequest,
    required this.onSelect,
  });

  final BobGoQuoteStatus status;
  final BobGoQuote? quote;
  final BobGoRate? selectedRate;
  final bool isLoading;
  final String? errorMessage;

  /// False until the delivery address is complete.
  final bool canRequest;
  final DateTime now;
  final VoidCallback onRequest;
  final ValueChanged<BobGoRate> onSelect;

  bool get _showRates =>
      quote != null &&
      (status == BobGoQuoteStatus.ready ||
          status == BobGoQuoteStatus.needsSelection);

  @override
  Widget build(BuildContext context) {
    final problem = errorMessage ??
        (status == BobGoQuoteStatus.expired || status == BobGoQuoteStatus.stale
            ? bobGoQuoteProblemMessage(status)
            : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          canRequest
              ? 'We will price the courier for your address. Prices include VAT.'
              : 'Fill in your delivery address above to see courier prices.',
          style: GoogleFonts.poppins(
            fontSize: 12,
            height: 1.45,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 48,
          width: double.infinity,
          child: OutlinedButton(
            key: const ValueKey('bobgo-get-rates'),
            onPressed: (!canRequest || isLoading) ? null : onRequest,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.terracotta,
              side: BorderSide(
                color: canRequest ? AppTheme.terracotta : AppTheme.sand,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.terracotta,
                    ),
                  )
                : Text(
                    quote == null ? 'Get delivery rates' : 'Refresh rates',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        if (problem != null) ...[
          const SizedBox(height: 12),
          Container(
            key: const ValueKey('bobgo-problem'),
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              problem,
              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.error),
            ),
          ),
        ],
        if (_showRates) ...[
          const SizedBox(height: 12),
          ...quote!.rates.map(
            (rate) => _RateTile(
              rate: rate,
              selected: selectedRate?.key == rate.key,
              onTap: () => onSelect(rate),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              bobGoQuoteValidityLabel(quote!.expiresAt, now),
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppTheme.textHint,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _RateTile extends StatelessWidget {
  const _RateTile({
    required this.rate,
    required this.selected,
    required this.onTap,
  });

  final BobGoRate rate;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final eta = rate.etaLabel;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        key: ValueKey('bobgo-rate-${rate.key}'),
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          constraints: const BoxConstraints(minHeight: 56),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.terracotta.withValues(alpha: 0.05)
                : AppTheme.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? AppTheme.terracotta
                  : AppTheme.sand.withValues(alpha: 0.4),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 22,
                color: selected ? AppTheme.terracotta : AppTheme.textHint,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${rate.providerName} - ${rate.serviceLevelName}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (eta != null)
                      Text(
                        eta,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatBobGoPrice(rate.amount),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    'incl. VAT',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textHint,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
