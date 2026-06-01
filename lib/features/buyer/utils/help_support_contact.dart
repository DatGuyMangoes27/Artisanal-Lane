const helpSupportEmail = 'nicky@artisanlanesa.com';
const helpSupportWhatsappDisplay = '+27730687908';

final Uri helpSupportEmailLaunchUri = Uri.parse('mailto:$helpSupportEmail');
final Uri helpSupportWhatsappLaunchUri = Uri.parse('https://wa.me/27730687908');

Uri vendorApplicationReviewWhatsappUri({required String businessName}) {
  final message = Uri.encodeComponent(
    'Hi Artisan Lane, I would like to chat about my vendor application for '
    '$businessName.',
  );

  return Uri.parse('https://wa.me/27730687908?text=$message');
}
