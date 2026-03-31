import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme.dart';
import '../providers/buyer_providers.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _search(String query) {
    if (query.trim().isEmpty) return;
    ref.read(recentSearchesProvider.notifier).add(query.trim());
    context.push('/search/results?q=${Uri.encodeComponent(query.trim())}');
  }

  void _closeSearch() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      context.pop();
      return;
    }
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final recentSearches = ref.watch(recentSearchesProvider);
    final trending = ref.watch(trendingSearchesProvider);
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          // ── Header ───────────────────────────────────────────────
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _closeSearch,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                            color: AppTheme.sand.withValues(alpha: 0.3),
                          ),
                          borderRadius: BorderRadius.circular(14),
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
                          size: 20,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Search',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Search Bar ───────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                onSubmitted: _search,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'Search for anything handmade...',
                  hintStyle: GoogleFonts.poppins(
                    color: AppTheme.textHint,
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 22,
                    color: AppTheme.textPrimary,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(
                      Icons.clear_rounded,
                      size: 20,
                      color: AppTheme.textHint,
                    ),
                    onPressed: _controller.clear,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),

          // ── Recent Searches ──────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: recentSearches.when(
                data: (searches) => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Searches',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 20,
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (searches.isNotEmpty)
                      TextButton(
                        onPressed: () =>
                            ref.read(recentSearchesProvider.notifier).clear(),
                        child: Text(
                          'Clear',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppTheme.terracotta,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: recentSearches.when(
                data: (searches) => searches.isEmpty
                    ? _EmptyBlock(message: 'No recent searches yet.')
                    : Column(
                        children: searches
                            .map(
                              (s) => _RecentSearchTile(
                                text: s,
                                onTap: () => _search(s),
                                onRemove: () => ref
                                    .read(recentSearchesProvider.notifier)
                                    .remove(s),
                              ),
                            )
                            .toList(),
                      ),
                loading: () => const SizedBox(height: 48),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),

          // ── Trending ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Trending Searches',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 20,
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: trending.when(
                data: (terms) => Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: terms
                      .map(
                        (t) => _TrendingChip(label: t, onTap: () => _search(t)),
                      )
                      .toList(),
                ),
                loading: () => Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: List.generate(
                    5,
                    (_) => Container(
                      width: 100,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.bone,
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),

          // ── Browse by Category ───────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Browse by Category',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 20,
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 100,
              child: categories.when(
                data: (cats) => ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  scrollDirection: Axis.horizontal,
                  itemCount: cats.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 24),
                  itemBuilder: (context, index) {
                    final cat = cats[index];
                    return GestureDetector(
                      onTap: () => context.push(
                        '/home/category/${cat.id}?name=${cat.name}',
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: AppTheme.bone,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.sand.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                cat.icon,
                                color: AppTheme.terracotta,
                                size: 24,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            cat.name,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                              fontSize: 10,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                loading: () => ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  scrollDirection: Axis.horizontal,
                  itemCount: 9,
                  separatorBuilder: (_, __) => const SizedBox(width: 24),
                  itemBuilder: (_, __) => Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          color: AppTheme.bone,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(width: 48, height: 10, color: AppTheme.bone),
                    ],
                  ),
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

class _RecentSearchTile extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _RecentSearchTile({
    required this.text,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: const Icon(
          Icons.history_rounded,
          size: 20,
          color: AppTheme.textHint,
        ),
        title: Text(
          text,
          style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textPrimary),
        ),
        trailing: GestureDetector(
          onTap: onRemove,
          child: const Icon(
            Icons.close_rounded,
            size: 16,
            color: AppTheme.textHint,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

class _TrendingChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TrendingChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      side: BorderSide(color: AppTheme.sand.withValues(alpha: 0.3)),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 0,
      label: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  final String message;

  const _EmptyBlock({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search_off_rounded,
            color: AppTheme.textHint,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.textHint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
