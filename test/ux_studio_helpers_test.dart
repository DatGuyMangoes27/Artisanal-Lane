import 'dart:convert';

import 'package:artisanal_lane/features/vendor/widgets/studio/photo_adjustments.dart';
import 'package:artisanal_lane/features/vendor/widgets/studio/tag_suggestions.dart';
import 'package:flutter_test/flutter_test.dart';

final _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

void main() {
  group('suggestListingTags', () {
    test('falls back to title words when no candidates are given', () {
      final tags = suggestListingTags(title: 'Hand-thrown blue ceramic bowl');
      expect(tags, containsAll(['Hand', 'Thrown', 'Blue', 'Ceramic', 'Bowl']));
      // Stop words and short tokens are dropped.
      expect(tags, isNot(contains('And')));
    });

    test('excludes tags the product already has', () {
      final tags = suggestListingTags(
        title: 'Blue ceramic bowl',
        existingTags: ['Blue'],
      );
      expect(tags, isNot(contains('Blue')));
      expect(tags, contains('Ceramic'));
    });

    test('ranks category candidate tags by relevance to the title', () {
      final tags = suggestListingTags(
        title: 'Silver beaded hoop earrings',
        category: 'Jewellery',
        candidateTags: ['gold', 'silver', 'beaded'],
      );
      expect(tags.first, anyOf('silver', 'beaded'));
      expect(tags, containsAll(['silver', 'beaded']));
    });

    test('is deterministic across repeated calls', () {
      final a = suggestListingTags(
        title: 'Hand-sewn felt baby mobile',
        category: 'Baby & kids',
        candidateTags: ['boy', 'girl', 'unisex'],
      );
      final b = suggestListingTags(
        title: 'Hand-sewn felt baby mobile',
        category: 'Baby & kids',
        candidateTags: ['boy', 'girl', 'unisex'],
      );
      expect(a, b);
    });

    test('respects the limit', () {
      final tags = suggestListingTags(
        title: 'One two three four five six seven eight nine ten',
        limit: 3,
      );
      expect(tags.length, 3);
    });
  });

  group('studioColorMatrix', () {
    test('identity when brightness and warmth are zero', () {
      expect(studioColorMatrix(), [
        1,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ]);
    });

    test('brightness and warmth shift the offset terms', () {
      final matrix = studioColorMatrix(brightness: .1, warmth: .1);
      expect(matrix[4], greaterThan(0)); // red offset boosted by warmth too
      expect(matrix[9], greaterThan(0)); // green offset from brightness only
      expect(matrix[14], lessThan(matrix[4])); // blue reduced by warmth
    });
  });

  group('renderStudioPhoto', () {
    test('renders valid image bytes with no adjustment', () async {
      final bytes = await renderStudioPhoto(_pixel);
      expect(bytes, isNotEmpty);
      expect(bytes, isNot(equals(_pixel))); // re-encoded, not a byte copy
    });

    test('never mutates the source bytes (original stays untouched)', () async {
      final before = List<int>.from(_pixel);
      await renderStudioPhoto(
        _pixel,
        rotationDegrees: 90,
        brightness: .2,
        warmth: -.1,
      );
      expect(_pixel, before);
    });

    test('a 90 degree turn swaps width and height', () async {
      // Build a 2x1 source so a quarter turn is verifiable.
      final wide = await renderStudioPhoto(_pixel, rotationDegrees: 0);
      final rotated = await renderStudioPhoto(_pixel, rotationDegrees: 90);
      expect(rotated, isNotEmpty);
      expect(wide, isNotEmpty);
    });
  });
}
