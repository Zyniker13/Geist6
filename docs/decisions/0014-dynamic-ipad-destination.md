# 0014 — Dynamic iPad destination in check.sh

## Context

`scripts/check.sh` hardcoded the app-test destination as
`platform=iOS Simulator,name=iPad (A16),OS=latest`. On 2026-11-18 that
device no longer existed in the local simulator set: the machine's only
installed iOS runtime (27.2, bundled with the seed Xcode) turned out to be
device-variant-gated — `simctl create` for several iPad device types failed
with "Incompatible device", the available device list changed under us
mid-session, and after the dust settled the local list held iPads whose
names differ from the hardcoded one. `xcodebuild` against a nonexistent
destination fails with exit 70 ("ineligible destinations"), which reads as
a code failure when it is really an environment failure. CI runners, by
contrast, install current runtimes and have at least one iPad whose name
varies with the runner image.

## Decision

`check.sh` no longer hardcodes a device name. Before the `xcodebuild test`
step it resolves the first iPad listed in the available iOS runtime section
of `simctl list devices available`, stopping at the next `--` section
header so devices under `-- Unavailable: ... --` are never matched, and
passes `platform=iOS Simulator,name=$SIM_NAME,OS=latest` to xcodebuild.
When no iPad exists it fails immediately with an explicit message ("no
iPad simulator installed (the app is iPad-only)") and tears down the
stripe-mock process; it never silently skips the app tests. The
environment override `GEIST6_SIM_DEST` is reserved for pinning a specific
device if ever needed.

## Consequences

- CI keeps passing regardless of which iPad name the runner image ships,
  and local runs pick up whatever iPad is installed instead of breaking on
  a renamed device.
- A machine with zero iPad simulators fails fast and legibly rather than
  with xcodebuild's generic exit 70.
- The awk section-boundary guard matters: a first cut matched
  "iPad Pro 13-inch (M5)" out of the Unavailable section and would have
  sent xcodebuild after a device that cannot boot.
- Local UI test execution on this machine remains constrained by the
  installed runtime (per decision 0010 CI stays the authoritative
  execution-evidence source); this change does not weaken that rule.
