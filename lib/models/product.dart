class Product {
  final String id;
  final String shopId;
  final String? categoryId;
  final String title;
  final String? description;
  final double price;
  final double? compareAtPrice;
  final int stockQty;
  final List<String> images;
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

  const Product({
    required this.id,
    required this.shopId,
    this.categoryId,
    required this.title,
    this.description,
    required this.price,
    this.compareAtPrice,
    this.stockQty = 0,
    this.images = const [],
    this.isPublished = true,
    this.isFeatured = false,
    this.careInstructions,
    this.featuredAt,
    required this.createdAt,
    required this.updatedAt,
    this.shopName,
    this.shopLogoUrl,
    this.categoryName,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    List<String> parseImages(dynamic img) {
      if (img == null) return [];
      if (img is List) return img.map((e) => e.toString()).toList();
      return [];
    }

    // Handle joined shop data
    final shopData = json['shops'] as Map<String, dynamic>?;
    final categoryData = json['categories'] as Map<String, dynamic>?;

    return Product(
      id: json['id'] as String,
      shopId: json['shop_id'] as String,
      categoryId: json['category_id'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      price: (json['price'] as num).toDouble(),
      compareAtPrice: json['compare_at_price'] != null
          ? (json['compare_at_price'] as num).toDouble()
          : null,
      stockQty: json['stock_qty'] as int? ?? 0,
      images: parseImages(json['images']),
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
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'shop_id': shopId,
        'category_id': categoryId,
        'title': title,
        'description': description,
        'price': price,
        'compare_at_price': compareAtPrice,
        'stock_qty': stockQty,
        'images': images,
        'is_published': isPublished,
        'is_featured': isFeatured,
        'care_instructions': careInstructions,
      };

  bool get isOnSale => compareAtPrice != null && compareAtPrice! > price;
  bool get isInStock => stockQty > 0;
  bool get isLowStock => stockQty > 0 && stockQty <= 5;
  String get primaryImage =>
      images.isNotEmpty ? images.first : 'https://images.unsplash.com/photo-1565193566173-7a0ee3dbe261?w=400&h=400&fit=crop';
  double get discountPercent =>
      isOnSale ? ((compareAtPrice! - price) / compareAtPrice! * 100) : 0;
}
