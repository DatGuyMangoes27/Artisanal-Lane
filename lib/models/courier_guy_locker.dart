class CourierGuyLocker {
  final String code;
  final String name;
  final String address;
  final String? landmark;
  final String province;
  final String city;
  final double? latitude;
  final double? longitude;
  final String pointType;

  const CourierGuyLocker({
    required this.code,
    required this.name,
    required this.address,
    this.landmark,
    required this.province,
    required this.city,
    this.latitude,
    this.longitude,
    required this.pointType,
  });

  factory CourierGuyLocker.fromJson(Map<String, dynamic> json) {
    final detailedAddress =
        json['detailed_address'] as Map<String, dynamic>? ?? const {};
    final type = json['type'] as Map<String, dynamic>? ?? const {};
    final place = json['place'] as Map<String, dynamic>? ?? const {};

    double? parseCoordinate(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    return CourierGuyLocker(
      code: (json['code'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
      address:
          (detailedAddress['formatted_address'] as String? ??
                  json['address'] as String? ??
                  '')
              .trim(),
      landmark: (json['landmark'] as String?)?.trim(),
      province: (detailedAddress['province'] as String? ?? '').trim(),
      city:
          (place['town'] as String? ??
                  detailedAddress['locality'] as String? ??
                  detailedAddress['sublocality'] as String? ??
                  '')
              .trim(),
      latitude: parseCoordinate(json['latitude']),
      longitude: parseCoordinate(json['longitude']),
      pointType: (type['name'] as String? ?? 'Locker').trim(),
    );
  }

  Map<String, dynamic> toOrderJson() => {
        'carrier': 'courier_guy',
        'point_type': pointType.toLowerCase(),
        'code': code,
        'name': name,
        'address': address,
        'city': city,
        'province': province,
        if (landmark != null && landmark!.isNotEmpty) 'landmark': landmark,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      };

  String get title => code.isEmpty ? name : '$name ($code)';

  String get subtitle {
    final parts = <String>[
      if (address.isNotEmpty) address,
      if (landmark != null && landmark!.isNotEmpty) landmark!,
    ];
    return parts.join(' • ');
  }
}
