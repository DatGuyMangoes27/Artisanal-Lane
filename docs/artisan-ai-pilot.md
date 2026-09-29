# Artisan listing assistant — internal pilot

The real Product editor now opens “Make it listing-ready”: Words, Photos, Pricing.
Words/photos call the server only after consent. Pricing is an offline cost
calculator, not an AI valuation. Suggestions require review and explicit apply.
Generated photos are appended, never overwrite originals. Internal test accounts
still cannot save/publish products.

## Deployment boundary

On 25 September the user approved the private backend deployment, with paid
generation kept disabled. Migration 20260925083131_artisan_ai_requests.sql and
artisan-ai v1 are deployed with JWT verification enabled. ARTISAN_AI_ENABLED is
explicitly false and the allowlist contains only the existing vendor4 test UUID.
No OpenAI secret was configured or retrieved and no paid generation performed.
The phone reached the capabilities endpoint and displayed AI as disabled.
Rotate the API key previously exposed in
chat; configure a replacement in server secret management, never Git or Flutter.

After explicit approval:

1. The approved migration/function are deployed. For future changes, check
   migration history and never batch-push unrelated pending migrations.
2. Retain gateway JWT verification and Auth user verification in the handler.
3. Keep ARTISAN_AI_ENABLED=false initially. Configure OPENAI_API_KEY,
   ARTISAN_AI_ALLOWED_USERS (comma-separated exact Auth UUIDs),
   ARTISAN_AI_TEXT_MODEL and ARTISAN_AI_IMAGE_MODEL as server secrets.
   Model names are deliberately not silently selected. Confirm model access,
   image-edit/structured-output compatibility and pricing before enabling.
4. Use a dedicated provider project with budget alerts and any available hard
   limits. Request caps are NOT currency expenditure caps.
5. Enable only for approved internal testers and validate on a connected phone.

## Safeguards

- Auth verified remotely; own shop checked in a service-only invoker RPC. No
  user-metadata or client-asserted authorization.
- Transaction advisory lock protects rolling 24-hour quotas: per user 5 images /
  20 listings; global 25 / 100. Failed/uncertain attempts count.
- UUID + payload hash prevent changed-input replays. Same-ID retries return
  stored state without another paid call. No automatic provider retries.
- Private result storage has restrictive fences against legacy permissive
  policies. Users read only their own results; only server writes.
- Bounded photo bytes, no arbitrary remote URL fetching; strict listing schema,
  refusal/incomplete validation; originals are not stored by this service.
- No raw provider errors, credentials or photo payloads logged.
- UI freezes uncertain requests and offers Check existing result. Recovery is
  currently in-memory while the assistant stays open, not across process death.

## Validation and remaining gates

Run node scripts/test-artisan-ai-policies.mjs, npx.cmd --yes deno test
supabase/functions/artisan-ai/core_test.ts and flutter test --no-pub
test/listing_assistant_test.dart. PostgreSQL tests use isolated PGlite, never
production. Provider tests use injected fake responses; they do not prove real
model access or generation quality. Widget tests do not prove native permissions.

Before public release: durable request recovery, expired/orphan-result retention,
stale-pending reconciliation, moderation/reporting, approved privacy/disclosure
copy, real provider cost/quality checks, device photo/retry/account-switch tests.
Keep this internal until those gates pass.

Official contracts checked: [Image editing](https://developers.openai.com/api/docs/guides/image-generation#edit-images),
[structured output](https://developers.openai.com/api/docs/guides/structured-outputs),
[function authentication](https://supabase.com/docs/guides/functions/auth).
