import '../../../models/bobgo.dart';

const bobGoShippingKey = 'bobgo_door_to_door';

enum BobGoQuoteStatus {
  /// No quote requested yet.
  none,

  /// Quote saved, a rate is chosen and the address/basket still match.
  ready,

  /// Quote saved but no rate chosen yet.
  needsSelection,

  /// The 20 minute server-side quote expired; a new one is required.
  expired,

  /// The delivery address changed after the quote; a new one is required.
  stale,
}

/// Decides whether the saved quote can be sent to `create-checkout`.
BobGoQuoteStatus bobGoQuoteStatus({
  required BobGoQuote? quote,
  required BobGoRate? selectedRate,
  required String? quotedFingerprint,
  required String currentFingerprint,
  required DateTime now,
}) {
  if (quote == null) return BobGoQuoteStatus.none;
  if (quote.isExpiredAt(now)) return BobGoQuoteStatus.expired;
  if (quotedFingerprint != currentFingerprint) return BobGoQuoteStatus.stale;
  if (selectedRate == null) return BobGoQuoteStatus.needsSelection;
  return BobGoQuoteStatus.ready;
}

/// Buyer-facing message for a quote that cannot be used, or null when fine.
String? bobGoQuoteProblemMessage(BobGoQuoteStatus status) {
  switch (status) {
    case BobGoQuoteStatus.expired:
      return 'Your delivery quote expired. Get fresh rates to continue.';
    case BobGoQuoteStatus.stale:
      return 'Your delivery address changed. Get fresh rates to continue.';
    case BobGoQuoteStatus.needsSelection:
      return 'Choose a delivery service to continue.';
    case BobGoQuoteStatus.none:
      return 'Get delivery rates to continue.';
    case BobGoQuoteStatus.ready:
      return null;
  }
}

/// "R95.00" - shipping is a real charge so it keeps two decimals.
String formatBobGoPrice(double amount) => 'R${amount.toStringAsFixed(2)}';

/// "Valid for 12 more minutes" style hint for the quote timer.
String bobGoQuoteValidityLabel(DateTime? expiresAt, DateTime now) {
  if (expiresAt == null) return '';
  final remaining = expiresAt.difference(now);
  if (remaining.isNegative || remaining == Duration.zero) {
    return 'Quote expired';
  }
  final minutes = (remaining.inSeconds / 60).ceil();
  return minutes <= 1
      ? 'Quote valid for about a minute'
      : 'Quote valid for $minutes more minutes';
}
