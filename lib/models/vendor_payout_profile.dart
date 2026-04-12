class VendorPayoutProfile {
  final String vendorId;
  final String accountHolderName;
  final String bankName;
  final String accountNumber;
  final String branchCode;
  final String accountType;
  final String registeredPhone;
  final String registeredEmail;
  final String? identityNumber;
  final String? businessRegistrationNumber;
  final String verificationStatus;
  final String? statusNotes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? reviewedAt;

  const VendorPayoutProfile({
    required this.vendorId,
    required this.accountHolderName,
    required this.bankName,
    required this.accountNumber,
    required this.branchCode,
    required this.accountType,
    required this.registeredPhone,
    required this.registeredEmail,
    this.identityNumber,
    this.businessRegistrationNumber,
    required this.verificationStatus,
    this.statusNotes,
    required this.createdAt,
    required this.updatedAt,
    this.reviewedAt,
  });

  factory VendorPayoutProfile.fromJson(Map<String, dynamic> json) {
    return VendorPayoutProfile(
      vendorId: json['vendor_id'] as String,
      accountHolderName: json['account_holder_name'] as String? ?? '',
      bankName: json['bank_name'] as String? ?? '',
      accountNumber: json['account_number'] as String? ?? '',
      branchCode: json['branch_code'] as String? ?? '',
      accountType: json['account_type'] as String? ?? '',
      registeredPhone: json['registered_phone'] as String? ?? '',
      registeredEmail: json['registered_email'] as String? ?? '',
      identityNumber: json['identity_number'] as String?,
      businessRegistrationNumber:
          json['business_registration_number'] as String?,
      verificationStatus:
          json['verification_status'] as String? ?? 'not_started',
      statusNotes: json['status_notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'vendor_id': vendorId,
        'account_holder_name': accountHolderName,
        'bank_name': bankName,
        'account_number': accountNumber,
        'branch_code': branchCode,
        'account_type': accountType,
        'registered_phone': registeredPhone,
        'registered_email': registeredEmail,
        'identity_number': identityNumber,
        'business_registration_number': businessRegistrationNumber,
        'verification_status': verificationStatus,
        'status_notes': statusNotes,
      };

  String get maskedAccountNumber {
    final trimmed = accountNumber.replaceAll(RegExp(r'\s+'), '');
    if (trimmed.length <= 4) return trimmed;
    return '${'*' * (trimmed.length - 4)}${trimmed.substring(trimmed.length - 4)}';
  }

  bool get isVerified => verificationStatus == 'verified';
  bool get needsAction =>
      verificationStatus == 'not_started' ||
      verificationStatus == 'action_required';
}
