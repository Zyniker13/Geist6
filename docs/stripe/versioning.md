# API versioning and the pinned version

Research note from milestone M0. Written from Stripe's documentation as of
2026-11-16, against API version 2026-10-28.endive (spec release v2600). The
decision this note feeds is decision 0004. Sources are listed at the end.

## How Stripe versions the API

Since the 2024-09-30.acacia release Stripe ships a new API version **monthly
with no breaking changes**, and a **major release twice a year** (Acacia,
Basil, Clover, Dahlia, and now Endive) that starts with a version containing
breaking changes. Version strings are dates plus a release codename and
suffix: `2026-10-28.endive` is the current GA monthly version in the Endive
major; `2026-10-28.preview` is the companion version for public-preview
endpoints. Recent majors: Basil → Clover (2026-01-28.clover) → Dahlia
(2026-03-25.dahlia) → Endive (2026-09-30.endive, current).

Every Stripe account has a **default API version** (set in Workbench), used
when a request sends no version header and for webhook event payloads unless
the endpoint was created with an explicit version. Any request can override
the version per call with the `Stripe-Version` header. Stripe's strongly typed
SDKs pin the version current at their release; Stripe's guidance is to
specify the version in code rather than rely on the account default.

## What the app does

1. **Pin one version: 2026-10-28.endive** (decision 0004). Every request —
   `/v1` and `/v2` — sends `Stripe-Version: 2026-10-28.endive`. Responses
   therefore always match the models generated from the pinned spec,
   regardless of what default version each account happens to sit on. This is
   exactly the account-version independence the roadmap requires.
2. **`/v2` requires the header.** The v2 namespace mandates `Stripe-Version`
   on every request; the client sends the pin unconditionally, which also
   satisfies this.
3. **Preview endpoints are out of scope.** The pinned GA spec contains no
   preview endpoints; features documented only under `.preview` versions are
   not in the inventory and need no rows in the coverage matrix. If the
   maintainer later wants a preview feature, that is a decision to re-pin (or
   additionally pin) the preview spec.
4. **Events and versioning.** `/v1` snapshot events are frozen at the version
   in force when they were created; retrieving them with a newer header does
   not reshape them. The app decodes event payloads losslessly (unknown
   fields kept) so historical events still open cleanly.
5. **Lossless decoding as the version hedge.** Between pins, Stripe may add
   fields or enum values to responses. The generated models keep unknown
   JSON fields and unknown enum cases, so an added field is visible (raw view)
   rather than a decode failure, and the app keeps working until the next pin.

## Upgrade policy

- **Monthly releases:** safe by Stripe's process. The build agent bumps the
  pinned spec, regenerates models (`stripe-gen`), reruns the inventory check,
  and reviews the changelog entries for that release. No roadmap change is
  needed for a non-breaking monthly bump; the pinned-version decision record
  gets an addendum line.
- **Major releases:** treated like a small project. Read the major release's
  changelog, regenerate, fix what breaks, and record the new pin in decision
  0004 with the reasons. CI (the generator regeneration check) fails the build
  until the models match the newly pinned spec, so drift cannot be merged.
- **The pin lives in exactly two places**: the spec file under
  `Sources/StripeSpec/Resources/` and the version constant in StripeSpec;
  `Tools/inventory check` fails if either drifts from the other.

## What "newer or older than the pin" means in the UI

The app is the same for every account: it always speaks `2026-10-28.endive`.
Accounts on older defaults simply get responses rendered per our pin (the
header wins). The only visible artifact is that objects created or updated
under the account's own tooling (Stripe Dashboard, other SDKs) may have been
rendered under a different version at their write time; the app shows what
the API returns now, which is the pin's shape.

## Sources

- `https://docs.stripe.com/api/versioning.md` — monthly process, majors, current version string, per-request override, account default
- `https://docs.stripe.com/upgrades.md` — upgrade steps, specify the version in code, event destination `snapshot_api_version`
- `https://docs.stripe.com/changelog.md` — version list and per-release entries (Basil, Clover, Dahlia, Endive; 2026-10-28.endive current)
- `https://docs.stripe.com/api-v2-overview.md` — v2 requires `Stripe-Version`; thin events unversioned
- Pinned spec: `info.version` = 2026-10-28.endive at release v2600
