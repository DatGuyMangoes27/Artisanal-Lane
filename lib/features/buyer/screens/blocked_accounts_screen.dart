import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../core/ui/friendly_error.dart';
import '../../../widgets/skeleton.dart';
import '../providers/blocking_providers.dart';
import '../providers/buyer_providers.dart';

typedef BlockedProfile = ({String id, String name, String? avatarUrl});

/// Display details for the accounts in [blockedUserIdsProvider].
final blockedProfilesProvider = FutureProvider<List<BlockedProfile>>((ref) {
  final ids = ref.watch(blockedUserIdsProvider).value ?? const <String>{};
  return ref.read(supabaseServiceProvider).getPublicProfileSummaries(ids);
});

/// Settings → Blocked accounts.
class BlockedAccountsScreen extends ConsumerWidget {
  const BlockedAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(blockedUserIdsProvider);
    final profiles = ref.watch(blockedProfilesProvider);
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBg,
        scrolledUnderElevation: 0,
        title: Text(
          'Blocked accounts',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
      body: ids.when(
        loading: () => const _BlockedSkeleton(),
        error: (error, _) => ErrorRetryView(
          error: error,
          title: "Couldn't load blocked accounts",
          onRetry: () => ref.invalidate(blockedUserIdsProvider),
        ),
        data: (blocked) {
          if (blocked.isEmpty) return const _EmptyBlocked();
          final list = profiles.value;
          if (profiles.hasError && list == null) {
            return ErrorRetryView(
              error: profiles.error,
              title: "Couldn't load blocked accounts",
              onRetry: () => ref.invalidate(blockedProfilesProvider),
            );
          }
          if (list == null) return const _BlockedSkeleton();
          final byId = {for (final p in list) p.id: p};
          final rows = [
            for (final id in blocked)
              byId[id] ??
                  (id: id, name: 'Artisan Lane member', avatarUrl: null),
          ];
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _BlockedRow(profile: rows[i]),
          );
        },
      ),
    );
  }
}

class _BlockedRow extends ConsumerWidget {
  const _BlockedRow({required this.profile});
  final BlockedProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.sand.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme.bone,
            backgroundImage: profile.avatarUrl == null
                ? null
                : CachedNetworkImageProvider(profile.avatarUrl!),
            child: profile.avatarUrl == null
                ? Text(
                    profile.name.characters.first.toUpperCase(),
                    style: GoogleFonts.playfairDisplay(
                      color: AppTheme.terracotta,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              profile.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          OutlinedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.maybeOf(context);
              final ok = await unblockUser(ref, profile.id);
              messenger?.showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  content: Text(
                    ok
                        ? '${profile.name} is unblocked.'
                        : "Couldn't unblock ${profile.name} right now. "
                              'Please try again.',
                  ),
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(44, 44),
              side: const BorderSide(color: AppTheme.terracotta),
              foregroundColor: AppTheme.terracotta,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );
  }
}

class _EmptyBlocked extends StatelessWidget {
  const _EmptyBlocked();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.block_outlined,
            size: 40,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(height: 14),
          Text(
            'Nobody blocked',
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "People you block can't comment on your posts or message you. "
            'You can block someone from their comment, profile or chat.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              height: 1.45,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );
}

class _BlockedSkeleton extends StatelessWidget {
  const _BlockedSkeleton();

  @override
  Widget build(BuildContext context) => Skeleton(
    child: ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, _) => const SkeletonBox(height: 64),
    ),
  );
}
