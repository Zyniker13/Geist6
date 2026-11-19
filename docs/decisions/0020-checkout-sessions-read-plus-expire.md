# Decision 0020: Checkout sessions are read-plus-expire in v1

## Context

M4's payment coverage includes checkout sessions. The generated StripeClient
has `createSession(expand:idempotencyKey:)` for `POST /v1/checkout/sessions`,
but the generator produced no body-params parameter for it: session creation
needs line items (price + quantity) and there is no way to pass them. The
dashboard's job for checkout sessions is monitoring (what did customers open,
what is open/complete/expired) and closing stray open sessions.

## Decision

The Checkout segment ships with list, detail (with fetched line items), and
one write: expire an open session, behind the management-mode gate with an
idempotency key like every other write. Session creation is left to the API
explorer milestone (M10), where free-form writes belong, and to storefronts —
a dashboard does not create checkout sessions.

## Consequences

- `PaymentsBackend` gains `checkoutSessions(created:customer:status:)`,
  `retrieveCheckoutSession(id:)`, and `checkoutSessionLineItems(id:)`;
  `PaymentsWriteService` gains `expireCheckoutSession(id:summary:)`.
- The filter serves the segment with its created/customer/status dimensions
  (server-side where supported); amount filtering is skipped because
  `amount_total` is null until the session completes.
- If a later milestone needs programmatic session creation, it must first
  extend the generator to emit create params for `/v1/checkout/sessions`,
  regenerate, and reopen this decision.
