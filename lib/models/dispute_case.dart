class DisputeParticipant {
  final String participantId;
  final String roleInCase;
  final String? displayName;
  final String? avatarUrl;

  const DisputeParticipant({
    required this.participantId,
    required this.roleInCase,
    this.displayName,
    this.avatarUrl,
  });

  factory DisputeParticipant.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return DisputeParticipant(
      participantId: json['participant_id'] as String,
      roleInCase: json['role_in_case'] as String? ?? 'admin',
      displayName: profile?['display_name'] as String?,
      avatarUrl: profile?['avatar_url'] as String?,
    );
  }

  String get label {
    if (displayName != null && displayName!.trim().isNotEmpty) {
      return displayName!;
    }
    switch (roleInCase) {
      case 'buyer':
        return 'Buyer';
      case 'seller':
        return 'Seller';
      default:
        return 'Admin';
    }
  }
}

class DisputeCase {
  final String id;
  final String orderId;
  final String raisedBy;
  final String reason;
  final String status;
  final String? resolution;
  final String conversationId;
  final String buyerId;
  final String sellerId;
  final List<DisputeParticipant> participants;

  const DisputeCase({
    required this.id,
    required this.orderId,
    required this.raisedBy,
    required this.reason,
    required this.status,
    this.resolution,
    required this.conversationId,
    required this.buyerId,
    required this.sellerId,
    this.participants = const [],
  });

  DisputeParticipant? participantFor(String userId) {
    for (final participant in participants) {
      if (participant.participantId == userId) return participant;
    }
    return null;
  }
}

class DisputeOpenResult {
  final String disputeId;
  final String? conversationId;
  final bool reused;

  const DisputeOpenResult({
    required this.disputeId,
    required this.conversationId,
    required this.reused,
  });

  factory DisputeOpenResult.fromJson(Map<String, dynamic> json) {
    return DisputeOpenResult(
      disputeId: json['disputeId'] as String,
      conversationId: json['conversationId'] as String?,
      reused: json['reused'] as bool? ?? false,
    );
  }
}
