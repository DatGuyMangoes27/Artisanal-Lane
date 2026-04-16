const ACTIVE_DISPUTE_STATUSES = new Set(["open", "investigating"]);

export function buildDisputeConversationParticipants({
  conversationId,
  buyerId,
  sellerId,
  adminIds,
}) {
  const participants = [
    {
      conversation_id: conversationId,
      participant_id: buyerId,
      role_in_case: "buyer",
    },
    {
      conversation_id: conversationId,
      participant_id: sellerId,
      role_in_case: "seller",
    },
  ];

  const seenIds = new Set([buyerId, sellerId]);
  for (const adminId of adminIds) {
    if (seenIds.has(adminId)) continue;
    seenIds.add(adminId);
    participants.push({
      conversation_id: conversationId,
      participant_id: adminId,
      role_in_case: "admin",
    });
  }

  return participants;
}

export function prepareDisputeOpen({
  orderId,
  buyerId,
  sellerId,
  reason,
  adminIds,
  existingDispute,
}) {
  const trimmedReason = reason.trim();
  if (trimmedReason.length === 0) {
    throw new Error("A dispute reason is required.");
  }

  if (
    existingDispute != null &&
    ACTIVE_DISPUTE_STATUSES.has(existingDispute.status) &&
    existingDispute.conversationId != null
  ) {
    return {
      reuseExisting: true,
      disputeId: existingDispute.id,
      conversationId: existingDispute.conversationId ?? null,
      createDispute: null,
      createConversation: null,
      createInitialMessage: null,
      participants: [],
    };
  }

  const conversationId = crypto.randomUUID();
  const shouldCreateDispute =
    existingDispute == null ||
    !ACTIVE_DISPUTE_STATUSES.has(existingDispute.status);
  return {
    reuseExisting: false,
    disputeId: existingDispute?.id ?? null,
    conversationId,
    createDispute: shouldCreateDispute
      ? {
          order_id: orderId,
          raised_by: buyerId,
          reason: trimmedReason,
          status: "open",
        }
      : null,
    createConversation: {
      id: conversationId,
      order_id: orderId,
      buyer_id: buyerId,
      seller_id: sellerId,
    },
    createInitialMessage: {
      conversation_id: conversationId,
      sender_id: buyerId,
      body: trimmedReason,
      message_type: "text",
    },
    participants: buildDisputeConversationParticipants({
      conversationId,
      buyerId,
      sellerId,
      adminIds,
    }),
  };
}
