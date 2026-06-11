"use client";

import { useRef, useState } from "react";
import { Plus, Trash2, Wand2 } from "lucide-react";

import { Button } from "@/components/ui/button";
import type { VendorProductVariant } from "@/lib/marketplace/vendor-data";

const DEFAULT_OPTION_ONE_NAME = "Size";
const DEFAULT_OPTION_TWO_NAME = "Color";

type OptionGroup = {
  name: string;
  values: string[];
};

type VariantRow = {
  key: string;
  optionOne: string;
  optionTwo: string;
  price: string;
  compareAtPrice: string;
  stock: string;
  imagesText: string;
  isActive: boolean;
};

function parseInitialOptionGroups(raw: unknown[]): OptionGroup[] {
  return raw
    .map((entry) => {
      const record = entry != null && typeof entry === "object" ? (entry as Record<string, unknown>) : {};
      const values = Array.isArray(record.values) ? record.values.map(String) : [];
      return { name: String(record.name ?? "").trim(), values };
    })
    .filter((group) => group.name.length > 0);
}

function moneyText(value: number | null | undefined) {
  return value == null ? "" : String(value);
}

let rowCounter = 0;

function blankRow(): VariantRow {
  rowCounter += 1;
  return {
    key: `row-${rowCounter}`,
    optionOne: "",
    optionTwo: "",
    price: "",
    compareAtPrice: "",
    stock: "0",
    imagesText: "",
    isActive: true,
  };
}

function rowFromVariant(variant: VendorProductVariant, index: number): VariantRow {
  return {
    key: `initial-${index}`,
    optionOne: variant.optionValues[0] ?? variant.displayName,
    optionTwo: variant.optionValues[1] ?? "",
    price: moneyText(variant.price),
    compareAtPrice: moneyText(variant.compareAtPrice),
    stock: String(variant.stockQty),
    imagesText: variant.images.join("\n"),
    isActive: variant.isActive,
  };
}

/** Split comma/newline separated values, trimming and deduping case-insensitively. */
function parseOptionValues(raw: string): string[] {
  const seen = new Set<string>();
  const values: string[] = [];
  for (const piece of raw.split(/[\n,]/)) {
    const trimmed = piece.trim();
    const normalized = trimmed.toLowerCase();
    if (!trimmed || seen.has(normalized)) continue;
    seen.add(normalized);
    values.push(trimmed);
  }
  return values;
}

function comboKey(optionOne: string, optionTwo: string) {
  const second = optionTwo.trim().toLowerCase();
  const first = optionOne.trim().toLowerCase();
  return second ? `${first}|${second}` : first;
}

function isBlankRow(row: VariantRow) {
  return (
    !row.optionOne.trim() &&
    !row.optionTwo.trim() &&
    !row.price.trim() &&
    !row.compareAtPrice.trim() &&
    row.stock.trim() === "0" &&
    !row.imagesText.trim()
  );
}

function parsePrice(value: string): number | null {
  const trimmed = value.trim();
  if (!trimmed) return null;
  const parsed = Number(trimmed.replace(",", ".").replace(/[^0-9.-]/g, ""));
  return Number.isFinite(parsed) ? parsed : null;
}

/**
 * Mirrors the mobile app's normalizeProductPricingForSave: the lower amount
 * becomes the live price and the higher one the compare-at price.
 */
function normalizePricing(priceText: string, compareAtText: string) {
  const price = parsePrice(priceText) ?? 0;
  const compareAt = parsePrice(compareAtText);
  if (compareAt == null || compareAt === price) {
    return { price, compareAtPrice: null };
  }
  return {
    price: Math.min(price, compareAt),
    compareAtPrice: Math.max(price, compareAt),
  };
}

function parseImagesText(raw: string): string[] {
  return raw
    .split(/\n/)
    .map((line) => line.trim())
    .filter(Boolean);
}

function distinctValues(values: string[]): string[] {
  return [...new Set(values.map((value) => value.trim()).filter(Boolean))];
}

const inputClass = "rounded-2xl border border-artisan-clay px-4 py-3 text-sm text-foreground";
const fieldLabelClass = "grid gap-2 text-sm font-medium text-artisan-sienna";

export function VariantOptionsEditor({
  initialOptionGroups,
  initialVariants,
}: {
  initialOptionGroups: unknown[];
  initialVariants: VendorProductVariant[];
}) {
  const groups = parseInitialOptionGroups(initialOptionGroups);
  const containerRef = useRef<HTMLDivElement>(null);

  const [hasOptions, setHasOptions] = useState(groups.length > 0);
  const [optionOneName, setOptionOneName] = useState(groups[0]?.name ?? "");
  const [optionOneValuesText, setOptionOneValuesText] = useState(groups[0]?.values.join(", ") ?? "");
  const [optionTwoName, setOptionTwoName] = useState(groups[1]?.name ?? "");
  const [optionTwoValuesText, setOptionTwoValuesText] = useState(groups[1]?.values.join(", ") ?? "");
  const [rows, setRows] = useState<VariantRow[]>(() => {
    if (!initialVariants.length) return [];
    return [...initialVariants]
      .sort((a, b) => a.sortOrder - b.sortOrder)
      .map(rowFromVariant);
  });
  const [notice, setNotice] = useState<{ tone: "info" | "error"; text: string } | null>(null);

  const optionTwoEnabled = optionTwoName.trim().length > 0;

  function toggleOptions(enabled: boolean) {
    setNotice(null);
    setHasOptions(enabled);
    if (enabled) {
      if (!optionOneName.trim()) setOptionOneName(DEFAULT_OPTION_ONE_NAME);
      if (rows.length === 0) setRows([blankRow()]);
    } else {
      setOptionOneName("");
      setOptionOneValuesText("");
      setOptionTwoName("");
      setOptionTwoValuesText("");
      setRows([]);
    }
  }

  function readBaseFormValue(name: string): string {
    const form = containerRef.current?.closest("form");
    const field = form?.elements.namedItem(name);
    if (field instanceof HTMLInputElement) return field.value.trim();
    return "";
  }

  function updateRow(key: string, patch: Partial<VariantRow>) {
    setRows((current) => current.map((row) => (row.key === key ? { ...row, ...patch } : row)));
  }

  function addRow() {
    setNotice(null);
    setRows((current) => [...current, blankRow()]);
  }

  function removeRow(key: string) {
    if (rows.length <= 1) {
      setNotice({ tone: "error", text: "Keep at least one combination for this product." });
      return;
    }
    setNotice(null);
    setRows((current) => current.filter((row) => row.key !== key));
  }

  function generateCombinations() {
    const oneName = optionOneName.trim();
    const oneValues = parseOptionValues(optionOneValuesText);
    const twoName = optionTwoName.trim();
    const twoValues = parseOptionValues(optionTwoValuesText);

    if (!oneName) {
      setNotice({ tone: "error", text: "Add the first option name before generating combinations." });
      return;
    }
    if (oneValues.length === 0) {
      setNotice({ tone: "error", text: "Add at least one value for the first option." });
      return;
    }
    if (twoName && twoValues.length === 0) {
      setNotice({ tone: "error", text: "Add at least one value for the second option." });
      return;
    }

    const existingByKey = new Map<string, VariantRow>();
    for (const row of rows) {
      const key = comboKey(row.optionOne, row.optionTwo);
      if (!key || isBlankRow(row)) continue;
      existingByKey.set(key, row);
    }

    const seed = rows.find((row) => !isBlankRow(row));
    const seedPrice = seed?.price.trim() || readBaseFormValue("price");
    const seedCompareAt = seed?.compareAtPrice.trim() || readBaseFormValue("compareAtPrice");
    const seedStock = seed?.stock.trim() || "0";

    const newGeneratedRow = (optionOne: string, optionTwo: string): VariantRow => ({
      ...blankRow(),
      optionOne,
      optionTwo,
      price: seedPrice,
      compareAtPrice: seedCompareAt,
      stock: seedStock,
    });

    const generated: VariantRow[] = [];
    for (const oneValue of oneValues) {
      if (!twoName) {
        const key = comboKey(oneValue, "");
        const existing = existingByKey.get(key);
        if (existing) existingByKey.delete(key);
        generated.push(existing ?? newGeneratedRow(oneValue, ""));
        continue;
      }
      for (const twoValue of twoValues) {
        const key = comboKey(oneValue, twoValue);
        const existing = existingByKey.get(key);
        if (existing) existingByKey.delete(key);
        generated.push(existing ?? newGeneratedRow(oneValue, twoValue));
      }
    }

    const unmatched = [...existingByKey.values()];
    setRows([...generated, ...unmatched]);
    setNotice({
      tone: "info",
      text:
        unmatched.length > 0
          ? `Generated ${generated.length} combinations. Kept ${unmatched.length} unmatched existing row(s) below.`
          : `Generated ${generated.length} combinations.`,
    });
  }

  // Serialize current state into the same JSON the server action already consumes.
  let optionGroupsJson = "[]";
  let variantsJson = "[]";
  if (hasOptions) {
    const serializedGroups = [
      {
        name: optionOneName.trim() || DEFAULT_OPTION_ONE_NAME,
        values: distinctValues(rows.map((row) => row.optionOne)),
      },
      ...(optionTwoEnabled
        ? [{ name: optionTwoName.trim(), values: distinctValues(rows.map((row) => row.optionTwo)) }]
        : []),
    ];
    const serializedVariants = rows.map((row, index) => {
      const optionValues = [row.optionOne.trim(), ...(optionTwoEnabled ? [row.optionTwo.trim()] : [])];
      const pricing = normalizePricing(row.price, row.compareAtPrice);
      return {
        displayName: optionValues.join(" / "),
        optionValues,
        price: pricing.price,
        compareAtPrice: pricing.compareAtPrice,
        stockQty: Math.trunc(parsePrice(row.stock) ?? 0),
        images: parseImagesText(row.imagesText),
        isActive: row.isActive,
        sortOrder: index,
      };
    });
    optionGroupsJson = JSON.stringify(serializedGroups);
    variantsJson = JSON.stringify(serializedVariants);
  }

  return (
    <div ref={containerRef} className="grid gap-5">
      <input type="hidden" name="optionGroupsJson" value={optionGroupsJson} />
      <input type="hidden" name="variantsJson" value={variantsJson} />

      <label className="flex items-start gap-3 rounded-2xl border border-artisan-clay/70 p-4 text-sm font-medium text-artisan-sienna">
        <input
          type="checkbox"
          checked={hasOptions}
          onChange={(event) => toggleOptions(event.target.checked)}
          className="mt-0.5"
        />
        <span className="grid gap-1">
          This product has multiple options
          <span className="font-normal text-muted-foreground">
            {hasOptions
              ? "Set up sizes, colours or other combinations below."
              : "Off by default — turn on if this product comes in variations like size or colour."}
          </span>
        </span>
      </label>

      {hasOptions ? (
        <>
          <p className="text-sm text-muted-foreground">
            Most products only need Size and Color. You can rename these if your product needs something
            different. Enter values separated by commas or new lines, then generate the combinations below.
          </p>
          <div className="grid gap-4 lg:grid-cols-2">
            <label className={fieldLabelClass}>
              Primary option name
              <input
                value={optionOneName}
                onChange={(event) => setOptionOneName(event.target.value)}
                placeholder={DEFAULT_OPTION_ONE_NAME}
                required
                className={inputClass}
              />
            </label>
            <label className={fieldLabelClass}>
              Second option name (optional)
              <input
                value={optionTwoName}
                onChange={(event) => setOptionTwoName(event.target.value)}
                placeholder={DEFAULT_OPTION_TWO_NAME}
                className={inputClass}
              />
            </label>
            <label className={fieldLabelClass}>
              {optionOneName.trim() ? `${optionOneName.trim()} values` : "Option 1 values"}
              <textarea
                value={optionOneValuesText}
                onChange={(event) => setOptionOneValuesText(event.target.value)}
                placeholder="Small, Medium, Large"
                className={`min-h-20 ${inputClass}`}
              />
            </label>
            <label className={fieldLabelClass}>
              {optionTwoName.trim() ? `${optionTwoName.trim()} values` : "Option 2 values"}
              <textarea
                value={optionTwoValuesText}
                onChange={(event) => setOptionTwoValuesText(event.target.value)}
                placeholder="Black, Natural, Red"
                disabled={!optionTwoEnabled}
                className={`min-h-20 ${inputClass} disabled:bg-artisan-clay/10 disabled:text-muted-foreground`}
              />
            </label>
          </div>

          <div>
            <Button
              type="button"
              variant="outline"
              onClick={generateCombinations}
              className="rounded-full border-artisan-terracotta/45 text-artisan-terracotta hover:bg-artisan-terracotta/10 hover:text-artisan-terracotta"
            >
              <Wand2 className="size-4" />
              Generate combinations
            </Button>
          </div>

          {notice ? (
            <p
              className={`rounded-2xl border px-4 py-3 text-sm ${
                notice.tone === "error"
                  ? "border-red-200 bg-red-50 text-red-700"
                  : "border-artisan-clay/70 bg-artisan-clay/10 text-artisan-sienna"
              }`}
            >
              {notice.text}
            </p>
          ) : null}

          <div className="grid gap-4">
            {rows.map((row, index) => (
              <div key={row.key} className="grid gap-4 rounded-2xl border border-artisan-clay/70 p-4">
                <div className="flex items-center justify-between">
                  <h4 className="text-base font-semibold text-artisan-sienna">Combination {index + 1}</h4>
                  {rows.length > 1 ? (
                    <button
                      type="button"
                      onClick={() => removeRow(row.key)}
                      className="inline-flex items-center gap-1 text-sm font-medium text-red-600 hover:text-red-700"
                      aria-label={`Remove combination ${index + 1}`}
                    >
                      <Trash2 className="size-4" />
                      Remove
                    </button>
                  ) : null}
                </div>
                <div className="grid gap-4 lg:grid-cols-2">
                  <label className={fieldLabelClass}>
                    {optionOneName.trim() || "Option 1 value"}
                    <input
                      value={row.optionOne}
                      onChange={(event) => updateRow(row.key, { optionOne: event.target.value })}
                      placeholder="e.g. Small, Large, Terracotta"
                      required
                      className={inputClass}
                    />
                  </label>
                  {optionTwoEnabled ? (
                    <label className={fieldLabelClass}>
                      {optionTwoName.trim()}
                      <input
                        value={row.optionTwo}
                        onChange={(event) => updateRow(row.key, { optionTwo: event.target.value })}
                        placeholder="e.g. Red, Blue, Natural"
                        required
                        className={inputClass}
                      />
                    </label>
                  ) : null}
                  <label className={fieldLabelClass}>
                    Price
                    <input
                      value={row.price}
                      onChange={(event) => updateRow(row.key, { price: event.target.value })}
                      inputMode="decimal"
                      placeholder="What buyers pay"
                      required
                      className={inputClass}
                    />
                  </label>
                  <label className={fieldLabelClass}>
                    Compare-at price
                    <input
                      value={row.compareAtPrice}
                      onChange={(event) => updateRow(row.key, { compareAtPrice: event.target.value })}
                      inputMode="decimal"
                      placeholder="Optional original price"
                      className={inputClass}
                    />
                  </label>
                  <label className={fieldLabelClass}>
                    Stock quantity
                    <input
                      value={row.stock}
                      onChange={(event) => updateRow(row.key, { stock: event.target.value })}
                      inputMode="numeric"
                      required
                      className={inputClass}
                    />
                  </label>
                </div>
                <label className={fieldLabelClass}>
                  Combination image URLs
                  <textarea
                    value={row.imagesText}
                    onChange={(event) => updateRow(row.key, { imagesText: event.target.value })}
                    placeholder="One hosted image URL per line"
                    className={`min-h-20 ${inputClass}`}
                  />
                </label>
              </div>
            ))}
          </div>

          <div>
            <Button
              type="button"
              variant="ghost"
              onClick={addRow}
              className="rounded-full text-artisan-terracotta hover:bg-artisan-terracotta/10 hover:text-artisan-terracotta"
            >
              <Plus className="size-4" />
              Add another combination
            </Button>
          </div>
        </>
      ) : null}
    </div>
  );
}
