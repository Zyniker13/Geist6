# 0024 — Checkout Sessions belong to M6, not M4

## Context

The M4 roadmap line listed Checkout Sessions among payments work, but the
coverage matrix (regenerated from the pinned spec and reviewed five times in
M0) assigns all six `/v1/checkout/sessions` operations — list, retrieve,
line items, create, update, expire — to M6 (Billing), grouped with the
billing-portal session rows under the `Session` resource. M4's prose predates
the final matrix. During the M4 review pass this mismatch surfaced; the
matrix is the operative worklist ("feature milestones each cover their rows
of the coverage matrix"), and M6's prose never mentioned checkout sessions
either.

## Decision

Checkout Session coverage stays in M6, per the matrix. The M4 roadmap line
drops its Checkout Sessions mention; the M6 line gains it. The data layer
already carries `expireCheckoutSession` and the filter sheet a checkout
section from earlier M4 work; those are not moved — data-layer verbs are not
milestone-bound, and M6's screens will use them.

## Consequences

M4 closes with no Checkout Session screens built; that is not a gap against
the matrix, which never put them in M4. M6 must build the tier-2 list,
detail, edit, and expire flows for checkout sessions alongside the billing
portal sessions.
