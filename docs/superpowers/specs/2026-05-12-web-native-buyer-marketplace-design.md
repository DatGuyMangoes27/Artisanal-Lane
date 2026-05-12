# Web-Native Buyer Marketplace Design

## Summary

This spec defines a web-native buyer marketplace inside the existing `landing/` Next.js application. The website should reach buyer-side parity with the Flutter app over phased releases while reusing the same Supabase database, storage buckets, Edge Functions, TradeSafe checkout flow, shipping integrations, chat, disputes, and review data.

The first product direction is full buyer parity, not a browse-only website. Buyers should eventually be able to discover products, manage cart and favourites, complete TradeSafe checkout, view orders, chat with sellers, raise disputes, submit reviews, manage saved addresses, and update account settings from the website.

## Goals

- Build buyer-side marketplace functionality in the existing Next.js `landing/` app instead of exposing Flutter Web.
- Keep public browsing SEO-friendly with server-rendered product, shop, and category pages where practical.
- Allow guest users to browse and build a cart, then require sign-in before payment.
- Reuse existing Supabase tables, RLS policies, storage buckets, RPCs, and Edge Functions.
- Preserve payment and stock safety by using `create-checkout` for order creation rather than inserting orders directly from the browser.
- Support the same buyer account capabilities as the app: orders, favourites, saved addresses, messages, disputes, reviews, profile/settings, help, and legal pages.
- Ship in phases so each major buyer area can be tested and released without waiting for the entire parity project to finish.

## Non-Goals

- Rebuilding the vendor dashboard in this buyer marketplace project.
- Replacing the existing admin dashboard.
- Rewriting TradeSafe, Courier Guy, Pargo, dispute, or escrow logic in Next.js.
- Building a Flutter Web wrapper.
- Adding a persistent notification history table in the first release.
- Changing the core checkout rule that the current backend supports one shop per checkout.

## Route Structure

### Public Marketplace

- `/shop` shows the main web marketplace landing, product discovery, categories, featured content, fresh arrivals, and curated collections.
- `/products/[id-or-slug]` shows SEO-friendly product detail pages with variants, images, stock state, shipping summaries, reviews, shop attribution, favourite action, and add-to-cart action.
- `/shops/[id-or-slug]` shows public shop profiles with shop details, products, market events where available, reviews, follow/favourite-style actions where applicable, and a message seller entry point.
- Search and category filtering can live under `/shop` query parameters at first, then move to dedicated routes such as `/shop/search` or `/shop/categories/[id]` if the URL structure needs cleaner SEO pages.

### Commerce

- `/cart` supports guest and signed-in carts, quantity updates, stock guard messaging, variant display, product removal, and checkout CTA.
- `/checkout` requires sign-in, syncs or validates the cart, captures shipping and gift options, searches pickup points or lockers, validates buyer contact details, and invokes `create-checkout`.
- `/payment/success` handles TradeSafe return success states and routes buyers to confirmation.
- `/payment/error` handles cancelled or failed TradeSafe returns and sends buyers back to cart or checkout with clear copy.
- `/cart/confirmation` can be retained as an internal confirmation route if it keeps parity with the app and existing deep-link expectations.

### Buyer Account

- `/account` shows buyer profile summary, order/favourite/cart counts, and navigation to account sections.
- `/account/orders` lists buyer orders.
- `/account/orders/[id]` shows order detail, items, seller contact entry points, tracking, status timeline, review prompts, dispute entry, and confirm receipt action.
- `/account/messages` lists buyer-seller chat threads.
- `/account/messages/[threadId]` shows realtime chat with attachments and read state.
- `/account/disputes` lists dispute-related orders or active disputes.
- `/account/disputes/[id]` shows dispute detail and conversation if a dedicated dispute route is cleaner than nesting under orders.
- `/account/settings` manages buyer settings and delete account.
- `/account/addresses` manages saved shipping addresses from `profiles.shipping_addresses`.
- `/account/favourites` shows saved products.
- `/account/help`, `/account/about`, `/account/about/terms`, and `/account/about/privacy` mirror buyer app support/legal content where needed.

## Architecture

### Application Boundary

All web-native buyer UI lives under `landing/`. The Flutter app remains the mobile client. Both clients use the same Supabase backend and should behave consistently because payment, stock, dispute, escrow, and checkout side effects stay in existing backend functions.

The current `landing/` stack already has:

- Next.js App Router.
- Supabase browser and server clients in `landing/src/lib/supabase/`.
- Server actions and service-role patterns for admin functionality.
- Tailwind and shadcn-style UI components.
- Artisan Lane brand tokens and typography in `landing/src/app/globals.css` and layout files.

Buyer web should add its own data modules and route groups rather than mixing buyer logic into admin modules.

### Supabase Access

Use the anon/user Supabase client for normal buyer reads and writes that RLS permits, such as favourites, cart rows, chat messages, profile reads, saved address updates, and review submission.

Use existing Edge Functions for trusted side effects:

- `create-checkout` for order creation, stock reservation, seller payout checks, TradeSafe transaction setup, and checkout URL creation.
- `release-escrow` for confirm receipt.
- `open-dispute` for buyer disputes.
- `get-courier-guy-lockers` and `get-pargo-pickup-points` for pickup searches.
- `delete-account` for account deletion.

Do not insert orders or decrement stock directly from browser code.

### Data Modules

Add buyer-specific web data helpers under `landing/src/lib/marketplace/` or `landing/src/lib/buyer/`. Suggested modules:

- `catalog.ts` for product, category, search, curated, and shop reads.
- `cart.ts` for guest cart mapping, authenticated cart reads/writes, and stock-safe cart helpers.
- `checkout.ts` for shipping snapshots, checkout validation, and `create-checkout` invocation.
- `account.ts` for profile, saved addresses, favourites, order summaries, and settings.
- `messages.ts` for buyer chat thread/message reads and writes.
- `disputes.ts` for dispute reads and `open-dispute` actions.
- `reviews.ts` for product/shop review reads and submission helpers.

These helpers should keep route components thin and make tests easier.

## Feature Parity

### Product Discovery

The web marketplace should include the buyer app discovery concepts:

- Home marketplace page with featured sections.
- Fresh arrivals using newly added non-sale products.
- Categories and subcategories.
- Search with recent search UX and trending terms where available.
- Product filters for category, subcategory, tags, sale/featured state, and sort.
- Curated collection content.
- Shop directory or shop discovery entry points.
- Public shop profile pages.

### Product Detail

Product pages should include:

- Image gallery.
- Variant selection.
- Price and sale price display.
- Stock state and stock guard.
- Product shipping option summary.
- Shop attribution and link.
- Reviews.
- Favourite action with sign-in prompt if needed.
- Add to cart with sign-in deferred until checkout.
- Share-friendly metadata and URLs.

### Cart

Cart should support guest browsing and authenticated persistence:

- Guest cart stored locally in the browser.
- Authenticated cart stored in Supabase `carts` and `cart_items`.
- Sign-in at payment should offer to sync local cart to the user cart.
- Cart count should sum quantities.
- Quantity changes should respect product and variant stock.
- Multi-shop cart constraints must be clear before checkout because the existing `create-checkout` function supports one shop per checkout.

### Checkout

Checkout should require a signed-in buyer before TradeSafe payment starts. It should:

- Validate buyer contact requirements.
- Collect shipping address only for true door-to-door delivery.
- Support Courier Guy door-to-door where the product/shop allows it.
- Support Courier Guy pickup locker search.
- Support Pargo pickup point search.
- Support market pickup with enough location/province detail.
- Support gift options and the existing gift service fee behavior.
- Call `create-checkout` and redirect the buyer to TradeSafe hosted checkout.
- Handle return URLs via `/payment/success` and `/payment/error`.
- Clear or refresh cart state after confirmed payment through existing backend behavior.

### Buyer Account

Buyer account pages should include:

- Profile dashboard with counts and shortcuts.
- Order history.
- Order detail with status, items, shipping/pickup summary, tracking, and seller messaging entry.
- Confirm receipt action using `release-escrow`.
- Review prompts and review submission for eligible products/shops.
- Saved addresses.
- Favourites.
- Settings, help, about, terms, privacy, and delete account.

### Messaging

Messaging should reuse buyer-vendor chat tables:

- Thread list under `/account/messages`.
- Thread detail under `/account/messages/[threadId]`.
- Realtime updates where practical.
- Attachment upload through the existing `chat-attachments` bucket.
- Read markers and unread counts.
- Product/shop message entry points should create or fetch buyer chat threads using the existing `get_or_create_buyer_chat_thread` RPC or equivalent server action.

### Disputes

Dispute support should include:

- Dispute list or disputed order list.
- Dispute detail and conversation.
- Evidence attachments using the existing dispute attachment bucket.
- `open-dispute` Edge Function for starting a dispute.
- Clear entry from eligible order detail pages.

### Reviews

Reviews should include:

- Product reviews on product pages.
- Shop reviews on shop pages.
- Review submission from eligible completed/delivered orders.
- Eligibility checks aligned with existing review RPCs and mobile app behavior.

### Notifications

The first web-native release should include in-app unread indicators for messages and account areas where data already exists. Browser push belongs in Phase 5 using the existing `user_push_tokens` model, which already supports platform `web`, but this should not block buyer marketplace parity.

## Implementation Phases

### Phase 1: Foundation And Public Marketplace

- Add buyer route groups and shared marketplace layout.
- Add Supabase-backed catalog helpers.
- Build `/shop`, product pages, shop pages, categories/search/filter UX, and guest cart foundation.
- Ensure public pages avoid leaking archived or unpublished products.

### Phase 2: Commerce

- Add auth prompts and sign-in handoff from checkout.
- Add authenticated cart sync.
- Build `/cart`, `/checkout`, TradeSafe redirect, and payment return routes.
- Reuse existing shipping and checkout rules from the mobile app and Edge Functions.

### Phase 3: Buyer Account

- Build account dashboard, saved addresses, favourites, order list, order detail, confirm receipt, and review submission.
- Keep account reads/writes RLS-safe and avoid service-role access except where existing functions require it.

### Phase 4: Messaging And Disputes

- Build buyer message inbox, chat thread, attachment upload, unread indicators, dispute list, dispute detail, and open dispute flow.
- Add realtime where it improves user experience and is stable in the browser.

### Phase 5: Polish And Parity Gaps

- Add richer notification support if required.
- Improve SEO metadata for product/shop pages.
- Add analytics parity for search, product view, add to cart, checkout, and purchase events.
- Review any remaining buyer app screens and close parity gaps.

## Risks And Decisions

- The current checkout backend supports one shop per checkout. The web cart must either prevent multi-shop checkout or split checkout by shop.
- Browser code must not create orders directly. `create-checkout` is the safe boundary.
- Some mobile flows use WebView or native deep links. Web checkout should use browser redirects and web return routes.
- The mobile notifications screen is mostly a placeholder. Web should not promise persistent notification history until a table or backend feed exists.
- Public product pages need careful filters for `is_published`, `archived_at`, shop active state, and variant visibility.
- If any environment still has permissive demo RLS policies, production web launch should review and tighten them before exposing broader browser workflows.
- Web push is optional for initial parity because messages and unread badges can work without it.

## Testing Strategy

- Unit test data mappers for products, variants, shipping options, pickup summaries, order statuses, reviews, and cart totals.
- Test route guards for guest browsing, protected account pages, and checkout sign-in requirement.
- Test cart behavior for guest cart, authenticated cart, quantity updates, stock limits, and multi-shop constraints.
- Test checkout handoff to `create-checkout` with mocked function results and payment return routes.
- Test account pages for order visibility, saved address updates, confirm receipt action, and review eligibility.
- Test messaging and dispute helpers with mocked Supabase responses and attachment validation.
- Add browser-level smoke tests for the critical path once the web routes exist: browse product, add to cart, sign in, checkout handoff, order confirmation.

## Implementation Notes

- The implementation plan should start with route and data helper scaffolding, not UI-only pages.
- The web buyer modules should not import admin-only service-role helpers except in explicit server actions that require trusted backend behavior.
- Shared copy and business rules should be copied from the Flutter utilities first, then extracted into small TypeScript helpers where needed.
- Each phase should be independently shippable and should not require the next phase to work.
