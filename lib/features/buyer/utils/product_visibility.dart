import '../../../models/product.dart';

bool isBuyerVisibleProduct(Product product) {
  return product.isPublished && product.isInStock;
}
