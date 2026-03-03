import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/screens/welcome_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/forgot_password_screen.dart';

import '../features/buyer/screens/buyer_home_screen.dart';
import '../features/buyer/screens/categories_screen.dart';
import '../features/buyer/screens/category_products_screen.dart';
import '../features/buyer/screens/search_screen.dart';
import '../features/buyer/screens/search_results_screen.dart';
import '../features/buyer/screens/product_detail_screen.dart';
import '../features/buyer/screens/shop_profile_screen.dart';
import '../features/buyer/screens/shops_directory_screen.dart';
import '../features/buyer/screens/favourites_screen.dart';
import '../features/buyer/screens/cart_screen.dart';
import '../features/buyer/screens/checkout_screen.dart';
import '../features/buyer/screens/payment_screen.dart';
import '../features/buyer/screens/order_confirmation_screen.dart';
import '../features/buyer/screens/orders_history_screen.dart';
import '../features/buyer/screens/order_detail_screen.dart';
import '../features/buyer/screens/confirm_receipt_screen.dart';
import '../features/buyer/screens/raise_dispute_screen.dart';
import '../features/buyer/screens/buyer_profile_screen.dart';
import '../features/buyer/screens/settings_screen.dart';
import '../features/buyer/screens/notifications_screen.dart';
import '../features/buyer/screens/saved_addresses_screen.dart';
import '../features/buyer/screens/payment_methods_screen.dart';
import '../features/buyer/screens/help_support_screen.dart';
import '../features/buyer/screens/about_screen.dart';
import '../features/buyer/screens/legal_doc_screen.dart';

import '../features/vendor/screens/vendor_dashboard_screen.dart';
import '../features/vendor/screens/vendor_products_screen.dart';
import '../features/vendor/screens/product_form_screen.dart';
import '../features/vendor/screens/vendor_orders_screen.dart';
import '../features/vendor/screens/vendor_order_detail_screen.dart';
import '../features/vendor/screens/vendor_earnings_screen.dart';
import '../features/vendor/screens/vendor_profile_screen.dart';
import '../features/vendor/screens/vendor_shop_settings_screen.dart';
import '../features/vendor/screens/vendor_settings_screen.dart';
import '../features/vendor/screens/vendor_posts_screen.dart';
import '../features/vendor/screens/post_form_screen.dart';
import '../features/vendor/screens/vendor_onboarding_screen.dart';

import '../widgets/buyer_shell.dart';
import '../widgets/vendor_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _buyerShellKey = GlobalKey<NavigatorState>();
final _vendorShellKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/welcome',
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null;
      final path = state.uri.path;

      final isAuthRoute = path == '/welcome' ||
          path == '/login' ||
          path == '/register' ||
          path == '/forgot-password';

      // Guests can browse home, search, products, shops, categories
      final isBrowseRoute = path == '/home' ||
          path.startsWith('/home/') ||
          path == '/search' ||
          path.startsWith('/search/');

      // Favourites, cart and profile require a login
      final isProtectedBuyerRoute = path == '/favourites' ||
          path == '/cart' ||
          path.startsWith('/cart/') ||
          path == '/profile' ||
          path.startsWith('/profile/');

      if (!isLoggedIn) {
        if (isProtectedBuyerRoute) return '/login';
        if (!isAuthRoute && !isBrowseRoute) return '/welcome';
      }

      if (isLoggedIn && isAuthRoute) {
        final user = Supabase.instance.client.auth.currentUser;
        final role = user?.userMetadata?['role'] as String? ?? 'buyer';
        return role == 'vendor' ? '/vendor' : '/home';
      }

      return null;
    },
    routes: [
      // ── Auth Routes (no shell) ─────────────────────────────────
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // ── Buyer Shell ────────────────────────────────────────────
      ShellRoute(
        navigatorKey: _buyerShellKey,
        builder: (context, state, child) => BuyerShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: BuyerHomeScreen(),
            ),
            routes: [
              GoRoute(
                path: 'categories',
                builder: (context, state) => const CategoriesScreen(),
              ),
              GoRoute(
                path: 'category/:categoryId',
                builder: (context, state) => CategoryProductsScreen(
                  categoryId: state.pathParameters['categoryId']!,
                  categoryName:
                      state.uri.queryParameters['name'] ?? 'Products',
                ),
              ),
              GoRoute(
                path: 'product/:productId',
                builder: (context, state) => ProductDetailScreen(
                  productId: state.pathParameters['productId']!,
                ),
              ),
              GoRoute(
                path: 'shop/:shopId',
                builder: (context, state) => ShopProfileScreen(
                  shopId: state.pathParameters['shopId']!,
                ),
              ),
              GoRoute(
                path: 'shops',
                builder: (context, state) => const ShopsDirectoryScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/search',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SearchScreen(),
            ),
            routes: [
              GoRoute(
                path: 'results',
                builder: (context, state) => SearchResultsScreen(
                  query: state.uri.queryParameters['q'] ?? '',
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/favourites',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: FavouritesScreen(),
            ),
          ),
          GoRoute(
            path: '/cart',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: CartScreen(),
            ),
            routes: [
              GoRoute(
                path: 'checkout',
                builder: (context, state) => const CheckoutScreen(),
              ),
              GoRoute(
                path: 'payment',
                builder: (context, state) => PaymentScreen(
                  checkoutData: state.extra as Map<String, dynamic>?,
                ),
              ),
              GoRoute(
                path: 'confirmation',
                builder: (context, state) {
                  final extra = state.extra as Map<String, dynamic>?;
                  return OrderConfirmationScreen(
                    orderId: extra?['orderId'] as String?,
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: BuyerProfileScreen(),
            ),
            routes: [
              GoRoute(
                path: 'settings',
                builder: (context, state) => const SettingsScreen(),
              ),
              GoRoute(
                path: 'orders',
                builder: (context, state) => const OrdersHistoryScreen(),
                routes: [
                  GoRoute(
                    path: ':orderId',
                    builder: (context, state) => OrderDetailScreen(
                      orderId: state.pathParameters['orderId']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'confirm',
                        builder: (context, state) => ConfirmReceiptScreen(
                          orderId: state.pathParameters['orderId']!,
                        ),
                      ),
                      GoRoute(
                        path: 'dispute',
                        builder: (context, state) => RaiseDisputeScreen(
                          orderId: state.pathParameters['orderId']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              GoRoute(
                path: 'notifications',
                builder: (context, state) => const NotificationsScreen(),
              ),
              GoRoute(
                path: 'addresses',
                builder: (context, state) => const SavedAddressesScreen(),
              ),
              GoRoute(
                path: 'payment-methods',
                builder: (context, state) => const PaymentMethodsScreen(),
              ),
              GoRoute(
                path: 'help',
                builder: (context, state) => const HelpSupportScreen(),
              ),
              GoRoute(
                path: 'about',
                builder: (context, state) => const AboutScreen(),
                routes: [
                  GoRoute(
                    path: 'terms',
                    builder: (context, state) => const LegalDocScreen(
                      title: 'Terms of Service',
                      type: 'terms',
                    ),
                  ),
                  GoRoute(
                    path: 'privacy',
                    builder: (context, state) => const LegalDocScreen(
                      title: 'Privacy Policy',
                      type: 'privacy',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // ── Vendor Onboarding (no shell, before approval) ──────────
      GoRoute(
        path: '/vendor/onboarding',
        builder: (context, state) => const VendorOnboardingScreen(),
      ),

      // ── Vendor Shell ───────────────────────────────────────────
      ShellRoute(
        navigatorKey: _vendorShellKey,
        builder: (context, state, child) => VendorShell(child: child),
        routes: [
          GoRoute(
            path: '/vendor',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: VendorDashboardScreen(),
            ),
          ),
          GoRoute(
            path: '/vendor/products',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: VendorProductsScreen(),
            ),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) =>
                    const ProductFormScreen(),
              ),
              GoRoute(
                path: ':productId',
                builder: (context, state) => ProductFormScreen(
                  productId: state.pathParameters['productId'],
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/vendor/orders',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: VendorOrdersScreen(),
            ),
            routes: [
              GoRoute(
                path: ':orderId',
                builder: (context, state) => VendorOrderDetailScreen(
                  orderId: state.pathParameters['orderId']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/vendor/earnings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: VendorEarningsScreen(),
            ),
          ),
          GoRoute(
            path: '/vendor/profile',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: VendorProfileScreen(),
            ),
            routes: [
              GoRoute(
                path: 'shop',
                builder: (context, state) =>
                    const VendorShopSettingsScreen(),
              ),
              GoRoute(
                path: 'settings',
                builder: (context, state) =>
                    const VendorSettingsScreen(),
              ),
              GoRoute(
                path: 'posts',
                builder: (context, state) =>
                    const VendorPostsScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (context, state) =>
                        const PostFormScreen(),
                  ),
                  GoRoute(
                    path: ':postId',
                    builder: (context, state) => PostFormScreen(
                      postId: state.pathParameters['postId'],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
