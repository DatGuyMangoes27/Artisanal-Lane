import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/providers/auth_providers.dart';

// Enable only alongside the checked, deployed discovery migration.
final discoverySyncEnabledProvider = Provider(
  (ref) =>
      const bool.fromEnvironment('DISCOVERY_SYNC_ENABLED', defaultValue: false),
);
final discoveryRemoteStoreProvider = Provider(
  (ref) => DiscoveryRemoteStore(ref.watch(supabaseClientProvider)),
);

class DiscoveryRemoteStore {
  DiscoveryRemoteStore(this.client);
  final SupabaseClient client;
  void _check(String user) {
    if (client.auth.currentUser?.id != user) {
      throw StateError('Account changed while saving preferences.');
    }
  }

  Future<Map<String, Object?>?> load(String user) async {
    _check(user);
    final row = await client
        .from('discovery_choices')
        .select()
        .eq('user_id', user)
        .maybeSingle();
    _check(user);
    if (row == null) return null;
    final liked = <String>[], skipped = <String>[];
    // Paginate rather than silently truncating at the API's default row limit.
    var offset = 0;
    while (true) {
      final decisions = await client
          .from('discovery_product_decisions')
          .select('product_id,liked')
          .eq('user_id', user)
          .order('product_id')
          .range(offset, offset + 499);
      _check(user);
      for (final d in decisions) {
        (d['liked'] == true ? liked : skipped).add(d['product_id'] as String);
      }
      if (decisions.length < 500) break;
      offset += 500;
    }
    return {
      'categories': row['category_ids'],
      'budget': row['max_budget'],
      'liked': liked,
      'skipped': skipped,
    };
  }

  Future<void> saveChoices(
    String user,
    Set<String> categories,
    double? budget, {
    bool onlyIfMissing = false,
  }) async {
    _check(user);
    await client
        .from('discovery_choices')
        .upsert(
          {
            'user_id': user,
            'category_ids': categories.toList(),
            'max_budget': budget,
          },
          onConflict: 'user_id',
          ignoreDuplicates: onlyIfMissing,
        );
    _check(user);
  }

  Future<void> recordDecision(String user, String product, bool liked) async {
    _check(user);
    await client.from('discovery_product_decisions').upsert({
      'user_id': user,
      'product_id': product,
      'liked': liked,
    }, onConflict: 'user_id,product_id');
    _check(user);
  }

  /// Reverts a single decision (used to undo a swipe). Safe to call even if
  /// no row exists yet.
  Future<void> deleteDecision(String user, String product) async {
    _check(user);
    await client
        .from('discovery_product_decisions')
        .delete()
        .eq('user_id', user)
        .eq('product_id', product);
    _check(user);
  }

  Future<void> importLocalDecisions(
    String user,
    Set<String> liked,
    Set<String> skipped,
  ) async {
    final ids = {...liked, ...skipped}.toList();
    for (var start = 0; start < ids.length; start += 100) {
      _check(user);
      final batch = ids.skip(start).take(100).toList();
      // A deleted/hidden old product must not make the entire import fail.
      final visible = await client
          .from('products')
          .select('id')
          .inFilter('id', batch);
      _check(user);
      if (visible.isNotEmpty) {
        await client
            .from('discovery_product_decisions')
            .upsert(
              visible
                  .map(
                    (p) => {
                      'user_id': user,
                      'product_id': p['id'],
                      'liked': liked.contains(p['id']),
                    },
                  )
                  .toList(),
              onConflict: 'user_id,product_id',
              ignoreDuplicates: true,
            );
      }
    }
    _check(user);
  }
}
