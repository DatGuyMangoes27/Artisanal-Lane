import { assertEquals } from "jsr:@std/assert@1";

import { buildBobGoShipmentRequest } from "./bobgo.ts";

Deno.test("shipment booking reuses the paid checkout quote", () => {
  const request = buildBobGoShipmentRequest({
    orderId: "order-123",
    providerSlug: "sandbox",
    serviceLevelCode: "ECO",
    rateRequestSnapshot: {
      collection_address: { street_address: "1 Maker Road" },
      delivery_address: { street_address: "2 Buyer Road" },
      parcels: [{ submitted_weight_kg: 1 }],
      collection_contact_full_name: "Maker Name",
      collection_contact_mobile_number: "+27110000000",
      collection_contact_email: "maker@example.com",
      delivery_contact_full_name: "Buyer Name",
      delivery_contact_mobile_number: "+27220000000",
      delivery_contact_email: "buyer@example.com",
      declared_value: 500,
    },
  });

  assertEquals(request.provider_slug, "sandbox");
  assertEquals(request.service_level_code, "ECO");
  assertEquals(request.custom_order_number, "order-123");
  assertEquals(request.delivery_contact_name, "Buyer Name");
});
