import '../../../models/cart_item.dart';
import '../../../models/product.dart';
import '../../../models/product_variant.dart';

int availableStockForSelection(Product product, {ProductVariant? variant}) {
  return variant?.stockQty ?? product.stockQty;
}

int availableStockForCartItem(CartItem item) {
  return item.variant?.stockQty ?? item.product?.stockQty ?? 0;
}

int quantityForMatchingCartSelection(
  Iterable<CartItem> items,
  String productId, {
  String? variantId,
}) {
  return items
      .where(
        (item) => item.productId == productId && item.variantId == variantId,
      )
      .fold<int>(0, (sum, item) => sum + item.quantity);
}

bool canAddSelectionToCart(
  Iterable<CartItem> items,
  Product product, {
  ProductVariant? variant,
  int increment = 1,
}) {
  final availableStock = availableStockForSelection(product, variant: variant);
  final currentQuantity = quantityForMatchingCartSelection(
    items,
    product.id,
    variantId: variant?.id,
  );
  return currentQuantity + increment <= availableStock;
}

bool canIncreaseCartItemQuantity(CartItem item) {
  return item.quantity < availableStockForCartItem(item);
}

String stockLimitMessage(int availableStock) {
  if (availableStock <= 0) {
    return 'This item is out of stock';
  }
  if (availableStock == 1) {
    return 'Only 1 item left in stock';
  }
  return 'Only $availableStock items left in stock';
}
