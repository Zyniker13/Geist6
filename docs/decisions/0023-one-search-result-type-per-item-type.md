# 0023 — One search-result type per item type

## Context

The pinned OpenAPI spec titles the response schema of every `GET /v1/*/search`
endpoint `SearchResult`, while the `data` array item type differs per endpoint
(charge, customer, invoice, payment_intent, price, product, subscription). The
generator named inline list/search containers from that title and memoized
names per title, so the first search endpoint seen (charges) produced
`SearchResult` with `data: [Charge]`, and every later endpoint reused that same
struct. Six of the seven search endpoints therefore decoded other object types
into `[Charge]`; payment-intent search would have failed to decode or produced
wrong values.

## Decision

The generator now tracks the data item type of each generated list/search
container. When a container name is already taken by a type with a different
item type, the generator picks a name carrying the item type
(`PaymentIntentSearchResult`, `CustomerSearchResult`, ...). The charges search
keeps the plain `SearchResult` name, so existing call sites are unchanged.
Regenerated from the pinned spec; no model is hand-written.

## Consequences

- Each search endpoint returns its own correctly typed result; decoding a
  payment-intent search response as charges is no longer possible.
- Future endpoints whose inline responses share a title but differ in shape
  are named distinctly by item type instead of silently collapsing.
- Call sites for the six affected client methods change return types; the
  data layer's search functions were updated in the same change.
