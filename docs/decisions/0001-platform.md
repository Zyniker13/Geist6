# 0001: Platform, OS versions, and the portable core

## Context

The roadmap fixed the platform (native iPad app in Swift 6 and SwiftUI) but
left the exact OS targets to be set in M1 from the build machine's toolchain.
The environment check (STATUS.md, 2026-11-16) found Xcode 27.2 with the
iPadOS/iOS 27.2 simulator runtime, Swift 6.4.2, and simulators for iPad Pro
13-inch and 11-inch and base iPad.

## Decision

- Targets: iPad only, built with the iOS 27.2 SDK, deployment target
  **iPadOS 26.0** — the newest iPadOS Xcode supports and one major version
  back, as the roadmap requires. The app also runs on Apple silicon Macs as
  an iPad app (no separate Mac target).
- Swift language mode: Swift 6 with strict concurrency. SwiftPM tools version
  6.2 (the manifest needs 6.2 to express the iOS 26 platform).
- Package layout as in `ROADMAP.md`: everything without UI (spec, generated
  models, client, console logic) builds and tests with the Swift toolchain
  alone on macOS and Linux; Keychain, SwiftUI, Charts, App Intents, and
  WidgetKit stay in the thin app layer above it.

## Consequences

- UI test and simulator work uses iPad Pro 13-inch (M5), iPad Pro 11-inch
  (M5), and iPad (A16) simulators on iPadOS 27.2.
- CI's Linux job tests the package with a current stable Swift (6.2 or
  newer); no Swift version is pinned against an image SDK.
- iPadOS 26 as the floor: APIs newer than iPadOS 26 must be gated with
  availability checks or skipped.
