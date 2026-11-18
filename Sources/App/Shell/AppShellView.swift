import SwiftUI

/// A destination of the app shell's split view.
///
/// Each window owns its own selection, so two windows can show two
/// different accounts (decision 0011).
enum ShellDestination: Hashable {
  /// The home dashboard of the account with this ID.
  case home(UUID)
  /// Account management.
  case accounts
  /// Search within the account with this ID for this submitted query.
  case search(UUID, String)
}

/// The root of every window: a sidebar listing the accounts and a detail
/// pane with the selected destination.
struct AppShellView: View {
  @Environment(AccountStore.self) private var accountStore
  @Environment(\.openWindow) private var openWindow

  /// The account this window was opened for, or nil for the default window.
  var seedAccountID: UUID?

  @State private var activeID: UUID?
  @State private var selection: ShellDestination?
  @State private var searchText = ""

  /// The observable account list. Reads track the store, so the shell
  /// (and the sidebar it feeds) re-render on any account change — no
  /// @State snapshot that can go stale when a navigation swap loses a
  /// view instance (decision 0015).
  private var accounts: [Account] { accountStore.accountsList }

  /// UI tests can ask to start on the accounts screen.
  private var initialSelection: ShellDestination? {
    CommandLine.arguments.contains("--uitest-tab-accounts") ? .accounts : nil
  }

  var body: some View {
    return NavigationSplitView {
      AppSidebarView(
        accounts: accounts,
        activeID: activeID,
        selection: $selection,
        searchText: $searchText,
        onOpenInNewWindow: { account in
          openWindow(value: account.id)
        },
        onSubmitSearch: submitSearch
      )
    } detail: {
      NavigationStack {
        detailContent
      }
    }
    .task {
      await loadState()
    }
  }

  @ViewBuilder
  private var detailContent: some View {
    switch selection {
    case .accounts:
      AccountListView(onAccountsChanged: {
        Task { await refreshAccounts() }
      })
    case .home(let id):
      if let account = accounts.first(where: { $0.id == id }) {
        HomeView(account: account)
      } else {
        ContentUnavailableView(
          "Account not found",
          systemImage: "creditcard",
          description: Text("This account was removed.")
        )
      }
    case .search(let accountID, let query):
      if let account = accounts.first(where: { $0.id == accountID }) {
        SearchView(account: account, initialQuery: query)
      } else {
        ContentUnavailableView(
          "No account",
          systemImage: "magnifyingglass",
          description: Text("Add a Stripe account to search it.")
        )
      }
    case nil:
      ContentUnavailableView(
        "Select an account",
        systemImage: "sidebar.left",
        description: Text("Choose a Stripe account from the sidebar.")
      )
    }
  }

  /// The account search should run against: the account currently shown,
  /// otherwise the active account, otherwise the first known account.
  private func preferredSearchAccount() -> Account? {
    if case .search(let id, _) = selection, let account = accounts.first(where: { $0.id == id }) {
      return account
    }
    if case .home(let id) = selection, let account = accounts.first(where: { $0.id == id }) {
      return account
    }
    if let activeID, let account = accounts.first(where: { $0.id == activeID }) {
      return account
    }
    return accounts.first
  }

  private func loadState() async {
    await refreshAccounts()
    if selection == nil {
      if let initial = initialSelection {
        selection = initial
      } else if let seed = seedAccountID, accounts.contains(where: { $0.id == seed }) {
        selection = .home(seed)
      } else if let active = activeID, accounts.contains(where: { $0.id == active }) {
        selection = .home(active)
      } else if let first = accounts.first {
        selection = .home(first.id)
      } else {
        selection = .accounts
      }
    }
  }

  /// Reloads the sidebar's account list and active ID without touching
  /// the current selection. Called when the detail pane changes the
  /// account set (add, remove, rename), so the sidebar never shows a
  /// stale list.
  private func refreshAccounts() async {
    // Hydrate the store's observable list from the keychain; the
    // sidebar reads the list directly, so no assignment is needed.
    _ = await accountStore.list()
    activeID = await accountStore.activeID()
  }

  private func submitSearch() {
    let query = searchText.trimmingCharacters(in: .whitespaces)
    guard !query.isEmpty else { return }
    guard let account = preferredSearchAccount() else {
      // No account to search: send the user to account management.
      selection = .accounts
      return
    }
    selection = .search(account.id, query)
  }
}

/// The sidebar column: the accounts, account management, and the search field.
struct AppSidebarView: View {
  let accounts: [Account]
  let activeID: UUID?
  @Binding var selection: ShellDestination?
  @Binding var searchText: String
  var onOpenInNewWindow: (Account) -> Void
  var onSubmitSearch: () -> Void

  var body: some View {
    List(selection: $selection) {
      Section("Stripe accounts") {
        ForEach(accounts) { account in
          row(for: account)
            .tag(ShellDestination.home(account.id))
            .contextMenu {
              Button {
                onOpenInNewWindow(account)
              } label: {
                Label("Open in New Window", systemImage: "uiwindow.split.2x1")
              }
            }
        }
      }
      Section {
        Label("Manage accounts", systemImage: "creditcard")
          .tag(ShellDestination.accounts)
          .accessibilityIdentifier("sidebar.manageAccounts")
      }
    }
    .searchable(text: $searchText, placement: .sidebar, prompt: "Search this account")
    .onSubmit(of: .search) {
      onSubmitSearch()
    }
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Menu {
          ForEach(accounts) { account in
            Button {
              onOpenInNewWindow(account)
            } label: {
              Label(account.name, systemImage: "uiwindow.split.2x1")
            }
          }
        } label: {
          Label("Open window", systemImage: "uiwindow.split.2x1")
        }
        .disabled(accounts.isEmpty)
        .accessibilityLabel("Open in New Window")
      }
    }
    .navigationTitle("Geist6")
    .navigationSplitViewColumnWidth(min: 220, ideal: 250)
  }

  private func row(for account: Account) -> some View {
    HStack(spacing: 10) {
      Circle()
        .fill(AccountColor.color(for: account.color))
        .frame(width: 10, height: 10)
      VStack(alignment: .leading, spacing: 2) {
        Text(account.name)
          .lineLimit(1)
        Text(account.live ? "Live" : "Test")
          .font(.caption2)
          .foregroundStyle(account.live ? Color.red : Color.secondary)
      }
      Spacer()
      if account.id == activeID {
        Image(systemName: "star.fill")
          .font(.caption)
          .foregroundStyle(.yellow)
          .accessibilityLabel("Active account")
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("sidebar.account.\(account.name)")
  }
}
