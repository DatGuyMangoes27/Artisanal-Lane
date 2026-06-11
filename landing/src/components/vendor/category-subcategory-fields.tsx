"use client";

import { useState } from "react";

import type { VendorCategory, VendorSubcategory } from "@/lib/marketplace/vendor-data";

// Mirrors the mobile product form: the subcategory dropdown only appears once a
// category is chosen, lists only that category's subcategories, and resets
// whenever the category changes.
export function CategorySubcategoryFields({
  categories,
  subcategories,
  defaultCategoryId,
  defaultSubcategoryId,
}: {
  categories: VendorCategory[];
  subcategories: VendorSubcategory[];
  defaultCategoryId?: string | null;
  defaultSubcategoryId?: string | null;
}) {
  const [categoryId, setCategoryId] = useState(defaultCategoryId ?? "");
  const [subcategoryId, setSubcategoryId] = useState(defaultSubcategoryId ?? "");

  const categorySubcategories = categoryId
    ? subcategories.filter((subcategory) => subcategory.categoryId === categoryId)
    : [];
  const validSubcategoryId = categorySubcategories.some(
    (subcategory) => subcategory.id === subcategoryId,
  )
    ? subcategoryId
    : "";

  return (
    <>
      <label className="grid gap-2 text-sm font-medium text-artisan-sienna">
        Category
        <select
          name="categoryId"
          value={categoryId}
          onChange={(event) => {
            setCategoryId(event.target.value);
            setSubcategoryId("");
          }}
          className="rounded-2xl border border-artisan-clay px-4 py-3 text-sm"
        >
          <option value="">Select category</option>
          {categories.map((category) => (
            <option key={category.id} value={category.id}>{category.name}</option>
          ))}
        </select>
      </label>
      {categoryId ? (
        <label className="grid gap-2 text-sm font-medium text-artisan-sienna">
          Subcategory
          {categorySubcategories.length > 0 ? (
            <select
              name="subcategoryId"
              value={validSubcategoryId}
              onChange={(event) => setSubcategoryId(event.target.value)}
              className="rounded-2xl border border-artisan-clay px-4 py-3 text-sm"
            >
              <option value="">Select subcategory</option>
              {categorySubcategories.map((subcategory) => (
                <option key={subcategory.id} value={subcategory.id}>{subcategory.name}</option>
              ))}
            </select>
          ) : (
            <p className="px-1 py-3 text-sm font-normal text-muted-foreground">
              No subcategories available
            </p>
          )}
        </label>
      ) : null}
    </>
  );
}
