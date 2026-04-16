import '../../../models/shipping_option.dart';

List<ShippingOption> availableShippingOptionsForProducts(
  List<List<ShippingOption>> productShippingOptions,
) {
  if (productShippingOptions.isEmpty) return const [];

  final enabledByProduct = productShippingOptions
      .map(
        (options) => options.where((option) => option.enabled).toList(growable: false),
      )
      .toList(growable: false);

  if (enabledByProduct.any((options) => options.isEmpty)) {
    return const [];
  }

  final first = enabledByProduct.first;
  return first.where((candidate) {
    return enabledByProduct.every(
      (options) => options.any((option) => option.key == candidate.key),
    );
  }).toList(growable: false);
}

double calculateProductShippingTotal({
  required String methodKey,
  required List<int> itemQuantities,
  required List<List<ShippingOption>> productShippingOptions,
}) {
  if (itemQuantities.length != productShippingOptions.length) {
    throw ArgumentError(
      'itemQuantities and productShippingOptions must have the same length.',
    );
  }

  var total = 0.0;
  for (var index = 0; index < productShippingOptions.length; index++) {
    final options = productShippingOptions[index];
    final quantity = itemQuantities[index];
    ShippingOption? match;
    for (final option in options) {
      if (option.key == methodKey) {
        match = option;
        break;
      }
    }
    if (match == null || !match.enabled) {
      throw ArgumentError('Shipping method $methodKey is not available.');
    }
    total += match.price * quantity;
  }
  return total;
}
