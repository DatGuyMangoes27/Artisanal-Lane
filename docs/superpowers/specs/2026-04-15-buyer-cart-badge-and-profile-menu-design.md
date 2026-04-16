# Buyer Cart Badge And Profile Menu Design

## Summary

This spec adds a lightweight cart badge to the buyer bottom navigation and removes the unused `Payment Methods` entry from the buyer profile menu. The goal is to improve purchase-state visibility without changing cart flows or checkout behavior.

## Goals

- Show buyers that they already have items in their cart from anywhere in the buyer shell.
- Display a compact cart count badge only when the cart has items.
- Remove `Payment Methods` from the customer profile menu.

## Non-Goals

- Changing cart persistence or checkout logic.
- Removing the standalone payment methods route from the router.
- Reworking the buyer profile layout beyond removing that one row.

## UX Decisions

### Cart Badge

- The cart tab in the bottom navigation should show a badge when the cart count is greater than zero.
- The count should represent the total quantity across cart lines, not just the number of distinct products.
- Badge copy should cap at `9+` for larger totals.
- No badge should be shown when the cart is empty.

### Buyer Profile Menu

- Remove the `Payment Methods` item from the buyer profile menu.
- Leave the rest of the menu order unchanged.

## Implementation Notes

- Add a small reusable cart-nav icon widget or helper so the badge behavior can be tested directly.
- Make `BuyerShell` reactive to `cartItemsProvider`.
- Limit the profile change to `lib/features/buyer/screens/buyer_profile_screen.dart`.
