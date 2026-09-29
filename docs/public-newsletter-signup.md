# Public newsletter signup

The homepage now links to `/stay-updated`, a public email-and-consent form. No Auth account is created and no login is required. The previous account preference page redirects guests here, while preserving existing signed-in preferences.

Storage: `public.newsletter_subscribers`, with RLS enabled and no anon/authenticated privileges. Only the server-side service client writes. The table stores explicit consent time/version, an unverified-email flag, and a random unsubscribe token. Existing rows are never reactivated or disclosed on duplicate signup. A token-protected POST performs unsubscribe; GET alone makes no changes. A honeypot and per-source signup cap mitigate basic abuse. Rate-limit identifiers are keyed daily hashes, not raw IP addresses.

This is single opt-in collection, not email ownership verification. No confirmation email or campaign is sent. Before enabling a campaign sender, implement email verification/delivery, include each recipient's unsubscribe link, and reconcile suppression with any existing account-level `artisan_lane_email_updates.enabled=false` preferences. Never treat account metadata as authorization.

Checks: 122 unit tests pass; production build passes; database verification confirms RLS on and no anon/authenticated read access. The RLS-without-policies informational advisor finding is intentional for this server-only table.

Deployment target is the existing `artisanlane` Netlify site, `bfcc54b4-743d-4fe7-a5d3-fa2082de8606`, serving `https://artisanlanesa.co.za`. Release files are isolated in `release-website-20260907/landing`; unrelated working-tree payment/onboarding changes are not included.

Published 2026-09-07: Netlify production deploy `6a9e99475dae76d2abda6d6b`. Live guest signup and token-based unsubscribe succeeded using a non-deliverable QA address. Database verification confirmed that the test entry is unsubscribed and remains unverified. No campaign or confirmation email was sent.
