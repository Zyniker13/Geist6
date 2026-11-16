# 0005: Local cache storage library

## Context

The roadmap requires a local cache (recent objects per account and mode) so
the app opens instantly and works read-only offline, marked as such. The cache
lives in the portable core: it must build and test with the Swift toolchain on
macOS and Linux, hold no keys, and be clearable without losing anything.
Dependencies must be permissive-licensed and well maintained (decision 0002).

## Decision

Use **GRDB.swift** (MIT license) over SQLite for the cache.

Reasons:
- Mature, actively maintained, widely used; the standard Swift SQLite layer.
- Works with plain SPM on Linux (the portable core's CI target) as well as
  Apple platforms, unlike Apple-only options (Core Data, SwiftData).
- Permissive license (MIT), listed in `THIRD_PARTY.md`.
- Supports the access patterns the cache needs: typed records, value
  observation for the UI layer, and bounded eviction of old rows.

Alternatives considered: SQLite.swift (popular but less actively maintained
lately), raw SQLite3 C API via a thin wrapper (more code to own and audit for
SQL-injection safety), Core Data/SwiftData (Apple-only, not portable to the
Linux CI job).

## Consequences

- The cache schema is ours; keys, tokens, and anything secret never enter it
  (tested).
- The exact GRDB version is pinned in `Package.swift` and recorded in
  `THIRD_PARTY.md` when M1 wires the dependency in.
- Any future portability problem on Linux would be caught in CI immediately.
