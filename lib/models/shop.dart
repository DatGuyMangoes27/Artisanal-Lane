import 'shipping_option.dart';

class Shop {
  final String id;
  final String vendorId;
  final String name;
  final String slug;
  final String? bio;
  final String? brandStory;
  final String? coverImageUrl;
  final String? logoUrl;
  final String? location;
  final bool isActive;
  final bool isOffline;
  final bool isSpotlight;
  final DateTime? backToWorkDate;
  final DateTime? spotlightedAt;
  final List<ShippingOption> shippingOptions;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? productCount;

  const Shop({
    required this.id,
    required this.vendorId,
    required this.name,
    required this.slug,
    this.bio,
    this.brandStory,
    this.coverImageUrl,
    this.logoUrl,
    this.location,
    this.isActive = true,
    this.isOffline = false,
    this.isSpotlight = false,
    this.backToWorkDate,
    this.spotlightedAt,
    List<ShippingOption>? shippingOptions,
    required this.createdAt,
    required this.updatedAt,
    this.productCount,
  }) : shippingOptions = shippingOptions ?? const [];

  factory Shop.fromJson(Map<String, dynamic> json) {
    return Shop(
      id: json['id'] as String,
      vendorId: json['vendor_id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      bio: json['bio'] as String?,
      brandStory: json['brand_story'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      logoUrl: json['logo_url'] as String?,
      location: json['location'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      isOffline: json['is_offline'] as bool? ?? false,
      isSpotlight: json['is_spotlight'] as bool? ?? false,
      backToWorkDate: json['back_to_work_date'] != null
          ? DateTime.parse(json['back_to_work_date'] as String)
          : null,
      spotlightedAt: json['spotlighted_at'] != null
          ? DateTime.parse(json['spotlighted_at'] as String)
          : null,
      shippingOptions: ShippingOption.listFromJson(json['shipping_options']),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      productCount: json['product_count'] as int?,
    );
  }

  /// Returns only the enabled shipping options for this shop.
  List<ShippingOption> get enabledShippingOptions =>
      shippingOptions.where((o) => o.enabled).toList();

  Map<String, dynamic> toJson() => {
        'id': id,
        'vendor_id': vendorId,
        'name': name,
        'slug': slug,
        'bio': bio,
        'brand_story': brandStory,
        'cover_image_url': coverImageUrl,
        'logo_url': logoUrl,
        'location': location,
        'is_active': isActive,
        'is_offline': isOffline,
        'is_spotlight': isSpotlight,
        'spotlighted_at': spotlightedAt?.toIso8601String(),
        'back_to_work_date': backToWorkDate?.toIso8601String().split('T').first,
        'shipping_options': shippingOptions.map((o) => o.toJson()).toList(),
      };
}
