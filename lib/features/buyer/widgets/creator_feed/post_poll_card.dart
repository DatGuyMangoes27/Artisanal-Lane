import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../models/creator_parity.dart';
import '../../../../models/shop_post.dart';
import '../../../../widgets/sign_in_prompt_sheet.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../vendor/providers/vendor_providers.dart';

/// The poll attached to a post, or null when the post has none (or it
/// hasn't been created yet). Kept separate from [pollResultsProvider] so
/// the question/options (which never change once voting starts) don't
/// reload every time a vote comes in.
final postPollProvider = FutureProvider.autoDispose.family<PostPoll?, String>(
  (ref, postId) => ref.read(supabaseServiceProvider).getPostPoll(postId),
);

/// Vote counts and the signed-in viewer's own choice, with optimistic
/// voting: [PollResultsController.vote] flips the local tally immediately
/// and rolls back if the write fails.
class PollResultsController extends AsyncNotifier<PollResults> {
  PollResultsController(this.postId);
  final String postId;

  @override
  Future<PollResults> build() async {
    ref.watch(currentUserIdProvider);
    return ref.read(supabaseServiceProvider).getPollResults(postId);
  }

  /// Returns false when the vote failed (the tally has been rolled back).
  Future<bool> vote(int optionIndex) async {
    final current = state.value;
    if (current == null) return false;
    final votes = List<int>.from(current.votes);
    if (current.myVote != null && current.myVote! < votes.length) {
      votes[current.myVote!] = (votes[current.myVote!] - 1).clamp(0, 1 << 30);
    }
    if (optionIndex < votes.length) votes[optionIndex]++;
    state = AsyncData(PollResults(votes: votes, myVote: optionIndex));
    final service = ref.read(supabaseServiceProvider);
    try {
      await service.votePoll(postId, optionIndex);
    } catch (_) {
      if (ref.mounted) state = AsyncData(current);
      return false;
    }
    // Swap the optimistic tally for the server's live counts (other people
    // may have voted since this poll loaded). A failed refresh keeps the
    // optimistic numbers, which already include this vote.
    try {
      final fresh = await service.getPollResults(postId);
      if (ref.mounted) state = AsyncData(fresh);
    } catch (_) {}
    return true;
  }
}

final pollResultsProvider = AsyncNotifierProvider.autoDispose
    .family<PollResultsController, PollResults, String>(
      PollResultsController.new,
    );

/// Renders under a post's media when [ShopPost.format] is
/// [PostFormat.poll]: the question, tappable option rows before voting,
/// and percentage bars with vote counts once the viewer has voted, the
/// poll is closed, or they're the maker.
class PostPollCard extends ConsumerWidget {
  const PostPollCard({super.key, required this.post});
  final ShopPost post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pollAsync = ref.watch(postPollProvider(post.id));
    return pollAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: LinearProgressIndicator(minHeight: 3),
      ),
      error: (_, _) => _PollLoadError(
        message: "This poll couldn't be loaded.",
        onRetry: () => ref.invalidate(postPollProvider(post.id)),
      ),
      data: (poll) => poll == null
          ? const SizedBox.shrink()
          : _PollBody(post: post, poll: poll),
    );
  }
}

class _PollBody extends ConsumerWidget {
  const _PollBody({required this.post, required this.poll});
  final ShopPost post;
  final PostPoll poll;

  Future<void> _vote(WidgetRef ref, BuildContext context, int index) async {
    final user = ref.read(currentUserIdProvider);
    if (user == null) {
      await showSignInPromptSheet(
        context,
        title: 'Vote in this poll',
        message: 'Sign in to share your pick.',
      );
      return;
    }
    HapticFeedback.lightImpact();
    final ok = await ref
        .read(pollResultsProvider(post.id).notifier)
        .vote(index);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            poll.isClosed
                ? 'This poll has closed.'
                : "Couldn't record your vote. Please try again.",
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(pollResultsProvider(post.id));
    final ownShop = ref.watch(vendorShopProvider).value;
    final isOwner = ownShop?.id == post.shopId;
    final closed = poll.isClosed;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            poll.question,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          resultsAsync.when(
            loading: () => Column(
              children: [
                for (final option in poll.options)
                  _PollOptionButton(label: option, onTap: null),
              ],
            ),
            error: (_, _) => _PollLoadError(
              message: "Poll results couldn't be loaded.",
              onRetry: () => ref.invalidate(pollResultsProvider(post.id)),
            ),
            data: (results) {
              final voted = results.myVote != null;
              final showResults = voted || closed || isOwner;
              // Makers see live results but don't vote in their own poll.
              final canVote = !closed && !isOwner;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < poll.options.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: showResults
                          ? _PollResultBar(
                              key: Key('poll-option-${post.id}-$i'),
                              label: poll.options[i],
                              share: results.share(i),
                              votes: i < results.votes.length
                                  ? results.votes[i]
                                  : 0,
                              selected: results.myVote == i,
                              onTap: canVote
                                  ? () => _vote(ref, context, i)
                                  : null,
                            )
                          : _PollOptionButton(
                              key: Key('poll-option-${post.id}-$i'),
                              label: poll.options[i],
                              onTap: () => _vote(ref, context, i),
                            ),
                    ),
                  Text(
                    pollStatusLabel(
                      poll: poll,
                      totalVotes: results.total,
                      isOwner: isOwner,
                    ),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// The line under a poll: vote count, plus when it closes (or closed).
String pollStatusLabel({
  required PostPoll poll,
  required int totalVotes,
  bool isOwner = false,
  DateTime? now,
}) {
  final votes = '$totalVotes vote${totalVotes == 1 ? '' : 's'}';
  final reference = now ?? DateTime.now();
  final closesAt = poll.closesAt;
  if (closesAt != null && !closesAt.isAfter(reference)) {
    return 'Poll closed · $votes';
  }
  return [
    if (totalVotes == 0 && !isOwner) 'Be the first to vote' else votes,
    if (closesAt != null)
      'Ends in ${_pollTimeLeft(closesAt.difference(reference))}',
  ].join(' · ');
}

String _pollTimeLeft(Duration left) {
  if (left.inDays >= 1) return '${left.inDays}d';
  if (left.inHours >= 1) return '${left.inHours}h';
  return '${left.inMinutes < 1 ? 1 : left.inMinutes}m';
}

class _PollLoadError extends StatelessWidget {
  const _PollLoadError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
    child: Row(
      children: [
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}

class _PollOptionButton extends StatelessWidget {
  const _PollOptionButton({super.key, required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(24),
    child: Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.sand),
      ),
      alignment: Alignment.centerLeft,
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    ),
  );
}

class _PollResultBar extends StatelessWidget {
  const _PollResultBar({
    super.key,
    required this.label,
    required this.share,
    required this.votes,
    required this.selected,
    this.onTap,
  });
  final String label;
  final double share;
  final int votes;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final percent = (share * 100).round();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? AppTheme.terracotta : AppTheme.sand,
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            FractionallySizedBox(
              widthFactor: share.clamp(0.0, 1.0),
              child: Container(
                color: (selected ? AppTheme.terracotta : AppTheme.ochre)
                    .withValues(alpha: .16),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: selected
                            ? AppTheme.terracotta
                            : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$percent% · $votes',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
