import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../core/ui/friendly_error.dart';
import '../../../widgets/skeleton.dart';
import '../../chat/widgets/chat_widgets.dart';
import '../providers/buyer_providers.dart';

class BuyerMessagesScreen extends ConsumerWidget {
  const BuyerMessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threadsAsync = ref.watch(buyerThreadsStreamProvider);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBg,
        scrolledUnderElevation: 0,
        title: Text(
          'Messages',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
      body: threadsAsync.when(
        data: (threads) => ChatInboxList(
          threads: threads,
          showBuyerIdentity: false,
          emptyTitle: 'No conversations yet',
          emptySubtitle:
              'When you contact an artisan from a shop or product page, your messages will appear here.',
          onRefresh: () {
            ref.invalidate(buyerThreadsProvider);
            ref.invalidate(buyerThreadsStreamProvider);
          },
          onDelete: (thread) async {
            await ref.read(supabaseServiceProvider).hideChatThread(thread.id);
            ref.invalidate(buyerThreadsProvider);
            ref.invalidate(buyerThreadsStreamProvider);
          },
          onTap: (thread) => context.push('/profile/messages/${thread.id}'),
        ),
        loading: () => const _InboxSkeleton(),
        error: (error, _) => ErrorRetryView(
          error: error,
          title: "Couldn't load your conversations",
          onRetry: () {
            ref.invalidate(buyerThreadsProvider);
            ref.invalidate(buyerThreadsStreamProvider);
          },
        ),
      ),
    );
  }
}

class _InboxSkeleton extends StatelessWidget {
  const _InboxSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, __) => Skeleton(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const SkeletonBox(width: 48, height: 48, circle: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SkeletonBox(width: 120, height: 14),
                    const SizedBox(height: 8),
                    SkeletonBox(width: double.infinity, height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
