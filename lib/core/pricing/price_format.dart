/// Browsing price label: whole rands without cents (R480), cents only when
/// present (R153.85). Checkout and earnings totals keep two decimals.
String formatBrowsePrice(num price) {
  final hasCents = (price * 100).round() % 100 != 0;
  return 'R${price.toStringAsFixed(hasCents ? 2 : 0)}';
}
