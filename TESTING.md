# Testing

The app shows people's money and can move it, so testing is part of the design, not a step at the end. This file lists every suite, what it proves, and how to run it. Keep it true: when a suite is added, changed, or moved, update this file in the same commit.

## The Rules

1. **Every behavior has a test.** Logic lives in the Swift package and is tested with `swift test` on macOS and Linux; the user interface is tested with UI tests on the iPad simulator.
2. **Every bug gets a regression test** before it is fixed, with a comment saying what it caught.
3. **Dashboard mode is read-only, provably.** A test sends every non-GET request the client can build through a Dashboard-mode client and checks that each one is refused before it reaches the network.
4. **No live Stripe data in tests.** CI uses `stripe-mock` and fixtures only. A Stripe sandbox, if one is available, is used only locally; its key never enters the repository, a log, or a fixture.
5. **Keys never leak.** Tests check that keys never appear in the cache, logs, exports, the audit log, copy-as-curl output, or crash output.
6. **Local and CI are the same.** `scripts/check.sh` runs what CI runs. Jobs that need Xcode run when Xcode is present and are skipped with a clear message when it is not.
7. **No test is skipped to get green.** A failing test is fixed, or the behavior it checks is changed by a decision record.

## Suites

Paths and commands are the plan; fill in the real ones as each suite is built.

Built so far (as of M2): inventory, decoding, client contract, dashboard mode, key safety, UI tests. The remaining suites land with their milestones.

| Suite | Proves | Where | Runs |
| --- | --- | --- | --- |
| Generator | The generated models match the pinned spec; regeneration produces no diff | `Tests/GeneratorTests/`, CI regeneration check | every CI run |
| Inventory and coverage | Every resource and action in the pinned spec has a coverage-matrix row, and every in-scope row is reachable at its tier | `Tools/inventory --check` | every CI run |
| Decoding | Every fixture object decodes losslessly, including unknown fields and enum values, nulls, and expanded and unexpanded fields | `Tests/ModelsTests/` | every CI run |
| Client contract | Every endpoint works against `stripe-mock`: encoding, pagination, search, expansion, files, idempotency, retries, and every error type (`/v1`; `stripe-mock` serves only `/v1`, so `/v2` endpoints get the same coverage against hand-written response fixtures with obviously fake values) | `Tests/ClientTests/` | every CI run, macOS and Linux |
| Dashboard mode | No write request can be sent in Dashboard mode | `Tests/ClientTests/ReadOnlyTests` | every CI run |
| Money and metrics | Formatting in every currency, and dashboard and billing metrics against hand-checked fixtures | `Tests/ConsoleTests/` | every CI run |
| Key safety | Keys never reach the cache, logs, exports, or copy-as-curl | `TestsApp/KeySafetyTests.swift` (app unit target; key not in debug descriptions, store metadata, or client error text) | every CI run on macOS |
| UI tests | Main flows work end to end on the iPad simulator against `stripe-mock` | `TestsAppUI/` (scheme `Geist6`; runner takes `--api-base-url=http://127.0.0.1:12111`) | every CI run on macOS |
| Accessibility audits | Every screen passes automated accessibility checks | the app's UI test target | every CI run on macOS |
| Performance | Cold start, scrolling, and large caches stay within the M14 budgets | package benchmarks and UI test metrics | every CI run, full runs locally |
| Coverage | Which lines no test reaches | `swift test --enable-code-coverage` | every CI run, threshold enforced for the package |

## Running Everything

```sh
scripts/check.sh            # what CI runs
```

Individual commands as they exist today:

```sh
swift test                  # package logic tests (34 tests, ~5 s)
# Xcode app target (unit + UI, 44 tests; needs the simulator and stripe-mock on :12111):
xcodegen generate
xcodebuild -project Geist6.xcodeproj -scheme Geist6 \
  -destination 'platform=iOS Simulator,name=iPad (A16),OS=latest' \
  -derivedDataPath /tmp/geist6-dd test
```

## Results

Record the latest results here: coverage per package target, benchmark numbers against the budgets, the manual passes, and the date of each.
