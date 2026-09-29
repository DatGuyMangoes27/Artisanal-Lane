import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../core/ui/friendly_error.dart';
import '../../../widgets/african_patterns.dart';
import '../../../widgets/product_card.dart';
import '../../../widgets/skeleton.dart';
import '../providers/buyer_providers.dart';
import '../utils/curated_collection_destination.dart';

class CuratedCollectionScreen extends ConsumerWidget {
  const CuratedCollectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(curatedCollectionProductsProvider);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: RefreshIndicator(
        color: AppTheme.terracotta,
        backgroundColor: AppTheme.cardBg,
        onRefresh: () async {
          ref.invalidate(curatedCollectionProductsProvider);
        },
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
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
                            border: Border.all(
                              color: AppTheme.sand.withValues(alpha: 0.3),
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
                              curatedCollectionTitle,
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              curatedCollectionSubtitle,
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
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Text(
                    'A weekly edit of standout pieces from across Artisan Lane.',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      height: 1.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
              productsAsync.when(
                data: (products) {
                  if (products.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_awesome_outlined,
                                size: 40,
                                color: AppTheme.textSecondary.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Nothing curated just yet',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Check back soon for the next handpicked selection.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  height: 1.45,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton(
                                onPressed: () => context.pop(),
                                child: const Text('Keep browsing'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) =>
                            ProductCard(product: products[index]),
                        childCount: products.length,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 0.65,
                          ),
                    ),
                  );
                },
                loading: () => SliverPadding(
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
                          const Skeleton(child: SkeletonBox(radius: 16)),
                      childCount: 6,
                    ),
                  ),
                ),
                error: (error, _) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorRetryView(
                    error: error,
                    title: "Couldn't load the collection",
                    onRetry: () =>
                        ref.invalidate(curatedCollectionProductsProvider),
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
      ),
    );
  }
}
