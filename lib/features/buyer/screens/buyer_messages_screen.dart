import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
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
          onTap: (thread) => context.push('/profile/messages/${thread.id}'),
        ),
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.terracotta),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not load your conversations.\n$error',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: AppTheme.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}
