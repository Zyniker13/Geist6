import GeistData
import StripeModels
import SwiftUI

/// Detail screens for the tier-2 payment resources (decision 0022): a
/// mandate and a confirmation token. Both are read-only: Stripe's API only
/// updates mandates indirectly (through payment intent confirmation), and
/// confirmation tokens expire on their own, so there are no write controls.

/// The detail screen for one mandate.
struct MandateDetailView: View {
  enum Phase: Equatable {
    case loading
    case loaded(Mandate)
    case failed(String)
  }

  let mandateID: String
  let backend: any PaymentsBackend

  @State private var phase: Phase = .loading

  var body: some View {
    Group {
      switch phase {
      case .loading:
        ProgressView()
      case .failed(let message):
        ContentUnavailableView(
          "Couldn't load mandate",
          systemImage: "exclamationmark.triangle",
          description: Text(message)
        )
      case .loaded(let mandate):
        details(mandate)
      }
    }
    .navigationTitle("Mandate")
    .navigationBarTitleDisplayMode(.inline)
    .task(id: mandateID) { await load() }
  }

  private func load() async {
    phase = .loading
    do {
      phase = .loaded(try await backend.retrieveMandate(id: mandateID))
    } catch {
      phase = .failed(String(describing: error))
    }
  }

  @ViewBuilder
  private func details(_ mandate: Mandate) -> some View {
    List {
      Section {
        HStack(alignment: .firstTextBaseline) {
          Text(mandate.status.rawValue)
            .font(.title3.weight(.semibold))
          Spacer(minLength: 8)
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("payments.mandate.status")
      }

      Section("Details") {
        PaymentFactRow(label: "Type", value: mandate.type.rawValue)
        PaymentFactRow(
          label: "Created",
          value: mandate.customerAcceptance.acceptedAt.valueOrNil.map { accepted in
            accepted.date.formatted(date: .abbreviated, time: .omitted)
          } ?? "—")
        if let methodID = mandate.paymentMethod.idOrNil {
          PaymentFactRow(label: "Payment method", value: methodID)
        }
        PaymentFactRow(label: "Method type", value: mandate.paymentMethodDetails.type)
        PaymentFactRow(label: "Acceptance", value: mandate.customerAcceptance.type.rawValue)
      }
    }
  }
}

/// The detail screen for one confirmation token.
struct ConfirmationTokenDetailView: View {
  enum Phase: Equatable {
    case loading
    case loaded(ConfirmationToken)
    case failed(String)
  }

  let tokenID: String
  let backend: any PaymentsBackend

  @State private var phase: Phase = .loading

  var body: some View {
    Group {
      switch phase {
      case .loading:
        ProgressView()
      case .failed(let message):
        ContentUnavailableView(
          "Couldn't load confirmation token",
          systemImage: "exclamationmark.triangle",
          description: Text(message)
        )
      case .loaded(let token):
        details(token)
      }
    }
    .navigationTitle("Confirmation Token")
    .navigationBarTitleDisplayMode(.inline)
    .task(id: tokenID) { await load() }
  }

  private func load() async {
    phase = .loading
    do {
      phase = .loaded(try await backend.retrieveConfirmationToken(id: tokenID))
    } catch {
      phase = .failed(String(describing: error))
    }
  }

  @ViewBuilder
  private func details(_ token: ConfirmationToken) -> some View {
    List {
      Section {
        HStack(alignment: .firstTextBaseline) {
          Text(token.paymentMethodPreview.valueOrNil?.type.rawValue ?? "unknown")
            .font(.title3.weight(.semibold))
          Spacer(minLength: 8)
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("payments.confirmationToken.type")
      }

      Section("Details") {
        PaymentFactRow(
          label: "Created",
          value: token.created.date.formatted(date: .abbreviated, time: .omitted))
        if let expires = token.expiresAt.valueOrNil {
          PaymentFactRow(
            label: "Expires",
            value: expires.date.formatted(date: .abbreviated, time: .shortened))
        }
        if let usage = token.setupFutureUsage.valueOrNil {
          PaymentFactRow(label: "Setup future usage", value: usage.rawValue)
        }
        if let last4 = token.paymentMethodPreview.valueOrNil?.usBankAccount?.last4.valueOrNil {
          PaymentFactRow(label: "Account ending", value: "•••• \(last4)")
        }
      }
    }
  }
}
