# Website feedback implementation — 7 September 2026

## Implemented locally

- Homepage shows all categories using a product image from the matching category.
- New-arrivals links use `fresh=7`; catalogue pagination and search preserve this filter.
- Featured Finds shows up to 12 featured products instead of truncating to five.
- Artisan directory has an image-led spotlight rail using existing shop spotlight flags.
- Homepage and artisan signup copy includes R349/month, the existing introductory offer, benefits and payment-fee distinction.
- Terms now describe subscription rather than commission, marketplace removal for non-payment, emergency-only external buyer contact, promotional-content permission while participating, and the supplied contact address. Existing 14-day delivery confirmation wording is retained and cross-referenced. No payment-release automation or subscription enforcement was changed by this copy update.
- Buyer/vendor message pages refresh on live events and have a five-second visible-tab fallback, plus online/visibility recovery.
- Shop deletion now invalidates public pages as well as admin pages.
- Signed-in users with confirmed emails can opt in/out at `/account/email-updates`. Consent is stored in user-owned Auth metadata under `artisan_lane_email_updates`, including email, timestamp, source and consent version. This data must never be used for authorization.

## Evidence

- 30 test files / 116 tests pass, including new-arrivals pagination and email-consent tests.
- Production build passes. Focused ESLint passes.
- Local homepage and artisan pages checked using live catalogue data; mobile category layout checked.
- Read-only live database check: no chat tables in `supabase_realtime`; largest message thread has 30 messages, so the 1,000-row API cap does not explain reported delays.
- No active shop found linked to an application marked account-deleted. Shop directory reads active shop rows, not old application records.

## Remaining acceptance / release work

- Website feedback changes deployed to the verified production site `artisanlanesa.co.za` on 7 September 2026. Netlify deploy: `6a9e94f727b988aaa7dc3957`, site: `bfcc54b4-743d-4fe7-a5d3-fa2082de8606`. Release was isolated under `release-website-20260907/landing` from HEAD plus approved website files; only public cache invalidation was copied from the mixed admin-actions changes. Unrelated mobile, payments and onboarding edits were excluded. Source remains uncommitted.
- Isolated release passed 116 tests and the Netlify production build. Live homepage, artisans, terms and seven-day catalogue page two each returned HTTP 200 with expected new content.
- Obtain a specific deleted shop name to investigate the reported residual listing. Do not hide legitimate empty shops indiscriminately.
- Test message exchange using two authorized accounts. Replication itself has not been enabled on production; the fallback is functional independently of it. Admin pages retain their existing 4–6 second polling.
- Email signup is consent collection only. No campaign sender, subscriber export, scheduled campaign or provider synchronization has been added. Before campaigns, connect the selected delivery system, honor the latest consent and confirmed email, and include an unsubscribe link.
- No production signup, subscription payment, payout, or promotional message was triggered. Existing registration/payment changes still need their own end-to-end acceptance.
