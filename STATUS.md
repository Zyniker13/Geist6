# Status

Keep every field current after every meaningful step. This file and `ROADMAP.md` are the truth when work resumes.

- **Current milestone:** M1 (Foundation), core complete — app build verifying
- **Last done:** `stripe-gen` emits the full surface (660 operations, 11,078 types) and the whole package compiles; `swift test` green (inventory checks); committed generator fixes, CI workflow, check.sh, XcodeGen project, and the app skeleton
- **Next step:** verify the iPad app build (running), run lint gates, push, confirm CI green; then finish M1 (StripeClient against stripe-mock tests) and close M1
- **Blocked on:** nothing

## Environment Check

Do this once, before M0, and record the output here:

- `xcodebuild -version` and `xcrun simctl list runtimes`: the newest Xcode and an iPadOS simulator runtime are available.
- `xcrun simctl list devices available`: at least one 13-inch iPad Pro, one 11-inch iPad, and the base iPad simulator.
- `swift --version`, `xcodegen --version`, `swiftlint version`, `swift-format --version`, and `stripe-mock -version` (install missing tools with `brew install`; `stripe-mock` is in the `stripe/stripe-mock` tap).
- `curl -sI https://docs.stripe.com/llms.txt` and `curl -sI https://raw.githubusercontent.com/stripe/openapi/master/README.md` both return 200, so the research in M0 can reach its sources.

- Xcode 27.2 (Build 27B52); `xcrun simctl list runtimes`: iOS/iPadOS 27.2 runtime installed (plus tvOS and watchOS 27.2).
- `xcrun simctl list devices available`: iPad Pro 13-inch (M5), iPad Pro 11-inch (M5), iPad (A16), plus iPad mini and iPad Air variants — all required simulators present.
- Swift 6.4.2 (Apple, arm64); XcodeGen 2.46.0; SwiftLint 0.65.1; swift-format 604.0.0; stripe-mock 0.206.0. Nothing missing.
- `https://docs.stripe.com/llms.txt` returns 200; `https://raw.githubusercontent.com/stripe/openapi/master/README.md` returns 200.

Checked 2026-11-16; all checks pass, nothing to install.

## Needs the Maintainer

One bullet per item: what is needed, why, and the milestone that needs it.

- An optional Stripe sandbox and its restricted keys for local end-to-end tests (`stripe sandbox create` works without registration, but the keys stay with the maintainer and never enter the repository) — from M2 on.
- The final product name, chosen from decision 0006's candidates, with an App Store/trademark collision check — by M15.
- The Apple Developer and App Store Connect steps: bundle ID, signing, TestFlight, pricing, submission — at M15.
- Publishing the support page and privacy policy — at M15.

## Plan Review Passes (M0.3)

| Pass | Lens | What changed | Still open |
| --- | --- | --- | --- |
| 1 | Stripe compliance | Idempotency rule corrected to the verbs Stripe honors (`/v1` POST; `/v2` POST and DELETE; `/v1` DELETE idempotent by definition). Dispute evidence flow confirmed correct against the spec (evidence on the update, `close` endpoint; "submit" is an update parameter). Setup key validation and OAuth findings written into `docs/stripe/access.md` (OAuth needs a platform secret key; no pre-filled RAK link exists). | none |
| 2 | Coverage | All 162 resources and 687 operations now have matrix rows. Moved rows: v2 core accounts/persons/links to M8 (GA for Connect platforms, preview otherwise), v2 events and event destinations to M11, Mandates/Confirmation Tokens/PaymentIntent line items to M4, PaymentSource to M5, CustomerSession to M6, ExternalAccount and FeeRefund to M8. M4 and M8 text updated to match. | none |
| 3 | Safety | Matrix verified: every write row carries the idempotency and confirmation requirements from Keys and Safety; Dashboard mode blocks all writes in the client (tested from M1), so no money-moving action is reachable in Dashboard mode. Explorer writes are Management-mode and permission-gated. Matrix header now states this. | none |
| 4 | Order and achievability | `stripe-mock` verified empirically: serves `/v1` only (431 paths, 612 endpoints); `/v2` returns 404. M10's done-when and TESTING.md amended: `/v2` contract coverage comes from hand-written fixtures. Also found stripe-mock's flags changed (`-http-port`, no `-https false`) — recorded for M1's check.sh. `docs/metrics.md` assigned to M3 (needed by the home figures). | none |
| 5 | Scope and clarity | Setup resolved to the "otherwise" branch (no pre-filled RAK link): link to the Dashboard API keys page and list the exact boxes to tick. Two-minute setup stays achievable (paste key, few taps). No material change needed. | none |

## Log

- 2026-11-16: Roadmap written from general knowledge of Stripe; M0 checks it against Stripe's current documentation and API definition.
- 2026-11-16: Environment check passed (Xcode 27.2, iPadOS 27.2 runtime, Swift 6.4.2, XcodeGen 2.46.0, SwiftLint 0.65.1, swift-format 604.0.0, stripe-mock 0.206.0; both source URLs 200).
- 2026-11-16: M0: pinned Stripe's OpenAPI spec (release v2600, API version 2026-10-28.endive) and built `Tools/inventory`; generated `api-inventory.md`, `coverage-matrix.md`, and `api-inventory.json` (162 resources, 687 operations). Wrote the research notes in `docs/stripe/` (access, permissions, limits, versioning, events, brand) from the fetched Stripe pages; recorded decisions 0001–0006; logged the five review passes; filed the maintainer items. M0's done-when is met: notes cite sources, the tool's output matches the committed files, every resource has matrix rows, the fifth pass made no material change.
- 2026-11-16: M1 core: `stripe-gen` now generates the whole surface — 660 operations, 11,078 types (objects, lossless enums, unions, expandable/clearable/nullable wrappers, params structs, list containers, typed client methods) — and the full package compiles; `swift test` green. Fixed generator bugs found by the compiler: schema-key name collisions (dot vs underscore), const discriminators, recursive unions, empty CodingKeys, list-type dedup, missing imports. Added `scripts/check.sh`, `.github/workflows/ci.yml`, SwiftLint config, XcodeGen project, and the app entry skeleton. App build verification and lint gates next, then push.
