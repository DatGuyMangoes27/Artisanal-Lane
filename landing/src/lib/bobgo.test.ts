import { describe, expect, it } from "vitest";

import { buildBobGoRateRequest, flattenBobGoDoorRates } from "./bobgo";

describe("Bob Go shipping", () => {
  it("builds the documented sandbox rate request", () => {
    const request = buildBobGoRateRequest({
      collectionAddress: {
        company: "Artisan Lane seller",
        streetAddress: "1 Main Road",
        localArea: "Woodstock",
        city: "Cape Town",
        province: "Western Cape",
        postalCode: "7925",
      },
      deliveryAddress: {
        streetAddress: "2 Buyer Street",
        localArea: "Bryanston",
        city: "Johannesburg",
        province: "Gauteng",
        postalCode: "2191",
      },
      collectionContact: {
        fullName: "Test Artisan",
        email: "artisan@example.com",
        phone: "+27110000000",
      },
      deliveryContact: {
        fullName: "Test Buyer",
        email: "buyer@example.com",
        phone: "+27210000000",
      },
      parcels: [
        {
          description: "Handmade product",
          lengthCm: 20,
          widthCm: 15,
          heightCm: 10,
          weightKg: 0.75,
        },
      ],
      declaredValue: 450,
    });

    expect(request.collection_address.country).toBe("ZA");
    expect(request.parcels[0]).toMatchObject({
      submitted_length_cm: 20,
      submitted_width_cm: 15,
      submitted_height_cm: 10,
      submitted_weight_kg: 0.75,
    });
    expect(request.declared_value).toBe(450);
  });

  it("keeps only successful door-to-door rates and sorts by VAT-inclusive price", () => {
    const rates = flattenBobGoDoorRates({
      id: 10,
      provider_rate_requests: [
        {
          rate_response_id: 22,
          provider_id: 2,
          provider_slug: "sandbox",
          provider_name: "Sandbox Couriers",
          status: "success",
          responses: [
            {
              service_level_code: "EXP",
              rate_amount: 200,
              rate_amount_excl_vat: 173.91,
              charged_weight_kg: 2,
              status: "success",
              service_level: {
                name: "Express",
                description: "Fast door delivery",
                type: "express",
                delivery_type: "door",
              },
            },
            {
              service_level_code: "ECO",
              rate_amount: 100,
              rate_amount_excl_vat: 86.96,
              charged_weight_kg: 2,
              status: "success",
              service_level: {
                name: "Economy",
                description: "Economy door delivery",
                type: "economy",
                delivery_type: "door",
              },
            },
            {
              service_level_code: "PUP",
              rate_amount: 50,
              status: "success",
              service_level: {
                name: "Pickup point",
                delivery_type: "pickup",
              },
            },
          ],
        },
      ],
    });

    expect(rates.map((rate) => rate.serviceLevelCode)).toEqual(["ECO", "EXP"]);
    expect(rates[0].amount).toBe(100);
    expect(rates.every((rate) => rate.deliveryType === "door")).toBe(true);
  });
});
