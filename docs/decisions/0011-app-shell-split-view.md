# 0011 — App shell: split view, per-window accounts, multi-window

## Context

M3 builds the app shell for a native iPad dashboard. Stripe accounts are
the primary object: the user has one or more accounts and may want two
dashboards on screen at once (e.g. a test and a live account). M2 built
account management as a tabbed prototype. The M2 UI tests navigate via
tabs; any shell change must keep those tests meaningful.

## Decision

- Each window is rooted in a `NavigationSplitView`: a sidebar listing
  accounts plus "Manage accounts", and a detail pane showing the
  selected account's home dashboard, a search destination, or the
  accounts screen.
- The app declares `WindowGroup(for: UUID.self)`, where the value is an
  `Account.id`. A window seeded with an account id opens straight to
  that account's dashboard; other windows show the active account or
  the onboarding state when no accounts exist.
- "Open in New Window" (context menu on sidebar rows and a toolbar
  menu) calls `openWindow(value:)`; each window holds its own
  selection state, so two windows can show two different accounts.
- The global search field lives on the sidebar (the standard iPad
  split-view location) with results presented in the detail pane.
- The M2 tab-based shell is replaced; the M2 UI tests are updated to
  navigate the sidebar instead of tabs, keeping the same scenario
  (setup, list, edit, lock, empty state, home shows active account).

## Consequences

- Multi-window needs the `UIApplicationSupportsMultipleWindows` Info
 .plist key; the generated project sets it explicitly.
- Window selection state is per-window (`@State` inside the window's
  root view), not app-global, which is what makes two accounts on
  screen possible.
- State owned per window cannot also be an app-level `@Observable`
  shared by reference; dashboard and search models are created per
  window.
- The app target links `GeistData` and `GeistMetrics` from the package
  so the shell and dashboard stay thin over package logic.
