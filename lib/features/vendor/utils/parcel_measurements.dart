/// Packed parcel weight and size for courier (Bob Go) quotes. Stored on
/// products as shipping_weight_kg / shipping_length_cm / shipping_width_cm /
/// shipping_height_cm; the database requires each to be > 0 when present.
class ParcelMeasurements {
  final double? weightKg;
  final double? lengthCm;
  final double? widthCm;
  final double? heightCm;

  const ParcelMeasurements({
    this.weightKg,
    this.lengthCm,
    this.widthCm,
    this.heightCm,
  });

  bool get isEmpty =>
      weightKg == null &&
      lengthCm == null &&
      widthCm == null &&
      heightCm == null;

  bool get isComplete =>
      weightKg != null &&
      lengthCm != null &&
      widthCm != null &&
      heightCm != null;

  Map<String, dynamic> toProductJson() => {
    'shipping_weight_kg': weightKg,
    'shipping_length_cm': lengthCm,
    'shipping_width_cm': widthCm,
    'shipping_height_cm': heightCm,
  };
}

const maxParcelWeightKg = 70.0;
const maxParcelSideCm = 200.0;

/// Accepts "1.5" or "1,5"; returns null for blank or unparseable text.
double? parseParcelNumber(String? text) {
  final cleaned = (text ?? '').trim().replaceAll(',', '.');
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}

/// Validation result: [error] is a buyer/vendor-facing message, or null.
class ParcelMeasurementsResult {
  final ParcelMeasurements measurements;
  final String? error;
  const ParcelMeasurementsResult(this.measurements, this.error);
}

/// Parses the four form fields. All four are optional together (courier
/// delivery simply isn't quotable for the product), but a partial or
/// non-positive entry is an error.
ParcelMeasurementsResult parseParcelMeasurements({
  required String weightKg,
  required String lengthCm,
  required String widthCm,
  required String heightCm,
}) {
  final texts = [weightKg, lengthCm, widthCm, heightCm];
  final parsed = texts.map(parseParcelNumber).toList(growable: false);
  final measurements = ParcelMeasurements(
    weightKg: parsed[0],
    lengthCm: parsed[1],
    widthCm: parsed[2],
    heightCm: parsed[3],
  );

  final anyText = texts.any((t) => t.trim().isNotEmpty);
  if (!anyText) return ParcelMeasurementsResult(measurements, null);

  final badNumber = List.generate(
    4,
    (i) => texts[i].trim().isNotEmpty && parsed[i] == null,
  ).any((bad) => bad);
  if (badNumber) {
    return const ParcelMeasurementsResult(
      ParcelMeasurements(),
      'Packed weight and size must be numbers.',
    );
  }
  if (!measurements.isComplete) {
    return ParcelMeasurementsResult(
      measurements,
      'Add the packed weight, length, width and height together, or leave all four blank.',
    );
  }
  if (parsed.any((v) => v! <= 0)) {
    return ParcelMeasurementsResult(
      measurements,
      'Packed weight and size must be greater than zero.',
    );
  }
  if (parsed[0]! > maxParcelWeightKg ||
      parsed.skip(1).any((v) => v! > maxParcelSideCm)) {
    return ParcelMeasurementsResult(
      measurements,
      'That parcel is too large for standard courier delivery. Check the weight (kg) and sizes (cm).',
    );
  }
  return ParcelMeasurementsResult(measurements, null);
}
