/// Private collection address + Bob Go switch for a shop
/// (`shop_fulfillment_profiles`, vendor-readable only via RLS).
class ShopFulfillmentProfile {
  final String shopId;
  final String contactFullName;
  final String contactEmail;
  final String contactPhone;
  final String? company;
  final String streetAddress;
  final String localArea;
  final String city;
  final String province;
  final String postalCode;
  final bool bobgoEnabled;

  const ShopFulfillmentProfile({
    required this.shopId,
    this.contactFullName = '',
    this.contactEmail = '',
    this.contactPhone = '',
    this.company,
    this.streetAddress = '',
    this.localArea = '',
    this.city = '',
    this.province = '',
    this.postalCode = '',
    this.bobgoEnabled = false,
  });

  factory ShopFulfillmentProfile.fromJson(Map<String, dynamic> json) {
    String text(String key) => (json[key] as String?)?.trim() ?? '';
    return ShopFulfillmentProfile(
      shopId: json['shop_id'] as String,
      contactFullName: text('contact_full_name'),
      contactEmail: text('contact_email'),
      contactPhone: text('contact_phone'),
      company: (json['company'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['company'] as String).trim(),
      streetAddress: text('street_address'),
      localArea: text('local_area'),
      city: text('city'),
      province: text('province'),
      postalCode: text('postal_code'),
      bobgoEnabled: json['bobgo_enabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toUpsertJson() => {
    'shop_id': shopId,
    'contact_full_name': contactFullName.trim(),
    'contact_email': contactEmail.trim(),
    'contact_phone': contactPhone.trim(),
    'company': (company?.trim().isEmpty ?? true) ? null : company!.trim(),
    'street_address': streetAddress.trim(),
    'local_area': localArea.trim(),
    'city': city.trim(),
    'province': province.trim(),
    'postal_code': postalCode.trim(),
    'country_code': 'ZA',
    'bobgo_enabled': bobgoEnabled,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };

  ShopFulfillmentProfile copyWith({
    String? contactFullName,
    String? contactEmail,
    String? contactPhone,
    String? company,
    String? streetAddress,
    String? localArea,
    String? city,
    String? province,
    String? postalCode,
    bool? bobgoEnabled,
  }) => ShopFulfillmentProfile(
    shopId: shopId,
    contactFullName: contactFullName ?? this.contactFullName,
    contactEmail: contactEmail ?? this.contactEmail,
    contactPhone: contactPhone ?? this.contactPhone,
    company: company ?? this.company,
    streetAddress: streetAddress ?? this.streetAddress,
    localArea: localArea ?? this.localArea,
    city: city ?? this.city,
    province: province ?? this.province,
    postalCode: postalCode ?? this.postalCode,
    bobgoEnabled: bobgoEnabled ?? this.bobgoEnabled,
  );

  /// First problem with the collection details, or null when complete. The
  /// database requires every field except company.
  String? validate() {
    if (contactFullName.trim().isEmpty) return 'Add the contact name.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(contactEmail.trim())) {
      return 'Add a valid contact email.';
    }
    if (contactPhone.replaceAll(RegExp(r'[^0-9]'), '').length < 9) {
      return 'Add a contact phone number.';
    }
    if (streetAddress.trim().isEmpty) return 'Add the collection street address.';
    if (localArea.trim().isEmpty) return 'Add the collection suburb.';
    if (city.trim().isEmpty) return 'Add the collection city.';
    if (province.trim().isEmpty) return 'Choose the collection province.';
    if (postalCode.trim().isEmpty) return 'Add the collection postal code.';
    return null;
  }
}
