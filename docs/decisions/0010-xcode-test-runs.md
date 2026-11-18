# 0010 — Xcode test runs: solo machine, two phases

## Context

From M2 onward, `xcodebuild test` for the app scheme repeatedly hung for
many minutes (and in one case 30+ minutes) at the final
`PruneExplicitPrecompiledModules` build step — after CodeSign and Touch of
every product, before the first `Testing started` line. The hang
correlated perfectly with another Xcode build running concurrently on the
same machine by a different agent: the one run that reached test execution
did so when no other `xcodebuild` process was alive; every run that
deadlocked did so while another project's `xcodebuild` (separate
derived-data path and simulator) was active. Even the `test-without-building`
path re-runs the prune phase and deadlocked under contention. With a fresh
derived-data path and no concurrent Xcode build, the prune phase passes.

## Decision

1. Xcode test runs are run in two phases — `build-for-testing` first, then
   `test-without-building` — both in the background with output redirected
   to a file, since foreground invocations can exceed the shell time limit.
2. Before an Xcode test run, verify no other `xcodebuild` process is
   running (`ps -axo command | grep xcodebuild`); if one is, wait for it to
   exit first. The prune deadlock only occurs under concurrent Xcode
   builds, so a solo run is the cheap, reliable workaround.
3. `scripts/check.sh` uses a fresh derived-data path for every run
   (`rm -rf` first) and captures the test output to a file (no `tee`
   pipeline), because a pipeline reports the last command's exit status and
   would mask a test failure under `set -eu`.

## Consequences

- Test runs cost one full build when the derived-data path is fresh
  (several minutes) plus a fast product-only test pass; acceptable, and
  it makes runs deterministic.
- `check.sh` deletes `/tmp/geist6-dd` on every run; anyone debugging with
  incremental builds should invoke `xcodebuild` by hand instead.
- If the deadlock reappears with no concurrent build, the next step is
  filing against the SwiftBuild build service and trying the legacy build
  system; not needed so far.
