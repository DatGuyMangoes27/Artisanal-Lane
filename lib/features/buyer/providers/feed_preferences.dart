import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/providers/auth_providers.dart';

/// Personal "Shape your feed" choices: categories to see more of, and
/// makers to see fewer posts from. Cached on-device only, scoped per
/// signed-in account (or a shared guest bucket), and fed into the "For you"
/// ranking. Never synced or shown to anyone else.
class FeedPreferences {
  const FeedPreferences({
    this.boostedCategoryIds = const <String>{},
    this.mutedShopIds = const <String>{},
  });

  final Set<String> boostedCategoryIds;
  final Set<String> mutedShopIds;

  FeedPreferences copyWith({
    Set<String>? boostedCategoryIds,
    Set<String>? mutedShopIds,
  }) => FeedPreferences(
    boostedCategoryIds: boostedCategoryIds ?? this.boostedCategoryIds,
    mutedShopIds: mutedShopIds ?? this.mutedShopIds,
  );
}

String feedPreferencesKey(String? userId) =>
    'feed_preferences_v1:${userId?.trim().isNotEmpty == true ? userId : 'guest'}';

class FeedPreferencesNotifier extends AsyncNotifier<FeedPreferences> {
  String get _key => feedPreferencesKey(ref.read(currentUserIdProvider));

  @override
  Future<FeedPreferences> build() async {
    // Rebuild when the signed-in buyer changes so choices stay user-scoped.
    final userId = ref.watch(currentUserIdProvider);
    final key = feedPreferencesKey(userId);
    final prefs = await SharedPreferences.getInstance();
    return FeedPreferences(
      boostedCategoryIds: (prefs.getStringList('$key:boosted') ?? const [])
          .toSet(),
      mutedShopIds: (prefs.getStringList('$key:muted') ?? const []).toSet(),
    );
  }

  Future<void> toggleBoostedCategory(String categoryId) async {
    final key = _key;
    final current = state.value ?? const FeedPreferences();
    final next = {...current.boostedCategoryIds};
    if (!next.remove(categoryId)) next.add(categoryId);
    await _save(current.copyWith(boostedCategoryIds: next), key);
  }

  Future<void> muteShop(String shopId) async {
    final key = _key;
    final current = state.value ?? const FeedPreferences();
    if (current.mutedShopIds.contains(shopId)) return;
    await _save(
      current.copyWith(mutedShopIds: {...current.mutedShopIds, shopId}),
      key,
    );
  }

  Future<void> unmuteShop(String shopId) async {
    final key = _key;
    final current = state.value ?? const FeedPreferences();
    if (!current.mutedShopIds.contains(shopId)) return;
    final next = {...current.mutedShopIds}..remove(shopId);
    await _save(current.copyWith(mutedShopIds: next), key);
  }

  Future<void> _save(FeedPreferences next, String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('$key:boosted', next.boostedCategoryIds.toList());
    await prefs.setStringList('$key:muted', next.mutedShopIds.toList());
    if (key == _key) state = AsyncData(next);
  }
}

final feedPreferencesProvider =
    AsyncNotifierProvider<FeedPreferencesNotifier, FeedPreferences>(
      FeedPreferencesNotifier.new,
    );
