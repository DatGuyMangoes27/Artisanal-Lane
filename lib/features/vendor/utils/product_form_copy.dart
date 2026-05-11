const defaultProductOptionOneName = 'Size';
const defaultProductOptionTwoName = 'Color';

const productOptionsHelperText =
    'Most products only need Size and Color. You can rename these if your product needs something different.';

const defaultProductOptionOneValuesHint = 'Small, Medium, Large';
const defaultProductOptionTwoValuesHint = 'Black, Natural, Red';
const salePriceFieldLabel = 'Sale Price (R)';

class ProductPricingValues {
  final double price;
  final double? compareAtPrice;

  const ProductPricingValues({
    required this.price,
    required this.compareAtPrice,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductPricingValues &&
          runtimeType == other.runtimeType &&
          price == other.price &&
          compareAtPrice == other.compareAtPrice;

  @override
  int get hashCode => Object.hash(price, compareAtPrice);
}

class ProductPricingFieldValues {
  final String currentPriceText;
  final String salePriceText;

  const ProductPricingFieldValues({
    required this.currentPriceText,
    required this.salePriceText,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductPricingFieldValues &&
          runtimeType == other.runtimeType &&
          currentPriceText == other.currentPriceText &&
          salePriceText == other.salePriceText;

  @override
  int get hashCode => Object.hash(currentPriceText, salePriceText);
}

ProductPricingValues normalizeProductPricingForSave({
  required String currentPriceText,
  required String salePriceText,
}) {
  final currentPrice = parseProductPriceText(currentPriceText);
  final trimmedSalePrice = salePriceText.trim();

  if (trimmedSalePrice.isEmpty) {
    return ProductPricingValues(price: currentPrice, compareAtPrice: null);
  }

  final salePrice = parseProductPriceText(trimmedSalePrice);
  if (salePrice == currentPrice) {
    return ProductPricingValues(price: currentPrice, compareAtPrice: null);
  }

  final livePrice = currentPrice < salePrice ? currentPrice : salePrice;
  final originalPrice = currentPrice > salePrice ? currentPrice : salePrice;
  return ProductPricingValues(price: livePrice, compareAtPrice: originalPrice);
}

double parseProductPriceText(String value) {
  return double.parse(value.trim().replaceAll(',', '.'));
}

double? tryParseProductPriceText(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return double.tryParse(trimmed.replaceAll(',', '.'));
}

ProductPricingFieldValues pricingFieldsFromStoredValues({
  required double price,
  double? compareAtPrice,
}) {
  if (compareAtPrice == null || compareAtPrice == price) {
    return ProductPricingFieldValues(
      currentPriceText: price.toStringAsFixed(2),
      salePriceText: '',
    );
  }

  final originalPrice = price > compareAtPrice ? price : compareAtPrice;
  final salePrice = price < compareAtPrice ? price : compareAtPrice;
  return ProductPricingFieldValues(
    currentPriceText: originalPrice.toStringAsFixed(2),
    salePriceText: salePrice.toStringAsFixed(2),
  );
}

String currentPriceLabelForSalePrice(String salePriceText) {
  return salePriceText.trim().isNotEmpty ? 'Original Price (R)' : 'Price (R)';
}
