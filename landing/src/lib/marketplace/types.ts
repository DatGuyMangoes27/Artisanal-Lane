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
  shippingOptions: ShippingOption[];
  isFeatured: boolean;
  createdAt: string;
  shop: MarketplaceShopSummary | null;
  category: MarketplaceCategorySummary | null;
  subcategory: MarketplaceCategorySummary | null;
  variants: MarketplaceVariant[];
};

export type MarketplaceShop = MarketplaceShopSummary & {
  bio: string | null;
  brandStory: string | null;
  coverImageUrl: string | null;
  shippingOptions: ShippingOption[];
  productCount: number;
  products: MarketplaceProduct[];
};
