# 0029: The stripe-mock overlay spec

## Context

stripe-mock 0.206.0's bundled OpenAPI definition is older than the pinned
Stripe spec (2026-10-28.endive, decision 0004). Its `product` schema lacks
the `type` field our pinned spec requires, so the mock's response synthesis
drops `type` and the generated `Product` model — which requires it — cannot
decode the mock's product responses. Decision 0027 recorded the symptom and
its known follow-up: catalog UI tests that need product rows against
stripe-mock require a fixture/spec overlay for the mock, "generated at test
time from pinned upstream files, not vendored wholesale into the repository."

## Decision

A new tool, `Tools/mock-overlay`, builds the overlay at test time:

1. It ensures the two upstream files are in a cache directory: stripe-mock
   v0.206.0's `embedded/openapi/spec3.json` and `fixtures3.json`, fetched
   from the GitHub tag and verified against recorded SHA-256 digests. A
   cache entry with a wrong digest is refetched; a fetched file whose
   digest differs from the recorded pin is a hard error, so an upstream
   change can never silently flow in — the pin moves deliberately.
2. It copies the missing schema properties from the pinned Stripe spec
   into the mock's spec (today: `product.type`) and writes
   `overlay-spec3.json` beside the fixtures.
3. It prints the two paths; `scripts/check.sh` passes them to
   `stripe-mock --spec <overlay> --fixtures <fixtures>`.

The upstream files are never committed: the repository records only the
release tag, the digests, and the patch list. The MockServerTests harness
still boots a plain mock on a free port, because those contract tests use
hand-written fixtures and do not depend on `product.type`.

## Consequences

- The mock now serves `type: "good"` on product list, retrieve, and create
  responses, so catalog UI tests can assert on real product rows.
- New schema gaps surface as decode failures in tests, not as silent mock
  drift; each is added to `overlayProperties()` with a test that proves it.
- The overlay build needs network on first use per cache directory (CI and
  a clean machine), then is cached; the digest check keeps the cache honest.
- Bumping the stripe-mock pin (check.sh, CI, and this tool's tag and
  digests together) is one deliberate change.
