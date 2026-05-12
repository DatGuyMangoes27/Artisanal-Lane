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
