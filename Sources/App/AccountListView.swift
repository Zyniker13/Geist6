import SwiftUI

/// List of known Stripe accounts. Supports add, edit, remove, and select.
/// Shown inside the shell's detail pane, which provides the navigation stack.
///
/// Renders directly from the store's observable `accountsList`: every
/// add, edit, and removal re-renders the rows on the next run loop turn,
/// with no local snapshot that can go stale when navigation or sheet
/// re-creation swaps the view instance (decision 0015).
struct AccountListView: View {
  /// Called after the account set changes (add, remove) so the shell can
  /// refresh its keychain-derived state (active ID); the rows themselves
  /// are live store reads.
  var onAccountsChanged: () -> Void = {}

  @Environment(AccountStore.self) private var accountStore
  @State private var showingSetup = false
  @State private var accountToRemove: UUID?
  @State private var selectedAccount: Account?

  var body: some View {
    Group {
      if accountStore.accountsList.isEmpty {
        ContentUnavailableView(
          "No accounts",
          systemImage: "creditcard",
          description: Text("No Stripe accounts added yet.")
        )
      } else {
        List {
          ForEach(accountStore.accountsList) { account in
            AccountRow(account: account) {
              selectedAccount = account
            } onRemove: {
              accountToRemove = account.id
            }
          }
        }
      }
    }
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          showingSetup = true
        } label: {
          Label("Add account", systemImage: "plus")
        }
        .accessibilityIdentifier("accounts.add")
      }
    }
    // The detail is a navigation push, not a nested sheet: presenting a
    // sheet inside a sheet on iPadOS 26 re-creates the inner content with
    // the stale captured item. The push value may still be a stale
    // snapshot, so AccountDetailView reads live data from the store's
    // observable cache and only takes the pushed id as authoritative.
    .navigationDestination(item: $selectedAccount) { account in
      AccountDetailView(account: account)
    }
    .onChange(of: selectedAccount) { _, newValue in
      // Popping back from the detail: refresh the shell's keychain-derived
      // state. Row content needs no reload — it reads the store directly.
      if newValue == nil {
        onAccountsChanged()
      }
    }
    .navigationTitle("Accounts")
    .sheet(isPresented: $showingSetup) {
      SetupView(accountStore: accountStore) {
        onAccountsChanged()
      }
    }
    .alert("Remove account", isPresented: removeAlertBinding) {
      Button("Cancel", role: .cancel) {}
      Button("Remove", role: .destructive) {
        removeSelected()
      }
    }
    .task {
      // Hydrate the store from the keychain on first appearance.
      _ = await accountStore.list()
    }
  }

  private var removeAlertBinding: Binding<Bool> {
    Binding(
      get: { accountToRemove != nil },
      set: { if !$0 { accountToRemove = nil } }
    )
  }

  private func removeSelected() {
    guard let id = accountToRemove else { return }
    Task {
      await accountStore.remove(id: id)
      onAccountsChanged()
    }
  }
}

/// One row in the account list. Kept in its own view so the list's body
/// stays small enough for the type-checker.
private struct AccountRow: View {
  let account: Account
  let onSelect: () -> Void
  let onRemove: () -> Void

  var body: some View {
    Button(action: onSelect) {
      HStack {
        Circle()
          .fill(AccountColor.color(for: account.color))
          .frame(width: 24, height: 24)
        VStack(alignment: .leading) {
          Text(account.name)
            .font(.headline)
          Text(account.live ? "Live" : "Test")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        if account.dashboardLock {
          Image(systemName: "hand.raised.fill")
            .foregroundStyle(.secondary)
        }
      }
    }
    .accessibilityIdentifier("account.row")
    .swipeActions(edge: .trailing) {
      Button(role: .destructive, action: onRemove) {
        Label("Remove", systemImage: "trash")
      }
    }
  }
}
