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
      return 'Your payout details have been submitted and are under review.';
    case 'verified':
      return 'TradeSafe payouts are active.';
    case 'action_required':
      return 'Action required: update your payout details to continue receiving payouts.';
    case 'not_started':
    default:
      return 'Payout details required before payouts can be completed.';
  }
}
