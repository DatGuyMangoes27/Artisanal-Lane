import '../../../models/shipping_option.dart';

List<ShippingOption> availableShippingOptionsForProducts(
  List<List<ShippingOption>> productShippingOptions,
) {
  if (productShippingOptions.isEmpty) return const [];

  final enabledByProduct = productShippingOptions
      .map(
        (options) =>
            options.where((option) => option.enabled).toList(growable: false),
      )
      .toList(growable: false);

  if (enabledByProduct.any((options) => options.isEmpty)) {
    return const [];
  }

  final first = enabledByProduct.first;
  return first
      .where((candidate) {
        return enabledByProduct.every(
          (options) => options.any((option) => option.key == candidate.key),
        );
      })
      .toList(growable: false);
}

double calculateProductShippingTotal({
  required String methodKey,
  required List<List<ShippingOption>> productShippingOptions,
}) {
  var highestPrice = 0.0;
  for (final options in productShippingOptions) {
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
    if (match.price > highestPrice) {
      highestPrice = match.price;
    }
  }
  return highestPrice;
}
