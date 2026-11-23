# 0032: M8 Connect scope split — v1 rows mock-tested, v2 rows fixture-tested

## Context

M8 (Connect) has tier-2 rows on both API namespaces. The pinned spec generates
full client support for both: the v1 rows (`/v1/accounts`,
`/v1/accounts/{a}/capabilities|persons|external_accounts`, `/v1/account_links`,
`/v1/accounts/{a}/login_links`, `/v1/account_sessions`,
`/v1/application_fees[/{id}/refunds]`) and the v2 rows (`/v2/core/accounts`,
`/v2/core/account_links`, `/v2/core/accounts/{a}/persons`,
`/v2/core/account_tokens`, `/v2/core/accounts/{a}/person_tokens`).
stripe-mock 0.206.0 serves only the `/v1` namespace: every v1 row above
returns 200, while `/v2/core/*` returns 404 (probed; the mock implements
only v1). The M10 done-when already establishes the pattern for v2:
recorded response fixtures written by hand with obviously fake values.

The tier-3 vault rows (`GbBankAccount`, `UsBankAccount` under
`/v2/core/vault/*`, including microdeposits verbs) defer to M10 with the
other tier-3 rows, per ROADMAP.md's milestone rule that tier-2 rows may be
pulled early but tier-3 waits for the descriptor layer.

## Decision

- Slice 1 (this milestone's opening slice): connected-accounts list
  (GET /v1/accounts with the platform key), connected-account detail
  (retrieve + capabilities + persons + external accounts sections), the
  `Stripe-Account` targeting plumbing, and the always-visible active
  connected-account banner. All reads.
- Slice 2: the write verbs the spec generates — account link (v1), login
  link, account session, capability update, person create/update/delete,
  external-account delete, fee-refund create/update — through a
  `ConnectWriteService` with idempotency keys and the dashboard-lock gate.
- v1 rows: tested against stripe-mock (decode fixtures from mock samples,
  server-param recorder tests, UI tests).
- v2 rows: data-layer tests against hand-written recorded fixtures only
  (the mock cannot serve them); the UI presents v2 accounts through the
  same Connect screens when the platform key is a v2-era key. The v2
  client methods are exercised through recorded-response fixtures at the
  package layer; no UI test can drive them until stripe-mock grows v2.
- Tier-3 vault rows: M10.
- Platform-key detection: a key string alone cannot distinguish a platform
  key from a plain account key; the app detects platform capability at
  first connected-accounts load — a 200 list means platform, a 403 means
  the Connect section shows "not a platform key" instead of an error.

## Consequences

- Every v1 M8 row is provable green this milestone; v2 rows carry the
  same decode/param rigor at the package layer with fixtures, and are
  re-verified when a v2-capable mock exists (M10 contract tests).
- The Connect screens read through a `ConnectBackend` protocol so fixture
  stubs and the StripeClient conformance stay interchangeable, matching
  the payments/balances pattern.
- Acting on a connected account's own resources (charges, payouts,
  balances on the connected account) happens by rebuilding the client
  with `stripeAccount` set — the same screens, scoped to the connected
  account, which is how the done-when's "platform test" is proven.
