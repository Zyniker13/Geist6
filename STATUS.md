# Status

Keep every field current after every meaningful step. This file and `ROADMAP.md` are the truth when work resumes.

- **Current milestone:** M0 (Stripe research and plan review), not started
- **Last done:** roadmap, testing plan, and status written; no code yet
- **Next step:** run the Environment Check below, then start M0.1 (gather the Stripe sources)
- **Blocked on:** nothing

## Environment Check

Do this once, before M0, and record the output here:

- `xcodebuild -version` and `xcrun simctl list runtimes`: the newest Xcode and an iPadOS simulator runtime are available.
- `xcrun simctl list devices available`: at least one 13-inch iPad Pro, one 11-inch iPad, and the base iPad simulator.
- `swift --version`, `xcodegen --version`, `swiftlint version`, `swift-format --version`, and `stripe-mock -version` (install missing tools with `brew install`; `stripe-mock` is in the `stripe/stripe-mock` tap).
- `curl -sI https://docs.stripe.com/llms.txt` and `curl -sI https://raw.githubusercontent.com/stripe/openapi/master/README.md` both return 200, so the research in M0 can reach its sources.

- (not run yet)

## Needs the Maintainer

One bullet per item: what is needed, why, and the milestone that needs it.

- (none yet; see "Needs the Maintainer" in `ROADMAP.md` for the expected ones)

## Plan Review Passes (M0.3)

| Pass | Lens | What changed | Still open |
| --- | --- | --- | --- |

## Log

- 2026-11-16: Roadmap written from general knowledge of Stripe; M0 checks it against Stripe's current documentation and API definition.
