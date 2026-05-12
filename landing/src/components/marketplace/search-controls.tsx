"use client";

import { useRouter, useSearchParams } from "next/navigation";
import { FormEvent, useState } from "react";

import { Button } from "@/components/ui/button";
import type { MarketplaceCategorySummary } from "@/lib/marketplace/types";

export function SearchControls({ categories }: { categories: MarketplaceCategorySummary[] }) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [query, setQuery] = useState(searchParams.get("q") ?? "");
  const [categoryId, setCategoryId] = useState(searchParams.get("category") ?? "");
  const [sort, setSort] = useState(searchParams.get("sort") ?? "newest");

  function onSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const params = new URLSearchParams();
    if (query.trim()) params.set("q", query.trim());
    if (categoryId) params.set("category", categoryId);
    if (sort !== "newest") params.set("sort", sort);
    router.push(`/shop${params.size ? `?${params.toString()}` : ""}`);
  }

  return (
    <form id="search" onSubmit={onSubmit} className="grid gap-3 rounded-3xl border border-artisan-clay bg-card p-4 shadow-sm md:grid-cols-[1fr_220px_180px_auto]">
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
      </select>
      <Button type="submit" className="h-11 rounded-full">Search</Button>
    </form>
  );
}
