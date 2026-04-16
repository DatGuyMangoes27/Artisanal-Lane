# Vendor Payout Simplification And Product Gating Design

## Summary

This spec simplifies the vendor TradeSafe payout setup, replaces free-text bank entry with a supported-bank dropdown, derives as much data as possible from existing registration/profile records, and blocks new product listing until payout details are completed and confirmed by the vendor.

## Goals

- Remove payout form fields that are not needed for the current TradeSafe checkout integration.
- Replace the bank name text field with a dropdown driven by the app's existing TradeSafe-supported bank mapping.
- Reuse existing profile and vendor-application data wherever possible.
- Require payout setup completion before vendors can create new products.
- Replace review-process wording with a confirmation dialog that makes the vendor confirm the details are correct.

## Non-Goals

- Rebuilding the vendor payout data model from scratch.
- Blocking edits to existing products.
- Adding a manual admin review queue for payout details.

## UX Decisions

### Payout Form

Keep editable:
- `Account holder name`
- `Bank`
- `Account number`
- `Branch code`
- `Account type`
- `Phone number`

Derive from existing data:
- `Account holder name` defaults from the vendor profile display name.
- `Email address` comes from the registered profile email and is shown as derived rather than editable.
- `Phone number` defaults from the current profile phone when available.
- `Business name` can be shown as reference copy from the vendor application or shop, but is not required input for this payout form.

Remove from the form:
- `South African ID number`
- `Business registration number`
- free-text `Bank name`
- editable `Registered email address`

### Supported Dropdown Data

Use the same bank set already mapped in `supabase/functions/_shared/tradesafe.ts`:
- `ABSA`
- `African Bank`
- `Capitec`
- `Discovery Bank`
- `FNB`
- `Investec`
- `MTN`
- `Nedbank`
- `Postbank`
- `Sasfin`
- `Standard Bank`
- `TymeBank`
- `Other`

Use the currently supported TradeSafe account types:
- `Cheque`
- `Savings`
- `Transmission`
- `Bond`

### Completion Flow

- Saving payout details should first show a confirmation dialog.
- The dialog should tell the vendor to make sure every payout detail is correct because Artisan Lane will use them for payouts.
- Once confirmed and saved, the payout setup should be treated as complete immediately.
- Remove `submitted for review` wording from the UI.

### Product Listing Gate

Block new product creation until payout setup is complete:
- disable the add-product action on the vendor dashboard
- disable the add-product FAB on the vendor products screen
- disable the empty-state add-product button
- block the new-product route itself so direct navigation cannot bypass the requirement

When blocked, show a dialog or blocker state that explains payout details must be completed first and provide a direct action to open `Payout Details`.

## Implementation Notes

- Add a small payout-setup utility to centralize the supported bank list, supported account types, and payout-completion logic.
- Update the payout save flow to mark the profile complete immediately instead of using review language.
- Keep storing a vendor payout profile record, but stop collecting unneeded identity/business registration inputs in the app flow.
