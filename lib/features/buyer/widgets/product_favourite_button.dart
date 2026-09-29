import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../providers/favourite_actions.dart';

/// Heart overlay for product photos. Updates instantly and saves in the
/// background through [toggleFavourite].
class ProductFavouriteButton extends ConsumerWidget {
  const ProductFavouriteButton({super.key, required this.productId});
  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(isFavouriteProvider(productId));
    return Semantics(
      button: true,
      label: saved ? 'Remove from favourites' : 'Save to favourites',
      child: InkResponse(
        onTap: () => toggleFavourite(ref, context, productId),
        radius: 24,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(7),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: Icon(
                    saved
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    key: ValueKey(saved),
                    size: 18,
                    color: saved ? AppTheme.error : AppTheme.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
