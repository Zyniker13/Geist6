import GeistData
import StripeModels
import SwiftUI

/// Creates an onboarding or update link for a connected account. Not
/// money-moving: the link is a URL the connected account's person can
/// visit. One confirmation step restates the link type before the write
/// runs, and the write carries an idempotency key.
struct CreateAccountLinkSheet: View {
  let accountID: String
  let writer: ConnectWriteService
  let onFinished: (WriteResult) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var linkType: LinkTypeChoice = .onboarding
  @State private var confirmPresented = false
  @State private var running = false
  @State private var failureText: String?

  enum LinkTypeChoice: String, CaseIterable, Identifiable {
    case onboarding
    case update

    var id: String { rawValue }

    var label: String {
      switch self {
      case .onboarding: return "Onboarding"
      case .update: return "Update"
      }
    }

    var useCase: V2CoreAccountLinkUseCaseType {
      switch self {
      case .onboarding: return .accountOnboarding
      case .update: return .accountUpdate
      }
    }

    var summary: String {
      switch self {
      case .onboarding: return "Create onboarding link"
      case .update: return "Create update link"
      }
    }
  }

  /// Restates the exact account and link type before the write runs.
  private var confirmText: String {
    "Create an " + linkType.label.lowercased() + " link for " + accountID + "?"
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Picker("Link type", selection: $linkType) {
            ForEach(LinkTypeChoice.allCases) { choice in
              Text(choice.label).tag(choice)
            }
          }
          .accessibilityIdentifier("connect.link.type")
        } header: {
          Text("New account link")
        } footer: {
          Text(
            "The link opens Stripe's hosted page where this account's "
              + "person completes onboarding or updates their details.")
        }
        if let failureText {
          Section {
            Text(failureText)
              .font(.footnote)
              .foregroundStyle(.red)
              .accessibilityIdentifier("payments.write.error")
          }
        }
      }
      .navigationTitle("New account link")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Create") {
            failureText = nil
            confirmPresented = true
          }
          .disabled(running)
          .accessibilityIdentifier("connect.link.submit")
        }
      }
      .confirmationDialog(
        confirmText,
        isPresented: $confirmPresented, titleVisibility: .visible
      ) {
        Button("Create link") {
          Task { await run() }
        }
        .accessibilityIdentifier("connect.link.confirm")
        Button("Cancel", role: .cancel) {}
      }
    }
  }

  private func run() async {
    running = true
    failureText = nil
    let summary = linkType.summary + " " + accountID
    do {
      let link = try await writer.createAccountLink(
        account: accountID, type: linkType.useCase, summary: summary)
      onFinished(
        WriteResult(
          title: "Account link created",
          message: link.url))
    } catch {
      running = false
      failureText = writeErrorMessage(error)
    }
  }
}

/// Creates a login link for a connected account's Express dashboard. The
/// confirmation restates the account before the write runs.
struct CreateLoginLinkSheet: View {
  let accountID: String
  let writer: ConnectWriteService
  let onFinished: (WriteResult) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var confirmPresented = false
  @State private var running = false
  @State private var failureText: String?

  private var confirmText: String {
    "Create a login link for " + accountID + "?"
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Text(
            "The link signs this account's person in to their Express "
              + "dashboard. Links expire after use.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        } header: {
          Text("New login link")
        }
        if let failureText {
          Section {
            Text(failureText)
              .font(.footnote)
              .foregroundStyle(.red)
              .accessibilityIdentifier("payments.write.error")
          }
        }
      }
      .navigationTitle("New login link")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Create") {
            failureText = nil
            confirmPresented = true
          }
          .disabled(running)
          .accessibilityIdentifier("connect.loginlink.submit")
        }
      }
      .confirmationDialog(
        confirmText,
        isPresented: $confirmPresented, titleVisibility: .visible
      ) {
        Button("Create link") {
          Task { await run() }
        }
        .accessibilityIdentifier("connect.loginlink.confirm")
        Button("Cancel", role: .cancel) {}
      }
    }
  }

  private func run() async {
    running = true
    failureText = nil
    do {
      let link = try await writer.createLoginLink(
        account: accountID, summary: "Create login link " + accountID)
      onFinished(
        WriteResult(
          title: "Login link created",
          message: link.url))
    } catch {
      running = false
      failureText = writeErrorMessage(error)
    }
  }
}

/// Creates an embedded-components account session for a connected
/// account. The sheet picks which components to enable; the write
/// carries an idempotency key.
struct CreateAccountSessionSheet: View {
  let accountID: String
  let writer: ConnectWriteService
  let onFinished: (WriteResult) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var onboardingEnabled = true
  @State private var confirmPresented = false
  @State private var running = false
  @State private var failureText: String?

  private var confirmText: String {
    onboardingEnabled
      ? "Create an account session with onboarding for " + accountID + "?"
      : "Create an account session with no components for " + accountID + "?"
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Toggle("Onboarding component", isOn: $onboardingEnabled)
            .accessibilityIdentifier("connect.session.onboarding")
        } header: {
          Text("New account session")
        } footer: {
          Text(
            "A session issues a short-lived client secret that renders "
              + "Stripe's embedded components for this account.")
        }
        if let failureText {
          Section {
            Text(failureText)
              .font(.footnote)
              .foregroundStyle(.red)
              .accessibilityIdentifier("payments.write.error")
          }
        }
      }
      .navigationTitle("New account session")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Create") {
            failureText = nil
            confirmPresented = true
          }
          .disabled(running)
          .accessibilityIdentifier("connect.session.submit")
        }
      }
      .confirmationDialog(
        confirmText,
        isPresented: $confirmPresented, titleVisibility: .visible
      ) {
        Button("Create session") {
          Task { await run() }
        }
        .accessibilityIdentifier("connect.session.confirm")
        Button("Cancel", role: .cancel) {}
      }
    }
  }

  private func run() async {
    running = true
    failureText = nil
    do {
      let session = try await writer.createAccountSession(
        account: accountID,
        components: AccountSessionCreateParamsComponents(
          accountOnboarding: onboardingEnabled
            ? AccountSessionCreateParamsComponentsAccountOnboarding(
              enabled: true, features: nil)
            : nil),
        summary: "Create account session " + accountID)
      onFinished(
        WriteResult(
          title: "Account session created",
          message: "Client secret " + session.clientSecret.prefix(12) + "…"))
    } catch {
      running = false
      failureText = writeErrorMessage(error)
    }
  }
}
