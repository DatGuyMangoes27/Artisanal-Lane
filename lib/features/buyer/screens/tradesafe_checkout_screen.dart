import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../app/theme.dart';
import '../providers/buyer_providers.dart';
import '../utils/payment_deep_links.dart';

class TradeSafeCheckoutScreen extends ConsumerStatefulWidget {
  final Uri checkoutUri;
  final String? orderId;

  const TradeSafeCheckoutScreen({
    super.key,
    required this.checkoutUri,
    this.orderId,
  });

  @override
  ConsumerState<TradeSafeCheckoutScreen> createState() =>
      _TradeSafeCheckoutScreenState();
}

class _TradeSafeCheckoutScreenState
    extends ConsumerState<TradeSafeCheckoutScreen> {
  late final WebViewController _controller;
  int _progress = 0;
  String? _loadError;
  bool _handlingReturn = false;

  @override
  void initState() {
    super.initState();
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

  void _handleReturnRoute(String route) {
    if (_handlingReturn) return;
    _handlingReturn = true;

    ref.invalidate(cartItemsProvider);
    ref.invalidate(ordersProvider);
    ref.invalidate(ordersStreamProvider);
    if (widget.orderId != null) {
      ref.invalidate(orderDetailProvider(widget.orderId!));
      ref.invalidate(orderDetailStreamProvider(widget.orderId!));
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (route == '/cart/confirmation' && widget.orderId != null) {
        context.go(route, extra: {'orderId': widget.orderId});
        return;
      }
      context.go(route);
    });
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
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
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
      body: _loadError == null
          ? WebViewWidget(controller: _controller)
          : _CheckoutErrorState(
              message: _loadError!,
              onRetry: _reload,
            ),
    );
  }
}

class _CheckoutErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _CheckoutErrorState({
    required this.message,
    required this.onRetry,
  });

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
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.terracotta,
                foregroundColor: Colors.white,
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
