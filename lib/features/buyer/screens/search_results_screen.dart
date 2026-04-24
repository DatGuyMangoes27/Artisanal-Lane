import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme.dart';
import '../../../widgets/product_card.dart';
import '../providers/buyer_providers.dart';
import '../utils/search_results_layout.dart';

class SearchResultsScreen extends ConsumerStatefulWidget {
  final String query;

  const SearchResultsScreen({super.key, required this.query});

  @override
  ConsumerState<SearchResultsScreen> createState() =>
      _SearchResultsScreenState();
}

class _SearchResultsScreenState extends ConsumerState<SearchResultsScreen> {
  int _selectedFilter = 0;
  int _selectedSort = 0;

  static const _filterLabels = [
    'All',
    'Under R200',
    'R200 – R500',
    'Over R500',
    'On Sale',
  ];

  static const _filterIcons = [
    null,
    null,
    null,
    null,
    Icons.local_offer_outlined,
  ];

  static const _sortLabels = ['Newest', 'Price ↑', 'Price ↓', 'Popular'];

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchProductsProvider(widget.query));

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg, // White
      body: SafeArea(
        child: Column(
          children: [
            // ── Custom Header ──────────────────────────────────
            _buildHeader(context),

            // ── Filter Chips ───────────────────────────────────
            _buildFilterChips(),

            const SizedBox(height: 16),

            // ── Results Body ───────────────────────────────────
            Expanded(
              child: results.when(
                data: (items) {
                  if (items.isEmpty) {
                    return _buildEmptyState();
                  }
                  return Column(
                    children: [
                      // Count + Sort row
                      _buildCountAndSortRow(items.length),

                      const SizedBox(height: 12),

                      // Product grid
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 0.65,
                          ),
                          itemCount: items.length,
                          itemBuilder: (context, index) =>
                              ProductCard(product: items[index]),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.terracotta,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Searching the market…',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: AppTheme.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
                error: (error, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.cloud_off_rounded,
                            color: AppTheme.terracotta,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Something went wrong',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$error',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  Custom Header
  // ═══════════════════════════════════════════════════════════════
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        children: [
          // Back button – white rounded container, indigo icon
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppTheme.sand.withValues(alpha: 0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: AppTheme.textPrimary,
                size: 20,
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Title & subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Results',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '"${widget.query}"',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  Filter Chips
  // ═══════════════════════════════════════════════════════════════
  Widget _buildFilterChips() {
    return SizedBox(
      height: searchResultsChipRailHeight,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: searchResultsChipRailVerticalPadding,
        ),
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: _filterLabels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final selected = _selectedFilter == index;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              constraints: const BoxConstraints(
                minHeight: searchResultsChipMinHeight,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: searchResultsChipVerticalInset,
              ),
              decoration: BoxDecoration(
                color: selected ? AppTheme.terracotta : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: selected
                      ? AppTheme.terracotta
                      : AppTheme.sand.withValues(alpha: 0.3),
                  width: 1,
                ),
                boxShadow: [
                  if (!selected)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_filterIcons[index] != null) ...[
                    Icon(
                      _filterIcons[index],
                      size: 16,
                      color: selected ? Colors.white : AppTheme.textPrimary,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    _filterLabels[index],
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: searchResultsChipTextHeight,
                      color: selected ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  Count + Sort Row
  // ═══════════════════════════════════════════════════════════════
  Widget _buildCountAndSortRow(int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$count items found',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w400,
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedSort = (_selectedSort + 1) % _sortLabels.length;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.sort_rounded,
                    size: 16,
                    color: AppTheme.textPrimary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _sortLabels[_selectedSort],
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  Empty State
  // ═══════════════════════════════════════════════════════════════
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon in a decorative container
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.storefront_outlined,
                size: 40,
                color: AppTheme.terracotta,
              ),
            ),

            const SizedBox(height: 32),

            Text(
              'No treasures found',
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              'Try different keywords or browse\nour curated collections',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
