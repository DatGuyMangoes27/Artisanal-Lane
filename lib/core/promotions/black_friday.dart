import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Black Friday 2026: Friday 27 November 00:00 to Tuesday 1 December 00:00
/// South African time (UTC+2, no daylight saving), so it runs through Cyber
/// Monday and switches itself off at midnight. During the window every
/// product that is on sale shows a "Black Friday Deal" sticker, and Home and
/// Shop show the Black Friday banner. Shops choose their own discounts by
/// putting pieces on sale as usual.
final blackFridayStartUtc = DateTime.utc(2026, 11, 26, 22);
final blackFridayEndUtc = DateTime.utc(2026, 11, 30, 22);

bool blackFridayActiveAt(DateTime now) {
  final utc = now.toUtc();
  return !utc.isBefore(blackFridayStartUtc) && utc.isBefore(blackFridayEndUtc);
}

/// The time, overridable in tests.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Whether Black Friday is on right now. Rebuilds itself at the exact start
/// and end, so an app left open switches over at midnight.
final blackFridayActiveProvider = NotifierProvider<BlackFridayNotifier, bool>(
  BlackFridayNotifier.new,
);

class BlackFridayNotifier extends Notifier<bool> {
  Timer? _timer;

  @override
  bool build() {
    final now = ref.watch(clockProvider)();
    _timer?.cancel();
    final utc = now.toUtc();
    final next = utc.isBefore(blackFridayStartUtc)
        ? blackFridayStartUtc
        : utc.isBefore(blackFridayEndUtc)
        ? blackFridayEndUtc
        : null;
    // Only arm a timer when the change is near; far-off ones would keep a
    // timer pending for weeks (and in widget tests).
    if (next != null) {
      final wait = next.difference(utc);
      if (wait <= const Duration(days: 2)) {
        _timer = Timer(wait + const Duration(seconds: 1), ref.invalidateSelf);
      }
    }
    ref.onDispose(() => _timer?.cancel());
    return blackFridayActiveAt(now);
  }
}
