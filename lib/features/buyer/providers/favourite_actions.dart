import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../widgets/sign_in_prompt_sheet.dart';
import '../utils/product_detail_actions.dart';
import 'buyer_providers.dart';

/// Optimistic favourite state shared by every heart in the app. An override
/// holds the user's latest choice until the server list agrees with it.
class FavouriteOverrides {
  const FavouriteOverrides({this.values = const {}, this.inFlight = const {}});
  final Map<String, bool> values;
  final Set<String> inFlight;
}

class FavouriteOverridesNotifier extends Notifier<FavouriteOverrides> {
  @override
  FavouriteOverrides build() {
    ref.listen<List<String>>(currentFavouriteIdsProvider, (_, next) {
      final settled = next.toSet();
      final remaining = {
        for (final entry in state.values.entries)
          if (state.inFlight.contains(entry.key) ||
              settled.contains(entry.key) != entry.value)
            entry.key: entry.value,
      };
      if (remaining.length != state.values.length) {
        state = FavouriteOverrides(values: remaining, inFlight: state.inFlight);
      }
    });
    return const FavouriteOverrides();
  }

  void begin(String productId, bool saved) => state = FavouriteOverrides(
    values: {...state.values, productId: saved},
    inFlight: {...state.inFlight, productId},
  );

  void settle(String productId) => state = FavouriteOverrides(
    values: state.values,
    inFlight: {...state.inFlight}..remove(productId),
  );

  void rollback(String productId) => state = FavouriteOverrides(
    values: {...state.values}..remove(productId),
    inFlight: {...state.inFlight}..remove(productId),
  );
}

final favouriteOverridesProvider =
    NotifierProvider<FavouriteOverridesNotifier, FavouriteOverrides>(
      FavouriteOverridesNotifier.new,
    );

/// Favourite ids including choices still being saved.
final effectiveFavouriteIdsProvider = Provider<Set<String>>((ref) {
  final ids = ref.watch(currentFavouriteIdsProvider).toSet();
  for (final entry in ref.watch(favouriteOverridesProvider).values.entries) {
    entry.value ? ids.add(entry.key) : ids.remove(entry.key);
  }
  return ids;
});

final isFavouriteProvider = Provider.family<bool, String>(
  (ref, productId) =>
      ref.watch(effectiveFavouriteIdsProvider).contains(productId),
);

/// Toggles a favourite instantly, saving in the background and rolling back
/// with a message if the save fails. Guests are asked to sign in.
Future<void> toggleFavourite(
  WidgetRef ref,
  BuildContext context,
  String productId,
) async {
  final userId = ref.read(currentUserIdProvider);
  if (requiresSignInForFavourite(userId)) {
    await showSignInPromptSheet(
      context,
      title: 'Sign in to save favourites',
      message:
          'Create an account or sign in to save this item to your favourites.',
    );
    return;
  }
  final overrides = ref.read(favouriteOverridesProvider.notifier);
  if (ref.read(favouriteOverridesProvider).inFlight.contains(productId)) return;
  final saved = !ref.read(isFavouriteProvider(productId));
  final messenger = ScaffoldMessenger.maybeOf(context);
  HapticFeedback.lightImpact();
  overrides.begin(productId, saved);
  try {
    final service = ref.read(supabaseServiceProvider);
    if (saved) {
      await service.addFavourite(userId!, productId);
    } else {
      await service.removeFavourite(userId!, productId);
    }
    overrides.settle(productId);
    ref.invalidate(favouriteIdsProvider);
    ref.invalidate(favouriteProductsProvider);
  } catch (_) {
    overrides.rollback(productId);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? "Couldn't save to favourites. Please try again."
              : "Couldn't remove from favourites. Please try again.",
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
