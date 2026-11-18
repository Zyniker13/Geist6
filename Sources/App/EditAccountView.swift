import SwiftUI

/// Edit an existing account's name, colour, and dashboard lock.
///
/// Saving writes through the store; the store refreshes its
/// observable cache, which is what the detail view reads, so no
/// callback into the presenting view is needed.
struct EditAccountView: View {
  @Environment(\.dismiss) private var dismiss
  let account: Account
  let accountStore: AccountStore

  @State private var name: String
  @State private var dashboardLock: Bool
  @State private var selectedColor: String

  private var color: Color {
    AccountColor.color(for: selectedColor)
  }

  init(account: Account, accountStore: AccountStore) {
    self.account = account
    self.accountStore = accountStore
    self._name = State(initialValue: account.name)
    self._dashboardLock = State(initialValue: account.dashboardLock)
    self._selectedColor = State(initialValue: account.color)
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Account name") {
          TextField("Account name", text: $name)
            .accessibilityIdentifier("edit.name")
        }

        Section("Security") {
          Toggle("Dashboard lock", isOn: $dashboardLock)
            .accessibilityIdentifier("edit.lock")
        }

        Section("Colour") {
          ColorPicker("Account colour", selection: Binding(
            get: { color },
            set: { selectedColor = $0.description }
          ))
        }
      }
      .navigationTitle("Edit account")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            Task { await save() }
          }
          .accessibilityIdentifier("edit.save")
          .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
    }
  }

  @MainActor
  private func save() async {
    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

    await accountStore.update(
      id: account.id,
      name: trimmedName,
      color: selectedColor,
      dashboardLock: dashboardLock
    )

    dismiss()
  }
}
