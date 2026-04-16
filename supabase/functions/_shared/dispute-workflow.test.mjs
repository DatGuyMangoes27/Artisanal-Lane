import test from "node:test";
import assert from "node:assert/strict";

import {
  buildDisputeConversationParticipants,
  prepareDisputeOpen,
} from "./dispute-workflow.mjs";

test("prepareDisputeOpen reuses an active dispute instead of creating a new one", () => {
  const result = prepareDisputeOpen({
    orderId: "order-1",
    buyerId: "buyer-1",
    sellerId: "seller-1",
    reason: "Item not received",
    adminIds: ["admin-1", "admin-2"],
    existingDispute: {
      id: "dispute-1",
      status: "open",
      conversationId: "conversation-1",
    },
  });

  assert.equal(result.reuseExisting, true);
  assert.equal(result.disputeId, "dispute-1");
  assert.equal(result.conversationId, "conversation-1");
  assert.equal(result.createDispute, null);
  assert.equal(result.createConversation, null);
  assert.equal(result.createInitialMessage, null);
  assert.deepEqual(result.participants, []);
});

test("prepareDisputeOpen creates a new dispute case and conversation when no active dispute exists", () => {
  const result = prepareDisputeOpen({
    orderId: "order-2",
    buyerId: "buyer-1",
    sellerId: "seller-1",
    reason: "Wrong item received",
    adminIds: ["admin-1", "admin-2"],
    existingDispute: {
      id: "dispute-old",
      status: "resolved",
      conversationId: "conversation-old",
    },
  });

  assert.equal(result.reuseExisting, false);
  assert.deepEqual(result.createDispute, {
    order_id: "order-2",
    raised_by: "buyer-1",
    reason: "Wrong item received",
    status: "open",
  });
  assert.equal(result.createConversation.order_id, "order-2");
  assert.equal(result.createConversation.buyer_id, "buyer-1");
  assert.equal(result.createConversation.seller_id, "seller-1");
  assert.equal(typeof result.createConversation.id, "string");
  assert.equal(result.createInitialMessage.sender_id, "buyer-1");
  assert.equal(result.createInitialMessage.body, "Wrong item received");
  assert.equal(result.createInitialMessage.message_type, "text");
  assert.equal(
    result.createInitialMessage.conversation_id,
    result.createConversation.id,
  );
  assert.deepEqual(
    result.participants.map((participant) => participant.participant_id).sort(),
    ["admin-1", "admin-2", "buyer-1", "seller-1"],
  );
});

test("buildDisputeConversationParticipants de-duplicates admins who are already buyer or seller", () => {
  const participants = buildDisputeConversationParticipants({
    conversationId: "conversation-1",
    buyerId: "buyer-1",
    sellerId: "seller-1",
    adminIds: ["admin-1", "buyer-1", "seller-1", "admin-1"],
  });

  assert.deepEqual(participants, [
    {
      conversation_id: "conversation-1",
      participant_id: "buyer-1",
      role_in_case: "buyer",
    },
    {
      conversation_id: "conversation-1",
      participant_id: "seller-1",
      role_in_case: "seller",
    },
    {
      conversation_id: "conversation-1",
      participant_id: "admin-1",
      role_in_case: "admin",
    },
  ]);
});

test("prepareDisputeOpen rejects a blank dispute reason", () => {
  assert.throws(
    () =>
      prepareDisputeOpen({
        orderId: "order-3",
        buyerId: "buyer-1",
        sellerId: "seller-1",
        reason: "   ",
        adminIds: ["admin-1"],
        existingDispute: null,
      }),
    /reason/i,
  );
});

test("prepareDisputeOpen repairs an active dispute missing its conversation", () => {
  const result = prepareDisputeOpen({
    orderId: "order-4",
    buyerId: "buyer-1",
    sellerId: "seller-1",
    reason: "Need admin help",
    adminIds: ["admin-1"],
    existingDispute: {
      id: "dispute-4",
      status: "open",
      conversationId: null,
    },
  });

  assert.equal(result.reuseExisting, false);
  assert.equal(result.disputeId, "dispute-4");
  assert.equal(result.createDispute, null);
  assert.equal(result.createConversation.order_id, "order-4");
  assert.equal(result.createInitialMessage.body, "Need admin help");
});
