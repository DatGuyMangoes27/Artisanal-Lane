import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';

/// Packed weight/size inputs for courier delivery. Owned controllers live in
/// the product form so values save with the rest of the product.
class ParcelMeasurementsFields extends StatelessWidget {
  const ParcelMeasurementsFields({
    super.key,
    required this.weightController,
    required this.lengthController,
    required this.widthController,
    required this.heightController,
    this.errorText,
  });

  final TextEditingController weightController;
  final TextEditingController lengthController;
  final TextEditingController widthController;
  final TextEditingController heightController;
  final String? errorText;

  InputDecoration _decoration(String label, String suffix) => InputDecoration(
    labelText: label,
    suffixText: suffix,
    filled: true,
    fillColor: Colors.white,
    labelStyle: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textHint),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppTheme.sand.withValues(alpha: 0.5)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppTheme.sand.withValues(alpha: 0.5)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppTheme.terracotta, width: 1.5),
    ),
  );

  Widget _field(Key key, TextEditingController c, String label, String suffix) {
    return TextField(
      key: key,
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: GoogleFonts.poppins(fontSize: 15, color: AppTheme.textPrimary),
      decoration: _decoration(label, suffix),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('parcel-measurements'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Packed Parcel (courier delivery)',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Weight and size of this product once packed. Needed for door-to-door courier prices. Leave blank if you do not offer courier delivery for it.',
          style: GoogleFonts.poppins(
            fontSize: 12,
            height: 1.45,
            color: AppTheme.textHint,
          ),
        ),
        const SizedBox(height: 12),
        _field(
          const ValueKey('parcel-weight'),
          weightController,
          'Packed weight',
          'kg',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _field(
                const ValueKey('parcel-length'),
                lengthController,
                'Length',
                'cm',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _field(
                const ValueKey('parcel-width'),
                widthController,
                'Width',
                'cm',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _field(
                const ValueKey('parcel-height'),
                heightController,
                'Height',
                'cm',
              ),
            ),
          ],
        ),
        if (errorText != null) ...[
          const SizedBox(height: 8),
          Text(
            errorText!,
            key: const ValueKey('parcel-error'),
            style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.error),
          ),
        ],
      ],
    );
  }
}
