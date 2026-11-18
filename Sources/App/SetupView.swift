import SwiftUI
import StripeClient
import StripeModels

/// The setup flow: add a new Stripe account by pasting a key.
struct SetupView: View {
  @State private var name: String = ""
  @State private var apiKey: String = ""
  @State private var live: Bool = false
  @State private var dashboardLock: Bool = false
  @State private var selectedColor: String = ".systemBlue"

  private var color: Color {
    AccountColor.color(for: selectedColor)
  }
  @State private var errorMessage: String?
  @State private var isAdding: Bool = false
  @Environment(\.dismiss) private var dismiss

  let accountStore: AccountStore
  let onAdded: () -> Void

  /// Optional business name pre-filled from account verification.
  @State private var verifiedName: String?
  /// Optional country from account verification.
  @State private var verifiedCountry: String?

  var body: some View {
    NavigationStack {
      Form {
        if let verifiedName, !verifiedName.isEmpty {
          Section("Account verified") {
            Text(verifiedName)
              .foregroundStyle(.primary)
            if let country = verifiedCountry {
              Text("Country: \(country)")
                .foregroundStyle(.secondary)
            }
          }
        }

        Section("Account name") {
          TextField("My Stripe account", text: $name)
            .accessibilityIdentifier("setup.name")
        }

        Section("API key") {
          TextField("sk_live_… or sk_test_…", text: $apiKey)
            .accessibilityIdentifier("setup.apiKey")
          Toggle("Live key", isOn: $live)
            .accessibilityIdentifier("setup.live")
        }

        Section("Security") {
          Toggle("Dashboard lock (requires Face ID / passcode to write)", isOn: $dashboardLock)
            .accessibilityIdentifier("setup.lock")
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
              .accessibilityIdentifier("setup.error")
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
          .accessibilityIdentifier("setup.add")
          .disabled(isAdding || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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

    // Verify the key works by calling GET /v1/account (skip in production without override)
    if let baseURL = AppConfig.apiBaseUrl {
      let client = StripeClient(apiKey: apiKey, mode: .management, baseURL: baseURL)
      do {
        let account: StripeModels.Account = try await client.request(method: "GET", path: "/v1/account")
        if let bp = account.businessProfile, case .value(let profile) = bp {
          if case .value(let unwrappedName) = profile.name { verifiedName = unwrappedName }
        }
        verifiedCountry = account.country
      } catch {
        errorMessage = "Could not verify API key—check the base URL and try again"
        isAdding = false
        return
      }
    }

    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    // Pre-fill name from verification if empty
    let finalName = trimmedName.isEmpty ? (verifiedName ?? "") : trimmedName
    guard !finalName.isEmpty else {
      errorMessage = "Account name is required"
      isAdding = false
      return
    }

    // Check for duplicate name
    let existing = await accountStore.list()
    if existing.contains(where: { $0.name.lowercased() == finalName.lowercased() }) {
      errorMessage = "An account with this name already exists"
      isAdding = false
      return
    }

    let account = await accountStore.add(
      name: finalName,
      color: selectedColor,
      dashboardLock: dashboardLock,
      apiKey: apiKey,
      live: live
    )

    // Set as active
    await accountStore.setActive(id: account.id)

    dismiss()
    onAdded()
    isAdding = false
  }
}
