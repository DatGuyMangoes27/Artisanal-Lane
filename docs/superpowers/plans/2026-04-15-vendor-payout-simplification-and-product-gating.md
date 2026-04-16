# Vendor Payout Simplification And Product Gating Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Simplify the vendor payout setup, use a supported bank dropdown, reuse existing registration data, and prevent new product listing until payout details are completed.

**Architecture:** Add a focused vendor payout setup utility for supported banks, supported account types, and completion logic. Rework the Flutter payout form to use derived profile/application data plus a save-confirmation dialog, then reuse the same completion helper to gate product-creation actions and the new-product screen.

**Tech Stack:** Flutter, Dart, Riverpod, Supabase

---

## File Map

- Create: `lib/features/vendor/utils/vendor_payout_setup.dart`
- Modify: `lib/features/vendor/screens/vendor_payout_details_screen.dart`
- Modify: `lib/features/vendor/screens/vendor_products_screen.dart`
- Modify: `lib/features/vendor/screens/vendor_dashboard_screen.dart`
- Modify: `lib/features/vendor/screens/product_form_screen.dart`
- Modify: `lib/services/supabase_service.dart`
- Modify: `lib/features/vendor/utils/vendor_onboarding_flow.dart`
- Modify: `test/widget_test.dart`

### Task 1: Payout Setup Simplification And Product Gate

**Files:**
- Create: `lib/features/vendor/utils/vendor_payout_setup.dart`
- Modify: `lib/features/vendor/screens/vendor_payout_details_screen.dart`
- Modify: `lib/features/vendor/screens/vendor_products_screen.dart`
- Modify: `lib/features/vendor/screens/vendor_dashboard_screen.dart`
- Modify: `lib/features/vendor/screens/product_form_screen.dart`
- Modify: `lib/services/supabase_service.dart`
- Modify: `lib/features/vendor/utils/vendor_onboarding_flow.dart`
- Modify: `test/widget_test.dart`

- [ ] **Step 1: Write failing tests**

Add tests that expect:
- the supported TradeSafe bank dropdown options match the app's mapped bank set
- the supported account type list matches the mapped TradeSafe account types
- payout setup counts as complete only when the required payout fields are present

- [ ] **Step 2: Run tests to verify red**

Run: `flutter test test/widget_test.dart`

Expected: FAIL because the new payout-setup utility does not exist yet.

- [ ] **Step 3: Add payout setup utility**

Create the new utility with:
- supported bank labels
- supported account type values and labels
- payout completion helper logic used by the payout form and product gate

- [ ] **Step 4: Simplify payout form**

Update the payout screen to:
- remove ID number, business registration number, and editable email fields
- replace bank name text entry with a dropdown
- replace account type values with the supported mapped account types
- prefill data from the profile and payout record
- save after a confirmation dialog instead of review wording

- [ ] **Step 5: Sync required profile data**

When payout details are saved:
- persist the payout record with only the needed fields
- update the vendor profile phone when the payout form phone changes
- mark the payout setup complete immediately

- [ ] **Step 6: Gate product creation**

Use the shared payout completion helper to:
- disable add-product entry points on the dashboard and products screen
- show a payout-required dialog that links to the payout details screen
- block the new-product form when payout setup is incomplete

- [ ] **Step 7: Refresh completion copy**

Update payout banner and status text so the app no longer mentions review/submission and instead reflects incomplete vs complete setup.

- [ ] **Step 8: Run tests to verify green**

Run: `flutter test test/widget_test.dart`

Expected: PASS for the new payout-setup helper expectations and existing tests.

- [ ] **Step 9: Verify with static analysis**

Run: `flutter analyze lib/features/vendor/screens/vendor_payout_details_screen.dart lib/features/vendor/screens/vendor_products_screen.dart lib/features/vendor/screens/vendor_dashboard_screen.dart lib/features/vendor/screens/product_form_screen.dart lib/features/vendor/utils/vendor_payout_setup.dart`

Expected: no issues found in the updated files.
