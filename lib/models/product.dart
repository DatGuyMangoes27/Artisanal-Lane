import 'product_option_group.dart';
import 'product_variant.dart';

class Product {
  final String id;
  final String shopId;
  final String? categoryId;
  final String? subcategoryId;
  final String title;
  final String? description;
  final double price;
  final double? compareAtPrice;
  final int stockQty;
  final List<String> images;
  final List<ProductOptionGroup> optionGroups;
  final List<ProductVariant> variants;
  final List<String> tags;
  final bool isPublished;
  final bool isFeatured;
  final String? careInstructions;
  final DateTime? featuredAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined data
  final String? shopName;
  final String? shopLogoUrl;
  final String? categoryName;
  final String? subcategoryName;

  const Product({
    required this.id,
    required this.shopId,
    this.categoryId,
    this.subcategoryId,
    required this.title,
    this.description,
    required this.price,
    this.compareAtPrice,
    this.stockQty = 0,
    this.images = const [],
    this.optionGroups = const [],
    this.variants = const [],
    this.tags = const [],
    this.isPublished = true,
    this.isFeatured = false,
    this.careInstructions,
    this.featuredAt,
    required this.createdAt,
    required this.updatedAt,
    this.shopName,
    this.shopLogoUrl,
    this.categoryName,
    this.subcategoryName,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    List<String> parseImages(dynamic img) {
      if (img == null) return [];
      if (img is List) return img.map((e) => e.toString()).toList();
      return [];
    }

    List<String> parseTags(dynamic t) {
      if (t == null) return [];
      if (t is List) return t.map((e) => e.toString()).toList();
      return [];
    }

    List<ProductOptionGroup> parseOptionGroups(
      dynamic raw,
      List<ProductVariant> variants,
    ) {
      if (raw is List) {
        return raw
            .map(
              (entry) => ProductOptionGroup.fromJson(
                Map<String, dynamic>.from(entry as Map),
              ),
            )
            .where((group) => group.name.trim().isNotEmpty)
            .toList(growable: false);
      }

      if (variants.isEmpty) {
        return const [];
      }

      final maxOptions = variants.fold<int>(
        0,
        (max, variant) => variant.optionValues.length > max
            ? variant.optionValues.length
            : max,
      );

      return List.generate(maxOptions, (index) {
        final values = <String>{};
        for (final variant in variants) {
          final value = variant.optionValueAt(index)?.trim();
          if (value != null && value.isNotEmpty) {
            values.add(value);
          }
        }
        return ProductOptionGroup(
          name: index == 0 ? 'Option' : 'Option ${index + 1}',
          values: values.toList(growable: false),
        );
      }).where((group) => group.values.isNotEmpty).toList(growable: false);
    }

    final shopData = json['shops'] as Map<String, dynamic>?;
    final categoryData = json['categories'] as Map<String, dynamic>?;
    final subcategoryData = json['subcategories'] as Map<String, dynamic>?;
    final variantsData = json['product_variants'] as List?;
    final variants = variantsData != null
        ? (variantsData
              .map(
                (entry) => ProductVariant.fromJson(
                  Map<String, dynamic>.from(entry as Map),
                ),
              )
              .toList()
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)))
        : const <ProductVariant>[];

    return Product(
      id: json['id'] as String,
      shopId: json['shop_id'] as String,
      categoryId: json['category_id'] as String?,
      subcategoryId: json['subcategory_id'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      price: (json['price'] as num).toDouble(),
      compareAtPrice: json['compare_at_price'] != null
          ? (json['compare_at_price'] as num).toDouble()
          : null,
      stockQty: json['stock_qty'] as int? ?? 0,
      images: parseImages(json['images']),
      optionGroups: parseOptionGroups(json['option_groups'], variants),
      variants: variants,
      tags: parseTags(json['tags']),
      isPublished: json['is_published'] as bool? ?? true,
      isFeatured: json['is_featured'] as bool? ?? false,
      careInstructions: json['care_instructions'] as String?,
      featuredAt: json['featured_at'] != null
          ? DateTime.parse(json['featured_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      shopName: shopData?['name'] as String?,
      shopLogoUrl: shopData?['logo_url'] as String?,
      categoryName: categoryData?['name'] as String?,
      subcategoryName: subcategoryData?['name'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'shop_id': shopId,
    'category_id': categoryId,
    'subcategory_id': subcategoryId,
    'title': title,
    'description': description,
    'price': price,
    'compare_at_price': compareAtPrice,
    'stock_qty': stockQty,
    'images': images,
    'option_groups': optionGroups.map((group) => group.toJson()).toList(),
    'product_variants': variants.map((variant) => variant.toJson()).toList(),
    'tags': tags,
    'is_published': isPublished,
    'is_featured': isFeatured,
    'care_instructions': careInstructions,
  };

  bool get isOnSale => compareAtPrice != null && compareAtPrice! > price;
  bool get hasVariants => variants.isNotEmpty;
  ProductVariant? get defaultVariant {
    for (final variant in variants) {
      if (variant.isActive) {
        return variant;
      }
    }
    return variants.isNotEmpty ? variants.first : null;
  }

  bool get isInStock => stockQty > 0;
  bool get isLowStock => stockQty > 0 && stockQty <= 5;
  String get primaryImage => images.isNotEmpty
      ? images.first
      : 'https://images.unsplash.com/photo-1565193566173-7a0ee3dbe261?w=400&h=400&fit=crop';
  double get discountPercent =>
      isOnSale ? ((compareAtPrice! - price) / compareAtPrice! * 100) : 0;
}
