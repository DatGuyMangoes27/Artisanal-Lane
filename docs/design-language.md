# Artisan Lane design language (1.0)

The approved creator-commerce demo (`lib/concepts/creator_commerce/creator_commerce_mockup_app.dart`)
and the redesigned Feed, Discover, Shop and You tabs are the reference. Every screen
should feel like the same warm, editorial, craft-focused app. Use existing tokens in
`lib/app/theme.dart`; don't add new colours.

## Foundations

- **Surfaces:** page background `AppTheme.scaffoldBg`; cards `AppTheme.cardBg` with a
  1px `AppTheme.sand` border (≈30–50% alpha), radius 20–22, and at most a soft shadow
  (black ≈5%, blur 15, y 5). No Material grey cards, no heavy elevation.
- **Type:** Playfair Display for page titles, section headings, product/maker names and
  prices on hero surfaces; Poppins for everything else. Body 13–15px, labels ≥12px.
  Never below 12px.
- **Colour roles:** burgundy `terracotta` = primary actions and active states; `ochre` =
  highlights/badges sparingly; `baobab` = success; `error` = destructive only. Text uses
  `textPrimary` / `textSecondary` / `textHint`.
- **Icons:** Material *outlined/rounded* variants, 20–24px, in `textPrimary` or `terracotta`.

## Structure

- **Page header:** eyebrow (Poppins 11px, w800, letter-spacing 1.3, terracotta, UPPERCASE)
  + Playfair title (25–30px) + optional one-line subtitle — see
  `lib/features/buyer/widgets/creator_commerce_header.dart`. Pushed detail pages use a
  clean app bar on `scaffoldBg`: back arrow, Playfair title, ≤2 actions.
- **Sections:** Playfair 20–22px heading with an optional "See all" text action; 16–20px
  horizontal padding; 24–32px between sections.
- **Lists:** rows ≥56px, icon in a soft rounded square (bone/cardBg), title + optional
  subtitle, trailing chevron. Group related rows in one rounded card.
- **Primary action:** pill button (height 48–52, radius 26+) in terracotta, white Poppins
  w600 label. Important screens (checkout, forms) put it in a **sticky bottom bar**
  inside SafeArea. Secondary: outlined pill (terracotta border/label).
- **Chips/filters:** rounded pills; selected = filled tint, unselected = outline.
- **Status:** small rounded pills using the existing `statusX` colours at low alpha with
  the strong colour for text.
- **Sheets:** `showModalBottomSheet(useRootNavigator: true, showDragHandle: true)`,
  top radius 24, for choices, filters, confirmations and short forms instead of full pages
  or AlertDialogs. Destructive confirmations: sheet with red primary + outlined cancel.

## Behaviour

- **Loading:** `Skeleton`/`SkeletonBox` (`lib/widgets/skeleton.dart`) shaped like the
  content — not bare spinners (a small inline spinner inside a button is fine).
- **Errors:** `ErrorRetryView` / `friendlyErrorMessage` (`lib/core/ui/friendly_error.dart`).
  Never show exception text.
- **Empty states:** icon, Playfair one-liner, one helpful sentence, one action.
- **Feedback:** optimistic updates for reversible actions; floating SnackBars with plain
  copy (and Undo where possible); `HapticFeedback.lightImpact()` on likes/saves/swipes,
  `mediumImpact()` on successful completion.
- **Money:** browsing prices via `formatBrowsePrice`; totals, fees and payouts keep two
  decimals (`R1 234.50`).
- **Targets & text:** tap targets ≥44×44; support text scaling; no overflow at 320px width.
- **Copy:** plain, warm, second person. No internal terms (provider names, "sync",
  "pilot", "retry safely", ids).
