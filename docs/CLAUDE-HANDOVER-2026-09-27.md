# Artisan Lane — handover to Claude

Prepared 27 September 2026. Work in `C:\Users\st3ph\Artisanal-Lane` (Windows/PowerShell).

## Start here

Stephen wants the approved creator-commerce Android demo turned into a cohesive, working production app, retaining the existing marketplace. The last major request was “get it release ready”. **It is not release ready yet.** Do not confuse a passing build or isolated tests with live security, payment or device acceptance.

Read `docs/mobile-release-readiness.md` first, then `docs/creator-commerce-implementation.md` and `docs/artisan-ai-pilot.md`. Older implementation notes describe historical checkpoints, not guaranteed current deployment. This handover records work verified on 25 September; on 27 September only local checklist, flags and dirty Git status were refreshed. Live backend, phone and tests have not been rechecked today.

## User intent and working style

- Match the approved demo's visual language. Feed is the primary screen; Shop must feel like part of the same app, not a separate app.
- Integrated Feed / Discover / Shop / account journeys. The maker strip means **24-hour Stories**, not a static maker directory.
- Real products and real interactions: follow makers, likes, comments, tagged products, photo/video content and genuine swipe gestures in Discover.
- Shop needs consistent product cards, lighter price styling and row / two-column / single-card views.
- AI assistance belongs inside artisan product creation/editing: titles, descriptions, pricing guidance and curated product-image preparation. Original and generated images should enlarge for inspection.
- No placeholder-only interactions or disconnected showcase screens passed off as complete features.
- Be efficient with usage. Stephen explicitly asked for orchestration with cheaper workers on bounded tasks, while retaining careful integration/review. Avoid repeatedly rebuilding or rerunning whole suites during concurrent edits.
- Preserve unrelated dirty work. No reset, cleanup, wholesale staging, commits, pushes or public publishing without appropriate authorization.

## Repository and tooling

- Native Flutter app: `lib/`, `test/`, `android/`.
- Existing Next.js website: `landing/`. It shares backend data; permission changes require website regression checks too.
- Backend: `supabase/migrations/`, `supabase/functions/`.
- Connected Supabase project last verified: `byckurabenbunsbrzcpl`; recheck `supabase/.temp/project-ref` and connected tool target before writes.
- Flutter: `C:/Users/st3ph/flutter/bin/flutter.bat`; Dart alongside it.
- ADB: `C:/Users/st3ph/AppData/Local/Android/Sdk/platform-tools/adb.exe`.
- Last connected device: A142P, serial `00088148Q000727`. Recheck `adb devices`; do not assume it is connected now.
- Private preview package: `com.artisanallane.artisanal_lane.preview`.
- Use `npx.cmd supabase` if CLI work is needed; inspect `--help` before commands. Read the repository Supabase skills before database work.
- Isolated SQL policy tests use PGlite under `.codex/story-db-validation/node_modules/`.
- Git currently contains extensive modified and untracked app, website and backend work. Many essential new app files are untracked. Do not assume untracked means disposable or generated.
- Keep `.env`, service credentials, signing material, local tool configuration and private attachments out of commits and handovers. Do not print their contents.

## Implemented / last verified

### App integration and reliability

- Integrated creator Feed, swipe Discover, redesigned Shop and creation entry points are in source, distinct from the old standalone demo.
- New post publishing uses an immutable submission ID, insert-ignore and read-back validation. Lost responses can be retried without duplicate posts.
- Uploaded but unconfirmed submissions are saved per account before the database write and recovered without automatic publication.
- Post editor guards account changes, blocks back navigation while publishing and validates photos against the live 5 MB cap.
- Password recovery no longer performs a guest profile lookup first; its receipt does not reveal whether an account exists. Repeated submit and leaving-screen handling are tested. Actual email/deep-link delivery still needs acceptance testing.
- Fixed a product-editor Material/ExpansionTile rendering assertion.
- Removed raw checkout/dispute/locker diagnostic output without changing payment logic.
- Release builds cannot enable the private account's non-saving product-editor bypass.
- Android backup exclusions were added for sessions, private drafts and local media.

### New features prepared locally, NOT deployed

- Discovery sync: account-private choices and per-product decisions, paginated reads, local history import without replacing existing cloud decisions. No offline write queue; failure must not be shown as synced.
- Reporting: account-bound retry-safe receipt, hourly rate limit, immutable server-stamped target snapshot and admin review queue. Resolution/dismissal does not automatically remove content.
- Feed video: private storage markers, short-lived signed URLs obtained when opening, native fullscreen playback and fullscreen photo zoom. Client upload limits are 50 MB and 60 seconds. Actual camera/gallery/video device proof remains outstanding.

### Verification on 25 September

- Full Flutter suite: **200 passed**, no skips, with all four integrated feature flags enabled.
- Static analysis: no issues.
- Seven isolated SQL/storage suites: **122 assertions passed** (Stories 19; post interactions 29; AI 20; discovery 14; reports 11; post media 14; profile writes 15).
- Final signed AAB built successfully, 67.8 MB; `jarsigner -verify` passed with self-signed/certificate-chain/timestamp warnings.
- Artifact: `build/app/outputs/bundle/release/app-release.aab`.
- SHA-256: `CC266086195BA9265E780467E14C93EED4C1C5BA1C4554EE4A083979EEAC35A1`.
- That bundle enabled only `CREATOR_COMMERCE_ENABLED`; undeployed feature flags stayed off. It was not uploaded or accepted as a final release.
- Logs: `.codex/release-tests-final.log`, `.codex/release-build-final.log`.

Earlier phone evidence covered real catalogue browsing, Discover dragging, Shop layouts, product photo preparation/enlargement and a private Story upload/view/delete with server-side 24-hour expiry. It does **not** prove the latest changes, native video, every account role, cross-device interactions or live payments.

## Feature flags

`lib/core/constants/feature_flags.dart`:

- `CREATOR_COMMERCE_PREVIEW`: old standalone showcase; not the integrated production path.
- `CREATOR_COMMERCE_ENABLED`: integrated creator-commerce app.
- `CREATOR_SAFETY_ENABLED`: keep off until reporting backend is deployed and permissions are safe.
- `CREATOR_VIDEO_POSTS_ENABLED`: keep off until private media backend is deployed and validated.

`DISCOVERY_SYNC_ENABLED` lives in `lib/features/buyer/utils/discovery_remote_store.dart`; keep off until its migration is deployed. All flags default false. Passing flags during tests does not enable the installed app or backend.

## CRITICAL release blocker: live legacy permissions

Read-only inspection on 25 September found broad legacy demo policies and grants. No exploit was attempted against live accounts.

- `profiles` has `demo_profiles_all` and guest/member write grants covering role/privileged columns. `current_user_is_admin()` depends on profile role, so role protection is foundational.
- Additional broad demo ALL policies exist on shops, vendor applications, orders, order items, escrow transactions, carts, cart items, favourites and disputes. An invite-code update rule was also overly broad.
- Mutable shop ownership and profile roles undermine newer creator policies even if their isolated tests pass.
- Existing public profile reads expose private fields; prepared write hardening does not solve this. Design a public profile projection and migrate consumers.
- Additional advisor findings included unrelated legacy education tables without RLS, mutable function search paths and exposed privileged functions. Inspect scope; do not blindly alter unrelated tables.

Prepared migrations (not deployed as of last verification):

1. `20260925091906_creator_discovery_sync.sql`
2. `20260925092400_creator_content_reports.sql`
3. `20260925092610_add_private_creator_post_media.sql`
4. `20260925092917_harden_profile_writes.sql`

The profile-write migration preserves normal signup/vendor upsert and trusted service approvals while denying guest writes, foreign edits and privilege/payment-identity changes. It is **not a complete ownership fix**. Do not bulk-push every local migration; the checkout also contains unrelated work.

Earlier Stories and interaction deployments were authorized in conversation; private AI backend deployment was authorized with paid generation disabled. Confirm remote migration/function state rather than inferring deployment from local files.

## Approval boundaries

Three requests were pending at the end of the release work, with no approval reply in the visible conversation:

1. Deploy the new discovery/reporting/private-video backend after tests.
2. Deploy tested profile-write hardening.
3. Prepare/test/deploy broader ownership fixes across shop/order/escrow/customer tables, with website and app regression checks and no balance/history changes.

Confirm these permissions before live changes. The subsequent “yes” was **only** approval to price Vintage Art Bottles products at R500; it does not approve any release/backend/security work.

Paid AI remains disabled. A key was previously pasted into chat; **never reuse or reproduce it**. A fresh key must be configured securely with approval, model/cost limits and actual generation testing. Private test-account access is not authority to fake subscription, payment or KYC state for release.

## Remaining implementation / test gaps

- Broader ownership/security fixes and public/private profile separation, followed by website+app role and checkout regressions.
- User blocking, content takedown workflows, media retention/cleanup and completed moderation/store-policy requirements.
- Native gallery/camera/video upload and playback, bad-network retry, account switching, guest/buyer/artisan/admin paths and independent-account/device social tests.
- Real product publication under legitimate vendor entitlements; private non-saving editor mode is not proof.
- Durable ordinary drafts before upload and edit-submission recovery are incomplete. New-post permanent validation failures after submission creation may leave the editor in a locked retry state; inspect and test.
- Actual password reset delivery/return links, PayFast subscription activation/return, checkout, orders, refunds/disputes and messaging require live-provider acceptance. Earlier user reports included a subscription-success 404 and completed PayFast registration without access; do not assume resolved from source presence alone.
- Paid AI end-to-end remains untested/disabled.
- Play listing/privacy/data-safety review; verify published version code before bumping (last source version noted was 1.2.6+25).
- Final build and phone acceptance after changes; explicit public release approval. No store/public rollout was done in the readiness pass.

## Key source entry points

- Shell/navigation: `lib/app/router.dart`, `lib/widgets/buyer_shell.dart`, `lib/widgets/vendor_shell.dart`.
- Screens: `lib/features/buyer/screens/{creator_feed_screen,creator_shop_screen,discover_screen,story_viewer_screen,post_comments_screen,moderation_reports_screen}.dart`.
- Feed media/social: `lib/features/buyer/widgets/creator_feed/` and `lib/features/buyer/providers/`.
- Discovery: `lib/features/buyer/utils/discovery_preferences.dart`, `discovery_remote_store.dart`.
- Creation: `lib/features/vendor/screens/{product_form_screen,post_form_screen,story_composer_screen,listing_assistant_screen}.dart`.
- Retry/media services: `lib/features/vendor/services/{post_publication,pending_post_store,creator_post_media}.dart`.
- Backend access: `lib/services/supabase_service.dart`.
- Tests: `test/` and `scripts/test-*-policies.mjs`.

## Repeatable local checks

Run from the repository root, after coordinating any edits. Do not run paid provider calls as part of generic validation.

```powershell
& C:/Users/st3ph/flutter/bin/flutter.bat analyze --no-pub
& C:/Users/st3ph/flutter/bin/flutter.bat test --no-pub --dart-define=CREATOR_COMMERCE_ENABLED=true --dart-define=CREATOR_SAFETY_ENABLED=true --dart-define=CREATOR_VIDEO_POSTS_ENABLED=true --dart-define=DISCOVERY_SYNC_ENABLED=true

$checks = @('test-story-policies.mjs', 'test-post-interaction-policies.mjs', 'test-artisan-ai-policies.mjs', 'test-discovery-policies.mjs', 'test-content-report-policies.mjs', 'test-creator-post-media-policies.mjs', 'test-profile-write-policies.mjs', 'test-ownership-policies.mjs', 'test-profile-privacy-policies.mjs')
foreach ($check in $checks) {
  node "scripts/$check"
  if ($LASTEXITCODE -ne 0) { throw "Policy check failed: $check" }
}

# Only existing integrated functionality, not undeployed backend features:
& C:/Users/st3ph/flutter/bin/flutter.bat build appbundle --release --no-pub --dart-define=CREATOR_COMMERCE_ENABLED=true
```

## Recent completed live data change — do not repeat

On 25 September Stephen requested Vintage Art Bottles' current pricing become normal pricing, without a sale. Inspection found all five products had `price=0`, `compare_at_price=500`, no variants. We explicitly asked whether to make all five R500 regular price; Stephen said yes.

A guarded transaction updated exactly those five products to `price=500`, `compare_at_price=NULL`. A separate read verified all five. No other shop/product data was changed.

Shop: `39f87c70-56b8-423e-bd2a-a0f9a06b430d` (Vintage Art Bottles).
Products: Amara In The Poppies; Ella ember; Lady Rose Bloom; The Velvet Ascent; Wild leopard Princess kiss.

An earlier request to extend Daleen Ludick / h.of.clay@gmail.com's trial to 22 October is present in history, but this handover has no completion evidence. Verify status before claiming it is done or making another change.

## Recommended next response/work

Tell Stephen the app is substantially implemented and locally tested, but production security and end-to-end acceptance still block release. Confirm the pending live-change authority. Audit current state read-only, then fix ownership foundations with isolated adversarial and legitimate-flow tests before enabling new backend features. Continue device and moderation work in parallel only where scope and staffing are authorized. Keep the release checklist current and clearly distinguish source, deployed backend, installed APK and public release.
