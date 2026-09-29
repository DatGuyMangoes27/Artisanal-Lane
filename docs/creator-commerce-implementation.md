# Creator commerce implementation

## Consistent Shop layouts (2026-09-22)

- Replaced variable-height image cards with one reusable product tile. Image
  sizes, two-line title slots and prices align within each layout.
- Added Rows, Two cards and One card selectors without changing search/filter
  results. Simplified browsing shortcuts and softened filter/price typography.
- Six focused tests pass, including all layout switches and equal photo/price
  alignment for short versus long names. Scoped analysis is clean.
- Rebuilt and installed on A142P. Visually verified two-column layout in
  `docs/creator-commerce-preview/device-validation/09-shop-consistent-grid.png`.
- Remaining on-device layout interaction stopped when the phone showed a
  system screen. The incidental system capture was discarded; no private media
  was opened. Rows and One card are widget-tested, not device-visually verified.

## Shop redesign review (2026-09-22)

Directly redesigned the internal Shop with a real-product editorial panel,
compact filters, editable/clearable search, result counts, recoverable empty
states, lighter product cards, maker labels and accurate decimal/sale pricing.
Discover preferences still drive For you; All pieces retains catalogue access.
Five focused tests pass, including the editorial product route at 320px width.
Scoped analysis passed; final debug APK built and installed on A142P.
Personally inspected the loaded Shop and scrolled product grid captures:
`device-validation/07-shop-redesign-loaded.png` and `device-validation/08-shop-grid.png`
under `docs/creator-commerce-preview/`.
This does not complete 24-hour Stories, social engagement or real AI generation.

The approved Flutter showcase is the design reference. Implementation proceeds
inside the existing app, retaining marketplace, checkout, order, messaging,
subscription and artisan operations. The integrated build uses
`--dart-define=CREATOR_COMMERCE_ENABLED=true`. The earlier
`CREATOR_COMMERCE_PREVIEW` flag remains a separate historical showcase.

## Journeys

- Buyer: Feed or Discover → maker/shop or product → existing cart and checkout.
- Saved finds: You → Saved finds → product.
- Artisan: You → Artisan workspace → Products → add/edit a listing → photo
  preparation and listing details → review → existing save/publish controls.
- Publishing: Artisan workspace → My posts → create/edit → real shop feed.
- Business operations: existing orders, earnings, subscription and messages.

## Implementation and remaining work

The first integration connects a real paginated photo feed and follows, swipe
discovery with preferences saved per account on the device, marketplace
navigation, and photo tools within product creation. These are app features,
not the separate demo screens.

Release work still required:

- Post likes, comments, moderation/reporting, tagged products and richer media
  require schema and service extensions. The current checked-in `shop_posts`
  schema has captions, media URLs and publication status only.
- Review deployed follow/post policies before social release. Historical
  migrations contain permissive demo policies; source inspection alone does
  not establish which policies are currently deployed.
- Sync discovery preferences across devices and reuse ranking in Feed/Shop.
- Integrate real AI listing/image assistance within the product form, with
  server credentials, usage controls and user review. Previously shared test
  credentials were never installed; the old showcase is not a live AI service.
- Complete device acceptance for buyer, artisan and guest accounts, including
  upload failure/retry, account switching and checkout regression.

No website or production database deployment is part of this local integration.

## Validation (2026-09-22)

- Existing `test/widget_test.dart`: 93 passed with the default feature flag.
- Integrated navigation and preference unit tests: 3 passed with the new flag.
- Discover gesture, product route and 320x568 layout tests: 3 passed.
- Focused analysis of router, shells, profile, feed and artisan forms: clean.
- Focused Discover analysis: clean. Total tests run: 99 passed.
- Debug APK built successfully with the integrated flag, saved separately as
  `docs/creator-commerce-preview/builds/artisan-lane-integrated-20260922.apk`.
- Historical note: at this point no Android device was attached; subsequent
  device-validation evidence below supersedes that access limitation.
- Android build reports upcoming Flutter compatibility warnings for the existing
  Gradle, Android Gradle Plugin and Kotlin versions. Toolchain upgrades are not
  bundled into these feature changes.

## Device validation (2026-09-22, later session)

- A142P connected and authorized. Existing integrated APK installed successfully
  with `adb install -r`; preview app data retained.
- Package `com.artisanallane.artisanal_lane.preview`, version 1.2.6-preview (25),
  launched successfully with a cold-start result of `Status: ok`.
- Live maker feed loaded published content from shops.
- Discover loaded 100 real catalogue items. A right swipe changed the displayed
  product from Flamingo Confession to Garden of Unspoken Gold (99 remaining).
  This intentionally recorded one device-local preference, not a public like.
- Tapping the next card opened its matching product title and R1780 price.
- Buyer profile opened. No artisan workspace entry was visible for that account.
- This was an earlier sign-in observation. It is superseded by the later
  approved private vendor access recorded below; no passwords were requested
  in chat.
- No orders, payments, new follows, favourites or published content were created.
- Basket and complete end-to-end account flows remain unverified.
- Accessibility-tree checks establish loaded content/navigation, not comprehensive
  visual approval. Screenshot captured at
  `docs/creator-commerce-preview/device-validation/01-launch.png`.

## Device validation (2026-09-22, approved vendor pass)

- Reconnected to the authorized A142P (`00088148Q000727`) and confirmed the
  installed preview package is `com.artisanallane.artisanal_lane.preview`
  version `1.2.6-preview` (25).
- The approved private vendor account reached its dashboard as `Vendor 4 Test
  Shop` (`vendor4@mail.com`): zero products, orders and revenue. The dashboard
  visibly reports an inactive subscription and incomplete TradeSafe payout
  details.
- Products is reachable and shows the zero-product state with Add Product. One
  safe Add Product tap was blocked before the editor by the subscription dialog:
  it requires starting the free two months / R349 monthly artisan subscription
  before listing or receiving new buyer checkouts. The dialog was dismissed with
  Later; no subscription, payout setup, product, editor field, gallery picker or
  publish action was touched.
- Profile exposes Shop Posts. Its management route is reachable and correctly
  shows No Posts Yet; no create/edit controls were invoked. Orders is reachable
  and shows No orders. Earnings is reachable, shows R0 totals, and repeats the
  TradeSafe payout-details gate.
- The earlier buyer pass remains the buyer-navigation evidence (loaded feed,
  discover swipe and matching product route). This vendor pass did not switch
  roles or mutate data.
- Acceptance evidence is limited to accessibility-tree navigation/content; it
  is not a visual, gallery/upload, payment, payout, subscription, publishing or
  end-to-end order approval. The precise current blocker for product editing is
  the intentionally enforced inactive-subscription eligibility gate; payout
  completion is a separate prerequisite displayed on the dashboard and earnings
  route.

## Internal product-editor device test mode (2026-09-22)

- The private device-validation account may open the new-product editor only
  when the internal `CREATOR_COMMERCE_ENABLED` build flag is present. This is a
  local UI test seam, not a subscription, payout, checkout or backend override.
- Test mode is explicit in the editor. Publish, save and delete controls are
  disabled, and the save handler returns before any upload or persistence work.
  Local photo selection, crop and enlarged inspection can therefore be tested
  without creating a product or uploading media.
- Device proof: the flagged debug APK was installed over the private preview on
  A142P. From You → Artisan workspace → Products → Add Product, the vendor
  reached New Product despite inactive subscription/payout status and saw the
  explicit local-only test-mode notice. The footer showed Publish disabled and
  the non-saving control label; no photo picker or form control was used.
- Follow-up photo-source check used only the bundled `assets/preview/foldaway-
  tote.jpg`, copied to `/sdcard/Download/artisanal-lane-test-fixture.jpg`.
  The editor's Camera/Gallery chooser and Android picker opened. The picker did
  not expose a Download collection target, so selection, crop and enlarged
  inspection were intentionally stopped rather than browsing private recents.
  No media was opened, selected, uploaded or saved; the copied fixture remains
  on-device for a later explicit Download-picker path test.
- Final buyer navigation check: the buyer Shop tab loaded its searchable
  category and curated-listing surface. The Cart tab loaded the empty-basket
  state and Start Shopping action. No listing was opened, basket changed,
  checkout entered or order created.

## Real Stories vertical slice — 2026-09-22

- Replaced the mistaken maker-profile shortcut strip with actual story groups.
- Photo/video composer: local preview, caption, 50 MB cap, 60-second video
  validation, camera/gallery selection, explicit private-shop visibility notice.
- Viewer: previous/next, timed progression, hold/pause, background pause,
  account-change dismissal, expiry dismissal, and confirmed owner deletion.
- Private media uses authenticated downloads instead of permanent public URLs.
  Temporary downloaded video is removed when its viewer is disposed.
- New tables `shop_stories` and `shop_story_views` enforce ownership and
  server-stamped 24-hour expiry. View receipts are account-private. Inactive or
  offline shop stories are visible only to the owner, including the test shop.
- User explicitly approved deploying after checks. Migration
  `20260922210020_creator_stories.sql` deployed to `byckurabenbunsbrzcpl`.
  The local CLI-generated file was aligned to the actual remote migration version.
  Live verification: both tables have RLS, eight policies, private 50 MB bucket,
  anonymous read query succeeds with zero stories. No test media was uploaded.
- Supabase/Postgres guidance drove owner-scoped RLS, explicit grants, indexes,
  and local adversarial tests; the tests caught and corrected a recursive policy.
- Validation: 17 isolated PostgreSQL policy assertions; 3 story model tests;
  2 story-widget tests; 6 existing connected Shop tests; focused analysis clean;
  Android debug APK successfully built with `CREATOR_COMMERCE_ENABLED=true`.
- ADB lists no device. This build is NOT installed; no physical camera/gallery
  upload or native video playback has been verified for Stories yet.
- Release gaps: expired storage-object retention cleanup; feed pagination beyond
  the first 200 active stories; moderation/reporting; upload quotas and retry
  reconciliation; real device/network interruptions. Keep this an internal pilot.
- Wider app work remains: likes/comments/product-tagged posts, connected artisan
  creation workflows, secure real AI service with spend limits, and release QA.
- Existing unrelated Supabase security advisories remain. No advisory finding
  names the new story tables/function. This was not a full-project security audit.

## Connected Feed interactions — 2026-09-22

- Real like/unlike, persisted comment creation/edit/deletion and cursor-paged
  conversations. Guests can read but must sign in to interact. Failed comment
  submissions retain their text and reuse an idempotency UUID when retried.
- Comment author names/time are stamped server-side; clients can update only
  the body. Makers can delete comments on their posts but cannot rewrite them.
- Artisan post editor can search and tag up to five published products from its
  own shop. Tags save atomically with caption/media. Feed product links open the
  actual existing product route; unpublished/deleted products are not displayed.
- A single Feed Create menu connects to Product, Post and 24-hour Story flows.
- Live inspection confirmed legacy permissive demo post/follow policies. Added
  seven restrictive ownership/read guards, preserving the existing admin helper.
  This is a material security correction guided by the Supabase/Postgres skills.
- Explicit user approval received for this separate backend deployment.
  Migration `20260922213619_creator_post_interactions.sql` applied to
  `byckurabenbunsbrzcpl`; local filename aligned with remote migration history.
- Verified live: both new tables have RLS, seven restrictive guards exist,
  product_ids exists, guest engagement RPC returns a visible post summary.
  No user post, follow, like or comment data was created/deleted during validation.
- 29 isolated PostgreSQL checks pass against intentionally permissive legacy
  fixtures. 17 Flutter regressions pass (six new social/creation/keyboard tests,
  five Stories tests and six Shop tests). Focused analysis is clean. Debug Android
  build succeeds. No new Feed-related security advisor findings; pre-existing
  unrelated advisories remain outside this scoped audit.
- Phone remains disconnected from ADB: APK is built, NOT installed. No actual
  camera/gallery, cross-device social or native video acceptance is claimed.
- Remaining: real AI service and integrated artisan AI workflow; social reporting,
  moderation tooling/rate limits; Stories retention cleanup and scale work;
  actual device acceptance and public-release QA. These are not production-complete.

## Device acceptance and approved AI deployment — 2026-09-25

- Connected A142P detected; the 23 September creator-commerce APK was installed
  with replacement only (no app data cleared). vendor4 session was retained.
- Actual phone checks: live Feed content, all four main destinations, real Shop
  catalogue and row layout, touch-swipe Discover advancement, Feed Create menu,
  product-editor entry, native cropper with bundled sample, photo handoff into
  listing assistance and fullscreen original inspection.
- Pricing: R60 materials + R30 labour + R10 overheads at 35% gross margin yields
  R153.85; explicit Use this price returns to the existing product draft.
- User separately approved deploying AI while keeping paid generation disabled.
  Applied artisan_ai_requests; remote version 20260925083131 is aligned locally.
  Deployed artisan-ai v1 with verify_jwt=true; explicitly set ARTISAN_AI_ENABLED
  false and allowlisted only vendor4. No OpenAI credential was accessed/configured.
- Live database verification: RLS enabled, private result bucket, authenticated
  callers cannot invoke the reservation RPC, zero request records. The phone
  successfully read disabled capabilities. No new AI-related security advisories;
  unrelated pre-existing project warnings remain.
- Corrected Stories retries: immutable UUID and media path; check existing row
  before upload, tolerate only duplicate-object upload responses, insert-ignore
  duplicate IDs and verify persisted fields. Caption/media remain frozen after
  an uncertain response. This does not yet persist drafts across app restarts.
- Added a bundled upload-test photo action only for the exact private test
  account AND an inactive, offline shop, for actual upload tests without browsing
  personal gallery content. No public shop sees this action.
- Checks: 19 Stories PostgreSQL assertions (including retry expiry preservation),
  20 AI PostgreSQL assertions, 9 mocked AI-provider tests, 23 focused Flutter
  tests. Focused Stories analysis clean. Native camera/gallery and video capture,
  real AI generation, moderation/retention and broader release QA still pending.

## Embedded artisan listing assistant — 2026-09-23

- Added Make it listing-ready inside the actual product form, behind the existing
  creator-commerce feature flag. Words, Photos and Pricing share one editor flow.
- Words: confirmed facts, explicit provider consent, editable title/description
  suggestions and apply-before-save. Photos: gallery/local original, three shop
  styles, original/result enlargement with pinch zoom, explicit append to listing.
  Originals are not overwritten. No fake generated content substitutes for an
  unavailable service. Pricing is an offline cost/gross-margin calculator.
- Server implementation uses verified Auth and service-only own-shop reservation,
  strict output parsing, image byte limits, private output storage, rolling
  per-user/global quotas and same-ID replay protection. OpenAI/Supabase guidance
  informed these contracts and security guards. No client-side provider key.
- Migration 20260922223031_artisan_ai_requests.sql and artisan-ai function are
  LOCAL ONLY, not deployed. Paid generation remains disabled. No new key was
  configured, old exposed key was not reused, and no paid calls were made.
- Validation: 20 isolated PostgreSQL assertions, 9 injected-provider tests,
  19 focused Flutter tests (AI plus Feed/Stories/Shop), clean focused analysis,
  successful internal Android debug build. Provider tests are mocked, not real
  model/image-quality proof. Build has existing Gradle/Kotlin upgrade warnings.
- ADB still reports no connected device. Latest APK is built but NOT installed.
- Follow docs/artisan-ai-pilot.md for approval/configuration and acceptance gates.
  Durable AI recovery across app restart, result retention, live provider/device
  tests, social moderation/retention and public-release QA remain outstanding.

### Final phone verification — 2026-09-25

- Rebuilt and installed the corrected internal APK. Actual private-shop photo
  upload created story cb1a8ded-275e-411d-8cd3-280c1fa7c8cd with exactly 24 hours
  between server-created and expiry timestamps. Owner playback/download worked,
  pause worked, a seen receipt persisted, and anonymous read returned zero rows.
- Fixed phone-discovered issues: 30-second creation-time clock-skew tolerance
  (expiry still enforced), root-level fullscreen story viewer, light system bars
  and readable Next/Previous controls. Nested-navigation and skew regression
  tests were added. Final screenshot: .codex/story-fullscreen-20260925.png.
- Deleted only that newly created QA story via its in-app confirmation. Verified
  story row and storage object both absent. No other user's content was changed.
- Paid AI remains explicitly disabled; live AI request ledger still empty.
  Do not describe this as real AI generation or camera/gallery/video proof.
- Remaining release gates: secure fresh provider key plus approved model/cost
  configuration and real generation tests, durable drafts, media retention,
  moderation/reporting, native camera/gallery/video and cross-device acceptance.
  Public website and public mobile release were not deployed in this pass.
