import 'package:flutter/material.dart';

/// Represents one shipping method a shop offers.
/// Persisted as a JSONB array on shops.shipping_options.
class ShippingOption {
  final String key;
  final bool enabled;
  final double price;

  const ShippingOption({
    required this.key,
    required this.enabled,
    required this.price,
  });

  factory ShippingOption.fromJson(Map<String, dynamic> json) => ShippingOption(
        key: json['key'] as String,
        enabled: json['enabled'] as bool? ?? true,
        price: (json['price'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'key': key,
        'enabled': enabled,
        'price': price,
      };

  ShippingOption copyWith({bool? enabled, double? price}) => ShippingOption(
        key: key,
        enabled: enabled ?? this.enabled,
        price: price ?? this.price,
      );

  // ── Static catalogue of all supported methods ──────────────────
  static const _catalogue = {
    'courier_guy': _MethodMeta(
      name: 'The Courier Guy',
      description: 'Door-to-door delivery, 2–4 business days',
      icon: Icons.local_shipping_outlined,
    ),
    'pargo': _MethodMeta(
      name: 'Pargo',
      description: 'Pick up at a Pargo point near you',
      icon: Icons.store_outlined,
    ),
    'market_pickup': _MethodMeta(
      name: 'Market Pickup',
      description: 'Collect from the artisan in person',
      icon: Icons.handshake_outlined,
    ),
  };

  String get name => _catalogue[key]?.name ?? key;
  String get description => _catalogue[key]?.description ?? '';
  IconData get icon => _catalogue[key]?.icon ?? Icons.local_shipping_outlined;

  /// Returns the full default set of options (all enabled, default prices).
  static List<ShippingOption> defaults() => [
        const ShippingOption(key: 'courier_guy', enabled: true, price: 99.00),
        const ShippingOption(key: 'pargo', enabled: true, price: 65.00),
        const ShippingOption(key: 'market_pickup', enabled: true, price: 0.00),
      ];

  /// Parses the JSONB array from Supabase; falls back to [fallback] if null/empty.
  static List<ShippingOption> listFromJson(
    dynamic json, {
    List<ShippingOption>? fallback,
  }) {
    final fallbackValue = fallback ?? defaults();
    if (json == null) return fallbackValue;
    final list = json as List;
    if (list.isEmpty) return fallbackValue;
    return list
        .map((e) => ShippingOption.fromJson(e as Map<String, dynamic>))
        .where((option) => _catalogue.containsKey(option.key))
        .toList();
  }
}

class _MethodMeta {
  final String name;
  final String description;
  final IconData icon;
  const _MethodMeta({required this.name, required this.description, required this.icon});
}
