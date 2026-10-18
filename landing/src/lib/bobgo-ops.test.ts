import { afterEach, describe, expect, it, vi } from "vitest";

import { bobGoAttentionReason } from "@/lib/admin-bobgo-rules";
import { fetchBobGoWaybill, flattenBobGoDoorRates } from "@/lib/bobgo";
import {
  checkBobGoCartEligibility,
  hasParcelMeasurements,
  isFulfillmentProfileComplete,
  normalizeCartItems,
} from "@/lib/bobgo-eligibility";
import { parseParcelMeasurementFields } from "@/lib/marketplace/vendor-utils";

const profile = {
  bobgo_enabled: true,
  contact_full_name: "Thandi",
  contact_email: "thandi@example.com",
  contact_phone: "082 123 4567",
  street_address: "1 Clay Street",
  local_area: "Woodstock",
  city: "Cape Town",
  province: "Western Cape",
  postal_code: "7925",
};

const parcel = { shipping_weight_kg: 1, shipping_length_cm: 20, shipping_width_cm: 15, shipping_height_cm: 10 };

// Minimal service-role client stand-in for the two eligibility queries.
function fakeAdmin(products: unknown[], fulfillment: unknown) {
  const chain = (result: unknown) => {
    const builder: Record<string, unknown> = {};
    for (const method of ["select", "in", "eq", "is"]) builder[method] = () => builder;
    builder.maybeSingle = () => Promise.resolve({ data: fulfillment, error: null });
    builder.then = (resolve: (value: unknown) => void) => resolve(result);
    return builder;
  };
  return {
    from: (table: string) =>
      table === "products" ? chain({ data: products, error: null }) : chain({ data: fulfillment, error: null }),
  } as never;
}

afterEach(() => {
  vi.unstubAllEnvs();
  vi.unstubAllGlobals();
});

describe("Bob Go eligibility (website mirrors the app)", () => {
  it("requires an opted-in, complete collection profile", () => {
    expect(isFulfillmentProfileComplete(profile)).toBe(true);
    expect(isFulfillmentProfileComplete({ ...profile, bobgo_enabled: false })).toBe(false);
    expect(isFulfillmentProfileComplete({ ...profile, postal_code: " " })).toBe(false);
    expect(isFulfillmentProfileComplete({ ...profile, contact_email: "not-an-email" })).toBe(false);
    expect(isFulfillmentProfileComplete(null)).toBe(false);
  });

  it("requires all four parcel measurements", () => {
    expect(hasParcelMeasurements(parcel)).toBe(true);
    expect(hasParcelMeasurements({ ...parcel, shipping_width_cm: null })).toBe(false);
    expect(hasParcelMeasurements({ ...parcel, shipping_weight_kg: 0 })).toBe(false);
  });

  it("keeps one entry per cart line and drops junk", () => {
    expect(
      normalizeCartItems([
        { productId: "a", quantity: 1 },
        { productId: "a", quantity: 2 },
        { productId: "", quantity: 1 },
        { productId: "b", quantity: 0 },
      ]),
    ).toEqual([
      { productId: "a", quantity: 1 },
      { productId: "a", quantity: 2 },
    ]);
  });

  it("is never available while the server flag is off", async () => {
    vi.stubEnv("BOBGO_SHIPPING_ENABLED", "false");
    vi.stubEnv("NODE_ENV", "production");
    const result = await checkBobGoCartEligibility(
      fakeAdmin([{ id: "p1", shop_id: "s1", title: "Mug", price: 100, ...parcel }], profile),
      [{ productId: "p1", quantity: 1 }],
    );
    expect(result.available).toBe(false);
  });

  it("is not offered when the artisan has not enabled Bob Go (the reported bug)", async () => {
    vi.stubEnv("BOBGO_SHIPPING_ENABLED", "true");
    const products = [{ id: "p1", shop_id: "s1", title: "Mug", price: 100, ...parcel }];
    const items = [{ productId: "p1", quantity: 1 }];
    expect((await checkBobGoCartEligibility(fakeAdmin(products, null), items)).available).toBe(false);
    expect(
      (await checkBobGoCartEligibility(fakeAdmin(products, { ...profile, bobgo_enabled: false }), items)).available,
    ).toBe(false);
    expect((await checkBobGoCartEligibility(fakeAdmin(products, profile), items)).available).toBe(true);
  });

  it("is not offered when a product has no parcel size", async () => {
    vi.stubEnv("BOBGO_SHIPPING_ENABLED", "true");
    const result = await checkBobGoCartEligibility(
      fakeAdmin([{ id: "p1", shop_id: "s1", title: "Mug", price: 100 }], profile),
      [{ productId: "p1", quantity: 1 }],
    );
    expect(result).toEqual({ available: false, reason: "Mug needs packed parcel measurements before Bob Go can quote." });
  });
});

describe("Bob Go rates and waybill", () => {
  it("drops zero-priced or incomplete rates", () => {
    const rates = flattenBobGoDoorRates({
      provider_rate_requests: [
        {
          provider_slug: "sandbox",
          status: "success",
          responses: [
            { service_level_code: "ECO", rate_amount: 0, status: "success", service_level: { delivery_type: "door" } },
            { service_level_code: "", rate_amount: 50, status: "success", service_level: { delivery_type: "door" } },
            { service_level_code: "ONX", rate_amount: 95, status: "success", service_level: { delivery_type: "door" } },
          ],
        },
      ],
    });
    expect(rates.map((rate) => rate.serviceLevelCode)).toEqual(["ONX"]);
  });

  it("requests the waybill with tracking_references as a JSON array", async () => {
    const fetchMock = vi.fn().mockResolvedValue(
      new Response(new Uint8Array([37, 80, 68, 70]), { headers: { "content-type": "application/pdf" } }),
    );
    vi.stubGlobal("fetch", fetchMock);
    const waybill = await fetchBobGoWaybill("UASDKRRB", { apiKey: "k", baseUrl: "https://api.sandbox.bobgo.co.za/v2" });
    expect(waybill.body.byteLength).toBe(4);
    expect(String(fetchMock.mock.calls[0][0])).toContain(
      `/shipments/waybill?tracking_references=${encodeURIComponent('["UASDKRRB"]')}`,
    );
  });

  it("follows a JSON waybill download link", async () => {
    const fetchMock = vi.fn()
      .mockResolvedValueOnce(
        new Response(JSON.stringify({ url: "https://files.example/w.pdf" }), {
          headers: { "content-type": "application/json" },
        }),
      )
      .mockResolvedValueOnce(new Response(new Uint8Array([1, 2]), { headers: { "content-type": "application/pdf" } }));
    vi.stubGlobal("fetch", fetchMock);
    const waybill = await fetchBobGoWaybill("X", { apiKey: "k" });
    expect(waybill.body.byteLength).toBe(2);
    expect(fetchMock.mock.calls[1][0]).toBe("https://files.example/w.pdf");
  });
});

describe("Bob Go admin attention and parcel form", () => {
  const now = new Date("2026-10-18T12:00:00Z");
  const base = {
    id: "o1",
    status: "paid",
    shipping_cost: 95,
    paid_at: "2026-10-18T11:00:00Z",
    bobgo_booking_state: "booked",
    bobgo_booking_error: null,
    bobgo_charged_amount: 95,
  };

  it("flags failed, stuck and over-charged bookings only", () => {
    expect(bobGoAttentionReason(base, now)).toBeNull();
    expect(bobGoAttentionReason({ ...base, bobgo_booking_state: "failed", bobgo_booking_error: "no courier" }, now))
      .toContain("no courier");
    expect(bobGoAttentionReason({ ...base, bobgo_booking_state: "failed", bobgo_booking_attempts: 5 }, now))
      .toContain("exhausted");
    expect(bobGoAttentionReason({ ...base, bobgo_booking_state: "booking" }, now)).toContain("Stuck");
    expect(bobGoAttentionReason({ ...base, bobgo_charged_amount: 120 }, now)).toContain("R120.00");
    expect(bobGoAttentionReason({ ...base, status: "cancelled", bobgo_cancel_error: "already collected" }, now))
      .toContain("already collected");
  });

  it("leaves parcel sizes untouched when the fields were hidden and rejects partial sizes", () => {
    const form = (entries: Record<string, string>) => ({ get: (key: string) => entries[key] ?? null });
    expect(parseParcelMeasurementFields(form({}))).toEqual({});
    expect(
      parseParcelMeasurementFields(
        form({ parcelFieldsShown: "1", shippingWeightKg: "1", shippingLengthCm: "2", shippingWidthCm: "3", shippingHeightCm: "4" }),
      ),
    ).toEqual({ shipping_weight_kg: 1, shipping_length_cm: 2, shipping_width_cm: 3, shipping_height_cm: 4 });
    expect(parseParcelMeasurementFields(form({ parcelFieldsShown: "1" }))).toEqual({
      shipping_weight_kg: null,
      shipping_length_cm: null,
      shipping_width_cm: null,
      shipping_height_cm: null,
    });
    expect(() => parseParcelMeasurementFields(form({ parcelFieldsShown: "1", shippingWeightKg: "1" }))).toThrow();
  });
});
