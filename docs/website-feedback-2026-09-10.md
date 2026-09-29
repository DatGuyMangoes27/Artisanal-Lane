# Website feedback points 1–5

## Scope

- Shop cover now uses a maroon gradient concentrated at the bottom behind shop details, with a small upper shade for the back link. Removed brown and gold/green full-photo tint.
- Public `/help/photos` explains 1200px square product processing, eight-photo/8MB processed product limits, recommended logo size and responsive banner safe areas. Linked from product forms, shop settings, vendor navigation and account help. Recommendations are distinguished from limits.
- Shared buttons have visible maroon hover, focus outline and active feedback. Product and shop-save forms disable inputs and duplicate submission while saving, preserve entries on caught failure and show success/error status. Existing application pending feedback remains. No billing actions were changed.
- `fresh=7` now renders a dedicated grid without the main shop hero or duplicate carousel. Filters are collapsed initially, newest is default, pagination keeps filters, clear stays within new arrivals, and full-collection CTA exits to the main shop. Displayed range derives from the returned page, not a global filtered count.
- Artisan terms have a section anchor linked from vendor navigation, application and subscription pages. Existing fee wording and pricing remain unchanged pending confirmation.

## Validation

- 125 tests in 32 files pass, including new dedicated arrivals rendering, pagination/filter and empty-state tests.
- TypeScript check and focused ESLint pass.
- Local browser checked public arrivals with real catalogue data, shop header at default and 390px mobile width, mobile arrivals layout.
- Temporary local-only feedback fixture proved disabled pending state, preserved input on error, and success status. Fixture removed before publishing. No actual vendor product, subscription, payment or shop data was changed by QA.
- Release built from the isolated prior production source under `release-website-20260907/landing`. Latest remote release verified as `6a9e99475dae76d2abda6d6b` before publishing. Unrelated app/payment/onboarding working-tree edits excluded.

## Deployment

Published successfully to `https://artisanlanesa.co.za` on 10 September 2026. Netlify deploy `6aa27e63b0f5866777bb5bf3`; production build passed. Live HTTP checks returned 200 and expected content for New Arrivals, photo guide, artisan terms anchor and shop maroon gradient. Browser verified the public photo guide without login, desktop production shop banner and dedicated arrivals grid. No authenticated production save was performed; saving-state QA used the local synthetic fixture described above.
