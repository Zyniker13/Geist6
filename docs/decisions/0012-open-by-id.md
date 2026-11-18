# 0012 — Universal open-by-ID and raw object view

## Context

M3 requires "a universal 'open by ID' for any Stripe object ID" that
opens a basic object view. The data layer so far retrieves only typed
objects (charge, customer) through `StripeDataBackend`. Stripe object
IDs carry their kind in a prefix (`ch_`, `cus_`, `pi_`, `in_`, `sub_`,
`re_`, `po_`, `evt_`, `txn_`, `prod_`, `price_`, `acct_`, `tr_`,
`fee_`), so the collection path is derivable without a registry API.

## Decision

- `GeistData` gains a `StripeObjectKind` enum mapping ID prefix to the
  `/v1` collection path, matching known prefixes and rejecting
  unknown ones (including non-Stripe strings) rather than guessing.
- `StripeDataBackend` gains one method, `rawObject(path:) async throws
  -> Data`, backed by `StripeClient.perform` (which returns the raw
  response). Extending the protocol is acceptable: Geist6 is a private
  app, all conformers are in this repository, and the method is a
  read-only GET.
- `ObjectByIDService.fetch(_:)` resolves the prefix, fetches the raw
  body, and decodes it into a small `StripeJSON` tree in the package,
  so mapping and decoding are unit-testable without the app target.
- The app renders the decoded tree as a basic key/value list
  (`ObjectDetailView`). Typed, friendly detail views for charges and
  customers exist because search targets them; every other kind gets
  the generic view. Additional typed views can be added in later
  milestones without touching the routing.

## Consequences

- A wrong-but-well-formed ID (e.g. `ch_` + garbage) surfaces the
  backend error (404) as a load failure — honest behavior, and the
  stripe-mock fixtures accept arbitrary IDs so tests are stable.
- The generic view shows raw field names; it is a fallback, not the
  long-term presentation for major objects.
- `rawObject` is GET-only; it cannot be used to write, and dashboard
  mode's write refusal in `perform` is unaffected.
