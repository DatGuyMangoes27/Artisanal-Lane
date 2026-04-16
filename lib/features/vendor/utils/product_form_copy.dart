const defaultProductOptionOneName = 'Size';
const defaultProductOptionTwoName = 'Color';

const productOptionsHelperText =
    'Most products only need Size and Color. You can rename these if your product needs something different.';

const defaultProductOptionOneValuesHint = 'Small, Medium, Large';
const defaultProductOptionTwoValuesHint = 'Black, Natural, Red';
const salePriceFieldLabel = 'Sale Price (R)';

String currentPriceLabelForSalePrice(String salePriceText) {
  return salePriceText.trim().isNotEmpty ? 'Original Price (R)' : 'Price (R)';
}
