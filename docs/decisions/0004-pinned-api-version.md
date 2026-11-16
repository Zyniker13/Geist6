# 0004: The pinned API version and the upgrade policy

## Context

`docs/stripe/versioning.md` records how Stripe versions the API: monthly
non-breaking releases inside twice-yearly majors, an account default version
that requests can override per call, a mandatory `Stripe-Version` header on
`/v2`, and a separate `.preview` version family for public-preview endpoints.
Stripe's official OpenAPI repository publishes one file per release in two
variants: the public spec and the SDK spec.

## Decision

- Pin **API version 2026-10-28.endive** (the current GA monthly version),
  taken from Stripe's official OpenAPI release **v2600**, file
  `latest/openapi.spec3.sdk.json`, committed under
  `Sources/StripeSpec/Resources/openapi.spec3.sdk.json`.
- **Why the SDK variant:** it carries Stripe's generator annotations
  (`x-stripeResource`, `x-stripeOperations`, `x-expandableFields`,
  `x-expansionResources`, `x-stripeMostCommon`, polymorphic groups) that the
  model generator, the tier-2 descriptor engine, and `Tools/inventory` all
  read; the public spec omits them and keeps legacy alias paths (for example
  `/v1/accounts/{id}/bank_accounts`, `/v1/balance/history`) that the SDK spec
  has already consolidated.
- Every request sends `Stripe-Version: 2026-10-28.endive`, so responses match
  the pinned models regardless of each account's default version. Preview
  endpoints are out of scope: they are absent from the pinned GA spec.
- **Upgrade policy:** monthly non-breaking releases are taken promptly by
  bumping the pinned file, regenerating models and the inventory, and
  reviewing that release's changelog entries; the pin is updated in the two
  places it lives (the spec resource and the `StripeSpec.pinnedAPIVersion`
  constant). Major releases (the next after Endive) get the same steps plus a
  deliberate review of the breaking changes before the pin moves. CI fails
  when generated code or the generated docs no longer match the pinned file,
  so a spec bump cannot be merged half-done.

## Consequences

- Model generation and the coverage matrix are always exactly as wide as the
  pinned GA API; "full Stripe feature support" is measured against that file
  (`Tools/inventory check`), not against memory.
- New Stripe fields between pins decode losslessly (kept as raw values), so
  the app keeps working between pin updates.
- The repository carries a ~9 MB vendored spec; acceptable, and it is the
  machine-readable source of truth for everything downstream.
