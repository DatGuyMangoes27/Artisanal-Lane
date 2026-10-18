import 'product_option_group.dart';
import 'shipping_option.dart';
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
  final List<ShippingOption> shippingOptions;

  /// Packed parcel size for courier (Bob Go) quotes; null when not set.
  final double? shippingWeightKg;
  final double? shippingLengthCm;
  final double? shippingWidthCm;
  final double? shippingHeightCm;
  final bool isPublished;
  final bool isFeatured;
  final String? careInstructions;
  final String? fragranceDescription;
  final String fulfillmentMode;
  final double? madeToOrderPrice;
  final int? leadMinDays;
  final int? leadMaxDays;
  final int? madeToOrderCapacity;
  final bool allowCustomNote;
  final DateTime? featuredAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined data
  final String? shopName;
  final String? shopLogoUrl;
  final bool shopIsVerified;
  final String? shopLocation;
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
    this.shippingOptions = const [],
    this.shippingWeightKg,
    this.shippingLengthCm,
    this.shippingWidthCm,
    this.shippingHeightCm,
    this.isPublished = true,
    this.isFeatured = false,
    this.careInstructions,
    this.fragranceDescription,
    this.fulfillmentMode = 'stocked',
    this.madeToOrderPrice,
    this.leadMinDays,
    this.leadMaxDays,
    this.madeToOrderCapacity,
    this.allowCustomNote = false,
    this.featuredAt,
    required this.createdAt,
    required this.updatedAt,
    this.shopName,
    this.shopLogoUrl,
    this.shopIsVerified = false,
    this.shopLocation,
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
      shippingOptions: ShippingOption.listFromJson(
        json['shipping_options'],
        fallback: const [],
      ),
      shippingWeightKg: (json['shipping_weight_kg'] as num?)?.toDouble(),
      shippingLengthCm: (json['shipping_length_cm'] as num?)?.toDouble(),
      shippingWidthCm: (json['shipping_width_cm'] as num?)?.toDouble(),
      shippingHeightCm: (json['shipping_height_cm'] as num?)?.toDouble(),
      isPublished: json['is_published'] as bool? ?? true,
      isFeatured: json['is_featured'] as bool? ?? false,
      careInstructions: json['care_instructions'] as String?,
      fragranceDescription: json['fragrance_description'] as String?,
      fulfillmentMode: json['fulfillment_mode'] as String? ?? 'stocked',
      madeToOrderPrice: json['made_to_order_price'] != null
          ? (json['made_to_order_price'] as num).toDouble()
          : null,
      leadMinDays: json['made_to_order_lead_min_days'] as int?,
      leadMaxDays: json['made_to_order_lead_max_days'] as int?,
      madeToOrderCapacity: json['made_to_order_capacity'] as int?,
      allowCustomNote:
          json['made_to_order_allow_custom_note'] as bool? ?? false,
      featuredAt: json['featured_at'] != null
          ? DateTime.parse(json['featured_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      shopName: shopData?['name'] as String?,
      shopLogoUrl: shopData?['logo_url'] as String?,
      shopIsVerified: shopData?['is_verified'] as bool? ?? false,
      shopLocation: shopData?['location'] as String?,
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
    'shipping_options': shippingOptions
        .map((option) => option.toJson())
        .toList(),
    'shipping_weight_kg': shippingWeightKg,
    'shipping_length_cm': shippingLengthCm,
    'shipping_width_cm': shippingWidthCm,
    'shipping_height_cm': shippingHeightCm,
    'is_published': isPublished,
    'is_featured': isFeatured,
    'care_instructions': careInstructions,
    'fragrance_description': fragranceDescription,
    'fulfillment_mode': fulfillmentMode,
    'made_to_order_price': madeToOrderPrice,
    'made_to_order_lead_min_days': leadMinDays,
    'made_to_order_lead_max_days': leadMaxDays,
    'made_to_order_capacity': madeToOrderCapacity,
    'made_to_order_allow_custom_note': allowCustomNote,
  };

  bool get isOnSale => compareAtPrice != null && compareAtPrice! > price;
  bool get hasVariants => variants.isNotEmpty;

  /// Whether this product can ever be bought as made-to-order.
  bool get isMadeToOrderEnabled =>
      fulfillmentMode == 'made_to_order' ||
      fulfillmentMode == 'stocked_with_mto';

  /// Made-to-order only, with no stocked path at all.
  bool get isMadeToOrderOnly => fulfillmentMode == 'made_to_order';

  /// Made-to-order available to the buyer right now (enabled, and either
  /// MTO-only or the stocked path has run out).
  bool get isMadeToOrderAvailable =>
      isMadeToOrderEnabled && (isMadeToOrderOnly || stockQty <= 0);

  /// Price charged for a made-to-order purchase: the MTO override when set,
  /// otherwise the normal product price.
  double get effectiveMtoPrice => madeToOrderPrice ?? price;

  /// Human-friendly lead-time label, e.g. "14-21 days" or "21 days".
  String? get leadTimeLabel {
    if (leadMinDays == null && leadMaxDays == null) return null;
    final min = leadMinDays;
    final max = leadMaxDays;
    if (min != null && max != null) {
      return min == max ? '$min days' : '$min-$max days';
    }
    return '${min ?? max} days';
  }

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
  bool get supportsMadeToOrder =>
      fulfillmentMode == 'made_to_order' ||
      fulfillmentMode == 'stocked_with_mto';

  /// Made-to-order products stay buyable at zero stock, so listings must not
  /// hide them the way plain out-of-stock items are hidden.
  bool get isAvailableForPurchase => isInStock || supportsMadeToOrder;
  /// The product's first photo, or empty when it has none. Never a stock
  /// image: image widgets show their neutral fallback for an empty URL.
  String get primaryImage => images.isNotEmpty ? images.first : '';
  double get discountPercent =>
      isOnSale ? ((compareAtPrice! - price) / compareAtPrice! * 100) : 0;
}
