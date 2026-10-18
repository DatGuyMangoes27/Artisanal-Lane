# Release 1.3.0 (build 26) — store submission checklist

Prepared 18 October 2026. Nothing has been uploaded to Google Play or App Store
Connect; those steps are below.

## Build

All store builds use the production feature set in `config/release.json`
(creator commerce, safety/reporting, video posts, discovery sync). Internal
preview screens cannot ship: they are disabled in release builds in code.

```
.\scripts\build-release.ps1          # Android App Bundle (Google Play)
.\scripts\build-release.ps1 -Apk     # release APK for device testing
flutter build ipa --release --dart-define-from-file=config/release.json   # iOS, on a Mac
```

Android bundle: `build/app/outputs/bundle/release/app-release.aab`.

## Backend (already live)

- `20261018100000_ugc_safety.sql` applied 18 October: objectionable-language
  filter on all user text (posts, comments, stories, polls, reviews, chat,
  shop and profile names, product listings), reports on reviews and chat
  messages, community-guidelines acceptance. No existing content matched the
  filter.
- Website deployed with the Community Guidelines page and admin moderation for
  review/message reports.

## Apple guideline 1.2 (user-generated content) — what reviewers will find

| Requirement | Where |
|---|---|
| Terms with zero tolerance for objectionable content | Sign-up screen line; Community Guidelines (Settings, Help & Support, artisanlanesa.co.za/community-guidelines); one-time "I agree" sheet before a member first posts, comments, messages or reviews |
| Filter objectionable content | Server-side filter on every user text field, with a friendly in-app message |
| Report content | "Report" on posts, comments, stories, shops, reviews and chat messages (long-press); reports reviewed within 24 hours in the website admin (Moderation) |
| Block abusive users | Block on posts, comments, shop profiles, reviews and chats; Settings → Blocked accounts |
| Contact information | Help & Support (email and WhatsApp), Settings → Report a problem |

**App Review notes:** give Apple a demo buyer account and say where reporting
and blocking are (post "•••" menu, long-press a chat message, review "Report"
link), and that reports are reviewed within 24 hours.

## Before submitting

1. Install the release build on a real phone and check, signed in:
   - posting (the guidelines sheet appears once)
   - a poll
   - a story
   - the Listing Studio photo save and price
   - checkout to payment
   - reporting a review
   - long-pressing a message
2. Contact email: every contact address in the app and website now uses
   `nicky@artisanlanesa.com`. It's the only Artisan Lane domain that receives
   mail; addresses on `artisanlane.co.za`, `artisanallane.co.za` and
   `artisanlanesa.co.za` bounced. Consider a `support@` or `privacy@` alias on
   artisanlanesa.com and swapping it in.
3. Store listings: update screenshots for the feed, gift finder and Listing
   Studio, update the privacy and data-safety forms (they now cover chat and
   moderation data), and update the age rating for user-generated content.
4. Upload `app-release.aab` to Play (internal testing track first); build the
   iOS archive on a Mac with the command above.
5. After the new app is the minimum supported version, deploy
   `20260927224000_hide_private_profile_fields_from_members.sql` (profile privacy
   stage 3; see mobile-release-readiness.md).

## Known limits

- AI tools in the Listing Studio stay hidden until AI is switched on server-side.
- Bob Go courier stays off until the sandbox sign-off (`docs/bobgo-go-live.md`).
- If attaching a poll fails after its post is saved, the post shows without
  the poll until the maker taps Retry in the composer.
