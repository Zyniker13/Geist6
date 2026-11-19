# 0018 — Navigation: one shell-owned path, value-based pushes

## Context

M4's UI tests kept failing with `payments.charge.amount not found`. Instrumenting
the app showed why: the moment a charge row was tapped, `PaymentsView` was
destroyed and rebuilt (`segment` reset to `paymentIntents`, model reloaded). The
pushed charge detail then landed on a *different* view instance, so the detail's
fields never appeared.

The recreation was not caused by any app logic running at tap time. It came from
how the home stack pushed destinations:

- `HomeView` pushed `PaymentsView` through `.navigationDestination(isPresented:)`.
  The pushed content closure was re-evaluated when ancestors re-rendered, and the
  re-evaluated content produced a view with a *new* identity — SwiftUI then
  replaced the pushed view instead of keeping it.
- An earlier variant gated that closure on `if let paymentsClient` (client built
  asynchronously in `.task`), which made the destination flip between
  `ProgressView` and `PaymentsView` on the first render pass.

## Decision

The detail stack is owned by `AppShellView` as one `NavigationPath`:

- `NavigationStack(path: $path)` wraps `detailContent`.
- Every push is value-based: `HomeRoute` (`.payments`, `.event(String)`) for
  pushes from the dashboard, registered with
  `.navigationDestination(for: HomeRoute.self)` in `HomeView`; existing
  value-based routes (`PaymentRoute`) keep working unchanged, since their pushes
  append to the same stack path.
- `HomeView` takes `path: Binding<NavigationPath>` and appends to it (toolbar
  button, `NavigationLink(value:)`); no `isPresented`/`item:` navigation
  destinations remain on the home flow.
- The path is cleared on shell `selection` change so a switch to another account
  never inherits a stale stack.
- Per-destination state (`StripeClient`, `DashboardModel`) is still built in
  `HomeView.init` via `State(initialValue:)`, keeping destination closures
  unconditional.

## Consequences

- Pushed view identity is anchored to the path entry, so ancestor re-renders
  cannot rebuild pushed content; the `.task(id: segment)` in `PaymentsView` no
  longer re-fires at tap time.
- Debugging lesson (recorded in `TESTING.md`): when a pushed detail "loses"
  state, log `.task` runs and `onAppear` from the app (os.Logger with a stable
  prefix) — the recreated view announces itself as a *fresh* task run with the
  same identifier.
- XCUITest note: iPad `confirmationDialog` buttons appear twice in the
  accessibility tree; tests address them with `.firstMatch`.
