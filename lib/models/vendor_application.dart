class VendorApplication {
  final String id;
  final String userId;
  final String businessName;
  final String? motivation;
  final String? portfolioUrl;
  final String? location;
  final String status;
  final String? inviteCode;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const VendorApplication({
    required this.id,
    required this.userId,
    required this.businessName,
    this.motivation,
    this.portfolioUrl,
    this.location,
    required this.status,
    this.inviteCode,
    this.reviewedBy,
    this.reviewedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VendorApplication.fromJson(Map<String, dynamic> json) {
    return VendorApplication(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      businessName: json['business_name'] as String,
      motivation: json['motivation'] as String?,
      portfolioUrl: json['portfolio_url'] as String?,
      location: json['location'] as String?,
      status: json['status'] as String? ?? 'pending',
      inviteCode: json['invite_code'] as String?,
      reviewedBy: json['reviewed_by'] as String?,
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
}
