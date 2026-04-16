# Buyer Cart Badge And Profile Menu Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a cart count badge on the buyer bottom navigation and remove Payment Methods from the buyer profile menu.

**Architecture:** Add a small reusable widget or helper for the cart badge so the count behavior can be tested independently, then wire `BuyerShell` to the existing `cartItemsProvider`. Keep the profile change minimal by only removing the menu row from the existing screen.

**Tech Stack:** Flutter, Dart, Riverpod

---

## File Map

- Create: `lib/widgets/cart_nav_icon.dart`
- Modify: `lib/widgets/buyer_shell.dart`
- Modify: `lib/features/buyer/screens/buyer_profile_screen.dart`
- Modify: `test/widget_test.dart`

### Task 1: Cart Badge And Profile Menu Cleanup

**Files:**
- Create: `lib/widgets/cart_nav_icon.dart`
- Modify: `lib/widgets/buyer_shell.dart`
- Modify: `lib/features/buyer/screens/buyer_profile_screen.dart`
- Modify: `test/widget_test.dart`

- [ ] **Step 1: Write failing tests**

Add tests that expect:
- cart badge count sums cart item quantities
- the cart nav icon shows the badge text when the count is above zero
- the buyer profile screen no longer shows `Payment Methods`

- [ ] **Step 2: Run tests to verify red**

Run: `flutter test test/widget_test.dart`

Expected: FAIL because the cart badge widget/helper does not exist yet and the profile screen still renders `Payment Methods`.

- [ ] **Step 3: Add cart badge widget and wire buyer shell**

Create the reusable cart-nav icon, make `BuyerShell` watch `cartItemsProvider`, and pass the summed count into the cart tab icon.

- [ ] **Step 4: Remove the profile menu item**

Delete the `Payment Methods` row from `BuyerProfileScreen` while leaving the rest of the menu unchanged.

- [ ] **Step 5: Run tests to verify green**

Run: `flutter test test/widget_test.dart`

Expected: PASS for the new badge behavior and profile menu expectations.

- [ ] **Step 6: Verify with static analysis**

Run: `flutter analyze lib/widgets/buyer_shell.dart lib/features/buyer/screens/buyer_profile_screen.dart lib/widgets/cart_nav_icon.dart`

Expected: no issues found in the updated files.
