# 0033 — Connect lists v2 core accounts behind platform-key detection

## Context

The Connect screen (M8, decision 0032) lists connected accounts from
`GET /v1/accounts`, which only serves accounts of the acting platform.
Stripe's v2 core accounts (`GET /v2/core/accounts`) serve the platform's
own merchant and recipient accounts, but that endpoint is rejected with
403 for keys that are not v2-era platform keys. Recorded-fixture tests at
the package layer (slice 1) already prove the v2 request shapes and
decode; the screen had not adopted them.

## Decision

`ConnectModel.load()` probes `GET /v2/core/accounts` first:

- probe answers 200 with a non-empty page → v2 mode: the screen renders
  v2 rows (`connect.row.v2.<id>`) with display name or contact email,
  country when present, and a `Restricted` badge when `closed`; search
  filters client-side by name, email, and ID; tapping a row shows a
  detail sheet with identifier, contact email, country, applied
  configurations, and requirements entries (minimum deadline and each
  entry's description and awaiting-party).
- probe 403 (or the mock serving no /v2 at all) → v1 mode, unchanged:
  v1 rows, sections, and states, with the probe failure silenced.
- probe 200 with an empty page → also v1 mode: an empty v2 page is not
  proof of a v2-era key, so the v1 list and its error/empty states stay
  authoritative.
- v1 errors keep their pre-probe behavior; the probe never surfaces as
  an error of its own.

The v2 path reads only: the Stripe app stays read-only for the v2
namespace this milestone (decision 0032); detail screens add no actions.

The model and backend are proven by unit tests against hand-written v2
fixtures with obviously fake values (`acct_test_v2_1`,
`seller@example.com`); the UI test proves the mock (no /v2 routes)
silently falls back to v1 rows, not the rendering of v2 rows, which only
a live v2 platform could show.

## Consequences

- One probe request is added to every Connect load on v1 keys; it is a
  single list call with `limit=1` budget and is silenced on failure.
- `StripeClient.retrieveAccount(id:)` with `V2CoreAccountRetrieveParams`
  hits `/v2/core/accounts/{id}`; the recorded link/person/token tests
  (slice 1) already pin the write paths for later slices.
- stripe-mock cannot serve /v2, so CI proves the v1 fallback and the
  fixture-decoded model path, not a live v2 listing; this is the same
  trade recorded for the v2 package layer in slice 1.
