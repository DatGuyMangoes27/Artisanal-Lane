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
}: {
  categories: MarketplaceCategorySummary[];
  subcategories?: MarketplaceSubcategorySummary[];
}) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [query, setQuery] = useState(searchParams.get("q") ?? "");
  const [categoryId, setCategoryId] = useState(searchParams.get("category") ?? "");
  const [subcategoryId, setSubcategoryId] = useState(searchParams.get("subcategory") ?? "");
  const [sort, setSort] = useState(searchParams.get("sort") ?? "rotation");
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
    if (nextSort !== "rotation") params.set("sort", nextSort);
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
    setSort("rotation");
    setPriceFilter("");
    setAvailabilityFilter("");
    router.push("/shop");
  }

  return (
    <div id="search" className="overflow-hidden rounded-[1.75rem] border border-[#DFC9B5] bg-white shadow-[0_18px_55px_rgba(58,23,17,0.07)]">
      <div className="flex flex-col justify-between gap-2 border-b border-[#EADACC] bg-[linear-gradient(90deg,#FAF0E5_0%,#FFF9F2_55%,#F3F4E9_100%)] px-5 py-5 sm:flex-row sm:items-end sm:px-7">
        <div><p className="text-[9px] font-bold uppercase tracking-[0.22em] text-[#A6432B]">Find your piece</p><h2 className="mt-1 font-serif text-2xl font-bold text-[#351711]">Refine the collection</h2></div>
        <p className="text-xs text-[#8B6C59]">Search, filter and sort without losing your place.</p>
      </div>
      <form onSubmit={onSubmit} className="grid gap-4 p-5 sm:grid-cols-2 sm:p-7 lg:grid-cols-12">
        <label className="grid gap-1.5 sm:col-span-2 lg:col-span-4">
          <span className="text-[10px] font-bold uppercase tracking-[0.16em] text-[#806756]">Search</span>
          <input
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder="Search handmade products"
            className="h-12 min-w-0 rounded-xl border border-[#DFC9B5] bg-[#FFF9F2] px-4 text-sm outline-none transition focus:border-artisan-terracotta focus:ring-4 focus:ring-artisan-terracotta/10"
          />
        </label>
        <label className="grid gap-1.5 lg:col-span-2">
          <span className="text-[10px] font-bold uppercase tracking-[0.16em] text-[#806756]">Category</span>
          <select
            value={categoryId}
            onChange={(event) => {
              setCategoryId(event.target.value);
              setSubcategoryId("");
            }}
            className="h-12 rounded-xl border border-[#DFC9B5] bg-[#FFF9F2] px-3 text-sm outline-none focus:border-artisan-terracotta"
          >
            <option value="">All categories</option>
            {categories.map((category) => (
              <option key={category.id} value={category.id}>{category.name}</option>
            ))}
          </select>
        </label>
        <label className="grid gap-1.5 lg:col-span-2">
          <span className="text-[10px] font-bold uppercase tracking-[0.16em] text-[#806756]">Subcategory</span>
          <select
            value={validSubcategoryId}
            onChange={(event) => setSubcategoryId(event.target.value)}
            disabled={categorySubcategories.length === 0}
            className="h-12 rounded-xl border border-[#DFC9B5] bg-[#FFF9F2] px-3 text-sm outline-none focus:border-artisan-terracotta disabled:cursor-not-allowed disabled:opacity-50"
          >
            <option value="">All subcategories</option>
            {categorySubcategories.map((subcategory) => (
              <option key={subcategory.id} value={subcategory.id}>{subcategory.name}</option>
            ))}
          </select>
        </label>
        <label className="grid gap-1.5 lg:col-span-2">
          <span className="text-[10px] font-bold uppercase tracking-[0.16em] text-[#806756]">Price</span>
          <select value={priceFilter} onChange={(event) => setPriceFilter(event.target.value)} className="h-12 rounded-xl border border-[#DFC9B5] bg-[#FFF9F2] px-3 text-sm outline-none focus:border-artisan-terracotta">
            <option value="">Any price</option><option value="under_200">Under R200</option><option value="between_200_500">R200 - R500</option><option value="over_500">Over R500</option>
          </select>
        </label>
        <label className="grid gap-1.5 lg:col-span-2">
          <span className="text-[10px] font-bold uppercase tracking-[0.16em] text-[#806756]">Availability</span>
          <select value={availabilityFilter} onChange={(event) => setAvailabilityFilter(event.target.value)} className="h-12 rounded-xl border border-[#DFC9B5] bg-[#FFF9F2] px-3 text-sm outline-none focus:border-artisan-terracotta">
            <option value="">All products</option><option value="on_sale">On sale</option>
          </select>
        </label>
        <label className="grid gap-1.5 lg:col-span-2">
          <span className="text-[10px] font-bold uppercase tracking-[0.16em] text-[#806756]">Sort by</span>
          <select value={sort} onChange={(event) => setSort(event.target.value)} className="h-12 rounded-xl border border-[#DFC9B5] bg-[#FFF9F2] px-3 text-sm outline-none focus:border-artisan-terracotta">
            <option value="rotation">Fresh mix (rotates)</option><option value="newest">Newest</option><option value="price_asc">Price: low to high</option><option value="price_desc">Price: high to low</option><option value="popular">Popular</option>
          </select>
        </label>
        <div className="flex items-end gap-3 sm:col-span-2 lg:col-span-4">
          <Button type="submit" className="h-12 flex-1 rounded-full bg-gradient-to-r from-[#7A0000] via-[#9A2C12] to-[#8B4513] px-7 text-white hover:brightness-95">Show results</Button>
          <Button type="button" variant="ghost" className="h-12 rounded-full px-5 text-[#60483B]" onClick={clearFilters}>Clear</Button>
        </div>
      </form>
      {categorySubcategories.length > 0 ? (
        <div className="flex flex-wrap items-center gap-2 border-t border-artisan-clay/60 px-5 py-4 text-sm sm:px-7">
          <span className="mr-1 font-semibold text-[#351711]">Browse subcategories:</span>
          <button
            type="button"
            onClick={() => {
              setSubcategoryId("");
              applyFilters({ subcategoryId: "" });
            }}
            className={`rounded-full border px-3 py-1.5 font-medium transition ${validSubcategoryId === "" ? "border-artisan-terracotta bg-artisan-terracotta text-white" : "border-artisan-clay bg-background hover:border-artisan-terracotta hover:text-artisan-terracotta"}`}
          >
            All
          </button>
          {categorySubcategories.map((subcategory) => (
            <button
              key={subcategory.id}
              type="button"
              onClick={() => {
                setSubcategoryId(subcategory.id);
                applyFilters({ subcategoryId: subcategory.id });
              }}
              className={`rounded-full border px-3 py-1.5 font-medium transition ${validSubcategoryId === subcategory.id ? "border-artisan-terracotta bg-artisan-terracotta text-white" : "border-artisan-clay bg-background text-foreground hover:border-artisan-terracotta hover:text-artisan-terracotta"}`}
            >
              {subcategory.name}
            </button>
          ))}
        </div>
      ) : null}
    </div>
  );
}
