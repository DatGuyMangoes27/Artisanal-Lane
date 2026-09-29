import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/theme.dart';
import '../../../../core/ui/friendly_error.dart';
import '../../../../models/shop_story.dart';
import '../../../../widgets/skeleton.dart';
import '../../providers/story_providers.dart';

/// Shown on a maker's own story in place of the reaction row: a pill with
/// the reaction count that opens a sheet listing reactor names and emoji.
class StoryReactionsPill extends ConsumerWidget {
  const StoryReactionsPill({
    super.key,
    required this.story,
    required this.onSheetOpenChanged,
  });

  final ShopStory story;

  /// Called with true while the reactions sheet is open so the caller can
  /// pause the story, and false once it closes.
  final ValueChanged<bool> onSheetOpenChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!story.isLiveAt(DateTime.now())) return const SizedBox.shrink();
    final reactions = ref.watch(storyReactionsProvider(story.id));
    final count = reactions.value?.length;
    return Semantics(
      button: true,
      label: count == null || count == 0
          ? 'Reactions'
          : '$count ${count == 1 ? 'reaction' : 'reactions'}',
      child: InkWell(
        key: const ValueKey('story-reactions-pill'),
        borderRadius: BorderRadius.circular(22),
        onTap: () => _open(context, ref),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.favorite, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                'Reactions${count == null ? '' : ' · $count'}',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    onSheetOpenChanged(true);
    ref.invalidate(storyReactionsProvider(story.id));
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _StoryReactionsSheet(storyId: story.id),
    );
    onSheetOpenChanged(false);
  }
}

class _StoryReactionsSheet extends ConsumerWidget {
  const _StoryReactionsSheet({required this.storyId});
  final String storyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reactions = ref.watch(storyReactionsProvider(storyId));
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.6,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reactions',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: reactions.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Skeleton(child: SkeletonBox(height: 120)),
                  ),
                  error: (error, _) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      friendlyErrorMessage(
                        error,
                        fallback: 'Could not load reactions.',
                      ),
                      style: GoogleFonts.poppins(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  data: (rows) => rows.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.favorite_border,
                                color: AppTheme.textHint,
                                size: 32,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No reactions yet',
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Reactions to this story will show up here.",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: rows.length,
                          separatorBuilder: (_, _) =>
                              const Divider(height: 1, color: AppTheme.sand),
                          itemBuilder: (context, i) {
                            final row = rows[i];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              minLeadingWidth: 0,
                              leading: Text(
                                row.emoji,
                                style: const TextStyle(fontSize: 22),
                              ),
                              title: Text(
                                row.name,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
