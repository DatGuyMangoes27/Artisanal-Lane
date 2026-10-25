import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/feature_flags.dart';
import '../app/theme.dart';

class VendorShell extends StatelessWidget {
  final Widget child;

  const VendorShell({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/vendor/products')) return 1;
    if (location.startsWith('/vendor/orders')) return 2;
    if (location.startsWith('/vendor/earnings')) return 3;
    if (location.startsWith('/vendor/profile')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    // Hide the "Switch to shopping" bar while the keyboard is up so forms
    // (shop settings, product details) keep that room for the field being
    // typed in.
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      body: creatorCommerceEnabled
          ? Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: keyboardOpen
                      ? const SizedBox(width: double.infinity)
                      : Container(
                          color: AppTheme.cardBg,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            children: [
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.terracotta,
                                  minimumSize: const Size(0, 44),
                                ),
                                onPressed: () => context.go('/feed'),
                                icon: const Icon(
                                  Icons.swap_horiz_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  'Switch to shopping',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.textSecondary,
                                  minimumSize: const Size(0, 44),
                                ),
                                onPressed: () =>
                                    context.push('/vendor/profile/posts'),
                                icon: const Icon(
                                  Icons.dynamic_feed_outlined,
                                  size: 18,
                                ),
                                label: Text(
                                  'My posts',
                                  style: GoogleFonts.poppins(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                // The bar above already clears the status bar.
                Expanded(
                  child: MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    child: child,
                  ),
                ),
              ],
            )
          : child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex(context),
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go('/vendor');
            case 1:
              context.go('/vendor/products');
            case 2:
              context.go('/vendor/orders');
            case 3:
              context.go('/vendor/earnings');
            case 4:
              context.go('/vendor/profile');
          }
        },
        backgroundColor: AppTheme.cardBg,
        indicatorColor: AppTheme.terracotta.withValues(alpha: .12),
        height: 70,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Products',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Earnings',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
