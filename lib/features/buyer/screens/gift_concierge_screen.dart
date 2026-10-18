import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../core/ui/friendly_error.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/skeleton.dart';
import '../providers/buyer_providers.dart';
import '../providers/gift_finder_providers.dart';
import '../utils/shop_discovery_gift.dart';
import '../widgets/gift_result_card.dart';

/// Guided gift finder, pushed from the Shop tab's "Gift finder" shortcut.
///
/// Buyers answer who the gift is for, the occasion, a budget and (optionally)
/// what the person is into, then get a shortlist of real, buyable products
/// ranked on-device by [recommendGifts].
class GiftConciergeScreen extends ConsumerStatefulWidget {
  const GiftConciergeScreen({super.key});

  @override
  ConsumerState<GiftConciergeScreen> createState() =>
      _GiftConciergeScreenState();
}

class _GiftConciergeScreenState extends ConsumerState<GiftConciergeScreen> {
  final _scroll = ScrollController();
  GiftRecipient? _recipient;
  GiftOccasion? _occasion;
  GiftBudget? _budget;
  final Set<GiftInterest> _interests = {};
  bool _showResults = false;

  int get _missingAnswers =>
      [_recipient, _occasion, _budget].where((value) => value == null).length;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _setResults(bool show) {
    setState(() => _showResults = show);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  void _findGifts() {
    if (_missingAnswers > 0) return;
    HapticFeedback.mediumImpact();
    _setResults(true);
  }

  void _retry() {
    ref.invalidate(
      categoryProductsProvider(const CategoryProductFilter(categoryId: '')),
    );
    ref.invalidate(giftCatalogueProvider);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_showResults,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _showResults) _setResults(false);
      },
      child: Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
        appBar: AppBar(
          backgroundColor: AppTheme.scaffoldBg,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          leading: IconButton(
            tooltip: _showResults ? 'Back to questions' : 'Back',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(
            'Gift finder',
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        body: SafeArea(
          bottom: _showResults,
          child: SingleChildScrollView(
            key: const Key('gift-finder-scroll'),
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            child: _showResults ? _buildResults() : _buildQuestions(),
          ),
        ),
        bottomNavigationBar: _showResults ? null : _buildBottomBar(),
      ),
    );
  }

  Widget _buildQuestions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _GiftHeader(
          eyebrow: 'Handmade gifts',
          title: "Find a gift they'll love",
          subtitle:
              "Answer a few quick questions and we'll shortlist handmade "
              'pieces from our makers.',
        ),
        const SizedBox(height: 20),
        _StepCard(
          step: 1,
          title: "Who's it for?",
          answered: _recipient != null,
          child: _ChipWrap(
            children: [
              for (final value in GiftRecipient.values)
                _AnswerChip(
                  label: value.label,
                  icon: _recipientIcon(value),
                  selected: _recipient == value,
                  onTap: () => setState(() => _recipient = value),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _StepCard(
          step: 2,
          title: "What's the occasion?",
          answered: _occasion != null,
          child: _ChipWrap(
            children: [
              for (final value in GiftOccasion.values)
                _AnswerChip(
                  label: value.label,
                  icon: _occasionIcon(value),
                  selected: _occasion == value,
                  onTap: () => setState(() => _occasion = value),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _StepCard(
          step: 3,
          title: "What's your budget?",
          answered: _budget != null,
          child: _ChipWrap(
            children: [
              for (final value in GiftBudget.values)
                _AnswerChip(
                  label: value == GiftBudget.any ? 'Any budget' : value.label,
                  selected: _budget == value,
                  onTap: () => setState(() => _budget = value),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _StepCard(
          step: 4,
          title: 'What are they into?',
          subtitle: 'Optional. Pick as many as you like.',
          optional: true,
          answered: _interests.isNotEmpty,
          child: _ChipWrap(
            children: [
              for (final value in GiftInterest.values)
                _AnswerChip(
                  label: value.label,
                  icon: value.icon,
                  selected: _interests.contains(value),
                  onTap: () => setState(() {
                    if (!_interests.remove(value)) _interests.add(value);
                  }),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    final missing = _missingAnswers;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: GradientButton(
            key: const Key('gift-finder-submit'),
            label: missing == 0
                ? 'Show gift ideas'
                : 'Answer $missing more ${missing == 1 ? 'question' : 'questions'}',
            icon: missing == 0 ? Icons.card_giftcard_rounded : null,
            verticalPadding: 14,
            borderRadius: 26,
            fontSize: 15,
            onPressed: missing == 0 ? _findGifts : null,
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    final catalogue = ref.watch(giftCatalogueProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AnswersSummary(
          answers: [
            _recipient == GiftRecipient.home
                ? 'For the home'
                : 'For ${_recipient!.label.toLowerCase()}',
            _occasion!.label,
            _budget == GiftBudget.any ? 'Any budget' : _budget!.label,
            for (final interest in GiftInterest.values)
              if (_interests.contains(interest)) interest.label,
          ],
          onEdit: () => _setResults(false),
        ),
        const SizedBox(height: 20),
        catalogue.when(
          skipLoadingOnRefresh: false,
          loading: () => const _ResultsSkeleton(),
          error: (error, _) => Padding(
            padding: const EdgeInsets.only(top: 24),
            child: ErrorRetryView(
              error: error,
              title: "Couldn't load gift ideas",
              onRetry: _retry,
            ),
          ),
          data: (products) {
            final results = recommendGifts(
              products: products,
              recipient: _recipient!,
              occasion: _occasion!,
              budget: _budget!,
              interests: _interests,
            );
            if (results.isEmpty) return _buildEmpty();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        'Gift ideas',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
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
                const SizedBox(height: 4),
                Text(
                  'Picked from pieces you can buy today, best matches first.',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                _ResultsGrid(results: results),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    final canWiden = _budget != GiftBudget.any;
    return Padding(
      key: const Key('gift-finder-empty'),
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.bone,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.card_giftcard_outlined,
              size: 30,
              color: AppTheme.terracotta,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No matches yet',
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            canWiden
                ? 'No matches — try widening your budget.'
                : 'No matches — try a different occasion or who it\'s for.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              height: 1.45,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          if (canWiden)
            _PillButton(
              label: 'Widen my budget',
              filled: true,
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() => _budget = GiftBudget.any);
              },
            ),
          const SizedBox(height: 8),
          _PillButton(
            label: 'Change answers',
            filled: false,
            onPressed: () => _setResults(false),
          ),
        ],
      ),
    );
  }

  static IconData _recipientIcon(GiftRecipient value) => switch (value) {
    GiftRecipient.her => Icons.woman_outlined,
    GiftRecipient.him => Icons.man_outlined,
    GiftRecipient.kids => Icons.child_care_outlined,
    GiftRecipient.home => Icons.home_outlined,
    GiftRecipient.anyone => Icons.people_outline_rounded,
  };

  static IconData _occasionIcon(GiftOccasion value) => switch (value) {
    GiftOccasion.birthday => Icons.cake_outlined,
    GiftOccasion.thankYou => Icons.volunteer_activism_outlined,
    GiftOccasion.wedding => Icons.favorite_border_rounded,
    GiftOccasion.justBecause => Icons.wb_sunny_outlined,
  };
}

class _GiftHeader extends StatelessWidget {
  const _GiftHeader({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow.toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.3,
              color: AppTheme.terracotta,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.playfairDisplay(
              fontSize: 27,
              height: 1.15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 13,
              height: 1.5,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.title,
    required this.answered,
    required this.child,
    this.subtitle,
    this.optional = false,
  });

  final int step;
  final String title;
  final String? subtitle;
  final bool answered;
  final bool optional;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: answered
              ? AppTheme.terracotta.withValues(alpha: .35)
              : AppTheme.sand.withValues(alpha: .45),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: answered ? AppTheme.terracotta : AppTheme.bone,
                ),
                child: answered
                    ? const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: Colors.white,
                      )
                    : Text(
                        '$step',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.terracotta,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        title,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 8, runSpacing: 8, children: children);
}

class _AnswerChip extends StatelessWidget {
  const _AnswerChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.terracotta : AppTheme.textPrimary;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(24),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.terracotta.withValues(alpha: .10)
                  : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: selected
                    ? AppTheme.terracotta
                    : AppTheme.sand.withValues(alpha: .7),
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnswersSummary extends StatelessWidget {
  const _AnswersSummary({required this.answers, required this.onEdit});

  final List<String> answers;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.sand.withValues(alpha: .45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YOUR ANSWERS',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.3,
                    color: AppTheme.terracotta,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final answer in answers)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.bone.withValues(alpha: .7),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          answer,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onEdit,
            style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
            child: Text(
              'Edit',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.terracotta,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

int _columnsFor(double width) => width >= 900
    ? 4
    : width >= 600
    ? 3
    : 2;

/// Rows of equal-width cards. Each row sizes to its tallest card, so large
/// text never clips the way a fixed-extent grid would.
class _ResultsGrid extends StatelessWidget {
  const _ResultsGrid({required this.results});
  final List<GiftRecommendation> results;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnsFor(constraints.maxWidth);
        final rows = <Widget>[];
        for (var start = 0; start < results.length; start += columns) {
          final cells = <Widget>[];
          for (var i = 0; i < columns; i++) {
            if (i > 0) cells.add(const SizedBox(width: 12));
            final index = start + i;
            cells.add(
              Expanded(
                child: index < results.length
                    ? GiftResultCard(
                        key: ValueKey('gift-${results[index].product.id}'),
                        recommendation: results[index],
                      )
                    : const SizedBox.shrink(),
              ),
            );
          }
          if (rows.isNotEmpty) rows.add(const SizedBox(height: 14));
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: cells,
              ),
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }
}

class _ResultsSkeleton extends StatelessWidget {
  const _ResultsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      key: const Key('gift-finder-loading'),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = _columnsFor(constraints.maxWidth);
          final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
          Widget card() => SizedBox(
            width: width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: width, height: width, radius: 18),
                const SizedBox(height: 10),
                SkeletonBox(width: width * .5, height: 12),
                const SizedBox(height: 8),
                SkeletonBox(width: width * .85, height: 14),
                const SizedBox(height: 8),
                SkeletonBox(width: width * .35, height: 16),
              ],
            ),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SkeletonBox(width: 140, height: 22),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 18,
                children: [for (var i = 0; i < columns * 2; i++) card()],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.filled,
    required this.onPressed,
  });

  final String label;
  final bool filled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(26),
    );
    final text = Text(
      label,
      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 200),
      child: filled
          ? FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.terracotta,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 48),
                shape: shape,
              ),
              child: text,
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.terracotta,
                side: const BorderSide(color: AppTheme.terracotta),
                minimumSize: const Size(0, 48),
                shape: shape,
              ),
              child: text,
            ),
    );
  }
}
