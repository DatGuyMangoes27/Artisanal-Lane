import '../../../models/vendor_payout_profile.dart';

class VendorPayoutAccountTypeOption {
  final String value;
  final String label;

  const VendorPayoutAccountTypeOption({
    required this.value,
    required this.label,
  });
}

const supportedTradeSafeBanks = <String>[
  'ABSA',
  'African Bank',
  'Capitec',
  'Discovery Bank',
  'FNB',
  'Investec',
  'MTN',
  'Nedbank',
  'Postbank',
  'Sasfin',
  'Standard Bank',
  'TymeBank',
  'Other',
];

const supportedTradeSafeAccountTypes = <VendorPayoutAccountTypeOption>[
  VendorPayoutAccountTypeOption(value: 'cheque', label: 'Cheque'),
  VendorPayoutAccountTypeOption(value: 'savings', label: 'Savings'),
  VendorPayoutAccountTypeOption(value: 'transmission', label: 'Transmission'),
  VendorPayoutAccountTypeOption(value: 'bond', label: 'Bond'),
];

const vendorPayoutGateMessage =
    'Complete your payout details before adding products.';

bool isVendorPayoutSetupComplete(VendorPayoutProfile? payoutProfile) {
  if (payoutProfile == null) return false;

  return payoutProfile.accountHolderName.trim().isNotEmpty &&
      payoutProfile.bankName.trim().isNotEmpty &&
      payoutProfile.accountNumber.trim().isNotEmpty &&
      payoutProfile.branchCode.trim().isNotEmpty &&
      payoutProfile.accountType.trim().isNotEmpty &&
      payoutProfile.registeredPhone.trim().isNotEmpty &&
      payoutProfile.verificationStatus != 'not_started' &&
      payoutProfile.verificationStatus != 'action_required';
}
