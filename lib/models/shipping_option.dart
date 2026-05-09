import 'package:flutter/material.dart';

/// Represents one shipping method a shop offers.
/// Persisted as a JSONB array on shops.shipping_options.
const Object _marketNameSentinel = Object();

class ShippingOption {
  final String key;
  final bool enabled;
  final double price;
  final String? marketName;
  final String? marketLocation;
  final String? marketProvince;

  const ShippingOption({
    required this.key,
    required this.enabled,
    required this.price,
    this.marketName,
    this.marketLocation,
    this.marketProvince,
  });

  factory ShippingOption.fromJson(Map<String, dynamic> json) => ShippingOption(
    key: json['key'] as String,
    enabled: json['enabled'] as bool? ?? true,
    price: (json['price'] as num).toDouble(),
    marketName: _trimmedString(json['market_name']),
    marketLocation: _trimmedString(json['market_location']),
    marketProvince: _trimmedString(json['market_province']),
  );

  Map<String, dynamic> toJson() => {
    'key': key,
    'enabled': enabled,
    'price': price,
    if (marketName != null && marketName!.trim().isNotEmpty)
      'market_name': marketName!.trim(),
    if (marketLocation != null && marketLocation!.trim().isNotEmpty)
      'market_location': marketLocation!.trim(),
    if (marketProvince != null && marketProvince!.trim().isNotEmpty)
      'market_province': marketProvince!.trim(),
  };

  ShippingOption copyWith({
    bool? enabled,
    double? price,
    Object? marketName = _marketNameSentinel,
    Object? marketLocation = _marketNameSentinel,
    Object? marketProvince = _marketNameSentinel,
  }) => ShippingOption(
    key: key,
    enabled: enabled ?? this.enabled,
    price: price ?? this.price,
    marketName: identical(marketName, _marketNameSentinel)
        ? this.marketName
        : marketName as String?,
    marketLocation: identical(marketLocation, _marketNameSentinel)
        ? this.marketLocation
        : marketLocation as String?,
    marketProvince: identical(marketProvince, _marketNameSentinel)
        ? this.marketProvince
        : marketProvince as String?,
  );

  // ── Static catalogue of all supported methods ──────────────────
  static const _catalogue = {
    'courier_guy': _MethodMeta(
      name: 'Courier Guy Locker',
      description: 'Collect at a Courier Guy locker near you',
      icon: Icons.lock_outline_rounded,
    ),
    'courier_guy_door_to_door': _MethodMeta(
      name: 'Courier Guy Door to Door',
      description: 'Courier delivery to your address, 2–4 business days',
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
    const ShippingOption(key: 'courier_guy', enabled: true, price: 69.00),
    const ShippingOption(
      key: 'courier_guy_door_to_door',
      enabled: true,
      price: 110.00,
    ),
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

String? _trimmedString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

class _MethodMeta {
  final String name;
  final String description;
  final IconData icon;
  const _MethodMeta({
    required this.name,
    required this.description,
    required this.icon,
  });
}
