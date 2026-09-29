import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';
import '../../../core/ui/friendly_error.dart';
import '../../../models/creator_parity.dart';
import '../../../models/shop_post.dart';
import '../../../widgets/skeleton.dart';
import '../../buyer/providers/buyer_providers.dart'
    show supabaseServiceProvider;
import '../widgets/workspace/workspace_header.dart';

const _insightsPeriods = [7, 30, 90];

/// The signed-in maker's own performance summary, for the chosen period.
final shopInsightsProvider = FutureProvider.family<ShopInsights?, int>((
  ref,
  days,
) {
  return ref.read(supabaseServiceProvider).getShopInsights(days: days);
});

/// Fetches the shop_posts rows behind a maker's "Top posts" list, in the
/// same order as [ShopInsights.topPosts].
final _topPostsProvider =
    FutureProvider.family<List<ShopPost>, List<({String postId, int views})>>((
      ref,
      topPosts,
    ) async {
      if (topPosts.isEmpty) return const [];
      final ids = topPosts.map((e) => e.postId).toList(growable: false);
      final rows = await Supabase.instance.client
          .from('shop_posts')
          .select(ShopPost.select)
          .inFilter('id', ids);
      final byId = {
        for (final row in (rows as List).cast<Map<String, dynamic>>())
          row['id'] as String: ShopPost.fromJson(row),
      };
      return [
        for (final entry in topPosts)
          if (byId[entry.postId] != null) byId[entry.postId]!,
      ];
    });

/// A maker's own Insights screen: post/profile/product views, engagement
/// and follower growth for a chosen period, plus their top posts by views.
class ShopInsightsScreen extends ConsumerStatefulWidget {
  const ShopInsightsScreen({super.key});

  @override
  ConsumerState<ShopInsightsScreen> createState() => _ShopInsightsScreenState();
}

class _ShopInsightsScreenState extends ConsumerState<ShopInsightsScreen> {
  int _days = 30;

  @override
  Widget build(BuildContext context) {
    final insightsAsync = ref.watch(shopInsightsProvider(_days));

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.terracotta,
          onRefresh: () async {
            ref.invalidate(shopInsightsProvider(_days));
          },
          child: ListView(
            padding: EdgeInsets.zero,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (Navigator.of(context).canPop())
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8, top: 4),
                    child: IconButton(
                      tooltip: 'Back',
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: AppTheme.textPrimary,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                ),
              const WorkspaceHeader(
                eyebrow: 'Your shop',
                title: 'Insights',
                subtitle: 'How your posts and profile are performing',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    for (final period in _insightsPeriods) ...[
                      _PeriodChip(
                        label: '$period days',
                        selected: _days == period,
                        onTap: () => setState(() => _days = period),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              insightsAsync.when(
                data: (insights) {
                  if (insights == null) {
                    return const Padding(
                      padding: EdgeInsets.fromLTRB(20, 40, 20, 40),
                      child: _InsightsEmptyState(),
                    );
                  }
                  return _InsightsBody(insights: insights);
                },
                loading: () => const _InsightsSkeleton(),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: ErrorRetryView(
                    error: error,
                    title: "Couldn't load your insights",
                    onRetry: () => ref.invalidate(shopInsightsProvider(_days)),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppTheme.terracotta.withValues(alpha: 0.12)
          : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? AppTheme.terracotta
                  : AppTheme.sand.withValues(alpha: 0.4),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? AppTheme.terracotta : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _InsightsBody extends ConsumerWidget {
  final ShopInsights insights;

  const _InsightsBody({required this.insights});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tiles = <(String, String, IconData)>[
      ('Post views', '${insights.postViews}', Icons.visibility_outlined),
      ('Profile views', '${insights.profileViews}', Icons.person_outline),
      (
        'Product views',
        '${insights.productViews}',
        Icons.shopping_bag_outlined,
      ),
      ('Likes', '${insights.likes}', Icons.favorite_border),
      ('Comments', '${insights.comments}', Icons.chat_bubble_outline),
      ('Saves', '${insights.saves}', Icons.bookmark_border),
      (
        'New followers',
        '${insights.newFollowers}',
        Icons.person_add_alt_outlined,
      ),
      ('Followers', '${insights.followers}', Icons.people_outline),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.7,
            children: [for (final tile in tiles) _StatTile(tile: tile)],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(
            'Top posts',
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        if (insights.topPosts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Once your posts get views, the best-performing ones show up '
              'here.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppTheme.textHint,
                height: 1.5,
              ),
            ),
          )
        else
          Consumer(
            builder: (context, ref, _) {
              final topPostsAsync = ref.watch(
                _topPostsProvider(insights.topPosts),
              );
              return topPostsAsync.when(
                data: (posts) {
                  final viewsByPostId = {
                    for (final entry in insights.topPosts)
                      entry.postId: entry.views,
                  };
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        for (final post in posts)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _TopPostTile(
                              post: post,
                              views: viewsByPostId[post.id] ?? 0,
                            ),
                          ),
                      ],
                    ),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => const SizedBox.shrink(),
              );
            },
          ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final (String, String, IconData) tile;

  const _StatTile({required this.tile});

  @override
  Widget build(BuildContext context) {
    final (label, value, icon) = tile;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: AppTheme.terracotta),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textHint),
          ),
        ],
      ),
    );
  }
}

class _TopPostTile extends StatelessWidget {
  final ShopPost post;
  final int views;

  const _TopPostTile({required this.post, required this.views});

  @override
  Widget build(BuildContext context) {
    final thumbnail = post.mediaUrls.isNotEmpty ? post.mediaUrls.first : null;
    return InkWell(
      onTap: () => context.push('/create/post/${post.id}'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 48,
                height: 48,
                child: thumbnail == null
                    ? Container(
                        color: AppTheme.bone,
                        child: const Icon(
                          Icons.image_outlined,
                          color: AppTheme.textHint,
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: thumbnail,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          color: AppTheme.bone,
                          child: const Icon(
                            Icons.image_outlined,
                            color: AppTheme.textHint,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                post.caption.trim().isEmpty
                    ? 'Untitled post'
                    : post.caption.trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppTheme.textPrimary,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Row(
              children: [
                const Icon(
                  Icons.visibility_outlined,
                  size: 14,
                  color: AppTheme.textHint,
                ),
                const SizedBox(width: 4),
                Text(
                  '$views',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightsEmptyState extends StatelessWidget {
  const _InsightsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.insights_outlined, size: 40, color: AppTheme.textHint),
        const SizedBox(height: 14),
        Text(
          'Share your first post to start seeing insights',
          textAlign: TextAlign.center,
          style: GoogleFonts.playfairDisplay(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Once buyers view, like and save your posts, you\'ll see the '
          'numbers here.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textHint),
        ),
      ],
    );
  }
}

class _InsightsSkeleton extends StatelessWidget {
  const _InsightsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.7,
              children: List.generate(8, (_) => const SkeletonBox(radius: 16)),
            ),
            const SizedBox(height: 20),
            const SkeletonBox(width: 120, height: 20),
            const SizedBox(height: 12),
            const SkeletonBox(width: double.infinity, height: 68),
            const SizedBox(height: 10),
            const SkeletonBox(width: double.infinity, height: 68),
          ],
        ),
      ),
    );
  }
}
