export type ShippingOption = {
  key: string;
  enabled: boolean;
  price: number;
  marketName: string | null;
  marketLocation: string | null;
  marketProvince: string | null;
};

export type MarketplaceShopSummary = {
  id: string;
  name: string;
  slug: string;
  logoUrl: string | null;
  location: string | null;
  isOffline: boolean;
};

export type MarketplaceCategorySummary = {
  id: string;
  name: string;
  slug: string | null;
};

export type MarketplaceSubcategorySummary = {
  id: string;
  categoryId: string | null;
  name: string;
  slug: string | null;
};

export type MarketplaceVariant = {
  id: string;
  productId: string;
  displayName: string;
  optionValues: string[];
  price: number;
  compareAtPrice: number | null;
  stockQty: number;
  images: string[];
  isActive: boolean;
  sortOrder: number;
};

export type MarketplaceOptionGroup = {
  name: string;
  values: string[];
};

export type FulfillmentMode = "stocked" | "made_to_order" | "stocked_with_mto";

export type MarketplaceProduct = {
  id: string;
  shopId: string;
  title: string;
  description: string | null;
  price: number;
  compareAtPrice: number | null;
  stockQty: number;
  images: string[];
  tags: string[];
  fragranceDescription: string | null;
  shippingOptions: ShippingOption[];
  isFeatured: boolean;
  createdAt: string;
  shop: MarketplaceShopSummary | null;
  category: MarketplaceCategorySummary | null;
  subcategory: MarketplaceCategorySummary | null;
  variants: MarketplaceVariant[];
  optionGroups: MarketplaceOptionGroup[];
  fulfillmentMode: FulfillmentMode;
  madeToOrderPrice: number | null;
  leadMinDays: number | null;
  leadMaxDays: number | null;
  madeToOrderCapacity: number | null;
  allowCustomNote: boolean;
};

export type MarketplaceShop = MarketplaceShopSummary & {
  bio: string | null;
  brandStory: string | null;
  coverImageUrl: string | null;
  shippingOptions: ShippingOption[];
  productCount: number;
  products: MarketplaceProduct[];
};
