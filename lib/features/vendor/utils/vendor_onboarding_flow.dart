bool shouldShowVendorApprovalCelebration({
  required bool isApproved,
  required bool hasSeenVendorApproval,
}) {
  return isApproved && !hasSeenVendorApproval;
}

String vendorPayoutBannerMessage(String? status) {
  switch (status) {
    case 'under_review':
    case 'submitted':
      return 'Your payout details are saved and ready to use.';
    case 'verified':
      return 'TradeSafe payouts are active.';
    case 'action_required':
      return 'Update your payout details to continue adding products and receiving payouts.';
    case 'not_started':
    default:
      return 'Complete your payout details before adding products and receiving payouts.';
  }
}
