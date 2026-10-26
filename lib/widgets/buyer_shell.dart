import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app/theme.dart';
import '../app/tab_reselect.dart';
import '../features/buyer/providers/buyer_providers.dart';
import '../models/cart_item.dart';
import 'cart_nav_icon.dart';

class BuyerShell extends ConsumerWidget {
  /// Legacy (flag off) shell: a single navigator, `child` is the current
  /// page.
  final Widget? child;

  /// Creator-commerce shell: one navigator per tab (Home/Discover/Shop/Feed/
  /// You) so each tab keeps its own scroll position and state when
  /// switching. The router's branches must be in [creatorTabs] order.
  final StatefulNavigationShell? navigationShell;

  const BuyerShell({super.key, this.child, this.navigationShell})
    : assert(
        (child == null) != (navigationShell == null),
        'Pass exactly one of child (legacy) or navigationShell (creator).',
      );

  bool get _isGuest {
    if (!_isSupabaseInitialized) {
      return true;
    }
    return Supabase.instance.client.auth.currentSession == null;
  }

  bool get _isSupabaseInitialized {
    try {
      Supabase.instance.client;
      return true;
    } on AssertionError {
      return false;
    }
  }

  /// Bottom-nav order of the creator-commerce tabs (one router branch each).
  static const creatorTabs = [
    BuyerTab.home,
    BuyerTab.discover,
    BuyerTab.shop,
    BuyerTab.feed,
    BuyerTab.you,
  ];

  int _currentIndex(BuildContext context) {
    // With StatefulShellRoute the branch index is authoritative — it
    // reflects which tab's navigator is on screen, regardless of which tab
    // originally pushed a detail page (those are pushed on the root
    // navigator and never change the branch).
    if (navigationShell != null) return navigationShell!.currentIndex;

    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/search')) return 1;
    if (location.startsWith('/favourites')) return 2;
    if (location.startsWith('/cart')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  void _onTap(BuildContext context, WidgetRef ref, int index) {
    final guest = _isGuest;
    if (navigationShell != null) {
      if (guest && creatorTabs[index] == BuyerTab.you) {
        _showGuestSignInPrompt(context);
        return;
      }
      if (index == navigationShell!.currentIndex) {
        // Tapping the tab you're already on: pop that branch back to its
        // root and tell the screen to scroll to top.
        navigationShell!.goBranch(index, initialLocation: true);
        ref.read(tabReselectProvider(creatorTabs[index]).notifier).reselect();
        return;
      }
      navigationShell!.goBranch(index);
      return;
    }
    if (guest && (index == 2 || index == 3 || index == 4)) {
      _showGuestSignInPrompt(context);
      return;
    }
    switch (index) {
      case 0:
        context.go('/home');
      case 1:
        context.go('/search');
      case 2:
        context.go('/favourites');
      case 3:
        context.go('/cart');
      case 4:
        context.go('/profile');
    }
  }

  void _showGuestSignInPrompt(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.sand,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.terracotta, AppTheme.baobab],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.lock_open_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Sign in to continue',
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create an account or sign in to save favourites, manage your cart, and track orders.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.terracotta, AppTheme.baobab],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/login');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Sign In',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/register');
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.terracotta,
                  side: const BorderSide(
                    color: AppTheme.terracotta,
                    width: 1.5,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Create Account',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guest = _isGuest;
    final cartItems = ref.watch(cartItemsProvider).value ?? const <CartItem>[];
    final cartCount = cartBadgeCount(cartItems);

    return Scaffold(
      body: navigationShell ?? child!,
      bottomNavigationBar: navigationShell != null
          ? NavigationBar(
              selectedIndex: _currentIndex(context),
              onDestinationSelected: (index) => _onTap(context, ref, index),
              backgroundColor: AppTheme.cardBg,
              indicatorColor: AppTheme.terracotta.withValues(alpha: .12),
              height: 70,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_outlined),
                  label: 'Home',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.explore_outlined),
                  selectedIcon: Icon(Icons.explore),
                  label: 'Discover',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.storefront_outlined),
                  selectedIcon: Icon(Icons.storefront),
                  label: 'Shop',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.dynamic_feed_outlined),
                  selectedIcon: Icon(Icons.dynamic_feed),
                  label: 'Feed',
                ),
                NavigationDestination(
                  icon: const Icon(Icons.person_outline),
                  selectedIcon: const Icon(Icons.person),
                  label: guest ? 'Sign In' : 'You',
                ),
              ],
            )
          : BottomNavigationBar(
              currentIndex: _currentIndex(context),
              onTap: (index) => _onTap(context, ref, index),
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home_outlined),
                  label: 'Home',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.search_outlined),
                  activeIcon: Icon(Icons.search),
                  label: 'Search',
                ),
                BottomNavigationBarItem(
                  icon: Icon(
                    guest ? Icons.favorite_outline : Icons.favorite_outline,
                  ),
                  activeIcon: const Icon(Icons.favorite),
                  label: 'Favourites',
                ),
                BottomNavigationBarItem(
                  icon: CartNavIcon(count: cartCount, isActive: false),
                  activeIcon: CartNavIcon(count: cartCount, isActive: true),
                  label: 'Cart',
                ),
                BottomNavigationBarItem(
                  icon: Icon(
                    guest ? Icons.person_outline : Icons.person_outline,
                  ),
                  activeIcon: const Icon(Icons.person),
                  label: guest ? 'Sign In' : 'Profile',
                ),
              ],
            ),
    );
  }
}
