# 0026 — Gate checks: device selection, prewarmed builds, simulator lock

## Context

`scripts/check.sh` must run what CI runs, but development runs on a machine
shared by several agents: one CoreSimulatorService, one Xcode test service,
and long simulator waits (the sim-lock queue can exceed 40 minutes). Three
problems surfaced while running the M6 gate:

1. The script picked a generic iPad destination, which can collide with
   other agents' devices.
2. Each gate rebuilt the whole app from scratch inside the simulator lock,
   wasting most of the lock window on compilation.
3. The xcodebuild invocations were not wrapped in `sim-lock`, so two agents
   testing at once could stall each other.

## Decision

- Device selection prefers a device named `zGeist6_bot-*` (this agent's own
  simulator) and falls back to any available iPad, so the script still works
  unchanged in CI where no such device exists.
- `GEIST6_DD=<path>` selects a reusable DerivedData directory: when set, the
  script runs `xcodebuild test-without-building` against a prewarmed build
  instead of rebuilding, and never wipes that directory. Without it, the
  script behaves exactly as CI does (clean DerivedData, full build, `test`).
- When `~/.hermes/bin/sim-lock` exists, xcodebuild invocations are wrapped
  in it; otherwise the prefix is empty, so CI is unaffected.

## Consequences

- A long `build-for-testing` can warm DerivedData outside the lock while
  other work proceeds, and the gate then spends its lock window only on
  actually running tests.
- The prewarmed path must be regenerated after source changes; the plain
  (CI-equivalent) path remains the authoritative check, and the gate is run
  that way before pushes.
- The script stays the single entry point CI and local runs share.
