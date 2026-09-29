import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../core/ui/friendly_error.dart';
import '../providers/buyer_providers.dart';
import '../utils/shop_discovery_gift.dart';
import '../widgets/shop_product_tile.dart';

/// A three-step gift finder pushed from the Shop tab's Gift Concierge card.
/// Buyers pick who the gift is for, the occasion, and a budget, and get a
/// curated shortlist built with a small, transparent local ranking
/// ([rankGiftConciergeProducts]) over the already-loaded catalogue.
class GiftConciergeScreen extends ConsumerStatefulWidget {
  const GiftConciergeScreen({super.key});

  @override
  ConsumerState<GiftConciergeScreen> createState() =>
      _GiftConciergeScreenState();
}

class _GiftConciergeScreenState extends ConsumerState<GiftConciergeScreen> {
  GiftRecipient? _recipient;
  GiftOccasion? _occasion;
  GiftBudget? _budget;

  bool get _hasAnswers =>
      _recipient != null && _occasion != null && _budget != null;

  void _changeAnswers() {
    HapticFeedback.selectionClick();
    setState(() {
      _recipient = null;
      _occasion = null;
      _budget = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBg,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Gift concierge',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        actions: [
          if (_hasAnswers)
            TextButton(
              onPressed: _changeAnswers,
              child: Text(
                'Change answers',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppTheme.terracotta,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Answer three quick questions and we\'ll pull together a '
                'shortlist worth giving.',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              _StepSection<GiftRecipient>(
                stepNumber: 1,
                title: 'Who\'s it for?',
                values: GiftRecipient.values,
                labelOf: (value) => value.label,
                selected: _recipient,
                onSelected: (value) => setState(() => _recipient = value),
              ),
              const SizedBox(height: 24),
              _StepSection<GiftOccasion>(
                stepNumber: 2,
                title: 'What\'s the occasion?',
                values: GiftOccasion.values,
                labelOf: (value) => value.label,
                selected: _occasion,
                onSelected: (value) => setState(() => _occasion = value),
              ),
              const SizedBox(height: 24),
              _StepSection<GiftBudget>(
                stepNumber: 3,
                title: 'What\'s the budget?',
                values: GiftBudget.values,
                labelOf: (value) => value.label,
                selected: _budget,
                onSelected: (value) => setState(() => _budget = value),
              ),
              const SizedBox(height: 28),
              if (_hasAnswers) _buildResults(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    final catalogueAsync = ref.watch(
      categoryProductsProvider(const CategoryProductFilter(categoryId: '')),
    );

    return catalogueAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: CircularProgressIndicator(color: AppTheme.terracotta),
        ),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: ErrorRetryView(
          error: error,
          title: "Couldn't load gift ideas",
          onRetry: () => ref.invalidate(
            categoryProductsProvider(
              const CategoryProductFilter(categoryId: ''),
            ),
          ),
        ),
      ),
      data: (products) {
        final results = rankGiftConciergeProducts(
          products: products,
          recipient: _recipient!,
          occasion: _occasion!,
          budget: _budget!,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    'Curated for ${_recipient!.label.toLowerCase()}',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 21,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '${results.length} ${results.length == 1 ? 'idea' : 'ideas'}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (results.isEmpty)
              _buildEmptyState(context)
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 18,
                  crossAxisSpacing: 14,
                  mainAxisExtent:
                      (MediaQuery.of(context).size.width - 40 - 14) / 2 / .9 +
                      shopProductDetailsHeight(
                        MediaQuery.textScalerOf(context),
                      ),
                ),
                itemCount: results.length,
                itemBuilder: (context, index) => ShopProductTile(
                  key: ValueKey('gift-${results[index].id}'),
                  product: results[index],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final widerBudget = _budget != GiftBudget.any;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          const Icon(
            Icons.card_giftcard_outlined,
            size: 32,
            color: AppTheme.textHint,
          ),
          const SizedBox(height: 12),
          Text(
            'Nothing quite fits yet',
            style: GoogleFonts.playfairDisplay(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widerBudget
                ? 'Try a wider budget to see more pieces that could work.'
                : 'Try a different occasion or recipient to see more pieces.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
          if (widerBudget) ...[
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: () => setState(() => _budget = GiftBudget.any),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.terracotta,
                side: const BorderSide(color: AppTheme.terracotta),
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text('Widen the budget'),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepSection<T> extends StatelessWidget {
  const _StepSection({
    required this.stepNumber,
    required this.title,
    required this.values,
    required this.labelOf,
    required this.selected,
    required this.onSelected,
  });

  final int stepNumber;
  final String title;
  final List<T> values;
  final String Function(T value) labelOf;
  final T? selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 11,
              backgroundColor: AppTheme.terracotta,
              child: Text(
                '$stepNumber',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values
              .map(
                (value) => _AnswerChip(
                  label: labelOf(value),
                  selected: selected == value,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSelected(value);
                  },
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _AnswerChip extends StatelessWidget {
  const _AnswerChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.terracotta : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected
                ? AppTheme.terracotta
                : AppTheme.sand.withValues(alpha: .6),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? Colors.white : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}
