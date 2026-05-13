import { describe, expect, it } from "vitest";

import {
  getAddressSummary,
  mapSavedAddress,
  normalizeSavedAddresses,
  upsertSavedAddress,
} from "./buyer-preferences";

describe("buyer preferences helpers", () => {
  it("maps valid saved addresses and ignores invalid rows", () => {
    expect(
      normalizeSavedAddresses([
        {
          name: "Home",
          street: "1 Main Road",
          city: "Cape Town",
          postal_code: "8001",
          province: "Western Cape",
          country: "South Africa",
          phone: "0710000000",
          is_default: true,
        },
        { name: "Missing street" },
      ]),
    ).toEqual([
      {
        id: "0",
        name: "Home",
        street: "1 Main Road",
        city: "Cape Town",
        postalCode: "8001",
        province: "Western Cape",
        country: "South Africa",
        phone: "0710000000",
        isDefault: true,
      },
    ]);
  });

  it("creates a concise address summary", () => {
    const address = mapSavedAddress(
      {
        name: "Home",
        street: "1 Main Road",
        city: "Cape Town",
        postal_code: "8001",
        province: "Western Cape",
        country: "South Africa",
        phone: "0710000000",
      },
      0,
    );

    expect(getAddressSummary(address!)).toBe("1 Main Road, Cape Town, Western Cape, 8001");
  });

  it("upserts a default address and clears other defaults", () => {
    const updated = upsertSavedAddress(
      [
        {
          id: "0",
          name: "Old",
          street: "2 Old Road",
          city: "Durban",
          postalCode: "4001",
          province: "KwaZulu-Natal",
          country: "South Africa",
          phone: "0720000000",
          isDefault: true,
        },
      ],
      {
        name: "New",
        street: "3 New Road",
        city: "Cape Town",
        postalCode: "8001",
        province: "Western Cape",
        country: "South Africa",
        phone: "0730000000",
        isDefault: true,
      },
    );

    expect(updated.map((address) => address.isDefault)).toEqual([false, true]);
  });
});
