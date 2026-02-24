class Profile {
  final String id;
  final String role;
  final String? displayName;
  final String? email;
  final String? avatarUrl;
  final String? phone;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Profile({
    required this.id,
    required this.role,
    this.displayName,
    this.email,
    this.avatarUrl,
    this.phone,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      role: json['role'] as String? ?? 'buyer',
      displayName: json['display_name'] as String?,
      email: json['email'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      phone: json['phone'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'display_name': displayName,
        'email': email,
        'avatar_url': avatarUrl,
        'phone': phone,
      };

  bool get isBuyer => role == 'buyer';
  bool get isVendor => role == 'vendor';
  bool get isAdmin => role == 'admin';
}
