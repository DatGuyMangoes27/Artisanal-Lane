import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device key for the artisan's last Buying / Selling choice on the You tab.
const youTabSellingModeKey = 'you_tab_selling_mode';

/// Whether the You tab shows the selling hub (true) or the buying view
/// (false) for an artisan.
///
/// Starts on Selling for every artisan, whichever way they reached the tab
/// (straight after sign-in or via "Switch to shopping"), and then remembers
/// the last choice on this device. Only consulted for artisans; buyers never
/// see the switch.
class YouTabSellingModeNotifier extends Notifier<bool> {
  bool _chosenThisSession = false;

  @override
  bool build() {
    _restore();
    return true;
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(youTabSellingModeKey);
      if (saved != null && !_chosenThisSession && ref.mounted) {
        state = saved;
      }
    } catch (_) {
      // No saved choice available: stay on the Selling default.
    }
  }

  Future<void> choose({required bool selling}) async {
    _chosenThisSession = true;
    state = selling;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(youTabSellingModeKey, selling);
    } catch (_) {
      // Remembered for this session even if it cannot be saved.
    }
  }
}

final youTabSellingModeProvider =
    NotifierProvider<YouTabSellingModeNotifier, bool>(
      YouTabSellingModeNotifier.new,
    );
