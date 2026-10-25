import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../models/shop_fulfillment_profile.dart';

const _provinces = <String>[
  'Eastern Cape',
  'Free State',
  'Gauteng',
  'KwaZulu-Natal',
  'Limpopo',
  'Mpumalanga',
  'Northern Cape',
  'North West',
  'Western Cape',
];

/// "Courier delivery (Bob Go)" card for vendor shop settings: private
/// collection address, contact and the enable switch. Saves on its own so it
/// never blocks the rest of the shop form. Presentational: [onSave] does the
/// network work.
class BobGoCollectionSection extends StatefulWidget {
  const BobGoCollectionSection({
    super.key,
    required this.shopId,
    required this.initial,
    required this.onSave,
  });

  final String shopId;
  final ShopFulfillmentProfile? initial;
  final Future<void> Function(ShopFulfillmentProfile profile) onSave;

  @override
  State<BobGoCollectionSection> createState() => _BobGoCollectionSectionState();
}

class _BobGoCollectionSectionState extends State<BobGoCollectionSection> {
  late final _name = TextEditingController(
    text: widget.initial?.contactFullName,
  );
  late final _email = TextEditingController(text: widget.initial?.contactEmail);
  late final _phone = TextEditingController(text: widget.initial?.contactPhone);
  late final _company = TextEditingController(text: widget.initial?.company);
  late final _street = TextEditingController(
    text: widget.initial?.streetAddress,
  );
  late final _suburb = TextEditingController(text: widget.initial?.localArea);
  late final _city = TextEditingController(text: widget.initial?.city);
  late final _postal = TextEditingController(text: widget.initial?.postalCode);
  late String? _province = _provinces.contains(widget.initial?.province)
      ? widget.initial!.province
      : null;
  late bool _enabled = widget.initial?.bobgoEnabled ?? false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _name,
      _email,
      _phone,
      _company,
      _street,
      _suburb,
      _city,
      _postal,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  ShopFulfillmentProfile _draft() => ShopFulfillmentProfile(
    shopId: widget.shopId,
    contactFullName: _name.text,
    contactEmail: _email.text,
    contactPhone: _phone.text,
    company: _company.text,
    streetAddress: _street.text,
    localArea: _suburb.text,
    city: _city.text,
    province: _province ?? '',
    postalCode: _postal.text,
    bobgoEnabled: _enabled,
  );

  Future<void> _save() async {
    final draft = _draft();
    // Details are only mandatory once Bob Go is on or an address was started.
    final startedAddress = draft.streetAddress.trim().isNotEmpty;
    final problem = (_enabled || startedAddress) ? draft.validate() : null;
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    if (!_enabled && !startedAddress) {
      setState(() => _error = null);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(draft);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'We could not save these details. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Colors.white,
    labelStyle: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textHint),
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

  Widget _field(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
    Key? fieldKey,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      key: fieldKey,
      controller: controller,
      keyboardType: keyboardType,
      // "Next" moves down the form; the screen keeps each focused field in
      // view above the keyboard (RevealFocusedField in shop settings).
      textInputAction: TextInputAction.next,
      style: GoogleFonts.poppins(fontSize: 15, color: AppTheme.textPrimary),
      decoration: _decoration(label),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('bobgo-collection-section'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.sand.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Courier delivery (Bob Go)',
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Let buyers choose door-to-door courier delivery. The courier collects from the address below, which is never shown to buyers. Each product also needs its packed weight and size.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              height: 1.5,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Material(
            type: MaterialType.transparency,
            child: SwitchListTile.adaptive(
              key: const ValueKey('bobgo-enabled-switch'),
              contentPadding: EdgeInsets.zero,
              activeTrackColor: AppTheme.terracotta,
              title: Text(
                'Offer Bob Go delivery',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              value: _enabled,
              onChanged: (value) => setState(() => _enabled = value),
            ),
          ),
          const SizedBox(height: 8),
          _field('Contact name', _name, fieldKey: const ValueKey('bobgo-name')),
          _field(
            'Contact email',
            _email,
            keyboardType: TextInputType.emailAddress,
            fieldKey: const ValueKey('bobgo-email'),
          ),
          _field(
            'Contact phone',
            _phone,
            keyboardType: TextInputType.phone,
            fieldKey: const ValueKey('bobgo-phone'),
          ),
          _field('Business name (optional)', _company),
          _field(
            'Collection street address',
            _street,
            fieldKey: const ValueKey('bobgo-street'),
          ),
          _field('Suburb', _suburb, fieldKey: const ValueKey('bobgo-suburb')),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _field(
                  'City',
                  _city,
                  fieldKey: const ValueKey('bobgo-city'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _field(
                  'Postal code',
                  _postal,
                  keyboardType: TextInputType.number,
                  fieldKey: const ValueKey('bobgo-postal'),
                ),
              ),
            ],
          ),
          DropdownButtonFormField<String>(
            key: const ValueKey('bobgo-province'),
            initialValue: _province,
            isExpanded: true,
            decoration: _decoration('Province'),
            items: _provinces
                .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                .toList(growable: false),
            onChanged: (value) => setState(() => _province = value),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              key: const ValueKey('bobgo-collection-error'),
              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.error),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              key: const ValueKey('bobgo-collection-save'),
              onPressed: _saving ? null : _save,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.terracotta,
                side: const BorderSide(color: AppTheme.terracotta),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.terracotta,
                      ),
                    )
                  : Text(
                      'Save courier details',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
