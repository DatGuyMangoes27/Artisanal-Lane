import 'package:artisanal_lane/features/vendor/widgets/composer/composer_format_picker.dart';
import 'package:artisanal_lane/features/vendor/widgets/composer/composer_poll_editor.dart';
import 'package:artisanal_lane/features/vendor/widgets/composer/composer_schedule_section.dart';
import 'package:artisanal_lane/models/shop_post.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('composerMediaCountError (format-driven media rules)', () {
    test('photo requires exactly one image', () {
      expect(composerMediaCountError(PostFormat.photo, 0), isNotNull);
      expect(composerMediaCountError(PostFormat.photo, 1), isNull);
      expect(composerMediaCountError(PostFormat.photo, 2), isNotNull);
    });

    test('video requires exactly one item', () {
      expect(composerMediaCountError(PostFormat.video, 0), isNotNull);
      expect(composerMediaCountError(PostFormat.video, 1), isNull);
      expect(composerMediaCountError(PostFormat.video, 2), isNotNull);
    });

    test('carousel requires 2 to 10 images', () {
      expect(composerMediaCountError(PostFormat.carousel, 1), isNotNull);
      expect(composerMediaCountError(PostFormat.carousel, 2), isNull);
      expect(composerMediaCountError(PostFormat.carousel, 10), isNull);
      expect(composerMediaCountError(PostFormat.carousel, 11), isNotNull);
    });

    test('tutorial requires 2 to 10 images', () {
      expect(composerMediaCountError(PostFormat.tutorial, 1), isNotNull);
      expect(composerMediaCountError(PostFormat.tutorial, 2), isNull);
      expect(composerMediaCountError(PostFormat.tutorial, 10), isNull);
      expect(composerMediaCountError(PostFormat.tutorial, 11), isNotNull);
    });

    test(
      'poll has no media-count rule of its own (checked with its fields)',
      () {
        expect(composerMediaCountError(PostFormat.poll, 0), isNull);
      },
    );
  });

  group('composerPollError', () {
    test('requires a question', () {
      expect(
        composerPollError(
          question: '',
          options: const ['A', 'B'],
          imageCount: 1,
        ),
        isNotNull,
      );
    });

    test('question must be 200 characters or fewer', () {
      final longQuestion = 'a' * 201;
      expect(
        composerPollError(
          question: longQuestion,
          options: const ['A', 'B'],
          imageCount: 1,
        ),
        isNotNull,
      );
    });

    test('requires at least 2 filled options', () {
      expect(
        composerPollError(
          question: 'Q',
          options: const ['A', ''],
          imageCount: 1,
        ),
        isNotNull,
      );
      expect(
        composerPollError(
          question: 'Q',
          options: const ['A', 'B'],
          imageCount: 1,
        ),
        isNull,
      );
    });

    test('keeps the existing photo-required rule', () {
      expect(
        composerPollError(
          question: 'Q',
          options: const ['A', 'B'],
          imageCount: 0,
        ),
        isNotNull,
      );
    });

    test('accepts up to 4 options', () {
      expect(
        composerPollError(
          question: 'Q',
          options: const ['A', 'B', 'C', 'D'],
          imageCount: 1,
        ),
        isNull,
      );
    });
  });

  group('composerScheduleError (schedule bounds)', () {
    final now = DateTime(2026, 1, 1, 12);

    test('null (post now) is always valid', () {
      expect(composerScheduleError(null, now: now), isNull);
    });

    test('rejects fewer than 10 minutes from now', () {
      expect(
        composerScheduleError(now.add(const Duration(minutes: 5)), now: now),
        isNotNull,
      );
    });

    test('accepts exactly 10 minutes from now', () {
      expect(
        composerScheduleError(now.add(const Duration(minutes: 10)), now: now),
        isNull,
      );
    });

    test('accepts up to 60 days from now', () {
      expect(
        composerScheduleError(now.add(const Duration(days: 60)), now: now),
        isNull,
      );
    });

    test('rejects more than 60 days from now', () {
      expect(
        composerScheduleError(now.add(const Duration(days: 61)), now: now),
        isNotNull,
      );
    });

    test('rejects a time in the past', () {
      expect(
        composerScheduleError(now.subtract(const Duration(days: 1)), now: now),
        isNotNull,
      );
    });
  });

  group('composerFormatScheduleLabel', () {
    test('formats a readable date and 12-hour time', () {
      final label = composerFormatScheduleLabel(DateTime(2026, 3, 5, 14, 5));
      expect(label, 'Mar 5, 2026 · 2:05 PM');
    });

    test('formats midnight as 12 AM', () {
      final label = composerFormatScheduleLabel(DateTime(2026, 3, 5, 0, 0));
      expect(label, contains('12:00 AM'));
    });
  });

  group('ComposerPollDuration', () {
    test('durations map to the expected chip lengths', () {
      expect(ComposerPollDuration.oneDay.duration, const Duration(days: 1));
      expect(ComposerPollDuration.threeDays.duration, const Duration(days: 3));
      expect(ComposerPollDuration.oneWeek.duration, const Duration(days: 7));
      expect(ComposerPollDuration.noEnd.duration, isNull);
    });
  });
}
