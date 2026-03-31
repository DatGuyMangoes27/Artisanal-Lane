class Subcategory {
  final String id;
  final String categoryId;
  final String name;
  final String slug;
  final int sortOrder;
  final DateTime createdAt;

  const Subcategory({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.slug,
    this.sortOrder = 0,
    required this.createdAt,
  });

  factory Subcategory.fromJson(Map<String, dynamic> json) {
    return Subcategory(
      id: json['id'] as String,
      categoryId: json['category_id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      sortOrder: json['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'category_id': categoryId,
        'name': name,
        'slug': slug,
        'sort_order': sortOrder,
      };
}
