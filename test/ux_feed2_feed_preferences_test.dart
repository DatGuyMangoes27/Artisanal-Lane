import 'package:artisanal_lane/features/auth/providers/auth_providers.dart';
import 'package:artisanal_lane/features/buyer/providers/feed_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'feedPreferencesKey is scoped per account, with a shared guest bucket',
    () {
      expect(feedPreferencesKey(null), feedPreferencesKey(''));
      expect(feedPreferencesKey('user-1'), isNot(feedPreferencesKey('user-2')));
      expect(feedPreferencesKey('user-1'), isNot(feedPreferencesKey(null)));
    },
  );

  test(
    'toggling a boosted category persists across a rebuilt provider',
    () async {
      final container = ProviderContainer(
        overrides: [currentUserIdProvider.overrideWithValue('buyer-1')],
      );
      addTearDown(container.dispose);

      await container.read(feedPreferencesProvider.future);
      await container
          .read(feedPreferencesProvider.notifier)
          .toggleBoostedCategory('jewellery');

      final state = container.read(feedPreferencesProvider).value!;
      expect(state.boostedCategoryIds, {'jewellery'});

      // A fresh container simulates a cold app restart reading the same
      // on-device cache back.
      final restarted = ProviderContainer(
        overrides: [currentUserIdProvider.overrideWithValue('buyer-1')],
      );
      addTearDown(restarted.dispose);
      final reloaded = await restarted.read(feedPreferencesProvider.future);
      expect(reloaded.boostedCategoryIds, {'jewellery'});
    },
  );

  test('toggling a boosted category twice clears it', () async {
    final container = ProviderContainer(
      overrides: [currentUserIdProvider.overrideWithValue('buyer-2')],
    );
    addTearDown(container.dispose);
    await container.read(feedPreferencesProvider.future);
    final notifier = container.read(feedPreferencesProvider.notifier);

    await notifier.toggleBoostedCategory('homeware');
    expect(container.read(feedPreferencesProvider).value!.boostedCategoryIds, {
      'homeware',
    });
    await notifier.toggleBoostedCategory('homeware');
    expect(
      container.read(feedPreferencesProvider).value!.boostedCategoryIds,
      isEmpty,
    );
  });

  test('muting and unmuting a shop updates mutedShopIds', () async {
    final container = ProviderContainer(
      overrides: [currentUserIdProvider.overrideWithValue('buyer-3')],
    );
    addTearDown(container.dispose);
    await container.read(feedPreferencesProvider.future);
    final notifier = container.read(feedPreferencesProvider.notifier);

    await notifier.muteShop('shop-9');
    expect(container.read(feedPreferencesProvider).value!.mutedShopIds, {
      'shop-9',
    });

    await notifier.unmuteShop('shop-9');
    expect(
      container.read(feedPreferencesProvider).value!.mutedShopIds,
      isEmpty,
    );
  });

  test('preferences are isolated between different accounts', () async {
    final buyerOne = ProviderContainer(
      overrides: [currentUserIdProvider.overrideWithValue('buyer-a')],
    );
    addTearDown(buyerOne.dispose);
    await buyerOne.read(feedPreferencesProvider.future);
    await buyerOne
        .read(feedPreferencesProvider.notifier)
        .muteShop('shop-only-for-a');

    final buyerTwo = ProviderContainer(
      overrides: [currentUserIdProvider.overrideWithValue('buyer-b')],
    );
    addTearDown(buyerTwo.dispose);
    final buyerTwoPrefs = await buyerTwo.read(feedPreferencesProvider.future);
    expect(buyerTwoPrefs.mutedShopIds, isEmpty);
  });
}
