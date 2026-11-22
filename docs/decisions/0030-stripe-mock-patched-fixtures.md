# Decision 0030: Patched stripe-mock fixtures

## Context

The deactivate-promotion-code UI test needs the fixture promotion code to be
active when its detail screen opens, so the Actions menu offers Deactivate.
The upstream stripe-mock v0.206.0 `fixtures3.json` ships it with
`active=false` (and `promotion.coupon` null, which leaves the coupon section
empty). stripe-mock also never mutates fixture state on POST, so a write
never makes the fixture active. Decision 0029 pins the upstream files by
SHA-256 and forbids vendoring them.

## Decision

The overlay generator (`Tools/mock-overlay/main.swift`) writes a third file,
`patched-fixtures3.json`: a copy of the verified upstream fixtures with
explicit, recorded patches applied (today: the promotion_code resource's
`active` set to true and its `promotion.coupon` set to the fixture coupon
ID). check.sh starts stripe-mock from the overlay spec plus the patched
fixtures. The upstream files remain byte-pinned; the patched copy is
regenerated at test time from them, so nothing mock-specific is committed.

## Consequences

- Fixture behavior the tests rely on lives in one place in code (the
  `patchedFixtureData` function), versioned with the tests that need it.
- A future stripe-mock bump re-runs the patches automatically; a patch that
  no longer applies (missing resource) fails the tool loudly instead of
  silently degrading the tests.
- stripe-mock is stateless across requests in our use, so writes in one test
  do not affect what other tests read; the fixture base state is what every
  test starts from.
