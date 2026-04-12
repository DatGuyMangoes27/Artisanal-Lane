# Vendor UX And TradeSafe Payout Design

## Summary

This spec covers the next phase of vendor-facing UX and escrow readiness improvements for Artisan Lane. It removes the repetitive post-approval experience, adds warmer welcome messaging, surfaces Artisan Lane stationery payment details inside the app, and introduces in-app artisan payout onboarding that feeds the existing TradeSafe escrow lifecycle.

The admin-facing operational work for payout readiness and intervention belongs in the website admin at `landing/src/app/admin`, not in the Flutter app.

## Goals

- Show the vendor approval success experience once instead of on every return.
- Refresh buyer and vendor home experiences with simple welcome messaging.
- Add clear stationery payment instructions inside the vendor app.
- Capture artisan payout details inside the Artisan Lane app.
- Connect payout readiness to the existing TradeSafe-based escrow flow.
- Give the website admin visibility into payout onboarding state and payout blockers.

## Non-Goals

- Vendor subscriptions or subscription billing.
- Rebuilding the existing TradeSafe checkout and escrow release flow from scratch.
- A full finance back-office or reconciliation suite.
- Proof-of-payment upload for stationery requests in this phase.

## Current State

### What Already Exists

- Buyer checkout is already created through a TradeSafe-backed edge function.
- Orders already store TradeSafe transaction and allocation identifiers.
- TradeSafe callback handling already updates order and escrow state.
- Escrow release already calls the TradeSafe allocation acceptance flow.
- The website admin already handles approvals, disputes, stationery updates, and other operations.

### Current Gaps

- The approved vendor state currently behaves like a persistent entry point instead of a one-time milestone.
- Vendor dashboard greeting still uses generic `Hello, Maker` copy.
- Buyer home does not have a lightweight welcome-back cue.
- Stationery requests do not show Artisan Lane bank account details in the app.
- Artisan payout details are not clearly captured in the app.
- Payout readiness is not surfaced clearly to artisans or admins.

## User Experience Design

### 1. Vendor Approval Flow

The approval celebration screen remains part of the experience, but it becomes a one-time transition screen instead of a recurring gate.

#### Intended Behavior

1. Vendor application is approved.
2. Artisan sees the approval success screen once.
3. After the first continuation, the artisan is routed into vendor onboarding and then the normal vendor dashboard.
4. On later visits, the artisan returns directly to the vendor area instead of re-seeing the approval success state.

#### Follow-On Checklist

The vendor area should present a short readiness checklist until the required steps are complete:

- `Payout details`
- `Shop details`
- `Stationery information`

The checklist should disappear or collapse into a completed state once all required steps are finished.

### 2. Welcome Messaging

#### Vendor Side

Replace the current vendor greeting with:

- `Welcome back, Artisan`

This should appear on the vendor dashboard header in place of the current generic wording.

#### Buyer Side

Add a light-touch greeting near the top of the buyer home experience:

- `Welcome back`

This should remain visually secondary to search, discovery, and featured content.

### 3. Stationery Payment Details

Inside the vendor stationery screen, add a payment details panel that clearly explains how stationery requests are paid for.

#### Content

- `Artisan Lane`
- `Standard Bank`
- `Account number: 10271380908`
- `Swift: SBZA ZA JJ`
- `Electronic payment code: 051001`

#### Supporting Copy

Use clear wording that communicates:

- stationery requests are processed once payment reflects
- the artisan should use a recognizable payment reference
- fulfilment updates will appear in the stationery request timeline

This phase should use an informational bank-details card and request-status messaging. It should not introduce proof-of-payment uploads yet.

## TradeSafe Payout Onboarding

### Core Principle

Artisans enter payout details inside the Artisan Lane app. Artisan Lane then uses those details in backend-controlled flows that support TradeSafe-linked payout readiness. The artisan should not need to leave the app to complete basic payout onboarding.

### Vendor Payout Details Screen

Add a dedicated `Payout details` screen in the vendor app.

#### Fields

- Account holder name
- Bank name
- Account number
- Branch code
- Account type
- Registered phone number
- Registered email address
- South African ID number or business registration number, depending on the seller type supported by TradeSafe onboarding requirements

#### Statuses

The payout profile should have an explicit lifecycle:

- `not_started`
- `submitted`
- `under_review`
- `verified`
- `action_required`

These statuses should drive messaging in the vendor dashboard, earnings screen, and admin website.

### Vendor Messaging

The vendor app should explain the payout lifecycle clearly:

1. Buyer pays through TradeSafe.
2. Funds move into escrow.
3. Artisan fulfils the order.
4. Buyer confirms receipt or the release window completes.
5. TradeSafe release completes.
6. Funds can only pay out cleanly when the artisan payout profile is verified.

#### Dashboard Banner

If payout details are incomplete or not verified, show a banner with status-specific wording:

- `Payout details required before payouts can be completed.`
- `Your payout details have been submitted and are under review.`
- `Action required: update your payout details to continue receiving payouts.`
- `TradeSafe payouts are active.`

#### Access Rule

For this phase, artisans may enter the vendor area before payout verification is complete, but payout readiness must be clearly visible. Product publishing may optionally be restricted later, but this spec does not require that gate.

## Admin Website Design

All admin operational visibility for payout readiness belongs on the website admin, not in the Flutter app.

### Required Admin Visibility

The website admin should show, at minimum:

- payout onboarding status for each artisan
- whether payout details are missing
- whether verification is pending
- whether an order payout is blocked by missing or invalid vendor payout setup

### Website Admin Placement

The existing admin website already handles approvals, disputes, and stationery operations. Payout readiness should extend those existing patterns instead of creating a separate admin product.

Recommended integration points:

- vendor application approval workflow
- orders and disputes views
- dashboard summary cards or status badges

## Data Model Design

### New Vendor Payout Profile

Add a dedicated payout profile record instead of mixing sensitive payout fields into the general profile.

Suggested responsibilities:

- store bank and payout onboarding data
- track payout verification state
- store TradeSafe-linked payout identifiers if required
- record last submission and last status update times

### Data Handling Rules

- Sensitive payout fields must only be writable through privileged backend paths.
- Raw bank details must not be broadly exposed in client reads.
- Account numbers should be masked in UI after save.
- Vendor app reads should return only the fields needed to render state and masked values.
- Admin website views should prefer masked values unless full access is operationally necessary.

## Backend Flow Design

### Existing TradeSafe Flows To Preserve

- `create-checkout` remains the buyer checkout entry point.
- `tradesafe-callback` remains the source for payment-state updates.
- `release-escrow` remains the release path after buyer confirmation or admin action.

### New Payout Readiness Flow

1. Vendor submits payout details in the app.
2. Backend validates and stores the payout profile.
3. Backend marks the profile `submitted` or `under_review`.
4. When verification completes, payout profile becomes `verified`.
5. Website admin can see the status and intervene if the profile is blocked.
6. Vendor earnings and payout messaging use the payout profile status to explain whether released escrow can move through the expected payout path.

## Content Updates

Update wording across the product so it matches the new flow:

- vendor dashboard
- buyer home
- vendor earnings
- buyer help and legal screens where escrow is explained
- any vendor onboarding copy that still implies approval alone is enough for a fully payout-ready account

## Rollout Order

Implement in this order:

1. One-time vendor approval flow
2. Vendor welcome copy update
3. Buyer welcome copy update
4. Stationery bank-details panel
5. Vendor payout-details screen
6. Payout readiness banners and earnings messaging
7. Website admin payout status visibility
8. Copy cleanup across help and legal surfaces

## Testing Strategy

### Flutter App

- Verify approval success is shown once and not on every return.
- Verify vendor dashboard shows the new greeting.
- Verify buyer home shows the welcome-back treatment without disrupting discovery content.
- Verify stationery screen displays bank details correctly.
- Verify payout details form validation and submission states.
- Verify payout status banners render correctly for every payout-profile state.

### Supabase / Backend

- Verify payout profile writes go through privileged paths only.
- Verify masked payout values are returned to client reads.
- Verify existing TradeSafe checkout, callback, dispute, refund, and release flows still function after the payout-profile addition.

### Website Admin

- Verify payout readiness badges appear in the website admin.
- Verify admins can identify vendors blocked on payout setup.
- Verify order and dispute views can surface payout blockers when relevant.

## Risks

- TradeSafe onboarding requirements may require fields or verification rules beyond the current assumptions.
- Sensitive payout data must be carefully separated from normal profile reads.
- If payout status is unclear, artisans may assume released escrow means immediate bank settlement, so wording must stay precise.

## Recommendation

Proceed with the UX cleanup and in-app payout onboarding as one coordinated scope. This solves the most visible vendor confusion while building on the TradeSafe escrow foundation that already exists, and it keeps operational oversight where it belongs: the website admin.
