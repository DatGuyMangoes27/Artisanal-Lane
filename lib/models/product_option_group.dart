class ProductOptionGroup {
  final String name;
  final List<String> values;

  const ProductOptionGroup({required this.name, this.values = const []});

  factory ProductOptionGroup.fromJson(Map<String, dynamic> json) {
    final rawValues = json['values'];
    final values = rawValues is List
        ? rawValues.map((value) => value.toString()).toList(growable: false)
        : const <String>[];

    return ProductOptionGroup(
      name: (json['name'] as String? ?? '').trim(),
      values: values,
    );
  }

  Map<String, dynamic> toJson() => {'name': name, 'values': values};
}
