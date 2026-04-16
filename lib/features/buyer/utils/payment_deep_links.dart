final Uri paymentSuccessDeepLink = Uri.parse('artisanlane://payment/success');
final Uri paymentFailureDeepLink = Uri.parse('artisanlane://payment/error');
final Uri paymentSuccessWebUrl =
    Uri.parse('https://artisanlanesa.co.za/payment/success');
final Uri paymentFailureWebUrl =
    Uri.parse('https://artisanlanesa.co.za/payment/error');

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

  final normalizedHost = uri.host.toLowerCase();
  if (uri.scheme == 'https' && normalizedHost == 'artisanlanesa.co.za') {
    switch (uri.path) {
      case '/payment/success':
        return '/cart/confirmation';
      case '/payment/error':
        return '/cart';
      default:
        return null;
    }
  }

  return null;
}
