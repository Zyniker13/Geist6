# 0028: Tolerant union tag branches and the legacy-required exemption list

## Context

The subscriptions slice's decode tests failed in two places, both in
generated code:

1. `SubscriptionCustomer` (and every union where a full object and its
   deleted twin share the `object` tag) emitted a hard `try` decode for
   each tag branch, with the full object listed first. A deleted-customer
   payload therefore threw `keyNotFound: 'created'` instead of reaching
   the `deletedCustomer` branch.
2. The pinned OpenAPI spec marks `subscription_item.plan` required, but
   Stripe omits it on subscription items in practice (stripe-mock follows
   the live API). The generated non-optional `Plan` field made every
   subscription decode against the mock throw `keyNotFound: 'plan'`.

## Decision

- In `stripe-gen`, union tag branches now decode with a `try?` guard and
  fall through to the tolerant chain: `if tag == "x", let v = try?
  container.decode(T.self)`. Decode order is preserved (full object wins
  on complete data; the deleted twin wins when the payload only fits it);
  losslessness is unchanged — payloads that fit nothing land in `other`.
- The generator carries a `legacyRequiredOptional` set for fields the
  spec marks required but Stripe does not always send. Entries are
  `"<Struct>.<field>"`; such fields emit as plain optionals with
  `decodeIfPresent`. The list currently contains one entry,
  `SubscriptionItem.plan`. A general "all required $refs are tolerant"
  rule was rejected: it sweeps 544 sites and would need a fake
  default-constructed value (`?? Base()`) that does not exist for most
  referenced structs and would fabricate hollow objects — worse than nil.

## Consequences

- Deleted-object payloads decode as the deleted variant everywhere the
  twin shares the tag, instead of throwing.
- `SubscriptionItem.plan` is now `Plan?`; absence decodes as nil. UI and
  service code does not read `plan`, so no call sites changed.
- Regeneration touched 28 files (tag branches across all unions plus the
  plan change); the generator and generated files stay in lockstep, and
  CI still regenerates and fails on any diff.
- New decode tests cover both behaviors: deleted-customer payloads
  resolve to `.deletedCustomer`, and a subscription item without `plan`
  decodes with `plan == nil`.
