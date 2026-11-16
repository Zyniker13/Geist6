# 0003: How the app gets access to an account

## Context

`docs/stripe/access.md` evaluated every access method Stripe offers against
one constraint: Geist6 is a native iPad app with no server, holding only what
the user gives it. Stripe authenticates with API keys (HTTP Basic on `/v1`,
Bearer on `/v2`); key management itself has no API; Connect OAuth's token
exchange requires the platform's secret key; Stripe Apps can pre-provision a
restricted key but require publishing an app first.

## Decision

Setup recommends a **restricted API key (RAK) the user creates** in the
Dashboard, with the Dashboard or Management permission set from
`docs/stripe/permissions.md`. Setup:

- ranks RAK first and says why (least privilege; Stripe's own recommendation,
  including for tools that act like agents);
- accepts `rk_test_` / `rk_live_` / sandbox test keys, and `sk_` or `sk_org_`
  only after a clear warning that they are unrestricted, with a permanent
  badge in the UI; rejects `pk_` with an explanation;
- validates by prefix and then by calling `GET /v1/account`, shows the
  account's name and country, and builds the permission map from read-only
  probes and Stripe's permission-naming error messages;
- links to the Dashboard API keys page and lists the exact permissions to
  tick, because Stripe offers no pre-filled restricted-key link for general
  apps;
- recommends tagging the key as an agent key ("Authorizing agent access")
  when the user wants Stripe's approval rules over sensitive actions.

Out of scope for v1.0.0, with reasons recorded in After v1.0.0: Connect OAuth
(needs a platform secret key for the token exchange, so a server or an
unsafe embedded secret) and Stripe Apps distribution (publishing an app is
its own project; revisit as a distribution channel that would pre-fill key
permissions). Connect platforms use the app with their own RAK and the
`Stripe-Account` header; the app treats connected accounts as explicit,
visible targets.

## Consequences

- No account-creation or key-creation flow is possible in-app; rotation and
  revocation happen in the Dashboard, and the app detects dead keys (401) and
  points there.
- Every account holds keys per mode in the Keychain only (roadmap rules);
  the QR-code handoff path displays a key shown on another device and never
  persists it outside the Keychain.
- The permission map must degrade gracefully: features hidden, not crashed,
  when a key lacks a permission.
