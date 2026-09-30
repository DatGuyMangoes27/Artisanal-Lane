/// Bob Go door-to-door shipping models.
///
/// Rates come from the `bobgo-quote` edge function, which saves the quote on
/// the server; the app only ever sends the quote/rate identifiers back to
/// `create-checkout`, never a price.
class BobGoRate {
  final int rateResponseId;
  final String providerSlug;
  final String providerName;
  final String serviceLevelCode;
  final String serviceLevelName;
  final String description;

  /// VAT-inclusive price the buyer pays.
  final double amount;
  final double amountExcludingVat;
  final double chargedWeightKg;
  final DateTime? etaFrom;
  final DateTime? etaTo;
  final int? etaMinDays;
  final int? etaMaxDays;

  const BobGoRate({
    required this.rateResponseId,
    required this.providerSlug,
    required this.providerName,
    required this.serviceLevelCode,
    required this.serviceLevelName,
    this.description = '',
    required this.amount,
    this.amountExcludingVat = 0,
    this.chargedWeightKg = 0,
    this.etaFrom,
    this.etaTo,
    this.etaMinDays,
    this.etaMaxDays,
  });

  factory BobGoRate.fromJson(Map<String, dynamic> json) {
    int? positiveInt(Object? value) {
      final parsed = (value as num?)?.toInt();
      return parsed != null && parsed > 0 ? parsed : null;
    }

    DateTime? date(Object? value) =>
        value is String ? DateTime.tryParse(value) : null;

    return BobGoRate(
      rateResponseId: (json['rateResponseId'] as num).toInt(),
      providerSlug: json['providerSlug'] as String? ?? '',
      providerName: json['providerName'] as String? ?? 'Courier',
      serviceLevelCode: json['serviceLevelCode'] as String? ?? '',
      serviceLevelName: json['serviceLevelName'] as String? ?? 'Delivery',
      description: json['description'] as String? ?? '',
      amount: (json['amount'] as num).toDouble(),
      amountExcludingVat:
          (json['amountExcludingVat'] as num?)?.toDouble() ??
          (json['amount'] as num).toDouble(),
      chargedWeightKg: (json['chargedWeightKg'] as num?)?.toDouble() ?? 0,
      etaFrom: date(json['etaFrom']),
      etaTo: date(json['etaTo']),
      etaMinDays: positiveInt(json['etaMinDays']),
      etaMaxDays: positiveInt(json['etaMaxDays']),
    );
  }

  /// Stable identity of a rate inside one saved quote.
  String get key => '$rateResponseId|$providerSlug|$serviceLevelCode';

  /// "Estimated 2-4 business days" / "Estimated 3 Oct - 5 Oct", or null when
  /// the courier gave no estimate.
  String? get etaLabel {
    final from = etaFrom;
    final to = etaTo;
    if (from != null) {
      final start = _shortDate(from.toLocal());
      if (to != null && !_sameDay(from, to)) {
        return 'Estimated $start - ${_shortDate(to.toLocal())}';
      }
      return 'Estimated $start';
    }
    final min = etaMinDays;
    final max = etaMaxDays;
    if (min != null && max != null && min != max) {
      return 'Estimated $min-$max business days';
    }
    final days = max ?? min;
    if (days != null) {
      return 'Estimated $days business day${days == 1 ? '' : 's'}';
    }
    return null;
  }
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _shortDate(DateTime date) => '${date.day} ${_months[date.month - 1]}';

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// A saved, server-side Bob Go quote (valid for ~20 minutes).
class BobGoQuote {
  final String quoteId;
  final DateTime? expiresAt;
  final List<BobGoRate> rates;

  const BobGoQuote({
    required this.quoteId,
    required this.expiresAt,
    required this.rates,
  });

  factory BobGoQuote.fromJson(Map<String, dynamic> json) {
    final expires = json['expiresAt'];
    return BobGoQuote(
      quoteId: json['quoteId'] as String,
      expiresAt: expires is String ? DateTime.tryParse(expires) : null,
      rates: (json['rates'] as List? ?? const [])
          .map((r) => BobGoRate.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList(growable: false),
    );
  }

  bool isExpiredAt(DateTime now) {
    final expiry = expiresAt;
    return expiry != null && !expiry.isAfter(now);
  }
}

/// Delivery details the quote is bound to.
class BobGoDeliveryDetails {
  final String fullName;
  final String phone;
  final String streetAddress;
  final String localArea;
  final String city;
  final String province;
  final String postalCode;

  const BobGoDeliveryDetails({
    required this.fullName,
    required this.phone,
    required this.streetAddress,
    required this.localArea,
    required this.city,
    required this.province,
    required this.postalCode,
  });

  Map<String, dynamic> toJson() => {
    'fullName': fullName.trim(),
    'phone': phone.trim(),
    'streetAddress': streetAddress.trim(),
    'localArea': localArea.trim(),
    'city': city.trim(),
    'province': province.trim(),
    'postalCode': postalCode.trim(),
  };

  /// Changes whenever a detail that would invalidate the saved quote changes
  /// (basket/address). Normalised the same way the server compares addresses.
  String get fingerprint => [
    streetAddress,
    localArea,
    city,
    province,
    postalCode,
  ].map((part) => part.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase()).join('|');
}

/// The saved-quote selection passed through to `create-checkout`.
class BobGoSelection {
  final String quoteId;
  final BobGoRate rate;

  const BobGoSelection({required this.quoteId, required this.rate});

  Map<String, dynamic> toCheckoutJson() => {
    'bobgoQuoteId': quoteId,
    'bobgoRateResponseId': rate.rateResponseId,
    'bobgoProviderSlug': rate.providerSlug,
    'bobgoServiceLevelCode': rate.serviceLevelCode,
  };
}

/// Failure requesting rates, already phrased for the buyer.
class BobGoQuoteException implements Exception {
  final String message;
  const BobGoQuoteException(this.message);

  @override
  String toString() => message;
}
