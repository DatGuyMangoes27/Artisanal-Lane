import type { MarketplaceProduct } from "./types";

export type ProductReservationRow = {
  product_id: string;
  variant_id: string | null;
  quantity: number;
};

export function applyOwnReservations(
  products: MarketplaceProduct[],
  reservations: ProductReservationRow[],
) {
  if (reservations.length === 0) {
    return products;
  }

  const reservedByItem = new Map<string, number>();
  for (const reservation of reservations) {
    const key = reservation.variant_id
      ? `${reservation.product_id}:${reservation.variant_id}`
      : reservation.product_id;
    reservedByItem.set(key, (reservedByItem.get(key) ?? 0) + reservation.quantity);
  }

  return products.map((product) => {
    const productReservationQuantity = reservedByItem.get(product.id) ?? 0;
    const variants = product.variants.map((variant) => {
      const variantReservationQuantity = reservedByItem.get(`${product.id}:${variant.id}`) ?? 0;
      return variantReservationQuantity > 0
        ? { ...variant, stockQty: variant.stockQty + variantReservationQuantity }
        : variant;
    });
    const variantReservationQuantity = variants.reduce(
      (total, variant) =>
        total + (reservedByItem.get(`${product.id}:${variant.id}`) ?? 0),
      0,
    );

    return {
      ...product,
      variants,
      stockQty: product.stockQty + productReservationQuantity + variantReservationQuantity,
    };
  });
}
