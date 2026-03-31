import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme.dart';
import '../../../models/models.dart';
import '../../../widgets/african_patterns.dart';
import '../../../widgets/product_card.dart';
import '../providers/buyer_providers.dart';

class CategoryProductsScreen extends ConsumerStatefulWidget {
  final String categoryId;
  final String categoryName;

  const CategoryProductsScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  ConsumerState<CategoryProductsScreen> createState() =>
      _CategoryProductsScreenState();
}

class _CategoryProductsScreenState
    extends ConsumerState<CategoryProductsScreen> {
  String? _selectedSubcategoryId;
  final Set<String> _selectedTags = {};
  bool _onSale = false;
  bool _featured = false;
  String _sortBy = 'created_at';
  bool _ascending = false;
  String _sortLabel = 'Newest';

  CategoryProductFilter get _filter => CategoryProductFilter(
        categoryId: widget.categoryId,
        subcategoryId: _selectedSubcategoryId,
        tags: _selectedTags.toList(),
        onSale: _onSale,
        featured: _featured,
        sortBy: _sortBy,
        ascending: _ascending,
      );

  int get _activeFilterCount {
    int count = 0;
    if (_selectedSubcategoryId != null) count++;
    count += _selectedTags.length;
    if (_onSale) count++;
    if (_featured) count++;
    if (_sortBy != 'created_at' || _ascending) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final subcategoriesAsync =
        ref.watch(subcategoriesProvider(widget.categoryId));
    final productsAsync = ref.watch(categoryProductsProvider(_filter));

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context)),

            // Filter button + count row
            productsAsync.when(
              data: (items) => SliverToBoxAdapter(
                child: _buildFilterBar(items.length, subcategoriesAsync),
              ),
              loading: () => SliverToBoxAdapter(
                child: _buildFilterBar(0, subcategoriesAsync),
              ),
              error: (_, __) => SliverToBoxAdapter(
                child: _buildFilterBar(0, subcategoriesAsync),
              ),
            ),

            // Product grid
            productsAsync.when(
              data: (items) => items.isEmpty
                  ? SliverFillRemaining(child: _buildEmptyState())
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.65,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) =>
                              ProductCard(product: items[index]),
                          childCount: items.length,
                        ),
                      ),
                    ),
              loading: () => const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.terracotta,
                    strokeWidth: 3,
                  ),
                ),
              ),
              error: (error, _) => SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Error: $error',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 24, bottom: 40),
                child: Center(child: TripleDot()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _resolveCategorySlug() {
    final cats = ref.read(categoriesProvider).value ?? [];
    final match = cats.where((c) => c.id == widget.categoryId).firstOrNull;
    return match?.slug ?? '';
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
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
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.categoryName,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Explore handcrafted pieces',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppTheme.textHint,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(
    int count,
    AsyncValue<List<Subcategory>> subcategoriesAsync,
  ) {
    final badgeCount = _activeFilterCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _openFilterSheet(subcategoriesAsync),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: badgeCount > 0
                    ? AppTheme.terracotta.withValues(alpha: 0.08)
                    : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: badgeCount > 0
                      ? AppTheme.terracotta
                      : AppTheme.sand.withValues(alpha: 0.3),
                ),
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
                    Icons.tune_rounded,
                    size: 18,
                    color: badgeCount > 0
                        ? AppTheme.terracotta
                        : AppTheme.textPrimary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Filter',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: badgeCount > 0
                          ? AppTheme.terracotta
                          : AppTheme.textPrimary,
                    ),
                  ),
                  if (badgeCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: AppTheme.terracotta,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$badgeCount',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Spacer(),
          if (count > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.bone,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count ${count == 1 ? 'piece' : 'pieces'}',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openFilterSheet(AsyncValue<List<Subcategory>> subcategoriesAsync) {
    final categorySlug = _resolveCategorySlug();
    final filterTags = Category.filterTags[categorySlug] ?? [];
    final subcategories = subcategoriesAsync.value ?? [];

    String? tempSubcategoryId = _selectedSubcategoryId;
    final tempTags = Set<String>.from(_selectedTags);
    bool tempOnSale = _onSale;
    bool tempFeatured = _featured;
    String tempSortBy = _sortBy;
    bool tempAscending = _ascending;
    String tempSortLabel = _sortLabel;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.72,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            builder: (ctx, scrollController) => Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                12,
                24,
                24 + MediaQuery.of(ctx).padding.bottom,
              ),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.sand,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Filter & Sort',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Sort by
                  Text(
                    'Sort by',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _sheetChip('Newest', tempSortLabel == 'Newest', () {
                        setSheetState(() {
                          tempSortBy = 'created_at';
                          tempAscending = false;
                          tempSortLabel = 'Newest';
                        });
                      }),
                      _sheetChip('Price: Low to High', tempSortLabel == 'Price ↑', () {
                        setSheetState(() {
                          tempSortBy = 'price';
                          tempAscending = true;
                          tempSortLabel = 'Price ↑';
                        });
                      }),
                      _sheetChip('Price: High to Low', tempSortLabel == 'Price ↓', () {
                        setSheetState(() {
                          tempSortBy = 'price';
                          tempAscending = false;
                          tempSortLabel = 'Price ↓';
                        });
                      }),
                      _sheetChip('Name: A–Z', tempSortLabel == 'A–Z', () {
                        setSheetState(() {
                          tempSortBy = 'title';
                          tempAscending = true;
                          tempSortLabel = 'A–Z';
                        });
                      }),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Subcategory
                  if (subcategories.isNotEmpty) ...[
                    Text(
                      'Subcategory',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _sheetChip('All', tempSubcategoryId == null, () {
                          setSheetState(() => tempSubcategoryId = null);
                        }),
                        ...subcategories.map((s) => _sheetChip(
                              s.name,
                              tempSubcategoryId == s.id,
                              () => setSheetState(
                                  () => tempSubcategoryId = s.id),
                            )),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Quick filters
                  Text(
                    'Quick Filters',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _sheetChip(
                        'On Sale',
                        tempOnSale,
                        () => setSheetState(() => tempOnSale = !tempOnSale),
                        icon: Icons.local_offer_outlined,
                      ),
                      _sheetChip(
                        'Featured',
                        tempFeatured,
                        () => setSheetState(
                            () => tempFeatured = !tempFeatured),
                        icon: Icons.star_outline_rounded,
                      ),
                    ],
                  ),

                  // Category-specific tags
                  if (filterTags.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Material / Type',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: filterTags.map((tag) {
                        final sel = tempTags.contains(tag);
                        return _sheetChip(
                          tag[0].toUpperCase() + tag.substring(1),
                          sel,
                          () => setSheetState(() {
                            if (sel) {
                              tempTags.remove(tag);
                            } else {
                              tempTags.add(tag);
                            }
                          }),
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setSheetState(() {
                              tempSubcategoryId = null;
                              tempTags.clear();
                              tempOnSale = false;
                              tempFeatured = false;
                              tempSortBy = 'created_at';
                              tempAscending = false;
                              tempSortLabel = 'Newest';
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(
                                color: AppTheme.sand.withValues(alpha: 0.5)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            'Clear All',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedSubcategoryId = tempSubcategoryId;
                              _selectedTags
                                ..clear()
                                ..addAll(tempTags);
                              _onSale = tempOnSale;
                              _featured = tempFeatured;
                              _sortBy = tempSortBy;
                              _ascending = tempAscending;
                              _sortLabel = tempSortLabel;
                            });
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.terracotta,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            'Apply Filters',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sheetChip(String label, bool selected, VoidCallback onTap,
      {IconData? icon}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.terracotta.withValues(alpha: 0.1)
              : AppTheme.bone.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppTheme.terracotta
                : AppTheme.sand.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14,
                  color: selected ? AppTheme.terracotta : AppTheme.textHint),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color:
                    selected ? AppTheme.terracotta : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
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
              'No Pieces Yet',
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Handcrafted items in this category\nwill appear here soon.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.textHint,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
