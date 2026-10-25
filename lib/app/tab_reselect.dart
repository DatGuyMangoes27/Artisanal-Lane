import 'package:flutter_riverpod/flutter_riverpod.dart';

enum BuyerTab { home, discover, shop, feed, you }

/// Increments whenever the user taps the tab they are already on. Tab screens
/// listen to scroll back to the top, the standard social-app behaviour.
class TabReselectNotifier extends Notifier<int> {
  TabReselectNotifier(this.tab);
  final BuyerTab tab;

  @override
  int build() => 0;

  void reselect() => state++;
}

final tabReselectProvider =
    NotifierProvider.family<TabReselectNotifier, int, BuyerTab>(
      TabReselectNotifier.new,
    );
