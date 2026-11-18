# 0013 — Search: Search API first, list fallback otherwise

## Context

M3 requires search that works across accounts and objects. Stripe's
`/v1/<object>/search` endpoint (Stripe Search) is powerful but not
universally available: it is unavailable for some objects, and Stripe
documented that accounts without it get errors. stripe-mock — the
project's fixture server — accepts `GET /v1/charges/search?query=…`
but rejects `GET /v1/payouts/search?query=…` with a request validation
error, which is direct evidence that per-object availability differs
and the app must degrade.

## Decision

- For "general text" queries the service tries the Stripe Search API
  first; when the request fails with an availability error (HTTP 404
  or the "feature not enabled"/"no such endpoint" error family), it
  falls back to fetching the plain object list and filtering
  client-side (id, description, customer, and numeric amount when the
  whole query parses as a number).
- Customer email queries use `GET /v1/customers?email=…` directly —
  the list filter is the documented API for this and needs no fallback.
- Amount queries use the Search API with `amount:<n>`; if it errors,
  the same list fallback matches by exact amount.
- Fallback results are marked in the returned hits so the UI can label
  them "approximate" honestly.
- Payouts, invoices, and other list-shaped objects are not searched in
  M3; their natural surface (lists, upcoming payouts) is already on
  the dashboard. Extending search to them is a later milestone.

## Consequences

- Search remains usable against real accounts where Search is
  disabled, verified by unit tests with a backend that rejects the
  search endpoint.
- stripe-mock integration tests exercise both paths: charges through
  the Search API, and the fallback by configuring a rejecting backend
  (the payouts rejection itself is out of M3 search scope).
- The fallback fetches one page without pagination; it is a
  best-effort degradation, not a full-text index, and says so in the UI.
