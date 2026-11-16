# Limits that bound what the app can show and do

Research note from milestone M0. Written from Stripe's documentation as of
2026-11-16, against API version 2026-10-28.endive (spec release v2600).
Sources are listed at the end.

## Rate limits

Measured in requests per second, per Stripe account; each named API operation
is a separate endpoint. The documented numbers:

| Limit | Value |
| --- | --- |
| Global, live mode | 100 requests/second |
| Global, sandbox | 25 requests/second |
| Individual endpoints (default) | 25 requests/second |
| Search API | 20 read requests/second (live and sandboxes, separately counted) |
| Files API | 20 read/s, 20 write/s |
| Payouts API | 15 creates/s; 30 concurrent requests per business |
| Payment Intents | 1000 updates per object per hour |
| Subscriptions | 10 new invoices per subscription per minute; 20 per day; 200 quantity updates per hour |
| Connect account creation | live 30/s; sandbox 5/s |
| Global concurrency (live) | 50 in-progress requests |

A read allocation also applies: no more than an average of 500 read requests
per transaction over a rolling 30 days, with a floor of 10,000 read requests
per month; reporting, tax, and data-product endpoints are excluded. A
dashboard app polling lists must respect this: the refresh scheduler keeps
background polling well inside it (an idle account making a handful of list
calls per refresh stays orders of magnitude below the floor).

Rate-limited requests return `429` with a `Stripe-Rate-Limited-Reason` header:
`global-rate`, `endpoint-rate`, `global-concurrency`, `endpoint-concurrency`,
or `resource-specific`. The client retries those with exponential backoff and
jitter, and throttles globally when limiting is detected. A `429` with code
`lock_timeout` (no rate-limit header) is a lock timeout: it is safe to retry
and the client treats it like a rate limit.

## Pagination and page sizes

List methods take `limit` (1–100, default 10), `starting_after`, and
`ending_before`; responses carry `has_more`. The app uses `limit=100` for
list screens and walks pages with `starting_after` (forward) or
`ending_before` (backward). `/v2` lists paginate with page tokens and return
`next_page_url` / `previous_page_url`; filters cannot change after the first
page. Test-clock-generated objects are omitted from unfiltered list requests
(the app notes this where it matters, for example invoices under a test
clock).

## Search API

- Available on Charges, Customers, Invoices, PaymentIntents, Prices,
  Products, Subscriptions.
- Requires API version 2020-08-27 or later (our pin is newer).
- **Not immediately fresh**: results can lag up to about a minute; the docs
  say not to use search for read-after-write. The app treats search as a
  finder, never as the first refresh of a just-written object.
- Cached-status mismatch is documented: a query on a PaymentIntent status may
  return rows whose current status differs from the cached one it matched.
  The app shows the row's real status from the response, and search result
  rows always re-fetch on open.
- Rate limit 20 reads/second; unavailable to businesses in India (the app
  falls back to filtered list requests and shows why).
- Query language: up to 10 clauses joined by `AND`/`OR` (not both; no
  parentheses), negation with `-`, exact `:`, substring `~` (3+ characters),
  numeric `>` `<` `>=` `<=`, `field:null` presence, metadata via
  `metadata["key"]:"value"`, quotes required around string values.

## Events API

Events are retrievable for **30 days** after creation. The activity feed
polls `GET /v1/events` while open and in background refresh, de-duplicates by
event ID, and stores what it has seen; older events are simply absent from
Stripe, so the feed's history is bounded by that window. Connect platforms
see connected-account events tagged with the `account` attribute. `/v2`
emits thin events (no snapshot payload); the feed fetches the referenced
object on demand.

## Webhooks and event destinations

Webhook endpoints must be publicly reachable HTTPS URLs; an iPad app has
none, so the app polls the Events API instead and states plainly that
background alerts can be late. Up to 16 event destinations can be registered
on an account, and delivery retries run up to three days in live mode — these
facts matter only to the "After v1.0.0" server option and to users who run
their own endpoints, which the app can list and manage (tier 2).

## Files

Uploads are multipart requests to `files.stripe.com/v1/files` (different
subdomain from `api.stripe.com`), with a `purpose` and a `file`. Each purpose
defines its own formats and size limits; `identity_document` images must be
smaller than 8000×8000 px. Microsoft Office documents containing VBA macros
are rejected; PDFs are validated server-side and can be rejected for
formatting problems. Downloads go to `files.stripe.com/v1/files/{id}/contents`
with authentication, or anonymously through a `file_link`. Dispute evidence
uses an uploaded file ID exactly once.

## Other bounds the app respects

- **Metadata**: up to 50 keys; keys up to 40 characters; values up to 500
  characters; strings only; no `[` or `]` in keys; clearing is an empty string
  on `/v1` and `null` on `/v2`.
- **Expand**: up to four levels of expansion; on list requests paths start
  with `data.`; `/v2` has no `expand` (some endpoints use an `include`
  parameter).
- **Idempotency**: keys up to 255 characters; `/v1` remembers them for 24
  hours on `POST` only; `/v2` honors them on `POST` and `DELETE` for 30 days
  within the same account or sandbox.
- **Organization keys** add organization-level scoping on top of account
  scoping.

## Sources

- `https://docs.stripe.com/rate-limits.md` — all rate-limit and concurrency numbers, read allocation, `Stripe-Rate-Limited-Reason`, lock timeouts
- `https://docs.stripe.com/api/pagination.md` — limit 1–100 default 10, cursors, list response shape
- `https://docs.stripe.com/search.md` — searchable resources, freshness, mismatches, rate limit, India availability, query language, test-clock omission
- `https://docs.stripe.com/api/events.md` — 30-day retrieval window
- `https://docs.stripe.com/webhooks.md` — public HTTPS URLs, 16 destinations, retries
- `https://docs.stripe.com/file-upload.md` — files host, purposes and size rules, single-use evidence
- `https://docs.stripe.com/api/metadata.md` — metadata limits
- `https://docs.stripe.com/api/expanding_objects.md` — four-level expansion
- `https://docs.stripe.com/api/idempotent_requests.md` and `https://docs.stripe.com/api-v2-overview.md` — idempotency windows and verbs
- `https://docs.stripe.com/sandboxes.md` — sandboxes vs test mode
