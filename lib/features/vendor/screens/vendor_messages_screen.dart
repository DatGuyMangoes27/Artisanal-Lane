import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../chat/widgets/chat_widgets.dart';
import '../providers/vendor_providers.dart';

class VendorMessagesScreen extends ConsumerWidget {
  const VendorMessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threadsAsync = ref.watch(vendorThreadsStreamProvider);

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
          showBuyerIdentity: true,
          emptyTitle: 'No messages yet',
          emptySubtitle:
              'When a buyer or the Artisan Lane team contacts you, the conversation will show up here.',
          onRefresh: () {
            ref.invalidate(vendorThreadsProvider);
            ref.invalidate(vendorThreadsStreamProvider);
          },
          onTap: (thread) => context.push('/vendor/messages/${thread.id}'),
        ),
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.terracotta),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not load your messages.\n$error',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: AppTheme.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}
