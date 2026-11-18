# 0016 — Payments read layer and timeline

## Context

M4 adds the Payments surface. The generated Stripe client exposes dozens of
payment endpoints with heterogeneous response shapes (list envelopes,
`Expandable` references, lossless enums). Views need one narrow, typed door to
that data, and a payment's story (intent → charges → refunds → disputes →
balance transactions) is spread across several endpoints that must be joined
before it can be shown as one timeline.

## Decision

- `PaymentsBackend` (in `Sources/GeistData/Payments.swift`) extends
  `StripeDataBackend` with payment-specific read methods. It is the only door
  the payments views use.
- `StripePaymentsBackend` implements it on top of `StripeClient`. Search
  endpoints call `request` directly with a typed list response instead of the
  generic search-result wrapper.
- The payment story is assembled by `PaymentTimelineLoader` into
  `PaymentTimelineEntry` values (intent, charge, refund, dispute, balance
  transaction, line items), ordered newest-first. A missing piece is skipped,
  not fatal: the timeline survives gaps (tested).
- Detail views receive loaded objects, not IDs-only; `Kind.intent` carries the
  `PaymentIntent` payload so the detail view renders without a second fetch.
- Rows are read-only by construction in M4a; write controls arrive in M4b
  behind the management-mode gate.

## Consequences

- View code never touches `StripeClient` directly, so read/write gating and
  backend swapping stay in one layer.
- Fixture-based tests (`PaymentsFixtureBackend`) cover the loader without a
  server; the model shapes are pinned by hand-checked JSON fixtures.
- Required (non-`Nullable`) generated fields are pinned by those fixtures too:
  decoding a missing required key fails the test, which documents the wire
  contract (`PaymentIntent`: `amount_capturable`, `amount_received`,
  `capture_method`, `confirmation_method`, `metadata`, `payment_method_types`;
  `Dispute`: `balance_transactions`, full `evidence_details`,
  `evidence.enhanced_evidence`).
- Lossless customer enums (`ChargeCustomer`, `PaymentIntentCustomer`,
  `SetupIntentCustomer`) are unwrapped through shared `paymentCustomerID(_:)`
  helpers rather than per-view switches.
