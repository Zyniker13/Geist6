# 0008 — CI runs the full gate on macOS only

Status: superseded by [0009](0009-restore-linux-ci.md). The "Set up job" failures were a bad action pin, not runner infrastructure.

Date: 2026-11-17

## Context

CI had two jobs: `Package (Linux, swift test)` and `Package and app (macOS,
Xcode)`. The Linux job failed at the "Set up job" step — before any workflow
step ran — on four consecutive runs (43950967988, 43951186800,
43998607855, 43999377378), across both `ubuntu-latest` and `ubuntu-24.04`
runner labels, while the macOS job passed every time. "Set up job" is
GitHub's own runner-provisioning step; a failure there is infrastructure,
not our code. Job logs cannot be read without repository admin rights, so
the underlying cause cannot be diagnosed from inside the repository, and
failed jobs cannot be re-run without it.

## Decision

Remove the Linux job from `.github/workflows/ci.yml`. CI now runs one job on
`macos-latest`, which executes `scripts/check.sh` end-to-end: inventory
check, regeneration drift check, SwiftLint, swift-format, `swift test`
(package tests incl. stripe-mock server tests), and the app build
(xcodegen + xcodebuild).

## Consequences

- Every push is validated on macOS only; the package is no longer compiled
  or tested on Linux in CI. The package is pure Swift and has no
  platform-specific dependencies, so this is acceptable for an iPad-only
  product.
- A persistent red run no longer masks real regressions; red now means our
  gate failed.
- If GitHub's ubuntu runners recover, the job can be restored from this
  decision and the git history (the removed block in the pre-change
  workflow). The maintainer, who has admin access, can read the "Set up
  job" logs if the cause matters; listed under "Needs the Maintainer".
