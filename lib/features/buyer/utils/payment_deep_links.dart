final Uri paymentSuccessDeepLink = Uri.parse('artisanlane://payment/success');
final Uri paymentFailureDeepLink = Uri.parse('artisanlane://payment/error');
final Uri vendorSubscriptionSuccessDeepLink =
    Uri.parse('artisanlane://vendor-subscription/success');
final Uri vendorSubscriptionFailureDeepLink =
    Uri.parse('artisanlane://vendor-subscription/error');
final Uri vendorStationerySuccessDeepLink =
    Uri.parse('artisanlane://vendor-stationery/success');
final Uri vendorStationeryFailureDeepLink =
    Uri.parse('artisanlane://vendor-stationery/error');
final Uri paymentSuccessWebUrl =
    Uri.parse('https://artisanlanesa.co.za/payment/success');
final Uri paymentFailureWebUrl =
    Uri.parse('https://artisanlanesa.co.za/payment/error');
final Uri vendorSubscriptionSuccessWebUrl =
    Uri.parse('https://artisanlanesa.co.za/vendor/subscription/success');
final Uri vendorSubscriptionFailureWebUrl =
    Uri.parse('https://artisanlanesa.co.za/vendor/subscription/error');
final Uri vendorStationerySuccessWebUrl =
    Uri.parse('https://artisanlanesa.co.za/vendor/stationery/success');
final Uri vendorStationeryFailureWebUrl =
    Uri.parse('https://artisanlanesa.co.za/vendor/stationery/error');

String? resolvePaymentDeepLinkRoute(Uri uri) {
  if (uri.scheme == 'artisanlane' && uri.host == 'payment') {
    switch (uri.path) {
      case '/success':
        return '/cart/confirmation';
      case '/error':
        return '/cart';
      default:
        return null;
    }
  }

  if (uri.scheme == 'artisanlane' && uri.host == 'vendor-subscription') {
    switch (uri.path) {
      case '/success':
        return '/vendor/profile/subscription?status=success';
      case '/error':
        return '/vendor/profile/subscription?status=error';
      default:
        return null;
    }
  }

  if (uri.scheme == 'artisanlane' && uri.host == 'vendor-stationery') {
    switch (uri.path) {
      case '/success':
        return '/vendor/profile/stationery?status=success';
      case '/error':
        return '/vendor/profile/stationery?status=error';
      default:
        return null;
    }
  }

  final normalizedHost = uri.host.toLowerCase();
  if (uri.scheme == 'https' && normalizedHost == 'artisanlanesa.co.za') {
    switch (uri.path) {
      case '/payment/success':
        return '/cart/confirmation';
      case '/payment/error':
        return '/cart';
      case '/vendor/subscription/success':
        return '/vendor/profile/subscription?status=success';
      case '/vendor/subscription/error':
        return '/vendor/profile/subscription?status=error';
      case '/vendor/stationery/success':
        return '/vendor/profile/stationery?status=success';
      case '/vendor/stationery/error':
        return '/vendor/profile/stationery?status=error';
      default:
        return null;
    }
  }

  return null;
}
