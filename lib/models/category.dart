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

  // Line art icon mapping – outlined Flutter icons for each category slug
  static const Map<String, IconData> categoryIcons = {
    'art-design': Icons.palette_outlined,
    'clothing': Icons.checkroom_outlined,
    'beauty': Icons.spa_outlined,
    'jewellery': Icons.diamond_outlined,
    'home-living': Icons.home_outlined,
    'baby-kids': Icons.child_care_outlined,
  };

  IconData get icon => categoryIcons[slug] ?? Icons.category_outlined;
}
