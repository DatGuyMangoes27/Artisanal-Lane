import type { MarketplaceProduct } from "./types";

export function formatPrice(value: number) {
  const amount = new Intl.NumberFormat("en-ZA", {
    useGrouping: false,
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })
    .format(value)
    .replace(",", ".");

  return `R${amount}`;
}

export function isProductOnSale(product: MarketplaceProduct) {
  return product.compareAtPrice != null && product.compareAtPrice > product.price;
}

export function getProductPrimaryImage(product: MarketplaceProduct) {
  return product.images[0] ?? "/marketplace-placeholder.svg";
}

export function getProductStockLabel(product: MarketplaceProduct) {
  if (product.stockQty <= 0) return "Out of stock";
  if (product.stockQty <= 5) return `Only ${product.stockQty} left`;
  return "In stock";
}

// Black Friday 2026: 27 Nov 00:00 to 1 Dec 00:00 South African time (UTC+2).
// Every product on sale in that window shows a "Black Friday Deal" sticker.
export const BLACK_FRIDAY_START = new Date("2026-11-26T22:00:00Z");
export const BLACK_FRIDAY_END = new Date("2026-11-30T22:00:00Z");

export function isBlackFridayActive(now: Date = new Date()) {
  return now >= BLACK_FRIDAY_START && now < BLACK_FRIDAY_END;
}

export function isBlackFridayDeal(product: MarketplaceProduct, now: Date = new Date()) {
  return isBlackFridayActive(now) && isProductOnSale(product);
}
