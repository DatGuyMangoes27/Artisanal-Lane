# Website Launch Countdown Design

## Summary

This spec adds a compact launch countdown card to the public `WelcomeScreen` so visitors immediately see that Artisan Lane is launching on South Africa's Freedom Day, April 27. The goal is to create urgency and visibility without turning the full welcome experience into a temporary campaign page.

## Goals

- Show a clear launch message on the public entry screen.
- Count down live to April 27 using a lightweight, self-updating UI.
- Keep the existing welcome layout and sign-in actions intact.
- Avoid showing a broken or negative countdown on launch day.

## Non-Goals

- Redesigning the full welcome page.
- Adding backend configuration for launch timing.
- Deciding the permanent post-launch state beyond a safe same-day fallback.
- Changing routing, auth flows, or buyer browsing behavior.

## UX Decisions

### Placement

- Insert the countdown card below the marketplace subtitle and above the decorative divider.
- Keep the current logo, headline, CTA buttons, and guest browse link in their existing order.

### Launch Messaging

- Primary copy should read `Launching on Freedom Day`.
- Secondary copy should show `27 April`.
- Supporting copy may briefly reinforce that the marketplace is almost open.

### Countdown Behavior

- Display the remaining time as days, hours, minutes, and seconds.
- Update the countdown live while the screen is visible.
- On April 27, replace the numeric countdown with `Launching today`.
- Do not define the post-April-27 message yet; that can be decided separately closer to launch.

## Implementation Notes

- Limit the code change to `lib/features/auth/screens/welcome_screen.dart` unless extracting a tiny helper improves clarity.
- Convert `WelcomeScreen` from `StatelessWidget` to `StatefulWidget` so it can manage a periodic timer.
- Use a local timer-based countdown with proper cleanup in `dispose()`.
- Target April 27 in local device time and clamp the display state so negative values are never rendered.
- Keep styling aligned with the existing `AppTheme` and typography already used on the page.
