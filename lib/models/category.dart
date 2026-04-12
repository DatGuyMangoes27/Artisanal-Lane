import 'package:flutter/material.dart';

class Category {
  final String id;
  final String name;
  final String slug;
  final String? iconUrl;
  final int sortOrder;
  final DateTime createdAt;

  const Category({
    required this.id,
    required this.name,
    required this.slug,
    this.iconUrl,
    this.sortOrder = 0,
    required this.createdAt,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      iconUrl: json['icon_url'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'icon_url': iconUrl,
        'sort_order': sortOrder,
      };

  static const Map<String, IconData> categoryIcons = {
    'home': Icons.home_outlined,
    'art-design': Icons.palette_outlined,
    'jewellery': Icons.diamond_outlined,
    'clothing': Icons.checkroom_outlined,
    'accessories': Icons.shopping_bag_outlined,
    'baby-kids': Icons.child_care_outlined,
    'self-care': Icons.spa_outlined,
    'pantry': Icons.local_dining_outlined,
    'pets': Icons.pets_outlined,
    'other': Icons.more_horiz_rounded,
    // legacy slugs
    'home-living': Icons.home_outlined,
    'beauty': Icons.spa_outlined,
  };

  /// Category-specific filter tags (excluding universal on-sale/featured).
  static const Map<String, List<String>> filterTags = {
    'home': ['pottery', 'woodwork', 'textile', 'metal work'],
    'jewellery': ['silver', 'gold', 'beaded'],
    'clothing': ['men', 'women', 'unisex'],
    'baby-kids': ['boy', 'girl', 'unisex'],
    'pets': ['cats', 'dogs', 'other'],
    'other': ['misc', 'gift', 'seasonal'],
  };

  IconData get icon => categoryIcons[slug] ?? Icons.category_outlined;

  List<String> get availableFilterTags => filterTags[slug] ?? [];
}
