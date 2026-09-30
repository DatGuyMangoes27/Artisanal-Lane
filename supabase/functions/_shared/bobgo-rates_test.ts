import { assertEquals, assertThrows } from "jsr:@std/assert@1";

import { buildBobGoRateRequest, flattenBobGoDoorRates } from "./bobgo-rates.ts";

const address = {
  streetAddress: "1 Maker Road",
  localArea: "Sandton",
  city: "Johannesburg",
  province: "Gauteng",
  postalCode: "2196",
};
const contact = { fullName: "Name", email: "a@example.com", phone: "+27110000000" };

Deno.test("rate request rejects parcels without measurements", () => {
  assertThrows(() =>
    buildBobGoRateRequest({
      collectionAddress: address,
      deliveryAddress: address,
      collectionContact: contact,
      deliveryContact: contact,
      parcels: [{ description: "Mug", lengthCm: 10, widthCm: 10, heightCm: 0, weightKg: 1 }],
      declaredValue: 100,
    })
  );
});

Deno.test("only successful door rates are returned, cheapest first, with ETA", () => {
  const rates = flattenBobGoDoorRates({
    provider_rate_requests: [{
      status: "success",
      rate_response_id: 5,
      provider_id: 1,
      provider_slug: "sandbox",
      provider_name: "Sandbox",
      responses: [
        {
          status: "success",
          service_level_code: "EXP",
          rate_amount: 150,
          min_delivery_days: 1,
          max_delivery_days: 2,
          service_level: { name: "Express", delivery_type: "door" },
        },
        {
          status: "success",
          service_level_code: "ECO",
          rate_amount: 90,
          service_level: { name: "Economy", delivery_type: "door" },
        },
        {
          status: "success",
          service_level_code: "LOCKER",
          rate_amount: 50,
          service_level: { name: "Locker", delivery_type: "locker" },
        },
        { status: "failed", service_level_code: "X", rate_amount: 1, service_level: { delivery_type: "door" } },
      ],
    }],
  });
  assertEquals(rates.map((rate) => rate.serviceLevelCode), ["ECO", "EXP"]);
  assertEquals(rates[1].etaMinDays, 1);
  assertEquals(rates[0].etaMinDays, null);
});
