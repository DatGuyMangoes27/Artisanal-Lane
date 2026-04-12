# Vendor UX And TradeSafe Payouts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the approved vendor UX cleanup, in-app payout onboarding, and website-admin payout visibility without rebuilding the existing TradeSafe checkout flow.

**Architecture:** Add a dedicated vendor payout profile table plus a small approval-dismissal field on `profiles`, expose those records through focused Flutter providers and Supabase service methods, and extend the website admin data layer to surface payout readiness on dashboard and orders views. Keep TradeSafe checkout/release flows intact and use payout profile status as the readiness layer around them.

**Tech Stack:** Flutter, Riverpod, Supabase Postgres, Supabase Edge Functions, Next.js website admin

---

## File Map

- Modify: `supabase/migrations/014_add_tradesafe_payment_support.sql`
- Create: `supabase/migrations/026_add_vendor_payout_profiles.sql`
- Create: `lib/models/vendor_payout_profile.dart`
- Modify: `lib/models/models.dart`
- Modify: `lib/models/profile.dart`
- Modify: `lib/services/supabase_service.dart`
- Modify: `lib/features/vendor/providers/vendor_providers.dart`
- Create: `lib/features/vendor/screens/vendor_payout_details_screen.dart`
- Modify: `lib/app/router.dart`
- Modify: `lib/features/vendor/screens/vendor_onboarding_screen.dart`
- Modify: `lib/features/vendor/screens/vendor_dashboard_screen.dart`
- Modify: `lib/features/vendor/screens/vendor_profile_screen.dart`
- Modify: `lib/features/vendor/screens/vendor_stationery_requests_screen.dart`
- Modify: `lib/features/vendor/screens/vendor_earnings_screen.dart`
- Modify: `lib/features/buyer/screens/buyer_home_screen.dart`
- Modify: `landing/src/lib/admin-data.ts`
- Modify: `landing/src/components/admin/admin-ui.tsx`
- Modify: `landing/src/app/admin/(protected)/page.tsx`
- Modify: `landing/src/app/admin/(protected)/orders/page.tsx`
- Test: `test/widget_test.dart`

### Task 1: Schema And Data Models

**Files:**
- Create: `supabase/migrations/026_add_vendor_payout_profiles.sql`
- Modify: `lib/models/profile.dart`
- Create: `lib/models/vendor_payout_profile.dart`
- Modify: `lib/models/models.dart`

- [ ] **Step 1: Write failing model tests**

Add tests that expect:
- a `Profile` can read an approval-dismissal timestamp
- a `VendorPayoutProfile` can parse status and return a masked account label

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget_test.dart`
Expected: FAIL because the new model types and fields do not exist yet.

- [ ] **Step 3: Add schema and model support**

Create a migration that:
- adds `vendor_approved_seen_at` to `profiles`
- creates `vendor_payout_profiles`
- enables RLS
- allows vendors to select and upsert only their own payout row
- allows service-role/admin flows to manage verification fields

Add Dart model support for the new fields and payout profile shape.

- [ ] **Step 4: Run tests to verify model support compiles**

Run: `flutter test test/widget_test.dart`
Expected: PASS for the new model expectations or fail later on the next missing integration.

### Task 2: Flutter Payout Flow And One-Time Approval

**Files:**
- Modify: `lib/services/supabase_service.dart`
- Modify: `lib/features/vendor/providers/vendor_providers.dart`
- Create: `lib/features/vendor/screens/vendor_payout_details_screen.dart`
- Modify: `lib/app/router.dart`
- Modify: `lib/features/vendor/screens/vendor_onboarding_screen.dart`
- Modify: `lib/features/vendor/screens/vendor_dashboard_screen.dart`
- Modify: `lib/features/vendor/screens/vendor_profile_screen.dart`
- Modify: `lib/features/vendor/screens/vendor_earnings_screen.dart`

- [ ] **Step 1: Write failing widget expectations**

Add widget expectations that look for:
- `Welcome back, Artisan`
- `Welcome back`
- payout status wording such as `Payout details required before payouts can be completed.`

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget_test.dart`
Expected: FAIL because the new copy and payout UI are not present yet.

- [ ] **Step 3: Implement minimal Flutter flow**

Implement:
- provider/service methods to fetch and save payout profiles
- a `VendorPayoutDetailsScreen`
- a route at `/vendor/profile/payouts`
- onboarding logic that shows the approved celebration once, then uses the dismissal field
- dashboard and earnings banners driven by payout status
- profile navigation entry for payout details

- [ ] **Step 4: Run tests to verify it passes**

Run: `flutter test test/widget_test.dart`
Expected: PASS for the new vendor/buyer/payout copy assertions.

### Task 3: Stationery And Welcome Copy

**Files:**
- Modify: `lib/features/vendor/screens/vendor_stationery_requests_screen.dart`
- Modify: `lib/features/buyer/screens/buyer_home_screen.dart`

- [ ] **Step 1: Add failing expectation for stationery payment copy**

Assert that the stationery screen includes:
- `Standard Bank`
- `Account number: 10271380908`

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget_test.dart`
Expected: FAIL because the stationery payment panel does not exist yet.

- [ ] **Step 3: Implement the copy updates**

Add:
- a stationery payment-details card with the approved bank details
- supporting text about payment reflection and reference usage
- the buyer home welcome-back treatment

- [ ] **Step 4: Run tests to verify it passes**

Run: `flutter test test/widget_test.dart`
Expected: PASS for the stationery and welcome-copy expectations.

### Task 4: Website Admin Visibility

**Files:**
- Modify: `landing/src/lib/admin-data.ts`
- Modify: `landing/src/components/admin/admin-ui.tsx`
- Modify: `landing/src/app/admin/(protected)/page.tsx`
- Modify: `landing/src/app/admin/(protected)/orders/page.tsx`

- [ ] **Step 1: Add failing admin rendering expectation**

Add a small render-safe helper or typed mapping that expects payout readiness values like:
- `verified`
- `under_review`
- `action_required`

- [ ] **Step 2: Run relevant verification**

Run: `npm run lint`
Working directory: `landing`
Expected: FAIL or report missing types/usage before the new admin payout fields exist.

- [ ] **Step 3: Implement admin payout visibility**

Extend admin data loading so order and vendor/shop rows include payout status, then surface:
- payout status badges on dashboard cards or lists
- payout status and payout blocker messaging on orders table

- [ ] **Step 4: Run verification**

Run: `npm run lint`
Working directory: `landing`
Expected: PASS with no lint errors from the admin changes.

### Task 5: Final Verification

**Files:**
- Modify: `test/widget_test.dart`

- [ ] **Step 1: Run Flutter verification**

Run: `flutter test`
Expected: PASS

- [ ] **Step 2: Run website admin verification**

Run: `npm run lint`
Working directory: `landing`
Expected: PASS

- [ ] **Step 3: Spot-check requirements coverage**

Verify the diff includes:
- one-time vendor approval behavior
- `Welcome back, Artisan`
- buyer `Welcome back`
- stationery bank details
- payout details screen
- payout banners
- website-admin payout visibility
