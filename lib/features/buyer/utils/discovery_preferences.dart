import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/product.dart';
import '../../auth/providers/auth_providers.dart';
import 'discovery_remote_store.dart';

/// Personal choices with device caching and opt-in, account-private cloud sync.
class DiscoveryPreferences {
  const DiscoveryPreferences({
    this.categoryIds = const <String>{},
    this.maxBudget,
    this.likedProductIds = const <String>{},
    this.skippedProductIds = const <String>{},
  });

  final Set<String> categoryIds;
  final double? maxBudget;
  final Set<String> likedProductIds;
  final Set<String> skippedProductIds;

  DiscoveryPreferences copyWith({
    Set<String>? categoryIds,
    double? maxBudget,
    bool clearBudget = false,
    Set<String>? likedProductIds,
    Set<String>? skippedProductIds,
  }) => DiscoveryPreferences(
    categoryIds: categoryIds ?? this.categoryIds,
    maxBudget: clearBudget ? null : (maxBudget ?? this.maxBudget),
    likedProductIds: likedProductIds ?? this.likedProductIds,
    skippedProductIds: skippedProductIds ?? this.skippedProductIds,
  );

  Map<String, Object?> toJson() => {
    'categories': categoryIds.toList(),
    'budget': maxBudget,
    'liked': likedProductIds.toList(),
    'skipped': skippedProductIds.toList(),
  };
}

String discoveryPreferencesKey(String? userId) =>
    'discover_preferences_v1:${userId?.trim().isNotEmpty == true ? userId : 'guest'}';

DiscoveryPreferences discoveryPreferencesFromMap(Map<String, Object?> map) {
  Set<String> values(String key) =>
      ((map[key] as List?) ?? const <Object?>[]).whereType<String>().toSet();
  return DiscoveryPreferences(
    categoryIds: values('categories'),
    maxBudget: (map['budget'] as num?)?.toDouble(),
    likedProductIds: values('liked'),
    skippedProductIds: values('skipped'),
  );
}

class DiscoveryPreferencesNotifier extends AsyncNotifier<DiscoveryPreferences> {
  String get _key => discoveryPreferencesKey(ref.read(currentUserIdProvider));

  @override
  Future<DiscoveryPreferences> build() async {
    // Rebuild when the signed-in buyer changes so choices stay user-scoped.
    final userId = ref.watch(currentUserIdProvider);
    final sync = ref.watch(discoverySyncEnabledProvider) && userId != null;
    final remote = sync ? ref.watch(discoveryRemoteStoreProvider) : null;
    final key = discoveryPreferencesKey(userId);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(key);
    final map = <String, Object?>{};
    for (final entry in raw ?? <String>[]) {
      final split = entry.split('=');
      if (split.length < 2) continue;
      final values = split.sublist(1);
      if (split.first == 'budget') {
        map['budget'] = double.tryParse(values.join('='));
      } else {
        map[split.first] = values.join('=').isEmpty
            ? <String>[]
            : values.join('=').split(',');
      }
    }
    final cached = discoveryPreferencesFromMap(map);
    if (remote == null) return cached;
    // Seed preferences only when absent; never overwrite another device on open.
    await remote.saveChoices(
      userId!,
      cached.categoryIds,
      cached.maxBudget,
      onlyIfMissing: true,
    );
    if (prefs.getBool('$key:cloud-imported') != true) {
      await remote.importLocalDecisions(
        userId,
        cached.likedProductIds,
        cached.skippedProductIds,
      );
      await prefs.setBool('$key:cloud-imported', true);
    }
    final cloud = await remote.load(userId);
    if (cloud == null) throw StateError('Preferences could not be confirmed.');
    return discoveryPreferencesFromMap(cloud);
  }

  Future<void> updateChoices({
    required Set<String> categoryIds,
    required double? maxBudget,
  }) async {
    final key = _key;
    final user = ref.read(currentUserIdProvider);
    if (ref.read(discoverySyncEnabledProvider) && user != null) {
      await ref
          .read(discoveryRemoteStoreProvider)
          .saveChoices(user, categoryIds, maxBudget);
      if (key != _key) throw StateError('Your account changed.');
    }
    final next = (state.value ?? const DiscoveryPreferences()).copyWith(
      categoryIds: categoryIds,
      maxBudget: maxBudget,
      clearBudget: maxBudget == null,
    );
    await _save(next, key);
  }

  Future<void> recordDecision(String productId, {required bool liked}) async {
    final key = _key;
    final user = ref.read(currentUserIdProvider);
    if (ref.read(discoverySyncEnabledProvider) && user != null) {
      await ref
          .read(discoveryRemoteStoreProvider)
          .recordDecision(user, productId, liked);
      if (key != _key) throw StateError('Your account changed.');
    }
    final current = state.value ?? const DiscoveryPreferences();
    final likedIds = {...current.likedProductIds};
    final skippedIds = {...current.skippedProductIds};
    if (liked) {
      likedIds.add(productId);
      skippedIds.remove(productId);
    } else {
      skippedIds.add(productId);
      likedIds.remove(productId);
    }
    await _save(
      current.copyWith(
        likedProductIds: likedIds,
        skippedProductIds: skippedIds,
      ),
      key,
    );
  }

  /// Reverts a previous like/skip decision, restoring the product to the
  /// deck. Deletes the synced remote decision when sync applies, so the
  /// undo is not just a local-only illusion.
  Future<void> undoDecision(String productId) async {
    final key = _key;
    final current = state.value ?? const DiscoveryPreferences();
    if (!current.likedProductIds.contains(productId) &&
        !current.skippedProductIds.contains(productId)) {
      return;
    }
    final user = ref.read(currentUserIdProvider);
    if (ref.read(discoverySyncEnabledProvider) && user != null) {
      await ref
          .read(discoveryRemoteStoreProvider)
          .deleteDecision(user, productId);
      if (key != _key) throw StateError('Your account changed.');
    }
    final likedIds = {...current.likedProductIds}..remove(productId);
    final skippedIds = {...current.skippedProductIds}..remove(productId);
    await _save(
      current.copyWith(
        likedProductIds: likedIds,
        skippedProductIds: skippedIds,
      ),
      key,
    );
  }

  Future<void> _save(DiscoveryPreferences next, String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, [
      'categories=${next.categoryIds.join(',')}',
      'budget=${next.maxBudget ?? ''}',
      'liked=${next.likedProductIds.join(',')}',
      'skipped=${next.skippedProductIds.join(',')}',
    ]);
    if (key == _key) state = AsyncData(next);
  }
}

final discoveryPreferencesProvider =
    AsyncNotifierProvider<DiscoveryPreferencesNotifier, DiscoveryPreferences>(
      DiscoveryPreferencesNotifier.new,
    );

/// A deliberately transparent, local ranking. It only uses the buyer's saved
/// category, budget, and in-app like/skip decisions.
List<Product> rankDiscoverProducts(
  List<Product> products,
  DiscoveryPreferences preferences,
) {
  final liked = products
      .where((product) => preferences.likedProductIds.contains(product.id))
      .toList(growable: false);
  int score(Product product) {
    var value = product.isFeatured ? 1 : 0;
    if (preferences.categoryIds.contains(product.categoryId)) value += 6;
    for (final favourite in liked) {
      if (favourite.categoryId != null &&
          favourite.categoryId == product.categoryId) {
        value += 4;
      }
      value += product.tags.where(favourite.tags.contains).length * 2;
    }
    return value;
  }

  // Already-decided items (loved or skipped) never reappear in the deck.
  final visible = products
      .where((product) => !preferences.skippedProductIds.contains(product.id))
      .where((product) => !preferences.likedProductIds.contains(product.id))
      .where(
        (product) =>
            preferences.maxBudget == null ||
            product.price <= preferences.maxBudget!,
      )
      .toList();
  visible.sort((a, b) {
    final byScore = score(b).compareTo(score(a));
    return byScore != 0 ? byScore : b.createdAt.compareTo(a.createdAt);
  });
  return visible;
}
