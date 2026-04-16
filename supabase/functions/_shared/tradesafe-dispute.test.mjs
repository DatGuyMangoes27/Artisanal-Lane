import test from "node:test";
import assert from "node:assert/strict";

import { buildAllocationDisputeDeliveryRequest } from "./tradesafe-dispute.mjs";

test("buildAllocationDisputeDeliveryRequest includes required TradeSafe comment", () => {
  const request = buildAllocationDisputeDeliveryRequest({
    allocationId: "allocation-123",
    comment: "Item arrived damaged",
  });

  assert.match(request.mutation, /\$comment: String!/);
  assert.match(request.mutation, /allocationDisputeDelivery\(id: \$id, comment: \$comment\)/);
  assert.deepEqual(request.variables, {
    id: "allocation-123",
    comment: "Item arrived damaged",
  });
});
