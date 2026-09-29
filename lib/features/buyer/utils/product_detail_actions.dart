import '../../../core/pricing/price_format.dart';

const String productShareBaseUrl = 'https://artisanlanesa.co.za/products';

String buildProductShareText({
  required String productId,
  required String title,
  required double price,
}) {
  final productUrl = '$productShareBaseUrl/${Uri.encodeComponent(productId)}';
  return 'Check out $title on Artisan Lane! ${formatBrowsePrice(price)}\n'
      '$productUrl';
}

bool requiresSignInForFavourite(String? userId) {
  return userId == null || userId.isEmpty;
}

bool requiresSignInForCart(String? userId) {
  return userId == null || userId.isEmpty;
}
