class PargoPickupPoint {
  final String code;
  final String name;
  final String address;
  final String city;
  final String province;
  final String postalCode;
  final double? latitude;
  final double? longitude;

  const PargoPickupPoint({
    required this.code,
    required this.name,
    required this.address,
    required this.city,
    required this.province,
    required this.postalCode,
    this.latitude,
    this.longitude,
  });

  factory PargoPickupPoint.fromJson(Map<String, dynamic> json) {
    double? parseCoordinate(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    return PargoPickupPoint(
      code: (json['code'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
      address: (json['address'] as String? ?? '').trim(),
      city: (json['city'] as String? ?? '').trim(),
      province: (json['province'] as String? ?? '').trim(),
      postalCode: (json['postal_code'] as String? ?? '').trim(),
      latitude: parseCoordinate(json['latitude']),
      longitude: parseCoordinate(json['longitude']),
    );
  }

  Map<String, dynamic> toOrderJson() => {
    'carrier': 'pargo',
    'point_type': 'pickup_point',
    'code': code,
    'name': name,
    'address': address,
    'city': city,
    'province': province,
    if (postalCode.isNotEmpty) 'postal_code': postalCode,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
  };

  String get title => code.isEmpty ? name : '$name ($code)';

  String get subtitle {
    final parts = <String>[
      if (address.isNotEmpty) address,
      if (city.isNotEmpty) city,
      if (province.isNotEmpty) province,
    ];
    return parts.join(' • ');
  }
}
