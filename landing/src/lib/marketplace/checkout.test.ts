import { describe, expect, it } from "vitest";

import {
  buildCartLines,
  calculateShippingTotal,
  checkoutBlockingMessage,
  firstIncompleteCheckoutField,
  getAvailableShippingOptionsForCart,
  getCartSubtotal,
  getCheckoutBlocker,
  getSavedAddressCheckoutFields,
  requiresPickupPoint,
  requiresShippingAddress,
} from "./checkout";
import type { GuestCartItem } from "./cart";
import type { MarketplaceProduct } from "./types";

function product(overrides: Partial<MarketplaceProduct> = {}): MarketplaceProduct {
  return {
    id: "product-1",
    shopId: "shop-1",
    title: "Linen candle",
    description: null,
    price: 120,
    compareAtPrice: null,
    stockQty: 5,
    images: ["https://example.com/candle.jpg"],
    tags: [],
    shippingOptions: [
      { key: "courier_guy", enabled: true, price: 69, marketName: null, marketLocation: null, marketProvince: null },
      { key: "courier_guy_door_to_door", enabled: true, price: 110, marketName: null, marketLocation: null, marketProvince: null },
      { key: "market_pickup", enabled: true, price: 0, marketName: "Neighbourgoods", marketLocation: "Cape Town", marketProvince: "Western Cape" },
    ],
    isFeatured: false,
    createdAt: "2026-01-01T00:00:00.000Z",
    shop: {
      id: "shop-1",
      name: "StellieScent",
      slug: "stelliescent",
      logoUrl: null,
      location: "Western Cape",
      isOffline: false,
    },
    category: null,
    subcategory: null,
    variants: [
      {
        id: "variant-1",
        productId: "product-1",
        displayName: "Amber",
        optionValues: ["Amber"],
        price: 150,
        compareAtPrice: null,
        stockQty: 2,
        images: ["https://example.com/amber.jpg"],
        isActive: true,
        sortOrder: 0,
      },
    ],
    optionGroups: [],
    fulfillmentMode: "stocked",
    madeToOrderPrice: null,
    leadMinDays: null,
    leadMaxDays: null,
    madeToOrderCapacity: null,
    allowCustomNote: false,
    ...overrides,
  };
}

describe("marketplace checkout helpers", () => {
  it("hydrates guest cart items with product and variant pricing", () => {
    const items: GuestCartItem[] = [
      {
        key: "product-1:variant-1",
        productId: "product-1",
        variantId: "variant-1",
        quantity: 2,
        isMadeToOrder: false,
        customNote: null,
      },
    ];

    const lines = buildCartLines(items, [product()]);

    expect(lines).toMatchObject([
      {
        key: "product-1:variant-1",
        title: "Linen candle",
        variantName: "Amber",
        unitPrice: 150,
        quantity: 2,
        lineTotal: 300,
        stockQty: 2,
        image: "https://example.com/amber.jpg",
      },
    ]);
    expect(getCartSubtotal(lines)).toBe(300);
  });

  it("prices made-to-order lines with the MTO override and keeps them available at zero stock", () => {
    const items: GuestCartItem[] = [
      {
        key: "product-1:mto",
        productId: "product-1",
        variantId: null,
        quantity: 1,
        isMadeToOrder: true,
        customNote: "Sage green glaze",
      },
    ];

    const lines = buildCartLines(items, [
      product({
        stockQty: 0,
        fulfillmentMode: "made_to_order",
        madeToOrderPrice: 200,
        leadMinDays: 14,
        leadMaxDays: 21,
        variants: [],
      }),
    ]);

    expect(lines).toMatchObject([
      {
        key: "product-1:mto",
        unitPrice: 200,
        lineTotal: 200,
        isAvailable: true,
        isMadeToOrder: true,
        customNote: "Sage green glaze",
        leadMinDays: 14,
        leadMaxDays: 21,
      },
    ]);
    expect(getCheckoutBlocker(lines)).toBeNull();
  });

  it("blocks checkout when cart items span more than one shop", () => {
    const lines = buildCartLines(
      [
        { key: "product-1", productId: "product-1", variantId: null, quantity: 1 },
        { key: "product-2", productId: "product-2", variantId: null, quantity: 1 },
      ],
      [
        product(),
        product({
          id: "product-2",
          shopId: "shop-2",
          title: "Ceramic bowl",
          shop: {
            id: "shop-2",
            name: "Clay House",
            slug: "clay-house",
            logoUrl: null,
            location: "Gauteng",
            isOffline: false,
          },
        }),
      ],
    );

    expect(getCheckoutBlocker(lines)).toBe(
      "Checkout currently supports one artisan shop per order. Please complete each shop separately.",
    );
  });

  it("uses shipping methods shared by all cart products and totals per quantity", () => {
    const lines = buildCartLines(
      [
        { key: "product-1", productId: "product-1", variantId: null, quantity: 2 },
        { key: "product-2", productId: "product-2", variantId: null, quantity: 1 },
      ],
      [
        product(),
        product({
          id: "product-2",
          shippingOptions: [
            { key: "courier_guy", enabled: true, price: 80, marketName: null, marketLocation: null, marketProvince: null },
            { key: "pargo", enabled: true, price: 65, marketName: null, marketLocation: null, marketProvince: null },
          ],
        }),
      ],
    );

    expect(getAvailableShippingOptionsForCart(lines).map((option) => option.key)).toEqual([
      "courier_guy",
    ]);
    expect(calculateShippingTotal(lines, "courier_guy")).toBe(218);
  });

  it("knows which shipping methods need address or pickup details", () => {
    expect(requiresShippingAddress("courier_guy_door_to_door")).toBe(true);
    expect(requiresShippingAddress("courier_guy")).toBe(false);
    expect(requiresPickupPoint("courier_guy")).toBe(true);
    expect(requiresPickupPoint("pargo")).toBe(true);
    expect(requiresPickupPoint("market_pickup")).toBe(false);
  });

  it("maps a saved address to checkout form fields", () => {
    expect(
      getSavedAddressCheckoutFields({
        id: "home",
        name: "Home",
        street: "1 Main Road",
        city: "Cape Town",
        postalCode: "8001",
        province: "Western Cape",
        country: "South Africa",
        phone: "0710000000",
        isDefault: true,
      }),
    ).toEqual({
      name: "Home",
      phone: "0710000000",
      street: "1 Main Road",
      city: "Cape Town",
      postalCode: "8001",
      province: "Western Cape",
    });
  });

  it("validates checkout details according to the selected delivery method", () => {
    expect(
      firstIncompleteCheckoutField({
        fullName: "Buyer",
        streetAddress: "",
        city: "",
        postalCode: "",
        province: "",
        phoneNumber: "0710000000",
        selectedShippingMethod: "courier_guy",
        hasAvailableShippingMethods: true,
        requiresShippingAddress: false,
        requiresPickupPoint: true,
        pickupPoint: "",
      }),
    ).toBe("pickupPoint");

    expect(
      firstIncompleteCheckoutField({
        fullName: "Buyer",
        streetAddress: "",
        city: "Cape Town",
        postalCode: "8001",
        province: "Western Cape",
        phoneNumber: "0710000000",
        selectedShippingMethod: "courier_guy_door_to_door",
        hasAvailableShippingMethods: true,
        requiresShippingAddress: true,
        requiresPickupPoint: false,
        pickupPoint: "",
      }),
    ).toBe("streetAddress");

    expect(
      firstIncompleteCheckoutField({
        fullName: "Buyer",
        streetAddress: "",
        city: "",
        postalCode: "",
        province: "",
        phoneNumber: "",
        selectedShippingMethod: "market_pickup",
        hasAvailableShippingMethods: true,
        requiresShippingAddress: false,
        requiresPickupPoint: false,
        pickupPoint: "",
      }),
    ).toBe("phoneNumber");
  });

  it("uses buyer-facing checkout validation messages", () => {
    expect(checkoutBlockingMessage("pickupPoint")).toBe(
      "Please enter the pickup point or drop-off location for this shipping method.",
    );
    expect(checkoutBlockingMessage("shippingMethod")).toBe(
      "This product does not have any shipping options available yet.",
    );
    expect(checkoutBlockingMessage("phoneNumber")).toBe(
      "Please complete your checkout details before continuing to TradeSafe.",
    );
  });
});
