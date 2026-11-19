# Decision 0022 — M4 tier-2 payment rows are built early as compact structured views

## Context

The payments coverage matrix has three tier-2 rows that ride along with the
payments screen: Mandates, Confirmation Tokens, and the PaymentIntent
`amount_details` line items. Tier 2 is served in M10 by generated list/detail
views driven by resource descriptors; M4's "Done when" requires every payments
row built at its tier. Waiting for M10 would leave M4 payments visibly unable
to open a mandate or confirmation token even though the generated client,
models, and stripe-mock all already support them.

## Decision

Build the three tier-2 payments rows early, in M4, as compact structured views
in the app layer, ahead of M10's descriptor engine:

- Mandates: a `MandateDetailView` (status, type, payment method, acceptance),
  reached from the SetupIntent detail's mandate row and from open-by-ID
  (`ma_` prefix) and search.
- Confirmation Tokens: a `ConfirmationTokenDetailView` (created/expires,
  setup-future-usage, payment method preview), reached from open-by-ID
  (`ctoken_` prefix) and search.
- PaymentIntent line items: a "Line items" section on the payment intent
  detail, fetched best-effort from
  `GET /v1/payment_intents/{id}/amount_details_line_items`.

Routing additions in `StripeObjectKind` are limited to real Stripe prefixes
(`ma_`, `ctoken_`); the app opens the mock's sample objects through their
real-ID handling (stripe-mock serves `/v1/mandates/ma_test_123` with its
sample mandate, so UI tests use `ma_`-style IDs and no mock-specific prefix is
added).

## Consequences

- M4 payments coverage closes fully: every matrix payments row has a screen.
- When M10 lands, these three views may be re-hosted on the descriptor engine;
  their fetch paths already go through `PaymentsBackend`, so only the view
  layer changes.
- The views are compact, not exhaustive: fields outside the matrix's
  tier-2 scope remain visible through open-by-ID's raw JSON view.
- UI tests drive stripe-mock on port 12111 (as in decision 0020's flow).
