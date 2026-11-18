import GeistData
import StripeModels
import SwiftUI

/// The detail screen for one charge: money, method, refunds, dispute.
struct ChargeDetailView: View {
  enum Phase: Equatable {
    case loading
    case loaded(Charge)
    case failed(String)
  }

  let chargeID: String
  let backend: any PaymentsBackend

  @State private var phase: Phase = .loading
  @State private var balanceTransaction: BalanceTransaction?

  var body: some View {
    Group {
      switch phase {
      case .loading:
        ProgressView()
      case .failed(let message):
        ContentUnavailableView(
          "Couldn't load charge",
          systemImage: "exclamationmark.triangle",
          description: Text(message)
        )
      case .loaded(let charge):
        details(charge)
      }
    }
    .navigationTitle("Charge")
    .navigationBarTitleDisplayMode(.inline)
    .task(id: chargeID) { await load() }
  }

  @ViewBuilder
  private func details(_ charge: Charge) -> some View {
    List {
      Section {
        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .firstTextBaseline) {
            Text(MoneyFormat.amount(charge.amount, currency: charge.currency))
              .font(.largeTitle.weight(.bold))
            Spacer(minLength: 8)
            PaymentStatusBadge(text: charge.status.rawValue)
          }
          Text(charge.id)
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .textSelection(.enabled)
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("payments.charge.amount")
      }

      Section("Details") {
        PaymentFactRow(label: "Status", value: charge.status.rawValue)
        PaymentFactRow(label: "Captured", value: charge.captured ? "Yes" : "No")
        PaymentFactRow(label: "Refunded", value: charge.refunded ? "Yes" : "No")
        PaymentFactRow(label: "Created", value: "\(charge.created.date.formatted(date: .abbreviated, time: .omitted))")
        if let card = charge.paymentMethodDetails.valueOrNil?.card {
          PaymentFactRow(
            label: "Card",
            value: "\(card.brand.valueOrNil ?? "card") •••• \(card.last4.valueOrNil ?? "")"
          )
        }
        if let customer = charge.customer.valueOrNil {
          PaymentFactRow(label: "Customer", value: paymentCustomerID(customer))
        }
      }

      if let transaction = balanceTransaction {
        Section("Balance") {
          PaymentFactRow(label: "Net", value: MoneyFormat.amount(transaction.net, currency: transaction.currency))
          PaymentFactRow(label: "Fee", value: MoneyFormat.amount(transaction.fee, currency: transaction.currency))
          PaymentFactRow(label: "Gross", value: MoneyFormat.amount(transaction.amount, currency: transaction.currency))
        }
      }

      let refunds = charge.refunds?.valueOrNil?.data ?? []
      if !refunds.isEmpty {
        Section("Refunds") {
          ForEach(refunds, id: \.id) { refund in
            HStack(alignment: .firstTextBaseline) {
              Text(MoneyFormat.amount(refund.amount, currency: refund.currency))
                .font(.subheadline)
              Spacer(minLength: 8)
              PaymentStatusBadge(text: refund.status.valueOrNil ?? "pending")
            }
            .accessibilityElement(children: .combine)
          }
        }
      }
    }
  }

  private func load() async {
    phase = .loading
    balanceTransaction = nil
    do {
      let charge = try await backend.retrieveCharge(id: chargeID)
      phase = .loaded(charge)
      if let btxID = balanceTransactionID(charge.balanceTransaction) {
        balanceTransaction = try? await backend.retrieveBalanceTransaction(id: btxID)
      }
    } catch {
      phase = .failed(String(describing: error))
    }
  }
}

/// The detail screen for one refund.
struct RefundDetailView: View {
  enum Phase: Equatable {
    case loading
    case loaded(Refund)
    case failed(String)
  }

  let refundID: String
  let backend: any PaymentsBackend

  @State private var phase: Phase = .loading

  var body: some View {
    Group {
      switch phase {
      case .loading:
        ProgressView()
      case .failed(let message):
        ContentUnavailableView(
          "Couldn't load refund",
          systemImage: "exclamationmark.triangle",
          description: Text(message)
        )
      case .loaded(let refund):
        details(refund)
      }
    }
    .navigationTitle("Refund")
    .navigationBarTitleDisplayMode(.inline)
    .task(id: refundID) { await load() }
  }

  @ViewBuilder
  private func details(_ refund: Refund) -> some View {
    List {
      Section {
        HStack(alignment: .firstTextBaseline) {
          Text(MoneyFormat.amount(refund.amount, currency: refund.currency))
            .font(.largeTitle.weight(.bold))
          Spacer(minLength: 8)
          PaymentStatusBadge(text: refund.status.valueOrNil ?? "pending")
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("payments.refund.amount")
      }

      Section("Details") {
        PaymentFactRow(label: "Charge", value: refund.charge.valueOrNil?.idOrNil ?? "—")
        if let reason = refund.reason.valueOrNil {
          PaymentFactRow(label: "Reason", value: reason.rawValue)
        }
        PaymentFactRow(label: "Created", value: "\(refund.created.date.formatted(date: .abbreviated, time: .omitted))")
      }
    }
  }

  private func load() async {
    phase = .loading
    do {
      phase = .loaded(try await backend.retrieveRefund(id: refundID))
    } catch {
      phase = .failed(String(describing: error))
    }
  }
}
