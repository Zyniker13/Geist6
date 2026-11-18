import SwiftUI

/// List of known Stripe accounts. Supports add, edit, remove, and select.
struct AccountListView: View {
  @Environment(AccountStore.self) private var accountStore
  @State private var accounts: [Account] = []
  @State private var showingSetup = false
  @State private var accountToRemove: UUID?
  @State private var selectedAccount: Account?

  var body: some View {
    NavigationStack {
      Group {
        if accounts.isEmpty {
          ContentUnavailableView(
            "No accounts",
            systemImage: "creditcard",
            description: Text("No Stripe accounts added yet.")
          )
        } else {
          List {
            ForEach(accounts) { account in
              Button {
                selectedAccount = account
              } label: {
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
                Button(role: .destructive) {
                  accountToRemove = account.id
                } label: {
                  Label("Remove", systemImage: "trash")
                }
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
      // the stale captured item after the edit sheet dismisses, so edits
      // never showed up. A push keeps one live view that re-renders.
      .navigationDestination(item: $selectedAccount) { account in
        AccountDetailView(account: account)
      }
      .onChange(of: selectedAccount) { _, newValue in
        // Popping back from the detail: reload so edits and removals show.
        if newValue == nil {
          Task { await loadAccounts() }
        }
      }
    }
    .navigationTitle("Accounts")
    .sheet(isPresented: $showingSetup) {
      SetupView(accountStore: accountStore) {
        Task { await loadAccounts() }
      }
    }
    .alert("Remove account", isPresented: Binding(
      get: { accountToRemove != nil },
      set: { if !$0 { accountToRemove = nil } }
    )) {
      Button("Cancel", role: .cancel) {}
      Button("Remove", role: .destructive) {
        if let id = accountToRemove {
          Task {
            await accountStore.remove(id: id)
            accounts.removeAll { $0.id == id }
          }
        }
      }
    }
    .task {
      await loadAccounts()
    }
  }

  @MainActor
  private func loadAccounts() async {
    accounts = await accountStore.list()
  }
}
