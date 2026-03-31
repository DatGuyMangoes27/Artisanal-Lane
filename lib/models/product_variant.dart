class ProductVariant {
  final String id;
  final String productId;
  final String displayName;
  final List<String> optionValues;
  final double price;
  final double? compareAtPrice;
  final int stockQty;
  final List<String> images;
  final int sortOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProductVariant({
    required this.id,
    required this.productId,
    required this.displayName,
    this.optionValues = const [],
    required this.price,
    this.compareAtPrice,
    this.stockQty = 0,
    this.images = const [],
    this.sortOrder = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    List<String> parseImages(dynamic img) {
      if (img == null) return [];
      if (img is List) return img.map((e) => e.toString()).toList();
      return [];
    }

    List<String> parseOptionValues(dynamic values, String fallback) {
      if (values is List) {
        return values.map((entry) => entry.toString()).toList(growable: false);
      }
      if (fallback.isNotEmpty) {
        return [fallback];
      }
      return const [];
    }

    final legacyName =
        (json['color_name'] as String?) ??
        (json['display_name'] as String?) ??
        '';
    final optionValues = parseOptionValues(json['option_values'], legacyName);
    final displayName =
        (json['display_name'] as String?)?.trim().isNotEmpty == true
        ? (json['display_name'] as String).trim()
        : optionValues.join(' / ');

    return ProductVariant(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      displayName: displayName,
      optionValues: optionValues,
      price: (json['price'] as num).toDouble(),
      compareAtPrice: json['compare_at_price'] != null
          ? (json['compare_at_price'] as num).toDouble()
          : null,
      stockQty: json['stock_qty'] as int? ?? 0,
      images: parseImages(json['images']),
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'product_id': productId,
    'display_name': displayName,
    'color_name': optionValues.length <= 1
        ? (optionValues.isEmpty ? displayName : optionValues.first)
        : displayName,
    'option_values': optionValues,
    'price': price,
    'compare_at_price': compareAtPrice,
    'stock_qty': stockQty,
    'images': images,
    'sort_order': sortOrder,
    'is_active': isActive,
  };

  bool get isInStock => stockQty > 0;
  bool get isLowStock => stockQty > 0 && stockQty <= 5;
  bool get isOnSale => compareAtPrice != null && compareAtPrice! > price;
  String get primaryImage => images.isNotEmpty ? images.first : '';
  String get colorName => displayName;

  String? optionValueAt(int index) {
    if (index < 0 || index >= optionValues.length) {
      return null;
    }
    return optionValues[index];
  }
}
