export type PurchaseOrderRow = {
  id: string;
  status: string | null;
  total: number | string | null;
  shipping_cost: number | string | null;
  order_items?: { product_id: string | null; quantity: number | null }[] | null;
};

export type PurchaseSummary = {
  value: number;
  contentIds: string[];
  numItems: number;
};

/** What the buyer paid across the orders of one checkout (cancelled excluded). */
export function summarisePurchase(orders: PurchaseOrderRow[]): PurchaseSummary | null {
  const paid = orders.filter((order) => order.status !== "cancelled");
  if (!paid.length) return null;
  const ids = new Set<string>();
  let value = 0;
  let numItems = 0;
  for (const order of paid) {
    value += Number(order.total ?? 0) + Number(order.shipping_cost ?? 0);
    for (const item of order.order_items ?? []) {
      if (item.product_id) ids.add(item.product_id);
      numItems += Number(item.quantity ?? 0);
    }
  }
  if (!(value > 0)) return null;
  return { value: Math.round(value * 100) / 100, contentIds: [...ids], numItems };
}
