import '../../../models/product.dart';
import 'product_visibility.dart';

List<Product> favouriteProductsFromRows(List<dynamic> rows) {
  final products = <Product>[];

  for (final row in rows) {
    if (row is! Map) continue;
    final product = row['products'];
    if (product is! Map) continue;

    final parsedProduct = Product.fromJson(Map<String, dynamic>.from(product));
    if (!isBuyerVisibleProduct(parsedProduct)) continue;

    products.add(parsedProduct);
  }

  return products;
}
