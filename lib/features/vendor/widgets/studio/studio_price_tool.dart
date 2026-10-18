import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/theme.dart';
import '../../services/artisan_ai_service.dart';
import 'studio_ui.dart';

/// Cost-based price calculator: materials + labour + overheads, then the
/// seller's target margin on top (see [suggestedListingPrice]). Works fully
/// offline; nothing here is AI.
class StudioPriceTool extends StatefulWidget {
  const StudioPriceTool({super.key, required this.onUsePrice});

  final ValueChanged<double> onUsePrice;

  @override
  State<StudioPriceTool> createState() => _StudioPriceToolState();
}

class _StudioPriceToolState extends State<StudioPriceTool> {
  final _materials = TextEditingController();
  final _labour = TextEditingController();
  final _overheads = TextEditingController();
  final _margin = TextEditingController(text: '35');

  static final _formatters = <TextInputFormatter>[
    FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
  ];

  @override
  void dispose() {
    for (final c in [_materials, _labour, _overheads, _margin]) {
      c.dispose();
    }
    super.dispose();
  }

  double _read(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.')) ?? double.nan;

  String _money(double value) => 'R${value.toStringAsFixed(2)}';

  Widget _field(
    TextEditingController controller,
    String label, {
    String? helper,
    bool percent = false,
    TextInputAction action = TextInputAction.next,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: _formatters,
      textInputAction: action,
      onChanged: (_) => setState(() {}),
      style: GoogleFonts.poppins(fontSize: 15, color: AppTheme.textPrimary),
      decoration: studioInputDecoration(
        label,
        helper: helper,
        prefix: percent ? null : 'R ',
        suffix: percent ? '%' : null,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final materials = _read(_materials);
    final labour = _read(_labour);
    final overheads = _read(_overheads);
    final margin = _read(_margin);
    final price = suggestedListingPrice(
      materials: materials,
      labour: labour,
      overheads: overheads,
      margin: margin,
    );
    final costs = price == null ? 0.0 : materials + labour + overheads;

    return StudioToolLayout(
      actionBar: StudioActionBar(
        label: price == null
            ? 'Enter your costs'
            : 'Use ${_money(price)} as my price',
        icon: price == null ? null : Icons.check_rounded,
        onPressed: price == null
            ? null
            : () => widget.onUsePrice(double.parse(price.toStringAsFixed(2))),
      ),
      children: [
        const StudioIntro(
          title: 'Price calculator',
          body:
              'Add up what one piece costs you to make, choose your margin, '
              'and get a suggested price.',
        ),
        StudioCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const StudioLabel('Costs for one piece'),
              const SizedBox(height: 12),
              _field(_materials, 'Materials'),
              _field(
                _labour,
                'Your time',
                helper: 'What you pay yourself for the hours on one piece.',
              ),
              _field(_overheads, 'Packaging & other costs'),
              const StudioLabel('Your margin'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final preset in const [25, 35, 50])
                    ChoiceChip(
                      label: Text('$preset%'),
                      selected: margin == preset,
                      onSelected: (_) {
                        FocusScope.of(context).unfocus();
                        setState(() => _margin.text = preset.toString());
                      },
                      selectedColor: AppTheme.terracotta.withValues(alpha: .12),
                      side: BorderSide(
                        color: margin == preset
                            ? AppTheme.terracotta
                            : AppTheme.sand,
                      ),
                      labelStyle: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: margin == preset
                            ? AppTheme.terracotta
                            : AppTheme.textPrimary,
                      ),
                      showCheckmark: false,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _field(
                _margin,
                'Margin',
                percent: true,
                action: TextInputAction.done,
                helper: 'The share of the price you keep after costs.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        StudioCard(
          child: price == null
              ? Row(
                  key: const Key('studio-price-empty'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Icon(
                      Icons.calculate_outlined,
                      color: AppTheme.terracotta,
                      size: 22,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: StudioNote(
                        'Enter your costs (use 0 if something doesn\'t '
                        'apply) and a margin below 100% to see a suggested '
                        'price.',
                      ),
                    ),
                  ],
                )
              : Column(
                  key: const Key('studio-price-result'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SUGGESTED PRICE',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.3,
                        color: AppTheme.terracotta,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _money(price),
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _breakdownRow('Costs per piece', _money(costs)),
                    _breakdownRow(
                      'Your margin (${_trim(margin)}%)',
                      _money(price - costs),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 14),
        const StudioCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 20,
                color: AppTheme.textSecondary,
              ),
              SizedBox(width: 10),
              Expanded(
                child: StudioNote(
                  'This is a cost-based guide, not a market valuation. It '
                  'doesn\'t include delivery, fees or tax you haven\'t entered, '
                  'so compare it with similar pieces and adjust if you need to.',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _trim(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);

  Widget _breakdownRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      children: [
        Expanded(child: StudioNote(label)),
        const SizedBox(width: 8),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    ),
  );
}
