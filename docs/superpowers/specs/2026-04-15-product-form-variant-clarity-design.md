# Product Form Variant Clarity Design

## Summary

This spec simplifies the vendor product creation experience by steering sellers toward the most common option setup instead of starting from a fully blank variant model. The form should feel easier to understand without removing the ability to adapt when a product genuinely needs different option labels.

## Goals

- Reduce confusion when sellers create product combinations.
- Default the first two option groups to `Size` and `Color`.
- Keep option names editable so uncommon products still work.
- Add clearer pricing field headings in the product form.
- Replace `Compare at` wording with clearer `Sale Price` / `Original Price` labels in this form.

## Non-Goals

- Changing the product data model or variant payload structure.
- Restricting saved products to only `Size` and `Color`.
- Reworking buyer-side product option rendering.

## UX Decisions

### Product Options

- New products should start with `Size` in option field one and `Color` in option field two.
- Existing products should continue to load and preserve their saved option group names.
- Helper copy above the option section should explain that most products only need size and color, while still allowing edits.
- Value placeholders should reinforce common examples like `Small, Medium, Large` and `Black, Natural, Red`.

### Pricing Labels

- The second optional price field should be labeled `Sale Price (R)`.
- The main current-price field should be dynamic:
  when no sale price is entered, show `Price (R)`;
  when a sale price is entered, show `Original Price (R)`.
- The shared product-level pricing row should use this dynamic label behavior.
- Variant cards should also use the same dynamic pricing labels above the two pricing inputs.
- Any remaining `Compare at` wording inside this screen should be removed.

## Implementation Notes

- Limit the code change to `lib/features/vendor/screens/product_form_screen.dart`.
- Use controller defaults for new products rather than hard-coding labels only in hints.
- Avoid touching persistence logic because the existing payload shape already supports the clarified UI copy.
