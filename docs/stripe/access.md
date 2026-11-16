# How the app gets access to an account

Research note from milestone M0. Written from Stripe's documentation as of
2026-11-16, against API version 2026-10-28.endive (spec release v2600). The
decision this note feeds is decision 0003. Sources are listed at the end.

## The problem

Geist6 runs on an iPad with no server of its own. Every access method must
work with only a key (or token) the user controls on the device. Stripe
authenticates requests with API keys sent as HTTP Basic auth on `api.stripe.com`
(and `Bearer` tokens on `/v2`), so the question is which key types a third-party
iPad app can reasonably hold, and whether any flow that avoids holding a key
works without a server.

## Key types (Stripe's four)

| Type | Prefix | Unrestricted? | Safe to hold in an app? |
| --- | --- | --- | --- |
| Publishable key | `pk_` | No — tokenization and client-side use only; cannot read account data | Rejected at setup: it cannot do what the app exists to do |
| Restricted API key (RAK) | `rk_` | No — only the permissions granted per resource (None / Read / Write) | **Recommended**: least-privilege key, per Stripe |
| Secret key | `sk_` | Yes — every API resource | Allowed only with a warning; Stripe recommends RAKs instead |
| Organization key | `sk_org_` | Yes, at organization level over multiple accounts | Allowed with the same warning; useful for users with orgs, but it is a full-power key |

Notes from the docs: all Stripe APIs support restricted keys; write implies
read (a key that can write a resource can also read it); keys are revealed
once at creation in live mode and cannot be recovered; keys can be expired,
rotated, named, and annotated in the Dashboard; access policies (IP/ASN
allowlists, blocking VPNs, proxies, Tor) have replaced per-key IP
restrictions — an iPad has no fixed IP, so a live key used by the app must not
carry an IP allowlist, and the setup flow should say so.

Stripe now also tags RAKs as "agent keys" (created with the option
"Authorizing agent access to your account"); agent-tagged keys behave the same
but are subject to Stripe's approval rules that require a designated reviewer
to approve sensitive actions such as payouts, refunds, and account
configuration changes. Geist6 is exactly the kind of tool those rules protect
against, so setup should recommend creating the key as an agent key when the
user intends the app to act on its own.

## Access methods considered

### 1. Restricted API key the user creates (chosen)

The user creates a RAK in the Stripe Dashboard (API keys page: **Create
restricted key**), grants the Dashboard or Management permission set from
`permissions.md`, and pastes the key into the app. Setup then:

- checks the prefix (`rk_test_`, `rk_live_`, `sk_test_`, `sk_live_`,
  `sk_org_`, sandboxes' `*_test_` keys) to learn mode and type before sending
  anything;
- calls `GET /v1/account` to confirm the key works and to show the account's
  business name and country;
- builds the permission map from cheap read-only probes (`limit=1` list calls)
  plus Stripe's error messages, which name the permission to add.

What it can do: everything the granted permissions allow, in the account the
key belongs to. What it cannot do: anything not granted; and key management
itself — Stripe exposes no API to create, edit, or revoke API keys (no
`/v1/keys` endpoints exist in the pinned spec), so rotation and revocation
always happen in the Dashboard; the app can only detect a dead key (401) and
point at the Dashboard.

Revocation: the user expires or rotates the key in the Dashboard; the app
loses access at the next request (401) and can offer to remove the stored key.

### 2. Secret key (fallback with a warning)

Accepted after a clear warning that it can read and change everything in the
account, is badged in the UI everywhere it is active, and that the Dashboard
mode (read-only enforced in the client) matters more for such keys. Stripe's
own guidance is to prefer RAKs, so setup ranks RAK first and secret second.

### 3. OAuth as a Connect platform (out of scope for v1.0.0)

Stripe's Connect OAuth flow ("Connect with Stripe" button to
`connect.stripe.com/oauth/authorize`, then a token exchange at
`connect.stripe.com/oauth/token`) requires the *platform's* secret key to
complete: the token request is authenticated with the platform's secret key,
and Stripe says OAuth is not recommended for new Connect platforms. A
third-party app would have to be a registered platform with a `client_id` and
hold a platform secret to exchange codes — a secret that must not live in a
distributed app, which would in practice mean a server. Stripe offers no
public-client/device-code OAuth flow for the API. Conclusion: out of scope for
v1.0.0; listed in After v1.0.0 with the reason.

A Connect *platform user* can still use the app today with method 1: their
platform key plus the `Stripe-Account` header acts on connected accounts, and
the app treats each connected account as an explicit target (see `permissions.md`
for the connected-account permission column).

### 4. Stripe Apps with RAK authentication (future distribution channel)

A published Stripe App can be configured so that installing users generate a
RAK pre-provisioned with the app's declared permissions ("View API keys" on
the app's settings page). This removes the manual permission picker from
setup — the closest thing Stripe offers to a pre-filled restricted-key link —
but requires building and uploading a Stripe App (CLI, manifest, review) and
possibly a marketplace listing. It is a distribution channel, not an
authentication protocol: the user still copies an `rk_` key into the app.
Recorded as a candidate for After v1.0.0; v1.0.0 ships method 1.

### 5. Organization keys (`sk_org_`)

Accepted like a secret key (with the same warning). An organization key
operates across the org's accounts; the app would surface org accounts as
separate entries. Not the recommended path, but it costs nothing to accept
since authentication is identical.

## What setup therefore looks like

The shortest Stripe-supported path with no server: mode choice (Dashboard or
Management) → show the exact permission list with a deep link to the Dashboard
API keys page → user creates an `rk_` key and pastes it (or scans a QR of it
shown on another device) → app validates prefix and mode, calls
`GET /v1/account`, shows account name/country and the permission map →
optional second key (test mode or sandbox) → done. Two minutes is achievable;
the manual permission picking is the slowest part, and only Stripe Apps
distribution would remove it.

## Sources

- `https://docs.stripe.com/keys.md` — key types, sandbox vs live, agent keys, protecting keys, access policies
- `https://docs.stripe.com/keys/restricted-api-keys.md` — RAK creation, permissions, migration from secret keys
- `https://docs.stripe.com/keys/organization-api-keys.md` — organization keys
- `https://docs.stripe.com/keys-best-practices.md` — key handling guidance
- `https://docs.stripe.com/connect/oauth-standard-accounts.md` and `https://docs.stripe.com/connect/oauth-reference.md` — OAuth flow; token exchange authenticated with the platform secret key
- `https://docs.stripe.com/stripe-apps/api-authentication/rak.md` — Stripe Apps RAK authentication
- `https://docs.stripe.com/connect/authentication.md` — `Stripe-Account` header for connected accounts
- `https://docs.stripe.com/api/authentication.md` — Basic/Bearer authentication
- Pinned spec: no key-management endpoints exist (searched `components.schemas` and `paths` for key/permission management resources)
