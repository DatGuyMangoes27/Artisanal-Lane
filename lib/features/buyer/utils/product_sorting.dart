import '../../../models/product.dart';

List<Product> filterProductsForDisplay(
  List<Product> products, {
  bool onSale = false,
  bool featured = false,
}) {
  return products
      .where((product) {
        if (!product.isAvailableForPurchase) return false;
        if (onSale && !product.isOnSale) return false;
        if (featured && !product.isFeatured) return false;
        return true;
      })
      .toList(growable: false);
}

List<Product> sortProductsForDisplay(
  List<Product> products, {
  required String sortBy,
  required bool ascending,
}) {
  final sorted = [...products];

  int compare(Product a, Product b) {
    switch (sortBy) {
      case 'price':
        return a.price.compareTo(b.price);
      case 'title':
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      case 'popular':
        return compareProductPopularity(a, b);
      case 'created_at':
      default:
        return a.createdAt.compareTo(b.createdAt);
    }
  }

  sorted.sort((a, b) {
    final result = compare(a, b);
    return ascending ? result : -result;
  });

  return sorted;
}

int compareProductPopularity(Product a, Product b) {
  final featuredComparison = a.isFeatured == b.isFeatured
      ? 0
      : (a.isFeatured ? 1 : -1);
  if (featuredComparison != 0) return featuredComparison;

  final aFeaturedAt = a.featuredAt ?? a.createdAt;
  final bFeaturedAt = b.featuredAt ?? b.createdAt;
  return aFeaturedAt.compareTo(bFeaturedAt);
}

List<Product> filterSearchProductsForDisplay(
  List<Product> products, {
  required int selectedFilter,
}) {
  return products
      .where((product) {
        if (!product.isAvailableForPurchase) return false;
        switch (selectedFilter) {
          case 1:
            return product.price < 200;
          case 2:
            return product.price >= 200 && product.price <= 500;
          case 3:
            return product.price > 500;
          case 4:
            return product.isOnSale;
          case 0:
          default:
            return true;
        }
      })
      .toList(growable: false);
}

({String sortBy, bool ascending}) searchSortForIndex(int selectedSort) {
  switch (selectedSort) {
    case 1:
      return (sortBy: 'price', ascending: true);
    case 2:
      return (sortBy: 'price', ascending: false);
    case 3:
      return (sortBy: 'popular', ascending: false);
    case 0:
    default:
      return (sortBy: 'created_at', ascending: false);
  }
}
