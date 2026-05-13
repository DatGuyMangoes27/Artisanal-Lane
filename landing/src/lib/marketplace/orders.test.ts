import { describe, expect, it } from "vitest";

import {
  formatOrderStatus,
  formatShippingMethod,
  getOrderGrandTotal,
  getOrderPickupPointSummary,
  getOrderShortId,
  mapBuyerOrder,
} from "./orders";

const orderRow = {
  id: "599ec8a6-2f5d-4b1e-9ac3-ff1712544b00",
  buyer_id: "buyer-1",
  shop_id: "shop-1",
  status: "shipped",
  total: 250,
  shipping_cost: 69,
  shipping_method: "courier_guy",
  shipping_address: {
    name: "Buyer",
    phone: "0710000000",
    pickup_point: {
      name: "PUDO Stellenbosch",
      code: "PUDO-123",
      address: "Bird Street",
      province: "Western Cape",
    },
  },
  tracking_number: "TRACK123",
  tracking_url: "https://example.com/track",
  payment_state: "paid",
  payment_provider: "tradesafe",
  payment_url: "https://pay.example.com",
  shipped_at: "2026-05-12T10:00:00.000Z",
  received_at: null,
  is_gift: true,
  gift_recipient: "Friend",
  gift_message: "Enjoy",
  created_at: "2026-05-12T09:00:00.000Z",
  updated_at: "2026-05-12T10:00:00.000Z",
  shops: {
    name: "StellieScent",
    slug: "stelliescent",
  },
  order_items: [
    {
      id: "item-1",
      order_id: "599ec8a6-2f5d-4b1e-9ac3-ff1712544b00",
      product_id: "product-1",
      variant_id: "variant-1",
      variant_name: "Amber",
      variant_image: "variant.jpg",
      quantity: 2,
      unit_price: 125,
      created_at: "2026-05-12T09:00:00.000Z",
      products: {
        title: "Soy candle",
        images: ["product.jpg"],
      },
    },
  ],
};

describe("buyer order helpers", () => {
  it("maps Supabase order rows into buyer order summaries", () => {
    const order = mapBuyerOrder(orderRow);

    expect(order).toMatchObject({
      id: "599ec8a6-2f5d-4b1e-9ac3-ff1712544b00",
      shortId: "599EC8A6",
      shopName: "StellieScent",
      shopSlug: "stelliescent",
      status: "shipped",
      paymentState: "paid",
      shippingMethod: "courier_guy",
      trackingNumber: "TRACK123",
      items: [
        {
          id: "item-1",
          title: "Soy candle",
          variantName: "Amber",
          image: "variant.jpg",
          lineTotal: 250,
        },
      ],
    });
  });

  it("formats buyer-facing order labels and totals", () => {
    const order = mapBuyerOrder(orderRow);

    expect(getOrderShortId(order.id)).toBe("599EC8A6");
    expect(formatOrderStatus("paid")).toBe("Paid");
    expect(formatOrderStatus("FUNDS_RELEASED")).toBe("Funds released");
    expect(formatShippingMethod("courier_guy_door_to_door")).toBe("Courier Guy Door to Door");
    expect(getOrderGrandTotal(order)).toBe(349);
  });

  it("summarizes pickup point objects and strings", () => {
    expect(getOrderPickupPointSummary(mapBuyerOrder(orderRow))).toBe(
      "PUDO Stellenbosch (PUDO-123) Bird Street Western Cape",
    );
    expect(
      getOrderPickupPointSummary(
        mapBuyerOrder({
          ...orderRow,
          shipping_address: { pickup_point: "Market table near Gate 2" },
        }),
      ),
    ).toBe("Market table near Gate 2");
  });
});
