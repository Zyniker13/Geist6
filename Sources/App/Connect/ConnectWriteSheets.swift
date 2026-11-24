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
