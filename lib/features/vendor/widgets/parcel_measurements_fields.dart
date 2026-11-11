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
    this.shopOffersBobGo,
  });

  final TextEditingController weightController;
  final TextEditingController lengthController;
  final TextEditingController widthController;
  final TextEditingController heightController;
  final String? errorText;

  /// Whether the shop has "Offer Bob Go delivery" on with its collection
  /// details saved. Null while loading or unknown, so no status is shown.
  final bool? shopOffersBobGo;

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

  Widget _status() {
    final on = shopOffersBobGo!;
    final color = on ? AppTheme.baobab : AppTheme.ochre;
    return Container(
      key: ValueKey(on ? 'bobgo-shop-on' : 'bobgo-shop-off'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            on ? Icons.check_circle_outline : Icons.info_outline,
            size: 18,
            color: on ? AppTheme.sienna : AppTheme.textPrimary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              on
                  ? 'Bob Go is on for your shop. Add the packed weight and size below and buyers can choose door-to-door delivery for this product.'
                  : 'Bob Go is off for your shop. Turn on "Offer Bob Go delivery" in Shop Settings and save your collection details, then add the packed size here.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                height: 1.45,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('parcel-measurements'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.terracotta.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.terracotta.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_shipping_outlined,
                  size: 20,
                  color: AppTheme.terracotta,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bob Go Door to Door',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      "Courier to the buyer's address, priced live at checkout",
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppTheme.textHint,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "No price to set here: Bob Go quotes the buyer at checkout. Enter this product's weight and size once packed (box and wrapping included). Leave blank if you do not want to courier it.",
            style: GoogleFonts.poppins(
              fontSize: 12,
              height: 1.45,
              color: AppTheme.textHint,
            ),
          ),
          if (shopOffersBobGo != null) ...[
            const SizedBox(height: 10),
            _status(),
          ],
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
      ),
    );
  }
}
