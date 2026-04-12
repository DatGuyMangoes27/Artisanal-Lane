String buildProductShareText({
  required String title,
  required double price,
}) {
  return 'Check out $title on Artisan Lane! R${price.toStringAsFixed(0)}';
}

bool requiresSignInForFavourite(String? userId) {
  return userId == null || userId.isEmpty;
}

bool requiresSignInForCart(String? userId) {
  return userId == null || userId.isEmpty;
}
