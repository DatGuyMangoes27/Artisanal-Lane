import { assertEquals, assertRejects } from "jsr:@std/assert@1";

import {
  BobGoApiError,
  buildBobGoShipmentRequest,
  cancelBobGoShipment,
  createBobGoShipment,
  fetchBobGoWaybill,
  findBobGoShipmentForOrder,
  getBobGoTracking,
  isBobGoConfigured,
  parseBobGoShipment,
} from "./bobgo.ts";

const snapshot = {
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
};

type Call = { url: string; init: RequestInit };

// Replaces global fetch for one test and restores it afterwards.
async function withFetch(
  handler: (url: string, init: RequestInit) => Response | Promise<Response>,
  run: (calls: Call[]) => Promise<void>,
) {
  const original = globalThis.fetch;
  const calls: Call[] = [];
  Deno.env.set("BOBGO_SANDBOX_API_KEY", "test-key");
  Deno.env.set("BOBGO_SANDBOX_BASE_URL", "https://api.sandbox.bobgo.co.za/v2/");
  globalThis.fetch = ((input: string | URL | Request, init: RequestInit = {}) => {
    const url = String(input instanceof Request ? input.url : input);
    calls.push({ url, init });
    return Promise.resolve(handler(url, init));
  }) as typeof fetch;
  try {
    await run(calls);
  } finally {
    globalThis.fetch = original;
    Deno.env.delete("BOBGO_SANDBOX_API_KEY");
    Deno.env.delete("BOBGO_SANDBOX_BASE_URL");
  }
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });

Deno.test("shipment booking reuses the paid checkout quote", () => {
  const request = buildBobGoShipmentRequest({
    orderId: "order-123",
    providerSlug: "sandbox",
    serviceLevelCode: "ECO",
    rateRequestSnapshot: snapshot,
  });

  assertEquals(request.provider_slug, "sandbox");
  assertEquals(request.service_level_code, "ECO");
  assertEquals(request.custom_order_number, "order-123");
  assertEquals(request.custom_tracking_reference, "order-123");
  // Shipments use *_contact_name (rates use *_contact_full_name).
  assertEquals(request.delivery_contact_name, "Buyer Name");
  assertEquals(request.collection_contact_name, "Maker Name");
});

Deno.test("the delivery contact comes from the paid order when present", () => {
  const request = buildBobGoShipmentRequest({
    orderId: "o",
    providerSlug: "sandbox",
    serviceLevelCode: "ECO",
    rateRequestSnapshot: snapshot,
    deliveryContact: { name: " Gift Recipient ", phone: "" },
  });
  assertEquals(request.delivery_contact_name, "Gift Recipient");
  assertEquals(request.delivery_contact_mobile_number, "+27220000000");
});

Deno.test("parseBobGoShipment keeps a missing charge as null, not zero", () => {
  assertEquals(parseBobGoShipment({ id: 9, tracking_reference: "UAS1", charged_amount: null })?.chargedAmount, null);
  assertEquals(parseBobGoShipment({ id: 9, charged_amount: "95.50" })?.chargedAmount, 95.5);
  assertEquals(parseBobGoShipment({ tracking_reference: "x" }), null);
});

Deno.test("isBobGoConfigured follows the API key", () => {
  Deno.env.delete("BOBGO_SANDBOX_API_KEY");
  assertEquals(isBobGoConfigured(), false);
});

Deno.test("create posts to /shipments with bearer auth", async () => {
  await withFetch(
    () => json({ id: 77, tracking_reference: "UASDX44J", status: "pending-collection", submission_status: "success", charged_amount: 120 }),
    async (calls) => {
      const shipment = await createBobGoShipment({
        orderId: "order-1",
        providerSlug: "sandbox",
        serviceLevelCode: "ECO",
        rateRequestSnapshot: snapshot,
      });
      assertEquals(shipment.shipmentId, "77");
      assertEquals(shipment.trackingReference, "UASDX44J");
      assertEquals(calls[0].url, "https://api.sandbox.bobgo.co.za/v2/shipments");
      assertEquals(calls[0].init.method, "POST");
      assertEquals((calls[0].init.headers as Record<string, string>).Authorization, "Bearer test-key");
    },
  );
});

Deno.test("create classifies refusals vs ambiguous failures", async () => {
  await withFetch(() => json({ message: "Invalid service level" }, 400), async () => {
    const error = await assertRejects(
      () => createBobGoShipment({ orderId: "o", providerSlug: "p", serviceLevelCode: "X", rateRequestSnapshot: snapshot }),
      BobGoApiError,
    );
    assertEquals(error.ambiguous, false);
    assertEquals(error.message, "Invalid service level");
  });
  await withFetch(() => new Response("oops", { status: 502 }), async () => {
    const error = await assertRejects(
      () => createBobGoShipment({ orderId: "o", providerSlug: "p", serviceLevelCode: "X", rateRequestSnapshot: snapshot }),
      BobGoApiError,
    );
    assertEquals(error.ambiguous, true);
  });
  await withFetch(
    () => json({ id: 5, submission_status: "failed-indefinitely", failed_reason: "No courier" }),
    async () => {
      const error = await assertRejects(
        () => createBobGoShipment({ orderId: "o", providerSlug: "p", serviceLevelCode: "X", rateRequestSnapshot: snapshot }),
        BobGoApiError,
      );
      assertEquals(error.message, "No courier");
    },
  );
});

Deno.test("lookup only adopts live shipments for this order", async () => {
  await withFetch(
    () =>
      json([
        { id: 1, custom_tracking_reference: "other-order", status: "pending-collection" },
        { id: 2, custom_tracking_reference: "order-1", status: "cancelled" },
        { id: 3, custom_tracking_reference: "order-1", submission_status: "failed-indefinitely" },
        { id: 4, custom_tracking_reference: "order-1", status: "pending-collection", tracking_reference: "UAS4" },
      ]),
    async (calls) => {
      const found = await findBobGoShipmentForOrder("order-1");
      assertEquals(found?.shipmentId, "4");
      assertEquals(calls[0].url.includes("/shipments?tracking_reference=order-1"), true);
    },
  );
  await withFetch(() => json({ shipments: [] }), async () => {
    assertEquals(await findBobGoShipmentForOrder("order-1"), null);
  });
});

Deno.test("tracking parses the documented array response", async () => {
  await withFetch(
    () =>
      json([{
        shipment_id: 77,
        short_tracking_reference: "UASDRW78",
        status: "delivery-exception",
        tracking_events: [
          { status: "in-transit", date: "2026-10-01T08:00:00Z", message: "At hub" },
          { status: "delivery-exception", date: "2026-10-02T08:00:00Z", message: "Nobody home" },
        ],
      }]),
    async (calls) => {
      const snapshot = await getBobGoTracking("UASDRW78");
      assertEquals(snapshot?.trackingReference, "UASDRW78");
      assertEquals(snapshot?.status, "exception");
      assertEquals(snapshot?.rawStatus, "delivery-exception");
      assertEquals(snapshot?.statusDetail, "Nobody home");
      assertEquals(calls[0].url.endsWith("/tracking?tracking_reference=UASDRW78"), true);
    },
  );
});

Deno.test("waybill uses tracking_references as a JSON array and accepts a PDF", async () => {
  await withFetch(
    () => new Response(new Uint8Array([37, 80, 68, 70]), { headers: { "content-type": "application/pdf" } }),
    async (calls) => {
      const waybill = await fetchBobGoWaybill("UASDKRRB");
      assertEquals(waybill.bytes.length, 4);
      assertEquals(
        calls[0].url.includes(`tracking_references=${encodeURIComponent('["UASDKRRB"]')}`),
        true,
      );
    },
  );
});

Deno.test("waybill accepts a JSON body with a download URL", async () => {
  await withFetch(
    (url) =>
      url.startsWith("https://files.example")
        ? new Response(new Uint8Array([1, 2, 3]), { headers: { "content-type": "application/pdf" } })
        : json({ url: "https://files.example/waybill.pdf" }),
    async () => {
      const waybill = await fetchBobGoWaybill("UASDKRRB");
      assertEquals(waybill.bytes.length, 3);
    },
  );
});

Deno.test("cancel posts the tracking reference to /shipments/cancel", async () => {
  await withFetch(() => json({ status: "cancelled" }), async (calls) => {
    await cancelBobGoShipment("UASDRW78");
    assertEquals(calls[0].url, "https://api.sandbox.bobgo.co.za/v2/shipments/cancel");
    assertEquals(calls[0].init.method, "POST");
    assertEquals(JSON.parse(String(calls[0].init.body)), { tracking_reference: "UASDRW78" });
  });
  await withFetch(() => json({ message: "Shipment cannot be cancelled" }, 400), async () => {
    const error = await assertRejects(() => cancelBobGoShipment("X"), BobGoApiError);
    assertEquals(error.message, "Shipment cannot be cancelled");
  });
});
