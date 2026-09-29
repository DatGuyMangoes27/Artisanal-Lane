/// Pure, unit-testable "Near me" location matching for the Shop tab.
///
/// Product shop locations are free text such as "Johannesburg, Gauteng" or
/// "Cape Town, Western Cape". This intentionally does simple, transparent
/// substring matching against the buyer's chosen area (a province or major
/// city) rather than real geocoding, and understands a handful of common
/// South African abbreviations.
library;

/// The nine South African provinces, in a friendly display order.
const List<String> saProvinces = <String>[
  'Eastern Cape',
  'Free State',
  'Gauteng',
  'KwaZulu-Natal',
  'Limpopo',
  'Mpumalanga',
  'Northern Cape',
  'North West',
  'Western Cape',
];

/// A handful of major cities per province, shown under each province in the
/// "Choose your area" sheet so buyers can pick something more specific.
const Map<String, List<String>> saProvinceCities = <String, List<String>>{
  'Eastern Cape': ['Gqeberha', 'East London'],
  'Free State': ['Bloemfontein'],
  'Gauteng': ['Johannesburg', 'Pretoria', 'Sandton'],
  'KwaZulu-Natal': ['Durban', 'Pietermaritzburg'],
  'Limpopo': ['Polokwane'],
  'Mpumalanga': ['Nelspruit'],
  'Northern Cape': ['Kimberley'],
  'North West': ['Rustenburg'],
  'Western Cape': ['Cape Town', 'Stellenbosch'],
};

/// Common shorthand/aliases buyers or shop profiles use, mapped to the
/// canonical name they stand for. Matching is case-insensitive and this map
/// is applied as whole-word replacements before comparing.
const Map<String, String> _locationAliases = <String, String>{
  'jhb': 'johannesburg',
  'joburg': 'johannesburg',
  'joeys': 'johannesburg',
  'egoli': 'johannesburg',
  'cpt': 'cape town',
  'ct': 'cape town',
  'kzn': 'kwazulu-natal',
  'pta': 'pretoria',
  'tshwane': 'pretoria',
  'pe': 'gqeberha',
  'port elizabeth': 'gqeberha',
  'gqeberha': 'gqeberha',
  'dbn': 'durban',
  'gauteng': 'gauteng',
};

/// Normalizes free-text location strings so aliases and punctuation don't
/// prevent an otherwise-obvious match: lowercases, expands known
/// abbreviations, and strips punctuation.
String normalizeLocationText(String input) {
  var text = input.toLowerCase().trim();
  for (final entry in _locationAliases.entries) {
    text = text.replaceAll(
      RegExp('\\b${RegExp.escape(entry.key)}\\b'),
      entry.value,
    );
  }
  text = text.replaceAll(RegExp(r'[^a-z0-9\s-]'), ' ');
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return text;
}

/// Whether a product's shop location text matches the buyer's chosen area
/// (a province or city name). Products with no location never match, so
/// "Near me" excludes them rather than guessing.
bool matchesNearMeArea(String? shopLocation, String area) {
  if (shopLocation == null || shopLocation.trim().isEmpty) return false;
  final loc = normalizeLocationText(shopLocation);
  final target = normalizeLocationText(area);
  if (loc.isEmpty || target.isEmpty) return false;
  return loc.contains(target) || target.contains(loc);
}

/// Filters [products] to those whose shop location matches [area]. A null
/// or blank area returns the list unchanged (the filter is effectively off).
List<T> filterNearArea<T>(
  List<T> products,
  String? area,
  String? Function(T item) locationOf,
) {
  final trimmed = area?.trim();
  if (trimmed == null || trimmed.isEmpty) return products;
  return products
      .where((item) => matchesNearMeArea(locationOf(item), trimmed))
      .toList(growable: false);
}
