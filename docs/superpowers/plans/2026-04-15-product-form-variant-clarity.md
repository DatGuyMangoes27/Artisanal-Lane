# Product Form Variant Clarity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the vendor product form easier to understand by defaulting option names to Size and Color and relabeling pricing inputs with dynamic Price or Original Price behavior plus an explicit Sale Price field.

**Architecture:** Keep the existing product payload and variant generation logic intact, but improve the Flutter form copy and controller defaults so new products open with clearer starting values. Add a small pure helper for product-form copy and dynamic label logic so the behavior can be covered with unit tests, then wire the screen to that helper and validate with static analysis.

**Tech Stack:** Flutter, Dart, Riverpod

---

## File Map

- Create: `lib/features/vendor/utils/product_form_copy.dart`
- Modify: `lib/features/vendor/screens/product_form_screen.dart`
- Modify: `test/widget_test.dart`

### Task 1: Default Variant Labels And Pricing Copy

**Files:**
- Create: `lib/features/vendor/utils/product_form_copy.dart`
- Modify: `lib/features/vendor/screens/product_form_screen.dart`
- Modify: `test/widget_test.dart`

- [ ] **Step 1: Write failing tests for copy and label behavior**

Add tests that expect:
- default option names are `Size` and `Color`
- the current price label stays `Price (R)` without a sale price
- the current price label becomes `Original Price (R)` when a sale price exists
- helper copy explains that sellers can rename the default option labels

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/widget_test.dart`

Expected: FAIL because the new product-form helper does not exist yet.

- [ ] **Step 3: Add helper support and wire the form**

Set the new-product option name controllers to `Size` and `Color` during initialization so sellers start with the common setup instead of blank option names.

Create a helper file that owns the default option names, helper copy, and dynamic current-price label logic. Update the product form screen to use those helpers for the section copy, visible headings, and original-price wording.

- [ ] **Step 4: Refresh helper copy and placeholders**

Update the product options helper text and value hints so the section explicitly guides sellers toward size and color while keeping the fields editable.

- [ ] **Step 5: Add visible pricing headings**

Show explicit headings above both the fallback pricing row and the per-variant pricing row to make `Price` and `Sale Price` easier to distinguish.

- [ ] **Step 6: Replace compare-at wording**

Rename remaining `Compare at` labels and hints in this screen to `Sale Price` and `Original Price` where appropriate.

- [ ] **Step 7: Run tests to verify green**

Run: `flutter test test/widget_test.dart`

Expected: PASS for the product-form helper expectations and existing tests.

- [ ] **Step 8: Verify with static analysis**

Run: `flutter analyze lib/features/vendor/screens/product_form_screen.dart`

Expected: no errors in the updated form screen.
