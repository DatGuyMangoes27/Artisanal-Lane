"use client";

import { useRouter, useSearchParams } from "next/navigation";
import { FormEvent, useState } from "react";

import { Button } from "@/components/ui/button";
import type {
  MarketplaceCategorySummary,
  MarketplaceSubcategorySummary,
} from "@/lib/marketplace/types";

export function SearchControls({
  categories,
  subcategories = [],
  trendingTerms = [],
}: {
  categories: MarketplaceCategorySummary[];
  subcategories?: MarketplaceSubcategorySummary[];
  trendingTerms?: string[];
}) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [query, setQuery] = useState(searchParams.get("q") ?? "");
  const [categoryId, setCategoryId] = useState(searchParams.get("category") ?? "");
  const [subcategoryId, setSubcategoryId] = useState(searchParams.get("subcategory") ?? "");
  const [sort, setSort] = useState(searchParams.get("sort") ?? "newest");
  const [priceFilter, setPriceFilter] = useState(searchParams.get("price") ?? "");
  const [availabilityFilter, setAvailabilityFilter] = useState(searchParams.get("availability") ?? "");

  // Mirrors the mobile app: subcategory filtering only applies within a
  // selected category, and resets when the category changes.
  const categorySubcategories = categoryId
    ? subcategories.filter((subcategory) => subcategory.categoryId === categoryId)
    : [];
  const validSubcategoryId = categorySubcategories.some(
    (subcategory) => subcategory.id === subcategoryId,
  )
    ? subcategoryId
    : "";

  function applyFilters(overrides: Partial<{
    query: string;
    categoryId: string;
    subcategoryId: string;
    sort: string;
    priceFilter: string;
    availabilityFilter: string;
  }> = {}) {
    const nextQuery = overrides.query ?? query;
    const nextCategoryId = overrides.categoryId ?? categoryId;
    const nextSubcategoryId = overrides.subcategoryId ?? validSubcategoryId;
    const nextSort = overrides.sort ?? sort;
    const nextPriceFilter = overrides.priceFilter ?? priceFilter;
    const nextAvailabilityFilter = overrides.availabilityFilter ?? availabilityFilter;
    const params = new URLSearchParams();
    if (nextQuery.trim()) params.set("q", nextQuery.trim());
    if (nextCategoryId) params.set("category", nextCategoryId);
    if (nextCategoryId && nextSubcategoryId) params.set("subcategory", nextSubcategoryId);
    if (nextSort !== "newest") params.set("sort", nextSort);
    if (nextPriceFilter) params.set("price", nextPriceFilter);
    if (nextAvailabilityFilter) params.set("availability", nextAvailabilityFilter);
    router.push(`/shop${params.size ? `?${params.toString()}` : ""}`);
  }

  function onSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    applyFilters();
  }

  function clearFilters() {
    setQuery("");
    setCategoryId("");
    setSubcategoryId("");
    setSort("newest");
    setPriceFilter("");
    setAvailabilityFilter("");
    router.push("/shop");
  }

  return (
    <div id="search" className="rounded-3xl border border-artisan-clay bg-card p-4 shadow-sm">
      <form onSubmit={onSubmit} className="flex flex-col gap-3 md:flex-row md:flex-wrap md:items-center">
        <input
          value={query}
          onChange={(event) => setQuery(event.target.value)}
          placeholder="Search handmade products"
          className="h-11 min-w-0 rounded-full border border-input bg-background px-4 text-sm outline-none focus:ring-2 focus:ring-ring/30 md:min-w-[200px] md:flex-1"
        />
        <select
          value={categoryId}
          onChange={(event) => {
            setCategoryId(event.target.value);
            setSubcategoryId("");
          }}
          className="h-11 rounded-full border border-input bg-background px-4 text-sm"
        >
          <option value="">All categories</option>
          {categories.map((category) => (
            <option key={category.id} value={category.id}>{category.name}</option>
          ))}
        </select>
        <select
          value={validSubcategoryId}
          onChange={(event) => setSubcategoryId(event.target.value)}
          disabled={categorySubcategories.length === 0}
          className="h-11 rounded-full border border-input bg-background px-4 text-sm disabled:opacity-60"
        >
          <option value="">All subcategories</option>
          {categorySubcategories.map((subcategory) => (
            <option key={subcategory.id} value={subcategory.id}>{subcategory.name}</option>
          ))}
        </select>
        <select
          value={sort}
          onChange={(event) => setSort(event.target.value)}
          className="h-11 rounded-full border border-input bg-background px-4 text-sm"
        >
          <option value="newest">Newest</option>
          <option value="price_asc">Price: low to high</option>
          <option value="price_desc">Price: high to low</option>
          <option value="popular">Popular</option>
        </select>
        <select
          value={priceFilter}
          onChange={(event) => setPriceFilter(event.target.value)}
          className="h-11 rounded-full border border-input bg-background px-4 text-sm"
        >
          <option value="">Any price</option>
          <option value="under_200">Under R200</option>
          <option value="between_200_500">R200 - R500</option>
          <option value="over_500">Over R500</option>
        </select>
        <select
          value={availabilityFilter}
          onChange={(event) => setAvailabilityFilter(event.target.value)}
          className="h-11 rounded-full border border-input bg-background px-4 text-sm"
        >
          <option value="">All products</option>
          <option value="on_sale">On sale</option>
        </select>
        <div className="flex gap-3">
          <Button type="submit" className="h-11 flex-1 rounded-full md:flex-none">Apply</Button>
          <Button type="button" variant="outline" className="h-11 flex-1 rounded-full md:flex-none" onClick={clearFilters}>
            Clear
          </Button>
        </div>
      </form>
      {trendingTerms.length > 0 ? (
        <div className="mt-4 flex flex-wrap items-center gap-2 text-sm">
          <span className="text-muted-foreground">Trending:</span>
          {trendingTerms.map((term) => (
            <button
              key={term}
              type="button"
              onClick={() => {
                setQuery(term);
                applyFilters({ query: term });
              }}
              className="rounded-full border border-artisan-clay bg-background px-3 py-1 font-medium text-foreground transition hover:border-artisan-terracotta hover:text-artisan-terracotta"
            >
              {term}
            </button>
          ))}
        </div>
      ) : null}
    </div>
  );
}
