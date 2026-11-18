# 0015: AccountStore as the Single Source of Truth for Account UI

## Context

During M3 verification, the UI test `testManageAccountsRename` failed: after renaming
an account in the edit sheet, the detail view kept showing the old name, even though
the store write succeeded (an instrumented single-test run with app log probes showed
`update` persisted "New Name" and the read-back returned it).

The probe log showed the exact zombie-instance signature: the detail view's `onUpdate`
callback fired and its `refresh()` read the new name, but `onChange(of: account.name)`
never fired and `body` never re-rendered. Both assignments executed on a view instance
the visible view never reads.

The failure generalized: the third full check run failed the same test with a
*different* assertion — the detail now showed the new name, but the list row did not.
`AccountListView` renders rows from its local `@State accounts` array, so the same
re-created-instance / pop-time-reload race applies one level up: a rename saved in the
detail never re-renders the row, and the list's `onChange(of: selectedAccount)`
reload fires on a dead instance or never fires at all.

The detail view held the account in view-local `@State`, seeded from the value pushed
by `navigationDestination(item:)`. On iPadOS 26, navigation and sheet re-creation can
replace the visible view instance with a new one whose `@State` was re-seeded from the
(stale) captured item; mutations applied through the old instance's state never reach
the screen. A related M2 issue (sheet-inside-sheet staleness) had already pushed the
detail into a navigation stack — that fixed the dismissal, but view-local `@State`
remained the fragile link.

## Decision

`AccountStore` (already `@Observable`) now keeps an in-memory `cache: [UUID: Account]`:

- `cached(id:)` — new synchronous, observable read used by `AccountDetailView`.
- Every keychain path keeps the cache consistent: `add` populates it, `get` refreshes
  (and evicts on nil), `remove` evicts, and `update` / `updateConnectedAccounts`
  re-read from the keychain after a successful write and refresh the cache. A failed
  keychain write therefore cannot poison the cache: the read-back mirrors whatever the
  keychain actually holds.
- `AccountDetailView` no longer holds the account in `@State`. It reads
  `accountStore.cached(id:) ?? pushedSnapshot` synchronously, takes only the pushed
  `id` as authoritative, warms the cache via `.task(id:)`, and refreshes it when the
  edit sheet dismisses.
- `EditAccountView` writes through `store.update` and dismisses; the `onUpdate`
  callback and its M2-era debug probes are removed — the observable cache replaces
  the callback as the update channel.
- The list view renders directly from the store (see Extension below); its earlier
  intermediate form — `@State` snapshot plus a `resolved(_:)` row helper — was
  replaced when the third instance of the staleness pattern appeared in the shell.

A regression test at the logic level (`AccountStoreTests.updateRefreshesColdCache`)
pins the exact rename scenario: add, update, synchronous `cached(id:)` read must show
the new name without any async `get`.

## Extension: the shell sidebar is the third instance

The full-run verification kept peeling the pattern one layer up. Run five failed
before the tests could run at all: the `resolved(_:)` refactor made the list's single
`body` expression too complex for the type-checker ("unable to type-check this
expression in reasonable time") — fixed by extracting the row into its own
`AccountRow` view with hoisted bindings/actions (type-check-timeout lesson, recorded
in the swift-6-build skill). Run six then failed only `testManageAccountsRename`
again — but at a *new* assertion: the detail and the list row both showed the new
name, while the shell's sidebar row did not.

The sidebar renders from `AppShellView`'s own `@State accounts` snapshot, refreshed
by an `onAccountsChanged` callback chain that runs on the list's pop-time
`onChange`. Same zombie-snapshot class, third level up: the reload can fire on a
re-created list instance or never fire at all, and every snapshot below the store
goes stale one at a time.

Decision, applied fully this time:

- `AccountStore` gains `accountsList: [Account]` — an observable, name-sorted list
  rebuilt by every mutation path (`syncList()` after `add`/`get`/`remove`/`update`/
  `updateConnectedAccounts`; `list()` rebuilds it from keychain truth, dropping
  cache entries whose keychain rows are gone).
- `AppShellView` drops its `@State accounts` and reads a computed
  `accounts: [Account] { accountStore.accountsList }`; `refreshAccounts` only
  hydrates (keychain → cache → list) and refreshes `activeID`. The
  `onAccountsChanged` callback stays, but it now only refreshes keychain-derived
  state — no view's correctness depends on it.
- `AccountListView` drops its `@State accounts`, `loadAccounts()`, and
  `resolved(_:)`: rows render straight from `accountStore.accountsList`, which is
  already resolved data. `onAccountsChanged` is called on pop and after add/remove
  for the shell's `activeID` refresh only.
- The `.task` hydration calls (`_ = await accountStore.list()`) remain in both
  views so a cold cache fills from the keychain on first appearance.

## Consequences

- Views stay correct no matter which view instance survives navigation re-creation;
  the push value is a snapshot, not live state.
- Keychain remains the durable store; the cache is a same-process mirror and is
  repopulated from the keychain on every read path (`list`, `active` go through `get`),
  so a stale in-memory cache cannot outlive a process restart.
- The cache holds account metadata (including the API key string) in memory during the
  app's lifetime; account values already flowed through view `@State` the same way, so
  this adds no new exposure class. `Account` still redacts its key in any
  `String(describing:)` (decision 0014 area, KeySafetyTests).
- Store mutation paths now each do one extra keychain read (metadata refresh); cheap
  and keeps the cache strictly truthful.

## Verification

- `TestsApp/AccountStoreTests.swift`: seven cache tests plus the observable-list
  tests `accountsListTracksAddUpdateRemove` (add/update/remove reflected, and the
  rename reflected immediately) and `accountsListIsSortedByNameCaseInsensitive`.
- UI test `testManageAccountsRename` must pass in the full `scripts/check.sh` run
  (third M3 verification).
