import 'package:artisanal_lane/features/buyer/utils/shop_discovery_location.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeLocationText', () {
    test('lowercases and strips punctuation', () {
      expect(
        normalizeLocationText('Cape Town, Western Cape'),
        'cape town western cape',
      );
    });

    test('expands common abbreviations', () {
      expect(normalizeLocationText('JHB'), 'johannesburg');
      expect(normalizeLocationText('Joburg'), 'johannesburg');
      expect(normalizeLocationText('CPT'), 'cape town');
      expect(normalizeLocationText('KZN'), 'kwazulu-natal');
    });
  });

  group('matchesNearMeArea', () {
    test('matches a city within a "city, province" location', () {
      expect(
        matchesNearMeArea('Johannesburg, Gauteng', 'Johannesburg'),
        isTrue,
      );
    });

    test('matches a province against a city-level location', () {
      expect(matchesNearMeArea('Johannesburg, Gauteng', 'Gauteng'), isTrue);
    });

    test('is case-insensitive and understands aliases', () {
      expect(matchesNearMeArea('JHB', 'Johannesburg'), isTrue);
      expect(matchesNearMeArea('Joburg', 'Johannesburg'), isTrue);
      expect(matchesNearMeArea('CPT, South Africa', 'Cape Town'), isTrue);
      expect(matchesNearMeArea('Durban, KZN', 'KwaZulu-Natal'), isTrue);
    });

    test('does not match an unrelated area', () {
      expect(matchesNearMeArea('Durban, KwaZulu-Natal', 'Cape Town'), isFalse);
    });

    test('excludes products with no location', () {
      expect(matchesNearMeArea(null, 'Cape Town'), isFalse);
      expect(matchesNearMeArea('   ', 'Cape Town'), isFalse);
    });

    test('a blank area never matches', () {
      expect(matchesNearMeArea('Cape Town, Western Cape', ''), isFalse);
    });
  });

  group('filterNearArea', () {
    test('keeps all items when the area is null or blank', () {
      final items = ['Cape Town', 'Durban'];
      expect(filterNearArea(items, null, (s) => s), items);
      expect(filterNearArea(items, '  ', (s) => s), items);
    });

    test('filters to items whose location matches the area', () {
      final items = ['Cape Town, Western Cape', 'Durban, KwaZulu-Natal', null];
      final result = filterNearArea<String?>(items, 'Western Cape', (s) => s);
      expect(result, ['Cape Town, Western Cape']);
    });
  });
}
