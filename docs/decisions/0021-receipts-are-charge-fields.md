# Decision 0021: Receipts are charge fields, not a standalone resource

## Context

M4's payment coverage includes "receipts". The pinned specification
(`stripe/openapi` `latest/openapi.spec3.sdk.json`, API version
2026-10-28.endive, the source every generated model and client is built from)
contains no standalone Receipt resource: no `/v1/receipts` paths, no
`v1.receipt` schema. The same is true of the live spec at review time
(2026-11-18.endive). Stripe's OpenAPI definition simply does not model the
receipts API, and the generator — which is the only allowed source of models
— therefore emits nothing for it.

What the specification does model are receipt fields on payment objects:
`receipt_email`, `receipt_number`, and `receipt_url` on a Charge, and
`receipt_email` on a PaymentIntent. `receipt_url` points at the hosted
receipt page Stripe generates for the charge.

## Decision

"Receipts" in M4 is satisfied by surfacing the charge's receipt fields: the
receipt email and number shown on the charge detail screen, and `receipt_url`
offered as a link that opens the hosted receipt. There is no standalone
Receipt list or detail screen, and no hand-written Receipt model — the
"never hand-write a model the generator can produce" rule extends to a
resource the generator cannot produce at all.

## Consequences

- The charge detail view gains a receipt section (email, number, hosted
  receipt link); the PaymentIntent detail already carries the receipt email.
- The coverage matrix records receipts through these charge fields, not as
  resource rows; `GET /v1/receipts` and the PDF download endpoint stay out of
  scope until Stripe's specification models them.
- If Stripe adds the receipts API to the OpenAPI definition, a regeneration
  produces the models and this decision is reopened.
