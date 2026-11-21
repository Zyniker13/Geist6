# 0025 — Deterministic client naming for colliding operations

## Context

The generated `StripeClient` names its methods from the last path segment
(`/v1/climate/products` and `/v1/products` both became `listProducts`) and
names params structs from the resource class name plus the spec method name
(both wanted `ProductListParams`). Two behaviors hid this:

1. On a params-name collision the generator silently dropped the struct, so
   654 operations were emitted with no way to send filters or request bodies.
2. Method-name dedup ran per generated file, so cross-file pairs compiled
   into ambiguous overloads: with every operation now carrying its params
   struct, a bare call like `listProducts()` matched both the climate and
   the catalog product list and no longer compiled.

Stripe's API also has a v2 namespace that reuses many method names
(`accounts`, `events`, `disputes`, …), so the collision set is large — 47
method names collided across the generated client.

## Decision

All method and params names are assigned in one pre-pass over every
operation, before any emission, so naming never depends on file ordering.

- **Params structs** must be unique types. The canonical claimant of a
  contested base name is the operation with the fewest path segments (the
  top-level collection of the resource), ties broken by path string, and
  v2 operations always yield to v1. Everyone else gets a path-prefixed name
  (`ClimateProductListParams`), falling back to the full path when two
  operations share the first path segment.
- **Methods** keep the plain name unless a bare call could actually be
  ambiguous. Two same-name methods with different argument labels, or where
  one takes a required params value, are valid Swift overloads and resolve
  by label or type — so only fully-defaulted overloads with identical
  argument labels contest the name (`listProducts` for climate vs catalog;
  `listEvents` for v1 vs v2). The canonical claimant wins the plain name by
  the same rule as params; the rest are renamed after their leading verb
  (`listClimateProducts`, `listV2CoreEvents`).
- Where the old generator had renamed a method only within one file, the
  global rule produces cleaner names (`listTaxIds` with overloads
  `(customer:)` and `(_:)` instead of `listTaxIdsV1TaxIds`), and the few
  internal call sites that referenced the old names were updated.

## Consequences

- Every operation keeps its own params struct; nothing is silently dropped.
- Every bare call is unambiguous: the canonical operation always owns the
  plain method name, so `listProducts()` means the catalog product list.
- The v2 API surface is reachable with distinct names and is now emitted at
  all, which the old per-file dedup plus silent drops could not support.
- The rule is deterministic and stable under spec updates: a new resource
  can take a plain name only if it is the canonical (shortest-path) claimant.
- The generated tree changed wholesale; hand-written code needed updates
  only where it referenced the old per-file-renamed names (tax ids, refunds)
  or where the old params-less signatures were relied on.
