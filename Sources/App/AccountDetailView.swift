import SwiftUI

/// Detail view for a single account. Shows info and allows editing.
struct AccountDetailView: View {
  @Environment(AccountStore.self) private var accountStore
  @Environment(\.dismiss) private var dismiss
  let account: Account
  let onSelected: () -> Void

  @State private var isEditing = false
  @State private var showingSetup = false
  @State private var showingRemove = false

  var body: some View {
    NavigationStack {
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
        }
      }
    }
    .sheet(isPresented: $isEditing) {
      EditAccountView(account: account, accountStore: accountStore) { updated in
        // The @Bindable in EditAccountView will update the local copy
      }
    }
  }
}
