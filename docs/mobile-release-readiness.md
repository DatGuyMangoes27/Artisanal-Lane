# Creator-commerce Android release gate

Status: **NOT approved for public release**. This is the single current checklist;
older dated implementation notes describe earlier checkpoints, not current readiness.

## Verified 25 September 2026

- Existing creator-commerce preview was installed on A142P; real catalogue,
  swipe discovery, photo preparation and private Story upload/view/delete tested.
- Production signing configuration can build an Android App Bundle with the
  integrated creator flag. An AAB build is not Play upload, device acceptance,
  payment acceptance, store policy review or proof of all demo functionality.
- Final local AAB rebuilt successfully (67.8 MB), signature verification passed.
  Only `CREATOR_COMMERCE_ENABLED` was enabled; undeployed feature flags stayed off.
  SHA-256: `CC266086195BA9265E780467E14C93EED4C1C5BA1C4554EE4A083979EEAC35A1`.
  This bundle has not been installed, uploaded or approved as the final release.
- Release builds now cannot enable the private account's non-saving editor bypass.
- New post submission uses a stable UUID, insert-ignore and read-back validation.
  Uploaded, unconfirmed new submissions are persisted per account before database
  write and restored without automatic publishing. Drafts before submission and
  in-flight edit submissions are not yet durably saved.
- Upload retries keep an immutable object ID. Post editor blocks account changes
  and navigation during publishing. Photos are checked against the live 5 MB cap.
- Password recovery no longer queries profiles before Auth recovery; confirmation
  is non-enumerating, repeated submits are guarded, leaving during a request is safe.
- Removed 23 checkout/dispute/locker diagnostic statements including raw provider
  response data. No payment logic or provider configuration changed.
- Fixed a Material/ExpansionTile rendering assertion in product listing readiness.
- Final full suite passed 200 tests without skips with creator commerce, reporting,
  video posts and discovery sync flags enabled. These are automated checks, not
  device or live-provider acceptance.
- Final static analysis reports no issues. All seven isolated database/storage
  suites passed (122 assertions). These fixtures do not certify the live database:
  the broader demo policies listed below remain a release blocker.

## Deployed to production 27 September 2026 (approved by Stephen)

Applied to `byckurabenbunsbrzcpl` in this order. Remote migration versions are
the apply timestamps, not the local file prefixes.

1. `harden_profile_writes` (local `20260925092917`).
2. `remove_demo_permissions` (local `20260927190000`): dropped all 12 `demo_*`
   policies, user shop creation, direct vendor order updates, direct dispute
   inserts and open invite-code read/update. Added owner read of inactive shops,
   owner/admin draft-post read, a pending-only application insert guard and a
   trigger blocking non-server changes to shop ownership, activation and spotlight.
3. `creator_discovery_sync`, `creator_content_reports`, `add_private_creator_post_media`.

Verification: 49-assertion `scripts/test-ownership-policies.mjs` (mirrors the
live legacy policy set, includes a pre-fix exposure baseline); all earlier policy
suites; Flutter 199 passed/1 flag-gated skip; website 125/125. Live read-only
role probes (rolled back) matched expected counts exactly: guests/strangers see
0 of 74 orders, a buyer sees 28/28 own orders, a vendor 6/6 shop orders, 7/7
items, 2/2 escrow. API logs after deployment showed no 4xx/5xx or RLS denials.
No rows were changed.

Also deployed 27 September (approved): `restrict_server_only_rpcs` (stock and
stale-checkout functions are server-only) and `add_private_profile_readers`
(`get_my_profile()`, `get_order_buyer_contacts()`), both verified live.

### Profile privacy rollout (in progress)

Every user can still read every profile's email and phone. The fix is staged
because the published app and website read private columns directly:

1. Done: reader functions deployed; app and website source now read private
   fields only through them, and profile upserts no longer merge private columns
   (`scripts/test-profile-privacy-policies.mjs`, 29 assertions).
2. Deployed 27 September (approved): `hide_private_profile_fields_from_guests`.
   Guests read only id/display_name/avatar_url; verified live (144 shops still
   show owner names, no API errors). Known effect: the published app's
   forgot-password lookup now reports "not found"; those users reset on the
   website until they update.
   **Regression found and fixed 27 September:** the guest lock above also hid
   `profiles.role` from guests, but `current_user_is_admin()` and many inline
   admin checks read it as the caller, so every guest query on those tables
   failed (feed posts returned 401; learning resources too). Fixed live with
   `allow_guest_profile_role_for_policies` (guests may read `role` only). A
   guest read sweep of all 52 guest-readable tables now passes, and the privacy
   test has regression checks. Before stage 3, run the same sweep as a member.
3. `20260927224000_hide_private_profile_fields_from_members.sql` — deploy only
   after the updated website is deployed and the updated app is the minimum
   supported version. Older builds would fail to load or sync profiles.

### Other backend items

- `20260927210000_lock_unrelated_education_tables.sql` — **not deployed**
  (permission check declined it). Nine scheduling tables unused by Artisan Lane,
  with no API traffic; four have no RLS. Locks API access without changing data.
- Advisor: mutable function search paths; leaked-password protection disabled
  (Auth dashboard setting).

## Feature notes

- Discovery sync: account-private preferences and one decision row per product,
  so swipes on separate devices cannot replace each other's history. Existing local
  history imports without overwriting cloud decisions. New writes require an
  acknowledged connection; failed saves are not described as synced. Cloud reads
  are paginated. `DISCOVERY_SYNC_ENABLED` stays false until migration is deployed.
  Fourteen isolated PostgreSQL security checks and three provider-state tests pass.
- Reporting now has account-bound, retry-safe receipts, rate limiting and immutable
  server snapshots for admin review. Eleven isolated checks pass. Blocking users,
  takedown workflows and policy/store acceptance remain incomplete.
- Private Feed video upload, signed playback and fullscreen photo/video viewing
  are implemented locally; fourteen isolated storage assertions pass. Native
  video picking/playback still needs device proof. Backends are now deployed; a
  private preview APK with all four flags was installed on A142P on 27 September,
  but on-device acceptance of these features is still pending.

## UX overhaul (27 September, source only, not released)

A 67-item interaction audit was implemented across Feed, Stories, Discover,
Shop, product/maker pages, navigation/You tab and creation flows: comments as a
bottom sheet, optimistic likes/follows/favourites, double-tap like, swipeable
carousels, story auto-advance and swipe-down, stateful tabs, full-screen
composers with discard prompts, server search with sort/filter, friendly errors
and skeleton loading. Fixed during integration: broken shop-name search (live
API rejected the filter), a false "subscription required" in the Create menu,
misleading post-retry wording, and header crowding. Verified: analysis clean,
215/215 flagged and 213 (+2 skipped) default Flutter tests, emulator pass of
Feed and comments. Still open: in-feed video autoplay, server pagination for
the base Shop catalogue, stepped product form, "You may also like", profile
report backend, and device acceptance of the new interactions.

## Must complete before public release

- Approve/deploy the server-only RPC restriction; design the public-profile split.
- Run final full analysis, tests with release feature flags, security policy tests,
  native release build, and signed-binary dependency/permission checks.
- Verify real gallery/camera/video picking and playback, failed-upload recovery,
  account switching, and buyer/artisan/guest paths on devices.
- Test new social interactions and preferences across independent accounts/devices.
- Implement and verify media retention, reporting, moderation and blocking controls;
  complete the relevant user-generated-content store requirements.
- Test full real artisan product publishing with legitimate entitlements; do not
  convert the private editor bypass into fake payment/KYC approval.
- Regression-test checkout, payment return, paid subscription entitlements, orders,
  refunds/disputes and messaging. Existing unit tests do not prove live providers.
- Paid AI remains disabled. Securely configure a fresh key only with approval,
  confirm allowed models/cost limits, then run actual image/word generation tests.
- Review Play listing/privacy/data-safety declarations and increment version code
  against the actual published track before preparing the final upload artifact.
- Obtain explicit public-release approval. No Play, website or public rollout has
  occurred as part of this readiness work.

Android backup hardening excludes sessions/private drafts/media from cloud and
device-transfer backups. New devices must sign in again; synced server content
remains available, local-only drafts will not transfer. This follows the
[Android backup rules](https://developer.android.com/identity/data/autobackup).
