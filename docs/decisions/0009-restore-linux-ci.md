# 0009 — Restore the Linux CI job

Date: 2026-11-17

Supersedes [0008](0008-ci-macos-only.md).

## Context

Decision 0008 removed the Linux job, on the belief that its "Set up job"
failures were GitHub runner infrastructure. The job log says otherwise:
`Unable to resolve action swift-actions/setup-swift@6893b0f3…, unable to find
version`. That commit does not exist in the action's repository, so the runner
could not download the action. "Set up job" is where a runner resolves every
`uses:` reference, which is why the failure happened before any step ran.

## Decision

Restore the Linux job, with `swift-actions/setup-swift` pinned to
`7ca6abe6b3b0e8b5421b88be48feee39cbf52c6a`, the commit the `v2.4.0` tag
points to. Before pinning any action, resolve the SHA from the action's own
tags (`git ls-remote --tags https://github.com/<owner>/<action>`) instead of
writing one from memory.

## Consequences

- The package is compiled and tested on Linux again, as `ROADMAP.md` planned.
- A red "Set up job" means a `uses:` reference failed to resolve; read the job
  log (the repository is public, so the log is readable) before calling it
  infrastructure.
