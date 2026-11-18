import SwiftUI

/// Detail view for a single account. Pushed from the account list;
/// shows info and allows editing.
struct AccountDetailView: View {
  @Environment(AccountStore.self) private var accountStore
  @Environment(\.dismiss) private var dismiss
  @State private var account: Account
  @State private var isEditing = false

  init(account: Account) {
    _account = State(initialValue: account)
  }

  var body: some View {
    Form {
      Section("Account") {
        LabeledContent("Name", value: account.name)
        LabeledContent("Mode", value: account.live ? "Live" : "Test")
        LabeledContent("Dashboard lock", value: account.dashboardLock ? "On" : "Off")
      }

      Section("Connected accounts") {
        if account.connectedAccounts.isEmpty {
          Text("No connected accounts")
            .foregroundStyle(.secondary)
        } else {
          ForEach(account.connectedAccounts) { connected in
            LabeledContent(connected.displayName ?? connected.id, value: connected.type.rawValue.capitalized)
          }
        }
      }
    }
    .navigationTitle(account.name)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button("Edit") {
          isEditing = true
        }
        .accessibilityIdentifier("detail.edit")
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("Done") {
          dismiss()
        }
        .accessibilityIdentifier("detail.done")
      }
    }
    .sheet(isPresented: $isEditing, onDismiss: {
      Task { await refresh() }
    }, content: {
      EditAccountView(account: account, accountStore: accountStore) { updated in
        account = updated
      }
    })
  }

  @MainActor
  private func refresh() async {
    if let updated = await accountStore.get(id: account.id) {
      account = updated
    }
  }
}
