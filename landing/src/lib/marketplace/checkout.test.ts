import { describe, expect, it } from "vitest";

import {
  buildCartLines,
  buildCheckoutRequestBody,
  calculateCheckoutTotals,
  calculateShippingTotal,
  checkoutBlockingMessage,
  firstIncompleteCheckoutField,
  getAvailableShippingOptionsForCart,
  getCartSubtotal,
  getCheckoutBlocker,
  getSavedAddressCheckoutFields,
  groupCartLinesByShop,
  parseCheckoutResponse,
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
      combinedShippingEnabled: true,
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

  function twoShopLines() {
    return buildCartLines(
      [
        { key: "product-1", productId: "product-1", variantId: null, quantity: 2 },
        { key: "product-2", productId: "product-2", variantId: null, quantity: 1 },
        { key: "product-3", productId: "product-3", variantId: null, quantity: 1 },
      ],
      [
        product(),
        product({
          id: "product-2",
          shopId: "shop-2",
          title: "Ceramic bowl",
          price: 200,
          shippingOptions: [
            { key: "pargo", enabled: true, price: 65, marketName: null, marketLocation: null, marketProvince: null },
            { key: "courier_guy", enabled: true, price: 80, marketName: null, marketLocation: null, marketProvince: null },
          ],
          shop: {
            id: "shop-2",
            name: "Clay House",
            slug: "clay-house",
            logoUrl: null,
            location: "Gauteng",
            isOffline: false,
          },
        }),
        product({ id: "product-3", title: "Beeswax candle", price: 90 }),
      ],
    );
  }

  it("allows checkout when cart items span more than one shop", () => {
    expect(getCheckoutBlocker(twoShopLines())).toBeNull();
  });

  it("groups cart lines by shop in first-added order with per-shop subtotals", () => {
    const shops = groupCartLinesByShop(twoShopLines());

    expect(shops.map((shop) => [shop.shopId, shop.shopName, shop.quantity, shop.subtotal])).toEqual([
      ["shop-1", "StellieScent", 3, 330],
      ["shop-2", "Clay House", 1, 200],
    ]);
    expect(shops[0].lines.map((line) => line.productId)).toEqual(["product-1", "product-3"]);
  });

  it("works out delivery options and costs for each shop on its own", () => {
    const [stellie, clay] = groupCartLinesByShop(twoShopLines());

    // The second shop's options do not narrow the first shop's.
    expect(getAvailableShippingOptionsForCart(stellie.lines).map((option) => option.key)).toEqual([
      "courier_guy",
      "courier_guy_door_to_door",
      "market_pickup",
    ]);
    expect(getAvailableShippingOptionsForCart(clay.lines).map((option) => option.key)).toEqual([
      "pargo",
      "courier_guy",
    ]);
    expect(calculateShippingTotal(stellie.lines, "courier_guy")).toBe(69);
    expect(calculateShippingTotal(clay.lines, "pargo")).toBe(65);
  });

  it("names the shop whose products share no delivery option", () => {
    const clayHouse = {
      id: "shop-2",
      name: "Clay House",
      slug: "clay-house",
      logoUrl: null,
      location: null,
      isOffline: false,
    };
    const lines = buildCartLines(
      [
        { key: "product-1", productId: "product-1", variantId: null, quantity: 1 },
        { key: "product-2", productId: "product-2", variantId: null, quantity: 1 },
        { key: "product-3", productId: "product-3", variantId: null, quantity: 1 },
      ],
      [
        product(),
        product({
          id: "product-2",
          shopId: "shop-2",
          shippingOptions: [
            { key: "pargo", enabled: true, price: 65, marketName: null, marketLocation: null, marketProvince: null },
          ],
          shop: clayHouse,
        }),
        product({
          id: "product-3",
          shopId: "shop-2",
          shippingOptions: [
            { key: "courier_guy", enabled: true, price: 69, marketName: null, marketLocation: null, marketProvince: null },
          ],
          shop: clayHouse,
        }),
      ],
    );

    expect(getCheckoutBlocker(lines)).toBe(
      "Clay House: the products from this shop do not share a delivery option yet. Remove one of them to continue.",
    );
    // Bob Go can still quote that shop, so checkout may go ahead.
    expect(getCheckoutBlocker(lines, { allowDynamicShipping: (shopId) => shopId === "shop-2" })).toBeNull();
    expect(getCheckoutBlocker(lines, { allowDynamicShipping: (shopId) => shopId === "shop-1" })).not.toBeNull();
  });

  it("adds per-shop totals and charges the gift fee once per shop", () => {
    const shops = [
      { shopId: "shop-1", shopName: "StellieScent", subtotal: 330, shippingCost: 69 },
      { shopId: "shop-2", shopName: "Clay House", subtotal: 200, shippingCost: 65 },
    ];

    expect(calculateCheckoutTotals(shops, false)).toMatchObject({
      subtotal: 530,
      shippingCost: 134,
      giftFee: 0,
      total: 664,
    });
    const gift = calculateCheckoutTotals(shops, true);
    expect(gift.giftFee).toBe(60);
    expect(gift.total).toBe(724);
    expect(gift.shops.map((shop) => [shop.shopId, shop.giftFee, shop.total])).toEqual([
      ["shop-1", 30, 429],
      ["shop-2", 30, 295],
    ]);
  });

  it("builds a create-checkout body with one entry and its own pickup point per shop", () => {
    const shippingAddress = { name: "Buyer", phone: "0710000000", country: "South Africa" };
    const lockerPoint = { carrier: "courier_guy", point_type: "locker", code: "CG1", name: "Mall locker" };
    const marketPoint = { carrier: "market_pickup", point_type: "market", name: "Neighbourgoods" };
    const body = buildCheckoutRequestBody({
      userId: "buyer-1",
      reservationToken: "token-1",
      shippingAddress,
      isGift: true,
      giftRecipient: "  Gran ",
      giftMessage: "",
      couponCode: " clay10 ",
      shops: [
        {
          shopId: "shop-1",
          shippingMethod: "courier_guy",
          shippingCost: 69,
          shippingAddress: { pickup_point: lockerPoint },
        },
        {
          shopId: "shop-2",
          shippingMethod: "bobgo_door_to_door",
          shippingCost: 120,
          shippingAddress: null,
          bobgo: { quoteId: "quote-2", rateResponseId: 7, providerSlug: "tcg", serviceLevelCode: "ECO" },
        },
        {
          shopId: "shop-3",
          shippingMethod: "market_pickup",
          shippingCost: 0,
          shippingAddress: { pickup_point: marketPoint },
        },
      ],
    });

    expect(body).toEqual({
      userId: "buyer-1",
      reservationToken: "token-1",
      shippingAddress,
      shops: [
        {
          shopId: "shop-1",
          shippingMethod: "courier_guy",
          shippingCost: 69,
          bobgoQuoteId: null,
          bobgoRateResponseId: null,
          bobgoProviderSlug: null,
          bobgoServiceLevelCode: null,
          shippingAddress: { pickup_point: lockerPoint },
        },
        {
          // Door delivery uses the top-level address only.
          shopId: "shop-2",
          shippingMethod: "bobgo_door_to_door",
          shippingCost: 120,
          bobgoQuoteId: "quote-2",
          bobgoRateResponseId: 7,
          bobgoProviderSlug: "tcg",
          bobgoServiceLevelCode: "ECO",
        },
        {
          shopId: "shop-3",
          shippingMethod: "market_pickup",
          shippingCost: 0,
          bobgoQuoteId: null,
          bobgoRateResponseId: null,
          bobgoProviderSlug: null,
          bobgoServiceLevelCode: null,
          shippingAddress: { pickup_point: marketPoint },
        },
      ],
      isGift: true,
      giftRecipient: "Gran",
      giftMessage: null,
      couponCode: "CLAY10",
    });
  });

  it("keeps the original top-level delivery fields for a one-shop basket", () => {
    const body = buildCheckoutRequestBody({
      userId: "buyer-1",
      reservationToken: null,
      shippingAddress: {},
      isGift: false,
      giftRecipient: "Gran",
      giftMessage: "Enjoy",
      couponCode: "",
      shops: [
        {
          shopId: "shop-1",
          shippingMethod: "bobgo_door_to_door",
          shippingCost: 99,
          bobgo: { quoteId: "quote-1", rateResponseId: 3, providerSlug: "tcg", serviceLevelCode: "ECO" },
        },
      ],
    });

    expect(body).toMatchObject({
      shippingMethod: "bobgo_door_to_door",
      shippingCost: 99,
      bobgoQuoteId: "quote-1",
      bobgoRateResponseId: 3,
      bobgoProviderSlug: "tcg",
      bobgoServiceLevelCode: "ECO",
      giftRecipient: null,
      giftMessage: null,
      couponCode: null,
    });
    expect(body.shops).toHaveLength(1);
  });

  it("reads both create-checkout response shapes", () => {
    expect(
      parseCheckoutResponse({ orderId: "order-1", checkoutUrl: "https://pay.example/1", transactionId: "t-1" }),
    ).toEqual({ kind: "single", orderId: "order-1", checkoutUrl: "https://pay.example/1" });

    expect(
      parseCheckoutResponse({
        checkoutGroupId: "group-1",
        status: "awaiting_payment",
        orderId: "order-1",
        orderIds: ["order-1", "order-2"],
        checkoutUrl: "https://pay.example/basket",
        total: 724.5,
      }),
    ).toEqual({
      kind: "group",
      checkoutGroupId: "group-1",
      status: "awaiting_payment",
      orderIds: ["order-1", "order-2"],
      checkoutUrl: "https://pay.example/basket",
      total: 724.5,
    });

    // The buyer's TradeSafe wallet already covered the basket.
    expect(
      parseCheckoutResponse({ checkoutGroupId: "group-2", status: "funded", orderIds: ["order-3"], checkoutUrl: null }),
    ).toMatchObject({ kind: "group", status: "funded", checkoutUrl: null });

    expect(parseCheckoutResponse({ error: "Clay House: Please select a shipping method." })).toEqual({
      kind: "error",
      message: "Clay House: Please select a shipping method.",
    });
    expect(parseCheckoutResponse(null)).toEqual({ kind: "error", message: "Checkout failed." });
  });

  it("charges a shared shipping method once per shop", () => {
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
    expect(calculateShippingTotal(lines, "courier_guy")).toBe(80);
  });

  it("charges shipping per item when the seller turns combined shipping off", () => {
    const lines = buildCartLines(
      [
        { key: "product-1", productId: "product-1", variantId: null, quantity: 2 },
        { key: "product-2", productId: "product-2", variantId: null, quantity: 1 },
      ],
      [
        product({
          shop: {
            id: "shop-1",
            name: "StellieScent",
            slug: "stelliescent",
            logoUrl: null,
            location: "Western Cape",
            isOffline: false,
            combinedShippingEnabled: false,
          },
        }),
        product({
          id: "product-2",
          shop: {
            id: "shop-1",
            name: "StellieScent",
            slug: "stelliescent",
            logoUrl: null,
            location: "Western Cape",
            isOffline: false,
            combinedShippingEnabled: false,
          },
          shippingOptions: [
            { key: "courier_guy", enabled: true, price: 80, marketName: null, marketLocation: null, marketProvince: null },
          ],
        }),
      ],
    );

    expect(calculateShippingTotal(lines, "courier_guy")).toBe(218);
  });

  it("knows which shipping methods need address or pickup details", () => {
    expect(requiresShippingAddress("courier_guy_door_to_door")).toBe(false);
    expect(requiresShippingAddress("bobgo_door_to_door")).toBe(true);
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
      localArea: "Cape Town",
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
