import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme.dart';
import '../../../core/ui/friendly_error.dart';
import '../../../widgets/product_card.dart';
import '../../../widgets/skeleton.dart';
import '../providers/buyer_providers.dart';
import '../providers/favourite_actions.dart';

/// ═══════════════════════════════════════════════════════════════
/// Favourites Screen — "My Treasures"
///
/// Clean, high-end design with white background.
/// ═══════════════════════════════════════════════════════════════

class FavouritesScreen extends ConsumerStatefulWidget {
  const FavouritesScreen({super.key});

  @override
  ConsumerState<FavouritesScreen> createState() => _FavouritesScreenState();
}

class _FavouritesScreenState extends ConsumerState<FavouritesScreen> {
  /// Ids removed optimistically (hidden immediately) but not yet confirmed
  /// removed from the server list.
  final Set<String> _hiddenIds = {};

  @override
  Widget build(BuildContext context) {
    final favourites = ref.watch(favouriteProductsProvider);
    final canPop = context.canPop();

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: favourites.when(
        data: (items) {
          final visible = items
              .where((p) => !_hiddenIds.contains(p.id))
              .toList(growable: false);
          return RefreshIndicator(
            color: AppTheme.terracotta,
            onRefresh: () => ref.refresh(favouriteProductsProvider.future),
            child: _buildContent(context, ref, visible, canPop: canPop),
          );
        },
        loading: () => _buildLoading(canPop: canPop),
        error: (error, _) => Column(
          children: [
            if (canPop) _buildBackRow(context),
            Expanded(
              child: ErrorRetryView(
                error: error,
                title: "Couldn't load your treasures",
                onRetry: () => ref.invalidate(favouriteProductsProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeFavourite(BuildContext context, String productId) async {
    setState(() => _hiddenIds.add(productId));
    // toggleFavourite flips the shared optimistic favourite state (instant,
    // used by the heart overlay everywhere) and saves in the background.
    await toggleFavourite(ref, context, productId);
    if (!mounted || !context.mounted) return;
    if (ref.read(isFavouriteProvider(productId))) {
      // The save failed and rolled back — bring the card back.
      setState(() => _hiddenIds.remove(productId));
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Removed · Undo',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: AppTheme.textPrimary,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Undo',
            textColor: AppTheme.ochre,
            onPressed: () async {
              setState(() => _hiddenIds.remove(productId));
              await toggleFavourite(ref, context, productId);
            },
          ),
        ),
      );
  }

  // ── Back Row (shown only when this screen was pushed) ────────────
  Widget _buildBackRow(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: _FavouritesBackButton(onTap: () => context.pop()),
        ),
      ),
    );
  }

  // ── Main Content ─────────────────────────────────────────────

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    List items, {
    bool canPop = false,
  }) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        // Top padding for status bar
        SliverToBoxAdapter(
          child: SizedBox(height: MediaQuery.of(context).padding.top + 16),
        ),

        // ── Header ──────────────────────────────────────────
        SliverToBoxAdapter(child: _buildHeader(canPop: canPop)),

        if (items.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyState(context),
          )
        else ...[
          // ── Saved count pill ─────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Text(
                '${items.length} Saved Items',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textHint,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),

          // ── Product Grid ────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.65,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => ProductCard(
                  product: items[index],
                  isFavourite: true,
                  onFavouriteToggle: () =>
                      _removeFavourite(context, items[index].id),
                ),
                childCount: items.length,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── Header ───────────────────────────────────────────────────

  Widget _buildHeader({bool canPop = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canPop) ...[
            Builder(
              builder: (context) => Align(
                alignment: Alignment.centerLeft,
                child: _FavouritesBackButton(onTap: () => context.pop()),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            'My Treasures',
            style: GoogleFonts.playfairDisplay(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pieces you\'ve saved for later',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 24),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
        ],
      ),
    );
  }

  // ── Empty State ──────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.bone.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.favorite_outline_rounded,
                  size: 32,
                  color: AppTheme.textHint,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Treasures Yet',
              textAlign: TextAlign.center,
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Start exploring and save pieces\nthat speak to your heart.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),
            OutlinedButton(
              onPressed: () => context.go('/home'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.terracotta,
                side: const BorderSide(color: AppTheme.terracotta),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Explore the shop',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Loading State (skeleton grid) ─────────────────────────────

  Widget _buildLoading({bool canPop = false}) {
    return SafeArea(
      child: Column(
        children: [
          if (canPop)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Builder(
                  builder: (context) =>
                      _FavouritesBackButton(onTap: () => context.pop()),
                ),
              ),
            ),
          Expanded(
            child: Skeleton(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.65,
                ),
                itemCount: 6,
                itemBuilder: (context, index) => const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: SkeletonBox(radius: 16)),
                    SizedBox(height: 10),
                    SkeletonBox(height: 12, width: 100),
                    SizedBox(height: 6),
                    SkeletonBox(height: 14),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Back Button ────────────────────────────────────────────────
class _FavouritesBackButton extends StatelessWidget {
  const _FavouritesBackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
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
    );
  }
}
