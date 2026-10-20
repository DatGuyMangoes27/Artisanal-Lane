import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../app/theme.dart';
import '../../../core/ui/friendly_error.dart';
import '../providers/buyer_providers.dart';
import '../utils/multi_shop_checkout.dart';
import '../utils/payment_deep_links.dart';

class TradeSafeCheckoutScreen extends ConsumerStatefulWidget {
  final Uri checkoutUri;
  final String? orderId;

  /// Set for a several-shop checkout: one payment for the whole basket.
  /// TradeSafe's top-up page may not send the buyer back to our success
  /// page, so the screen also asks the server for the payment status.
  final String? checkoutGroupId;
  final List<String> orderIds;

  const TradeSafeCheckoutScreen({
    super.key,
    required this.checkoutUri,
    this.orderId,
    this.checkoutGroupId,
    this.orderIds = const [],
  });

  @override
  ConsumerState<TradeSafeCheckoutScreen> createState() =>
      _TradeSafeCheckoutScreenState();
}

class _TradeSafeCheckoutScreenState
    extends ConsumerState<TradeSafeCheckoutScreen> {
  static const _pollInterval = Duration(seconds: 4);

  late final WebViewController _controller;
  int _progress = 0;
  String? _loadError;
  bool _handlingReturn = false;
  Timer? _pollTimer;
  bool _polling = false;
  bool _closing = false;

  /// Shown instead of the payment page once a several-shop checkout expired
  /// or needs our team.
  String? _groupProblem;
  String _groupProblemTitle = '';

  @override
  void initState() {
    super.initState();
    if (widget.checkoutGroupId != null) {
      _pollTimer = Timer.periodic(_pollInterval, (_) => _pollGroupStatus());
    }
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (!mounted) return;
            setState(() => _progress = progress);
          },
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() => _loadError = null);
          },
          onWebResourceError: (error) {
            if (!mounted || error.isForMainFrame != true) return;
            setState(() {
              _loadError = error.description;
            });
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            final route = uri == null ? null : resolvePaymentDeepLinkRoute(uri);
            if (route == null) {
              return NavigationDecision.navigate;
            }

            _handleReturnRoute(route);
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(widget.checkoutUri);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  List<String> get _allOrderIds => {
    if (widget.orderId != null) widget.orderId!,
    ...widget.orderIds,
  }.toList(growable: false);

  void _refreshOrderProviders() {
    ref.invalidate(cartItemsProvider);
    ref.invalidate(ordersProvider);
    ref.invalidate(ordersStreamProvider);
    for (final orderId in _allOrderIds) {
      ref.invalidate(orderDetailProvider(orderId));
      ref.invalidate(orderDetailStreamProvider(orderId));
    }
  }

  void _handleReturnRoute(String route) {
    if (_handlingReturn) return;
    _handlingReturn = true;
    _pollTimer?.cancel();

    _refreshOrderProviders();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (route == '/cart/confirmation' && widget.orderId != null) {
        context.go(route, extra: _confirmationExtra());
        return;
      }
      context.go(route);
    });
  }

  Map<String, dynamic> _confirmationExtra() => {
    'orderId': widget.orderId ?? _allOrderIds.firstOrNull,
    if (widget.checkoutGroupId != null) ...{
      'orderIds': _allOrderIds,
      'checkoutGroupId': widget.checkoutGroupId,
    },
  };

  /// Asks the server where the several-shop payment stands (this also lets
  /// the server pay each shop once the money has arrived).
  Future<CheckoutGroupOutcome?> _pollGroupStatus() async {
    final groupId = widget.checkoutGroupId;
    if (groupId == null || _polling || _handlingReturn) return null;
    _polling = true;
    try {
      final status = await ref
          .read(supabaseServiceProvider)
          .checkoutGroupStatus(groupId);
      if (!mounted) return null;
      final outcome = checkoutGroupOutcome(status.status);
      switch (outcome) {
        case CheckoutGroupOutcome.paid:
          _handleReturnRoute('/cart/confirmation');
          break;
        case CheckoutGroupOutcome.expired:
        case CheckoutGroupOutcome.needsHelp:
          _pollTimer?.cancel();
          _refreshOrderProviders();
          setState(() {
            _groupProblem = checkoutGroupProblemMessage(outcome);
            _groupProblemTitle = outcome == CheckoutGroupOutcome.expired
                ? 'Checkout expired'
                : 'We need to check your payment';
          });
          break;
        case CheckoutGroupOutcome.waiting:
          break;
      }
      return outcome;
    } catch (error) {
      // A missed poll is fine; the next one (or the WebView return) catches up.
      debugPrint('[checkout-debug] checkout group status failed: $error');
      return null;
    } finally {
      _polling = false;
    }
  }

  /// Closing the payment page: for several shops, check once more so a
  /// payment TradeSafe did not report back is still picked up.
  Future<void> _close() async {
    if (_closing) return;
    if (widget.checkoutGroupId == null || _groupProblem != null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _closing = true);
    // Wait for a poll already in flight before asking again.
    while (_polling) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    final outcome = await _pollGroupStatus();
    if (!mounted || _handlingReturn) return;
    setState(() => _closing = false);
    if (outcome == CheckoutGroupOutcome.expired ||
        outcome == CheckoutGroupOutcome.needsHelp) {
      return; // The message is now on screen.
    }
    // Still waiting: the orders exist, so show them with a way back to pay.
    _pollTimer?.cancel();
    _handlingReturn = true;
    _refreshOrderProviders();
    context.go('/cart/confirmation', extra: _confirmationExtra());
  }

  Future<void> _reload() async {
    if (!mounted) return;
    setState(() {
      _loadError = null;
      _progress = 0;
    });
    await _controller.loadRequest(widget.checkoutUri);
  }

  @override
  Widget build(BuildContext context) {
    final interceptClose =
        widget.checkoutGroupId != null && _groupProblem == null;
    return PopScope(
      canPop: !interceptClose,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: _buildScaffold(context),
    );
  }

  Widget _buildBody() {
    final problem = _groupProblem;
    if (problem != null) {
      return _GroupProblemState(
        title: _groupProblemTitle,
        message: problem,
        onBackToBasket: () => context.go('/cart'),
        onViewOrders: () => context.go('/profile/orders'),
      );
    }
    final page = _loadError == null
        ? WebViewWidget(controller: _controller)
        : _CheckoutErrorState(message: _loadError!, onRetry: _reload);
    if (!_closing) return page;
    return Stack(
      children: [
        page,
        Positioned.fill(
          child: ColoredBox(
            color: AppTheme.scaffoldBg.withValues(alpha: 0.85),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    color: AppTheme.terracotta,
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Checking your payment…',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppTheme.textPrimary,
          ),
          onPressed: _close,
        ),
        title: Text(
          'Secure Payment',
          style: GoogleFonts.playfairDisplay(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: _progress < 100
              ? LinearProgressIndicator(
                  value: _progress == 0 ? null : _progress / 100,
                  minHeight: 3,
                  color: AppTheme.terracotta,
                  backgroundColor: AppTheme.sand.withValues(alpha: 0.2),
                )
              : const SizedBox(height: 3),
        ),
      ),
      body: _buildBody(),
    );
  }
}

class _GroupProblemState extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onBackToBasket;
  final VoidCallback onViewOrders;

  const _GroupProblemState({
    required this.title,
    required this.message,
    required this.onBackToBasket,
    required this.onViewOrders,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              size: 40,
              color: AppTheme.ochre,
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onBackToBasket,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.terracotta,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
              ),
              child: Text(
                'Back to basket',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onViewOrders,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
              ),
              child: Text(
                'View my orders',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckoutErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _CheckoutErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 40,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(height: 20),
            Text(
              'TradeSafe could not load right now.',
              textAlign: TextAlign.center,
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              friendlyErrorMessage(
                message,
                fallback: "We couldn't open secure checkout. Please try again.",
              ),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.terracotta,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
              ),
              child: Text(
                'Retry checkout',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
