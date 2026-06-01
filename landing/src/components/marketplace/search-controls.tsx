"use client";

import { useRouter, useSearchParams } from "next/navigation";
import { FormEvent, useState } from "react";

import { Button } from "@/components/ui/button";
import type { MarketplaceCategorySummary } from "@/lib/marketplace/types";

export function SearchControls({
  categories,
  trendingTerms = [],
}: {
  categories: MarketplaceCategorySummary[];
  trendingTerms?: string[];
}) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [query, setQuery] = useState(searchParams.get("q") ?? "");
  const [categoryId, setCategoryId] = useState(searchParams.get("category") ?? "");
  const [sort, setSort] = useState(searchParams.get("sort") ?? "newest");
  const [priceFilter, setPriceFilter] = useState(searchParams.get("price") ?? "");
  const [availabilityFilter, setAvailabilityFilter] = useState(searchParams.get("availability") ?? "");

  function applyFilters(overrides: Partial<{
    query: string;
    categoryId: string;
    sort: string;
    priceFilter: string;
    availabilityFilter: string;
  }> = {}) {
    const nextQuery = overrides.query ?? query;
    const nextCategoryId = overrides.categoryId ?? categoryId;
    const nextSort = overrides.sort ?? sort;
    const nextPriceFilter = overrides.priceFilter ?? priceFilter;
    const nextAvailabilityFilter = overrides.availabilityFilter ?? availabilityFilter;
    const params = new URLSearchParams();
    if (nextQuery.trim()) params.set("q", nextQuery.trim());
    if (nextCategoryId) params.set("category", nextCategoryId);
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
    setSort("newest");
    setPriceFilter("");
    setAvailabilityFilter("");
    router.push("/shop");
  }

  return (
    <div id="search" className="rounded-3xl border border-artisan-clay bg-card p-4 shadow-sm">
      <form onSubmit={onSubmit} className="grid gap-3 md:grid-cols-[1fr_180px_160px_160px_150px_auto_auto]">
        <input
          value={query}
          onChange={(event) => setQuery(event.target.value)}
          placeholder="Search handmade products"
          className="h-11 rounded-full border border-input bg-background px-4 text-sm outline-none focus:ring-2 focus:ring-ring/30"
        />
        <select
          value={categoryId}
          onChange={(event) => setCategoryId(event.target.value)}
          className="h-11 rounded-full border border-input bg-background px-4 text-sm"
        >
          <option value="">All categories</option>
          {categories.map((category) => (
            <option key={category.id} value={category.id}>{category.name}</option>
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
        <Button type="submit" className="h-11 rounded-full">Apply</Button>
        <Button type="button" variant="outline" className="h-11 rounded-full" onClick={clearFilters}>
          Clear
        </Button>
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
