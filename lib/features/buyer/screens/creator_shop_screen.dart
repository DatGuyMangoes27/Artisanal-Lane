import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/tab_reselect.dart';
import '../../../app/theme.dart';
import '../../../core/ui/friendly_error.dart';
import '../../../models/models.dart';
import '../../../widgets/cart_nav_icon.dart';
import '../../../widgets/skeleton.dart';
import '../providers/buyer_providers.dart';
import '../widgets/creator_commerce_header.dart';
import '../utils/discovery_preferences.dart';
import '../utils/shop_discovery_location.dart';
import '../utils/shop_discovery_reasons.dart';
import '../widgets/shop_product_tile.dart';

/// On-device key for the buyer's chosen "Near me" area (a province or city
/// name from [saProvinces]/[saProvinceCities]). Not synced anywhere.
const _nearMeAreaPrefsKey = 'shop_near_me_area_v1';

enum CreatorShopFilter { forYou, allPieces, featured, newDrops, underR500 }

List<Product> filterCreatorShopProducts({
  required List<Product> products,
  required String query,
  required CreatorShopFilter filter,
  DiscoveryPreferences? preferences,
}) {
  final normalized = query.trim().toLowerCase();
  final filtered = products
      .where(
        (product) =>
            (filter != CreatorShopFilter.featured || product.isFeatured) &&
            (filter != CreatorShopFilter.underR500 || product.price < 500) &&
            (normalized.isEmpty ||
                product.title.toLowerCase().contains(normalized) ||
                (product.shopName ?? '').toLowerCase().contains(normalized)),
      )
      .toList(growable: false);
  if (filter == CreatorShopFilter.newDrops) {
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
  if (filter == CreatorShopFilter.forYou && preferences != null) {
    return rankDiscoverProducts(filtered, preferences);
  }
  return filtered;
}

/// Sort options for the Shop sort & filter sheet.
enum ShopSortOption { recommended, newest, priceLowHigh, priceHighLow }

extension ShopSortOptionLabel on ShopSortOption {
  String get label => switch (this) {
    ShopSortOption.recommended => 'Recommended',
    ShopSortOption.newest => 'Newest',
    ShopSortOption.priceLowHigh => 'Price low → high',
    ShopSortOption.priceHighLow => 'Price high → low',
  };
}

/// Applies the sort & filter sheet's sort, price range, category and
/// on-sale choices on top of an already-filtered product list. Pure and
/// unit-testable independently of the widget.
List<Product> applyShopSortAndFilters(
  List<Product> products, {
  ShopSortOption sort = ShopSortOption.recommended,
  RangeValues? priceRange,
  Set<String> categoryIds = const {},
  bool onSaleOnly = false,
}) {
  var result = products.where((product) {
    if (onSaleOnly &&
        !(product.compareAtPrice != null &&
            product.compareAtPrice! > product.price)) {
      return false;
    }
    if (categoryIds.isNotEmpty &&
        !(product.categoryId != null &&
            categoryIds.contains(product.categoryId))) {
      return false;
    }
    if (priceRange != null &&
        (product.price < priceRange.start || product.price > priceRange.end)) {
      return false;
    }
    return true;
  }).toList();

  switch (sort) {
    case ShopSortOption.recommended:
      break;
    case ShopSortOption.newest:
      result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      break;
    case ShopSortOption.priceLowHigh:
      result.sort((a, b) => a.price.compareTo(b.price));
      break;
    case ShopSortOption.priceHighLow:
      result.sort((a, b) => b.price.compareTo(a.price));
      break;
  }
  return result;
}

class CreatorShopScreen extends ConsumerStatefulWidget {
  const CreatorShopScreen({super.key});

  @override
  ConsumerState<CreatorShopScreen> createState() => _CreatorShopScreenState();
}

class _CreatorShopScreenState extends ConsumerState<CreatorShopScreen>
    with AutomaticKeepAliveClientMixin {
  static const _pageSize = 24;

  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _scrollController = ScrollController();
  Timer? _debounce;

  String _query = '';
  String _debouncedQuery = '';
  CreatorShopFilter _filter = CreatorShopFilter.forYou;
  ShopProductView _view = ShopProductView.twoCards;

  ShopSortOption _sort = ShopSortOption.recommended;
  RangeValues? _priceRange;
  Set<String> _categoryIds = {};
  bool _onSaleOnly = false;

  bool _nearMeOn = false;
  String? _nearMeArea;

  int _visibleCount = _pageSize;
  int _lastTotal = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    _loadNearMeArea();
  }

  Future<void> _loadNearMeArea() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_nearMeAreaPrefsKey);
    if (!mounted || saved == null || saved.trim().isEmpty) return;
    setState(() => _nearMeArea = saved);
  }

  Future<void> _saveNearMeArea(String? area) async {
    final prefs = await SharedPreferences.getInstance();
    if (area == null || area.trim().isEmpty) {
      await prefs.remove(_nearMeAreaPrefsKey);
    } else {
      await prefs.setString(_nearMeAreaPrefsKey, area);
    }
  }

  Future<void> _toggleNearMe() async {
    if (_nearMeArea == null) {
      final chosen = await _pickNearMeArea();
      if (chosen == null || !mounted) return;
      setState(() {
        _nearMeArea = chosen;
        _nearMeOn = true;
        _resetPaging();
      });
      await _saveNearMeArea(chosen);
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _nearMeOn = !_nearMeOn;
      _resetPaging();
    });
  }

  Future<void> _changeNearMeArea() async {
    final chosen = await _pickNearMeArea();
    if (chosen == null || !mounted) return;
    setState(() {
      _nearMeArea = chosen;
      _nearMeOn = true;
      _resetPaging();
    });
    await _saveNearMeArea(chosen);
  }

  Future<String?> _pickNearMeArea() {
    return showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Choose your area',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "We'll show pieces from makers near you.",
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final province in saProvinces) ...[
                    Text(
                      province,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          label: Text(
                            province,
                            style: GoogleFonts.poppins(fontSize: 12),
                          ),
                          backgroundColor: Colors.white,
                          side: BorderSide(
                            color: AppTheme.sand.withValues(alpha: 0.6),
                          ),
                          onPressed: () =>
                              Navigator.of(sheetContext).pop(province),
                        ),
                        for (final city
                            in saProvinceCities[province] ?? const <String>[])
                          ActionChip(
                            label: Text(
                              city,
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                            backgroundColor: AppTheme.cardBg,
                            side: BorderSide(
                              color: AppTheme.sand.withValues(alpha: 0.6),
                            ),
                            onPressed: () =>
                                Navigator.of(sheetContext).pop(city),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels > position.maxScrollExtent - 480 &&
        _visibleCount < _lastTotal) {
      setState(() => _visibleCount = _visibleCount + _pageSize);
    }
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _resetPaging() => _visibleCount = _pageSize;

  void _onSearchChanged(String value) {
    setState(() {
      _query = value;
      _resetPaging();
    });
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _debouncedQuery = value.trim());
    });
  }

  void _runSearch(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    ref.read(recentSearchesProvider.notifier).add(trimmed);
    _debounce?.cancel();
    setState(() {
      _query = trimmed;
      _debouncedQuery = trimmed;
      _resetPaging();
    });
    _searchFocusNode.unfocus();
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {
      _query = '';
      _debouncedQuery = '';
      _resetPaging();
    });
  }

  int get _activeAdvancedFilterCount =>
      (_sort != ShopSortOption.recommended ? 1 : 0) +
      (_priceRange != null ? 1 : 0) +
      _categoryIds.length +
      (_onSaleOnly ? 1 : 0);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cartItems = ref.watch(cartItemsProvider).value ?? const <CartItem>[];
    final preferences = ref.watch(discoveryPreferencesProvider).value;
    final categories =
        ref.watch(categoriesProvider).value ?? const <Category>[];
    final favouriteProducts =
        ref.watch(favouriteProductsProvider).value ?? const <Product>[];

    ref.listen<int>(tabReselectProvider(BuyerTab.shop), (_, __) {
      _scrollToTop();
    });

    final isSearching = _debouncedQuery.isNotEmpty;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: SafeArea(
        child: isSearching
            ? ref
                  .watch(shopSearchProductsProvider(_debouncedQuery))
                  .when(
                    loading: () => _buildSkeleton(context, cartItems),
                    error: (error, _) => Column(
                      children: [
                        _buildSearchBar(context),
                        Expanded(
                          child: ErrorRetryView(
                            error: error,
                            title: "Couldn't search right now",
                            onRetry: () => ref.invalidate(
                              shopSearchProductsProvider(_debouncedQuery),
                            ),
                          ),
                        ),
                      ],
                    ),
                    data: (results) => _buildScaffoldBody(
                      context,
                      baseProducts: results,
                      cartItems: cartItems,
                      categories: categories,
                      isSearchMode: true,
                      onRefresh: () => ref.refresh(
                        shopSearchProductsProvider(_debouncedQuery).future,
                      ),
                    ),
                  )
            : ref
                  .watch(
                    categoryProductsProvider(
                      const CategoryProductFilter(categoryId: ''),
                    ),
                  )
                  .when(
                    loading: () => _buildSkeleton(context, cartItems),
                    error: (error, _) => Column(
                      children: [
                        _buildSearchBar(context),
                        Expanded(
                          child: ErrorRetryView(
                            error: error,
                            title: "Couldn't load the shop",
                            onRetry: () => ref.invalidate(
                              categoryProductsProvider(
                                const CategoryProductFilter(categoryId: ''),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    data: (catalogueProducts) => _buildScaffoldBody(
                      context,
                      baseProducts: filterCreatorShopProducts(
                        products: catalogueProducts,
                        query: _query,
                        filter: _filter,
                        preferences: preferences,
                      ),
                      cartItems: cartItems,
                      categories: categories,
                      isSearchMode: false,
                      referenceProducts: [
                        ...catalogueProducts.where(
                          (product) =>
                              preferences?.likedProductIds.contains(
                                product.id,
                              ) ??
                              false,
                        ),
                        ...favouriteProducts,
                      ],
                      likedCategoryIds: preferences?.categoryIds ?? const {},
                      onRefresh: () => ref.refresh(
                        categoryProductsProvider(
                          const CategoryProductFilter(categoryId: ''),
                        ).future,
                      ),
                    ),
                  ),
      ),
    );
  }

  // ── Skeleton loading state ────────────────────────────────────────
  Widget _buildSkeleton(BuildContext context, List<CartItem> cartItems) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: CreatorCommerceHeader(
            eyebrow: 'Curated for you',
            title: 'Shop the lane',
            subtitle: 'Handmade pieces from local makers.',
            cartCount: cartBadgeCount(cartItems),
          ),
        ),
        SliverToBoxAdapter(child: _buildSearchBar(context)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 18,
              crossAxisSpacing: 14,
              childAspectRatio: 0.62,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => Skeleton(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: const [
                    Expanded(child: SkeletonBox(radius: 14)),
                    SizedBox(height: 10),
                    SkeletonBox(height: 10, width: 80),
                    SizedBox(height: 6),
                    SkeletonBox(height: 14),
                  ],
                ),
              ),
              childCount: 6,
            ),
          ),
        ),
      ],
    );
  }

  // ── Search bar (also used standalone above error/loading states) ──
  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: _onSearchChanged,
        onSubmitted: _runSearch,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Find something worth keeping',
          prefixIcon: const Icon(Icons.search_rounded),
          filled: true,
          fillColor: AppTheme.cardBg,
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: _clearSearch,
                ),
        ),
      ),
    );
  }

  // ── Search suggestions (recent + trending) ─────────────────────────
  Widget _buildSearchSuggestions(BuildContext context) {
    if (!_searchFocusNode.hasFocus || _query.isNotEmpty) {
      return const SizedBox.shrink();
    }
    final recent = ref.watch(recentSearchesProvider).value ?? const [];
    final trending = ref.watch(trendingSearchesProvider).value ?? const [];
    if (recent.isEmpty && trending.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (recent.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      ref.read(recentSearchesProvider.notifier).clear(),
                  child: Text(
                    'Clear',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.terracotta,
                    ),
                  ),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: recent
                  .map(
                    (term) => _SuggestionChip(
                      label: term,
                      icon: Icons.history_rounded,
                      onTap: () {
                        _searchController.text = term;
                        _runSearch(term);
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
          ],
          if (trending.isNotEmpty) ...[
            Text(
              'Trending',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: trending
                  .map(
                    (term) => _SuggestionChip(
                      label: term,
                      icon: Icons.trending_up_rounded,
                      onTap: () {
                        _searchController.text = term;
                        _runSearch(term);
                      },
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ── Sort & filter bottom sheet ─────────────────────────────────────
  Future<void> _openFilterSheet(List<Category> categories) async {
    var sort = _sort;
    var priceRange = _priceRange ?? const RangeValues(0, 2000);
    var hasPriceRange = _priceRange != null;
    var categoryIds = {..._categoryIds};
    var onSaleOnly = _onSaleOnly;

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.sand,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Text(
                      'Sort & Filter',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Sort by',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ShopSortOption.values
                          .map(
                            (option) => ChoiceChip(
                              label: Text(
                                option.label,
                                style: GoogleFonts.poppins(fontSize: 12),
                              ),
                              selected: sort == option,
                              onSelected: (_) =>
                                  setSheetState(() => sort = option),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Price range',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        Switch(
                          value: hasPriceRange,
                          onChanged: (val) =>
                              setSheetState(() => hasPriceRange = val),
                          activeThumbColor: AppTheme.terracotta,
                        ),
                      ],
                    ),
                    if (hasPriceRange) ...[
                      RangeSlider(
                        values: priceRange,
                        min: 0,
                        max: 5000,
                        divisions: 50,
                        activeColor: AppTheme.terracotta,
                        labels: RangeLabels(
                          'R${priceRange.start.round()}',
                          'R${priceRange.end.round()}',
                        ),
                        onChanged: (values) =>
                            setSheetState(() => priceRange = values),
                      ),
                      Text(
                        'R${priceRange.start.round()} – R${priceRange.end.round()}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (categories.isNotEmpty) ...[
                      Text(
                        'Categories',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: categories
                            .map(
                              (category) => FilterChip(
                                label: Text(
                                  category.name,
                                  style: GoogleFonts.poppins(fontSize: 12),
                                ),
                                selected: categoryIds.contains(category.id),
                                onSelected: (selected) => setSheetState(() {
                                  if (selected) {
                                    categoryIds.add(category.id);
                                  } else {
                                    categoryIds.remove(category.id);
                                  }
                                }),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                    ],
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'On sale only',
                        style: GoogleFonts.poppins(fontSize: 13),
                      ),
                      value: onSaleOnly,
                      activeThumbColor: AppTheme.terracotta,
                      onChanged: (val) => setSheetState(() => onSaleOnly = val),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setSheetState(() {
                                sort = ShopSortOption.recommended;
                                hasPriceRange = false;
                                priceRange = const RangeValues(0, 2000);
                                categoryIds = {};
                                onSaleOnly = false;
                              });
                            },
                            child: const Text('Reset'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.terracotta,
                              minimumSize: const Size.fromHeight(44),
                            ),
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            child: const Text('Apply'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted) return;
    setState(() {
      _sort = sort;
      _priceRange = hasPriceRange ? priceRange : null;
      _categoryIds = categoryIds;
      _onSaleOnly = onSaleOnly;
      _resetPaging();
    });
  }

  // ── Main scaffold body (shared by catalogue & search modes) ───────
  Widget _buildScaffoldBody(
    BuildContext context, {
    required List<Product> baseProducts,
    required List<CartItem> cartItems,
    required List<Category> categories,
    required bool isSearchMode,
    required Future<void> Function() onRefresh,
    List<Product> referenceProducts = const [],
    Set<String> likedCategoryIds = const {},
  }) {
    var products = applyShopSortAndFilters(
      baseProducts,
      sort: _sort,
      priceRange: _priceRange,
      categoryIds: _categoryIds,
      onSaleOnly: _onSaleOnly,
    );
    if (_nearMeOn && _nearMeArea != null) {
      products = filterNearArea(
        products,
        _nearMeArea,
        (product) => product.shopLocation,
      );
    }
    _lastTotal = products.length;
    final visibleProducts = products.take(_visibleCount).toList();
    final hasMore = _visibleCount < products.length;
    final showReasons =
        !isSearchMode && _query.isEmpty && _filter == CreatorShopFilter.forYou;
    String? reasonFor(Product product) => showReasons
        ? shopForYouReason(
            product: product,
            likedCategoryIds: likedCategoryIds,
            referenceProducts: referenceProducts,
          )
        : null;

    return RefreshIndicator(
      color: AppTheme.terracotta,
      onRefresh: onRefresh,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: CreatorCommerceHeader(
              eyebrow: 'Curated for you',
              title: 'Shop the lane',
              subtitle: 'Handmade pieces from local makers.',
              cartCount: cartBadgeCount(cartItems),
            ),
          ),
          SliverToBoxAdapter(child: _buildSearchBar(context)),
          SliverToBoxAdapter(child: _buildSearchSuggestions(context)),
          if (!isSearchMode &&
              _query.isEmpty &&
              _filter == CreatorShopFilter.forYou &&
              products.length > 1)
            SliverToBoxAdapter(child: _ShopEditorial(product: products.first)),
          if (!isSearchMode)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _FilterPill(
                      label: 'For you',
                      selected: _filter == CreatorShopFilter.forYou,
                      onTap: () => setState(() {
                        _filter = CreatorShopFilter.forYou;
                        _resetPaging();
                      }),
                    ),
                    const SizedBox(width: 8),
                    _FilterPill(
                      label: 'All pieces',
                      selected: _filter == CreatorShopFilter.allPieces,
                      onTap: () => setState(() {
                        _filter = CreatorShopFilter.allPieces;
                        _resetPaging();
                      }),
                    ),
                    const SizedBox(width: 8),
                    _FilterPill(
                      label: 'Featured',
                      selected: _filter == CreatorShopFilter.featured,
                      onTap: () => setState(() {
                        _filter = CreatorShopFilter.featured;
                        _resetPaging();
                      }),
                    ),
                    const SizedBox(width: 8),
                    _FilterPill(
                      label: 'New drops',
                      selected: _filter == CreatorShopFilter.newDrops,
                      onTap: () => setState(() {
                        _filter = CreatorShopFilter.newDrops;
                        _resetPaging();
                      }),
                    ),
                    const SizedBox(width: 8),
                    _FilterPill(
                      label: 'Under R500',
                      selected: _filter == CreatorShopFilter.underR500,
                      onTap: () => setState(() {
                        _filter = CreatorShopFilter.underR500;
                        _resetPaging();
                      }),
                    ),
                    const SizedBox(width: 8),
                    _NearMePill(
                      selected: _nearMeOn,
                      area: _nearMeArea,
                      onTap: _toggleNearMe,
                      onChangeArea: _changeNearMeArea,
                    ),
                  ],
                ),
              ),
            ),
          if (!isSearchMode)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Row(
                  children: [
                    for (final entry in [
                      (
                        Icons.category_outlined,
                        'Categories',
                        '/home/categories',
                      ),
                      (Icons.storefront_outlined, 'Artisans', '/home/shops'),
                      (Icons.tune_rounded, 'Your taste', '/discover'),
                    ])
                      Expanded(
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: shopQuietInk,
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            minimumSize: const Size(0, 44),
                            textStyle: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          icon: Icon(entry.$1, size: 14),
                          label: Text(
                            entry.$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: () => entry.$3 == '/discover'
                              ? context.go(entry.$3)
                              : context.push(entry.$3),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (!isSearchMode)
            const SliverToBoxAdapter(child: _GiftFinderBanner()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      isSearchMode
                          ? 'Results for "$_debouncedQuery"'
                          : _query.isNotEmpty
                          ? 'Your search results'
                          : switch (_filter) {
                              CreatorShopFilter.forYou =>
                                'Finds for your everyday',
                              CreatorShopFilter.newDrops =>
                                'Fresh from the makers',
                              CreatorShopFilter.underR500 =>
                                'Little things. Big feeling.',
                              CreatorShopFilter.featured => 'In the spotlight',
                              CreatorShopFilter.allPieces =>
                                'Explore the collection',
                            },
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 23,
                        height: 1.15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${products.length} pieces',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SortFilterButton(
                    activeCount: _activeAdvancedFilterCount,
                    onTap: () => _openFilterSheet(categories),
                  ),
                  if (_sort != ShopSortOption.recommended)
                    _ActiveFilterChip(
                      label: _sort.label,
                      onRemoved: () => setState(() {
                        _sort = ShopSortOption.recommended;
                        _resetPaging();
                      }),
                    ),
                  if (_priceRange != null)
                    _ActiveFilterChip(
                      label:
                          'R${_priceRange!.start.round()}–R${_priceRange!.end.round()}',
                      onRemoved: () => setState(() {
                        _priceRange = null;
                        _resetPaging();
                      }),
                    ),
                  for (final categoryId in _categoryIds)
                    _ActiveFilterChip(
                      label: categories
                          .firstWhere(
                            (c) => c.id == categoryId,
                            orElse: () => Category(
                              id: categoryId,
                              name: 'Category',
                              slug: categoryId,
                              createdAt: DateTime.now(),
                            ),
                          )
                          .name,
                      onRemoved: () => setState(() {
                        _categoryIds = {..._categoryIds}..remove(categoryId);
                        _resetPaging();
                      }),
                    ),
                  if (_onSaleOnly)
                    _ActiveFilterChip(
                      label: 'On sale',
                      onRemoved: () => setState(() {
                        _onSaleOnly = false;
                        _resetPaging();
                      }),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: Row(
                children: [
                  Text(
                    'View',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.sand),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final mode in ShopProductView.values)
                          IconButton(
                            key: ValueKey('shop-view-${mode.name}'),
                            tooltip: switch (mode) {
                              ShopProductView.rows => 'Rows',
                              ShopProductView.twoCards => 'Two cards',
                              ShopProductView.oneCard => 'One card',
                            },
                            isSelected: _view == mode,
                            style: IconButton.styleFrom(
                              foregroundColor: AppTheme.textHint,
                              highlightColor: AppTheme.bone,
                            ),
                            selectedIcon: Icon(switch (mode) {
                              ShopProductView.rows => Icons.view_list_rounded,
                              ShopProductView.twoCards =>
                                Icons.grid_view_rounded,
                              ShopProductView.oneCard =>
                                Icons.view_agenda_outlined,
                            }, color: shopQuietInk),
                            icon: Icon(switch (mode) {
                              ShopProductView.rows => Icons.view_list_outlined,
                              ShopProductView.twoCards =>
                                Icons.grid_view_outlined,
                              ShopProductView.oneCard =>
                                Icons.view_agenda_outlined,
                            }, size: 20),
                            onPressed: () => setState(() => _view = mode),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (products.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.search_off_rounded,
                        size: 32,
                        color: AppTheme.textHint,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isSearchMode
                            ? 'Nothing matched "$_debouncedQuery". Try different keywords.'
                            : 'Nothing here just yet. Try a different search or browse all pieces.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          _clearSearch();
                          setState(() {
                            _filter = CreatorShopFilter.allPieces;
                            _sort = ShopSortOption.recommended;
                            _priceRange = null;
                            _categoryIds = {};
                            _onSaleOnly = false;
                          });
                        },
                        child: const Text('Show all pieces'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              sliver: _view == ShopProductView.rows
                  ? SliverList.builder(
                      itemCount: visibleProducts.length + (hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= visibleProducts.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.terracotta,
                                ),
                              ),
                            ),
                          );
                        }
                        final product = visibleProducts[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: ShopProductTile(
                            key: ValueKey('row-${product.id}'),
                            product: product,
                            row: true,
                            reason: reasonFor(product),
                            reserveReasonSpace: showReasons,
                          ),
                        );
                      },
                    )
                  : SliverLayoutBuilder(
                      builder: (context, constraints) {
                        final columns = _view == ShopProductView.twoCards
                            ? 2
                            : 1;
                        final width =
                            (constraints.crossAxisExtent - (columns - 1) * 14) /
                            columns;
                        return SliverGrid.builder(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                mainAxisExtent:
                                    width / (columns == 2 ? .9 : 1.15) +
                                    shopProductDetailsHeight(
                                      MediaQuery.textScalerOf(context),
                                      reserveReason: showReasons,
                                    ),
                                mainAxisSpacing: 18,
                                crossAxisSpacing: 14,
                              ),
                          itemCount: visibleProducts.length,
                          itemBuilder: (context, index) => ShopProductTile(
                            key: ValueKey('card-${visibleProducts[index].id}'),
                            product: visibleProducts[index],
                            reason: reasonFor(visibleProducts[index]),
                            reserveReasonSpace: showReasons,
                          ),
                        );
                      },
                    ),
            ),
          if (hasMore && _view != ShopProductView.rows)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(bottom: 24),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.terracotta,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ShopEditorial extends StatelessWidget {
  const _ShopEditorial({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 2, 20, 18),
    child: Semantics(
      button: true,
      label:
          'Explore ${product.title} by ${product.shopName ?? 'a local maker'}',
      child: InkWell(
        onTap: () => context.push('/home/product/${product.id}'),
        borderRadius: BorderRadius.circular(24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            height: 174,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: AppTheme.indigo),
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: 190,
                  child: CachedNetworkImage(
                    imageUrl: product.primaryImage,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) =>
                        Container(color: AppTheme.baobab),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.indigo,
                        Color(0xE62B3044),
                        Color(0x002B3044),
                      ],
                      stops: [0, .42, 1],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'THE ARTISAN EDIT',
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.ochre,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Made slowly.\nLoved for years.',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 25,
                            height: 1.05,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              product.shopName ?? 'Meet the maker',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const CircleAvatar(
                            radius: 15,
                            backgroundColor: Colors.white,
                            child: Icon(
                              Icons.arrow_outward_rounded,
                              size: 16,
                              color: AppTheme.indigo,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () {
      HapticFeedback.selectionClick();
      onTap();
    },
    borderRadius: BorderRadius.circular(24),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFE4EAE5) : Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: selected
              ? const Color(0xFFCCD8D0)
              : AppTheme.sand.withValues(alpha: .55),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected ? shopQuietInk : AppTheme.textSecondary,
        ),
      ),
    ),
  );
}

class _SortFilterButton extends StatelessWidget {
  const _SortFilterButton({required this.activeCount, required this.onTap});
  final int activeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: activeCount > 0 ? shopQuietInk : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.sand.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune_rounded,
              size: 16,
              color: activeCount > 0 ? Colors.white : AppTheme.textPrimary,
            ),
            const SizedBox(width: 6),
            Text(
              activeCount > 0
                  ? 'Sort & Filter ($activeCount)'
                  : 'Sort & Filter',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: activeCount > 0 ? Colors.white : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveFilterChip extends StatelessWidget {
  const _ActiveFilterChip({required this.label, required this.onRemoved});
  final String label;
  final VoidCallback onRemoved;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Text(label, style: GoogleFonts.poppins(fontSize: 12)),
      onDeleted: onRemoved,
      backgroundColor: AppTheme.cardBg,
      deleteIconColor: AppTheme.textSecondary,
      side: BorderSide(color: AppTheme.sand.withValues(alpha: 0.6)),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      avatar: Icon(icon, size: 14, color: AppTheme.textHint),
      label: Text(label, style: GoogleFonts.poppins(fontSize: 12)),
      backgroundColor: Colors.white,
      side: BorderSide(color: AppTheme.sand.withValues(alpha: 0.4)),
    );
  }
}

/// The "Near me" quick filter pill. Shows the chosen area once picked, and
/// offers a small pencil to change it without turning the filter off.
class _NearMePill extends StatelessWidget {
  const _NearMePill({
    required this.selected,
    required this.area,
    required this.onTap,
    required this.onChangeArea,
  });

  final bool selected;
  final String? area;
  final VoidCallback onTap;
  final VoidCallback onChangeArea;

  @override
  Widget build(BuildContext context) {
    final label = selected && area != null ? 'Near $area' : 'Near me';
    return Semantics(
      button: true,
      label: selected && area != null
          ? 'Near me filter, area $area, on'
          : 'Near me filter',
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE4EAE5) : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected
                  ? const Color(0xFFCCD8D0)
                  : AppTheme.sand.withValues(alpha: .55),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.place_outlined,
                size: 14,
                color: selected ? shopQuietInk : AppTheme.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? shopQuietInk : AppTheme.textSecondary,
                ),
              ),
              if (selected && area != null) ...[
                const SizedBox(width: 4),
                InkWell(
                  onTap: onChangeArea,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.edit_outlined,
                      size: 13,
                      color: shopQuietInk,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Prominent entry to the gift finder on the Shop tab.
class _GiftFinderBanner extends StatelessWidget {
  const _GiftFinderBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Material(
        color: AppTheme.terracotta.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          key: const Key('shop-gift-finder-banner'),
          borderRadius: BorderRadius.circular(18),
          onTap: () => context.push('/home/gift-concierge'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.terracotta,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.card_giftcard_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Find a gift they'll love",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Answer 3 quick questions for handmade ideas.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.terracotta,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
