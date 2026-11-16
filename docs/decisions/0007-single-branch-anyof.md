# 0007: Fix single-branch anyOf generation and tolerant nullable decode

## Context

The first green run of the stripe-mock contract suite exposed two systemic
defects in the generated models:

1. Decoding any object that contains a field typed by a single-branch
   `anyOf` (Stripe uses `anyOf: [$ref X]` as a nullable-reference wrapper;
   431 such sites) crashed the process with a stack overflow. The crash
   report showed `ChargeFraudDetails.init(from:)` recursing into itself
   forever: the generator turned the single-branch `anyOf` into a union
   enum named after the branch, producing `indirect case
   chargeFraudDetails(ChargeFraudDetails)` whose `init(from:)` decodes
   itself unconditionally. 76 such self-recursive enums existed across the
   generated surface. Because the crash was a stack overflow, no `try?`
   or error handling could catch it, and it masqueraded as unrelated
   networking crashes during earlier debugging.
2. Decoding failed with `keyNotFound` for fields the spec marks
   `required`+`nullable` (for example `charge.source`, a legacy field
   stripe-mock omits). Stripe's live API also omits such keys routinely,
   so the generated decoder must not throw on absence.

## Decision

- In `stripe-gen`, a single-branch `anyOf`/`oneOf` now classifies directly
  as the branch type instead of emitting a union enum. Genuine multi-branch
  unions (including legitimately recursive ones) are unchanged.
- Required+nullable fields now decode with `decodeIfPresent(...) ?? .null`:
  absence is treated the same as explicit null. Optional fields unchanged.

## Consequences

- Every decode path on the generated surface is stack-safe and tolerant of
  absent nullable keys; the 76 poison enums are gone (type count changed
  from 11,078 to 10,762).
- The absent/explicit-null distinction collapses to `.null` for
  required+nullable fields; the `Nullable<T>?` optional shape still
  expresses absence where the spec allows it.
- Pagination and search wrappers (`ListResponse`, `SearchResponse`) gained
  explicit `has_more` CodingKeys for the same reason: hand-written models
  cannot rely on key renaming the generated models do explicitly.
- Retry policy now includes 5xx alongside 429: writes are idempotent, so
  replaying after a server failure is safe and matches Stripe's guidance.
- The full test suite (32 tests across four suites) passes against
  stripe-mock and stubs.

Verification: crash-report backtrace showed the recursion cycle; after the
fix, zero `indirect case` self-references remain in generated code and the
contract suite completes green.
