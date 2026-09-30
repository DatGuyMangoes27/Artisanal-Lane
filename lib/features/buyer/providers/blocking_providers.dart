import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';
import '../../../widgets/sign_in_prompt_sheet.dart';
import 'buyer_providers.dart';
import 'creator_parity_providers.dart';

/// Accounts the signed-in user has blocked, updated instantly and rolled back
/// if the save fails.
final blockedUserIdsProvider =
    AsyncNotifierProvider<OptimisticIdSet, Set<String>>(
      () => OptimisticIdSet(
        (ref) => ref.read(supabaseServiceProvider).getBlockedUserIds(),
        (ref, id, on) =>
            ref.read(supabaseServiceProvider).setUserBlocked(id, on),
      ),
    );

final isUserBlockedProvider = Provider.family<bool, String>(
  (ref, userId) =>
      ref.watch(blockedUserIdsProvider).value?.contains(userId) ?? false,
);

/// Shops owned by accounts the viewer has blocked. Their posts and stories are
/// hidden alongside muted makers.
final blockedShopIdsProvider = FutureProvider<Set<String>>((ref) async {
  final blocked = ref.watch(blockedUserIdsProvider).value ?? const <String>{};
  if (blocked.isEmpty) return <String>{};
  return ref.read(supabaseServiceProvider).getShopIdsForVendors(blocked);
});

/// Every shop id the viewer shouldn't see content from (muted or blocked).
final hiddenShopIdsProvider = Provider<Set<String>>((ref) {
  final muted = ref.watch(mutedShopIdsProvider).value ?? const <String>{};
  final blocked = ref.watch(blockedShopIdsProvider).value ?? const <String>{};
  if (blocked.isEmpty) return muted;
  return {...muted, ...blocked};
});

/// True when the server refused a write because of a block, a takedown or a
/// permissions rule (Postgres "insufficient privilege").
bool isPermissionRejection(Object? error) {
  if (error is PostgrestException) {
    return error.code == '42501' ||
        error.message.toLowerCase().contains('row-level security');
  }
  final text = error?.toString().toLowerCase() ?? '';
  return text.contains('42501') || text.contains('row-level security');
}

const blockedCommentMessage =
    "You can't comment on this post. One of you has blocked the other.";
const blockedChatMessage = "You can't reply to this conversation.";

/// Shows the block confirmation sheet and, if confirmed, blocks [userId].
/// Blocking a maker ([shopId]) also mutes their shop so their posts and
/// stories disappear from the feed straight away.
Future<bool> confirmBlockUser(
  WidgetRef ref,
  BuildContext context, {
  required String userId,
  required String name,
  String? shopId,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (ref.read(currentUserIdProvider) == null) {
    await showSignInPromptSheet(
      context,
      title: 'Sign in to block people',
      message: 'Blocking keeps your conversations and comments comfortable.',
    );
    return false;
  }
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    backgroundColor: AppTheme.cardBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => _BlockSheet(name: name),
  );
  if (confirmed != true) return false;
  final ok = await ref.read(blockedUserIdsProvider.notifier).set(userId, true);
  if (ok && shopId != null) {
    await ref.read(mutedShopIdsProvider.notifier).set(shopId, true);
  }
  if (ok) HapticFeedback.mediumImpact();
  messenger?.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text(
        ok
            ? "You've blocked $name."
            : "Couldn't block $name right now. Please try again.",
      ),
      action: ok
          ? SnackBarAction(
              label: 'Undo',
              onPressed: () => unblockUser(ref, userId, shopId: shopId),
            )
          : null,
    ),
  );
  return ok;
}

/// Unblocks [userId] (and un-mutes their shop when [shopId] is given).
Future<bool> unblockUser(WidgetRef ref, String userId, {String? shopId}) async {
  final ok = await ref.read(blockedUserIdsProvider.notifier).set(userId, false);
  if (ok && shopId != null) {
    await ref.read(mutedShopIdsProvider.notifier).set(shopId, false);
  }
  return ok;
}

class _BlockSheet extends StatelessWidget {
  const _BlockSheet({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Block $name?',
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "They won't be able to comment on your posts or message you. "
              "They won't be notified. You won't see their comments, posts "
              'or stories. You can unblock them any time in Settings.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                height: 1.5,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                child: Text(
                  'Block $name',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
