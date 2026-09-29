import 'dart:async';
import 'package:artisanal_lane/features/auth/providers/auth_providers.dart';
import 'package:artisanal_lane/features/buyer/utils/discovery_preferences.dart';
import 'package:artisanal_lane/features/buyer/utils/discovery_remote_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Cloud implements DiscoveryRemoteStore {
  final choices = <String, Map<String, Object?>>{};
  final decisions = <String, Map<String, bool>>{};
  Completer<void>? pending;
  bool failWrites = false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<void> saveChoices(
    String user,
    Set<String> categories,
    double? budget, {
    bool onlyIfMissing = false,
  }) async {
    if (failWrites) throw StateError('offline');
    if (onlyIfMissing && choices.containsKey(user)) return;
    choices[user] = {'categories': categories.toList(), 'budget': budget};
  }

  @override
  Future<Map<String, Object?>?> load(String user) async {
    if (!choices.containsKey(user)) return null;
    return {
      ...choices[user]!,
      'liked': (decisions[user] ?? {}).entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList(),
      'skipped': (decisions[user] ?? {}).entries
          .where((e) => !e.value)
          .map((e) => e.key)
          .toList(),
    };
  }

  @override
  Future<void> recordDecision(String user, String product, bool liked) async {
    if (pending != null) await pending!.future;
    if (failWrites) throw StateError('offline');
    (decisions[user] ??= {})[product] = liked;
  }

  @override
  Future<void> importLocalDecisions(
    String user,
    Set<String> liked,
    Set<String> skipped,
  ) async {
    final rows = decisions[user] ??= {};
    for (final id in liked) {
      rows.putIfAbsent(id, () => true);
    }
    for (final id in skipped) {
      rows.putIfAbsent(id, () => false);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  ProviderContainer device(Cloud cloud, {String Function()? account}) {
    final c = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWith((ref) => account?.call() ?? 'buyer'),
        discoverySyncEnabledProvider.overrideWithValue(true),
        discoveryRemoteStoreProvider.overrideWithValue(cloud),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test(
    'two devices preserve separate swipes and share category and budget choices',
    () async {
      final cloud = Cloud();
      // Use the same backend with independent provider states.
      final first = device(cloud), second = device(cloud);
      await first.read(discoveryPreferencesProvider.future);
      await second.read(discoveryPreferencesProvider.future);
      await first
          .read(discoveryPreferencesProvider.notifier)
          .recordDecision('one', liked: true);
      await second
          .read(discoveryPreferencesProvider.notifier)
          .recordDecision('two', liked: false);
      await first
          .read(discoveryPreferencesProvider.notifier)
          .updateChoices(categoryIds: {'home'}, maxBudget: 500);
      final reloaded = await second.refresh(
        discoveryPreferencesProvider.future,
      );
      expect(reloaded.likedProductIds, {'one'});
      expect(reloaded.skippedProductIds, {'two'});
      expect(reloaded.categoryIds, {'home'});
      expect(reloaded.maxBudget, 500);
    },
  );
  test('failed remote writes do not pretend a preference was synced', () async {
    final cloud = Cloud();
    final actual = device(cloud);
    await actual.read(discoveryPreferencesProvider.future);
    cloud.failWrites = true;
    await expectLater(
      actual
          .read(discoveryPreferencesProvider.notifier)
          .recordDecision('one', liked: true),
      throwsStateError,
    );
    expect(
      actual.read(discoveryPreferencesProvider).value!.likedProductIds,
      isEmpty,
    );
  });
  test(
    'an in-flight old-account save cannot replace the new account state',
    () async {
      var user = 'a';
      final cloud = Cloud();
      final c = device(cloud, account: () => user);
      await c.read(discoveryPreferencesProvider.future);
      cloud.pending = Completer<void>();
      final saving = c
          .read(discoveryPreferencesProvider.notifier)
          .recordDecision('old', liked: true);
      final failure = expectLater(saving, throwsStateError);
      user = 'b';
      c.invalidate(currentUserIdProvider);
      await c.read(discoveryPreferencesProvider.future);
      cloud.pending!.complete();
      await failure;
      expect(
        c.read(discoveryPreferencesProvider).value!.likedProductIds,
        isEmpty,
      );
    },
  );
}
