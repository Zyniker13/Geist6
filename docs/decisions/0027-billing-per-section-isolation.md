# 0027: Per-section load isolation in the billing screen

## Context

The billing screen loads three sections: products, coupons, promotion codes.
The initial implementation fetched them sequentially under a single `catch`,
so any section failure blanked the whole screen and prevented the remaining
sections from ever being requested.

The first UI tests against stripe-mock exposed this: stripe-mock's product
fixtures and response synthesis are keyed to an older API version, and its
response builder drops fields that its bundled OpenAPI spec does not know —
including the `type` field that our pinned spec (`2026-10-28.endive`)
requires on `Product`. Product decode failed, the single catch turned that
into a full-screen error, and coupons never loaded even though stripe-mock
serves them fine.

## Decision

`BillingModel.load()` loads the three sections concurrently with `async let`,
each section in its own `do`/`catch` that records a section-level error
string. The screen ends in `.loaded` once every section settles; a failed
section renders an inline error row inside its own section, and other
sections keep their rows. The screen-level `.failed` phase was removed.

## Consequences

- One broken resource type degrades gracefully to one degraded section; the
  dashboard stays usable. This matches the roadmap's dashboard posture.
- The billing UI tests pass against stripe-mock even while its product
  fixtures cannot satisfy the pinned spec.
- Known follow-up: UI tests that need product rows against stripe-mock (the
  catalog work planned for M7) require a fixture/spec overlay for
  stripe-mock — patching the product schema and fixtures to include `type`,
  generated at test time from pinned upstream files, not vendored wholesale
  into the repository.
- Section errors are strings fit for display; structured errors would be
  needed if any screen must branch on the failure kind. None does today.
