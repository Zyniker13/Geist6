import SwiftUI

/// The setup flow: add a new Stripe account by pasting a key.
struct SetupView: View {
  @State private var name: String = ""
  @State private var apiKey: String = ""
  @State private var live: Bool = false
  @State private var dashboardLock: Bool = false
  @State private var selectedColor: String = ".systemBlue"

  private var color: Color {
    Color(selectedColor) ?? .gray
  }
  @State private var errorMessage: String? = nil
  @State private var isAdding: Bool = false
  @Environment(\.dismiss) private var dismiss

  let accountStore: AccountStore
  let onAdded: () -> Void

  var body: some View {
    NavigationStack {
      Form {
        Section("Account name") {
          TextField("My Stripe account", text: $name)
        }

        Section("API key") {
          TextField("sk_live_… or sk_test_…", text: $apiKey)
          Toggle("Live key", isOn: $live)
        }

        Section("Security") {
          Toggle("Dashboard lock (requires Face ID / passcode to write)", isOn: $dashboardLock)
        }

        Section("Colour") {
          ColorPicker("Account colour", selection: Binding(
            get: { color },
            set: { selectedColor = $0.description }
          ))
        }

        if let error = errorMessage {
          Section {
            Text(error)
              .foregroundStyle(.red)
          }
        }
      }
      .navigationTitle("Add account")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Add") {
            Task { await save() }
          }
          .disabled(isAdding || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
    }
  }

  @MainActor
  private func save() async {
    isAdding = true
    errorMessage = nil

    // Validate key format
    let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    let validPrefixes = ["sk_live_", "sk_test_", "rk_live_", "rk_test_", "rk_", "sk_", "rk_"]
    guard validPrefixes.contains(where: { trimmed.hasPrefix($0) }) else {
      errorMessage = "API key must start with sk_ or rk_"
      isAdding = false
      return
    }

    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

    // Check for duplicate name
    let existing = await accountStore.list()
    if existing.contains(where: { $0.name.lowercased() == trimmedName.lowercased() }) {
      errorMessage = "An account with this name already exists"
      isAdding = false
      return
    }

    let account = await accountStore.add(
      name: trimmedName,
      color: selectedColor,
      dashboardLock: dashboardLock,
      apiKey: trimmed,
      live: live
    )

    // Set as active
    await accountStore.setActive(id: account.id)

    dismiss()
    onAdded()
    isAdding = false
  }
}
