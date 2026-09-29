import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../widgets/sign_in_prompt_sheet.dart';
import 'buyer_providers.dart';

/// An account-private set of ids (saved posts, muted makers) that updates
/// instantly and saves in the background, rolling back if the save fails.
class OptimisticIdSet extends AsyncNotifier<Set<String>> {
  OptimisticIdSet(this._load, this._save);
  final Future<Set<String>> Function(Ref ref) _load;
  final Future<void> Function(Ref ref, String id, bool on) _save;
  final _inFlight = <String>{};

  @override
  Future<Set<String>> build() async {
    if (ref.watch(currentUserIdProvider) == null) return <String>{};
    return _load(ref);
  }

  /// Returns false when the save failed (the change has been rolled back).
  Future<bool> set(String id, bool on) async {
    if (_inFlight.contains(id)) return true;
    final before = state.value ?? <String>{};
    state = AsyncData(
      {...before}
        ..removeWhere((e) => e == id)
        ..addAll(on ? [id] : []),
    );
    _inFlight.add(id);
    try {
      await _save(ref, id, on);
      return true;
    } catch (_) {
      final now = state.value ?? <String>{};
      state = AsyncData(
        before.contains(id) ? ({...now}..add(id)) : ({...now}..remove(id)),
      );
      return false;
    } finally {
      _inFlight.remove(id);
    }
  }
}

final savedPostIdsProvider =
    AsyncNotifierProvider<OptimisticIdSet, Set<String>>(
      () => OptimisticIdSet(
        (ref) => ref.read(supabaseServiceProvider).getSavedPostIds(),
        (ref, id, on) => ref.read(supabaseServiceProvider).setPostSaved(id, on),
      ),
    );

/// Makers the account has muted: their posts and stories are hidden.
final mutedShopIdsProvider =
    AsyncNotifierProvider<OptimisticIdSet, Set<String>>(
      () => OptimisticIdSet(
        (ref) => ref.read(supabaseServiceProvider).getMutedShopIds(),
        (ref, id, on) => ref.read(supabaseServiceProvider).setShopMuted(id, on),
      ),
    );

final isPostSavedProvider = Provider.family<bool, String>(
  (ref, postId) =>
      ref.watch(savedPostIdsProvider).value?.contains(postId) ?? false,
);

final isShopMutedProvider = Provider.family<bool, String>(
  (ref, shopId) =>
      ref.watch(mutedShopIdsProvider).value?.contains(shopId) ?? false,
);

Future<bool> _requireAccount(
  WidgetRef ref,
  BuildContext context,
  String title,
  String message,
) async {
  if (ref.read(currentUserIdProvider) != null) return true;
  await showSignInPromptSheet(context, title: title, message: message);
  return false;
}

/// Saves or unsaves a post instantly, with a message if it fails.
Future<void> togglePostSaved(
  WidgetRef ref,
  BuildContext context,
  String postId,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (!await _requireAccount(
    ref,
    context,
    'Sign in to save posts',
    'Keep the posts you love in one place.',
  )) {
    return;
  }
  final saved = !ref.read(isPostSavedProvider(postId));
  HapticFeedback.lightImpact();
  final ok = await ref.read(savedPostIdsProvider.notifier).set(postId, saved);
  if (!ok) {
    messenger?.showSnackBar(
      const SnackBar(
        content: Text("Couldn't update your saved posts. Please try again."),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Mutes or unmutes a maker, offering Undo after muting.
Future<void> setShopMuted(
  WidgetRef ref,
  BuildContext context,
  String shopId, {
  required bool muted,
  String? shopName,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (!await _requireAccount(
    ref,
    context,
    'Sign in to tune your feed',
    'Mute makers and shape what you see.',
  )) {
    return;
  }
  final notifier = ref.read(mutedShopIdsProvider.notifier);
  final ok = await notifier.set(shopId, muted);
  messenger?.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text(
        !ok
            ? "Couldn't update that right now. Please try again."
            : muted
            ? "You won't see posts from ${shopName ?? 'this maker'} in your feed."
            : '${shopName ?? 'This maker'} is back in your feed.',
      ),
      action: ok && muted
          ? SnackBarAction(
              label: 'Undo',
              onPressed: () => notifier.set(shopId, false),
            )
          : null,
    ),
  );
}
