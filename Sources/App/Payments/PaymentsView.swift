import GeistData
import StripeModels
import SwiftUI

/// A tapped row's destination: detail screens fetch by ID.
enum PaymentRoute: Hashable {
  case intent(String)
  case charge(String)
  case refund(String)
  case setupIntent(String)
  case paymentMethod(String)
  case paymentLink(String)
}

/// The payments tab: six browsable lists of one account's payment objects.
/// Read-only by construction; write controls arrive in M4b behind the
/// management-mode gate.
struct PaymentsView: View {
  let account: Account
  let backend: any PaymentsBackend
  /// Nil for dashboard-locked accounts: no write UI exists at all.
  let writer: PaymentsWriteService?

  @State private var model: PaymentsModel?
  @State private var segment: PaymentsModel.Segment = .paymentIntents

  var body: some View {
    Group {
      if let model {
        content(model)
      } else {
        ProgressView()
      }
    }
    .navigationTitle("Payments")
    .task(id: segment) {
      if model == nil {
        model = PaymentsModel(backend: backend)
      }
      await model?.load(segment)
    }
  }

  @ViewBuilder
  private func content(_ model: PaymentsModel) -> some View {
    VStack(spacing: 0) {
      Picker("Segment", selection: $segment) {
        ForEach(PaymentsModel.Segment.allCases) { item in
          Text(item.label).tag(item)
        }
      }
      .pickerStyle(.segmented)
      .padding(.horizontal)
      .padding(.top, 8)
      .accessibilityIdentifier("payments.segment.\(segment.rawValue)")

      switch model.phase {
      case .failed(let message):
        ContentUnavailableView(
          "Couldn't load payments",
          systemImage: "exclamationmark.triangle",
          description: Text(message)
        )
      default:
        list(model)
      }
    }
  }

  @ViewBuilder
  private func list(_ model: PaymentsModel) -> some View {
    if empty(model) {
      if model.phase == .loading {
        ProgressView()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        ContentUnavailableView(
          "No \(segment.label)",
          systemImage: "creditcard",
          description: Text("Nothing has been created yet.")
        )
      }
    } else {
      rows(model)
    }
  }

  @ViewBuilder
  private func rows(_ model: PaymentsModel) -> some View {
    List {
      switch segment {
      case .paymentIntents:
        ForEach(model.paymentIntents, id: \.id) { intent in
          NavigationLink(value: PaymentRoute.intent(intent.id)) {
            PaymentIntentRow(intent: intent)
          }
        }
      case .charges:
        ForEach(model.charges, id: \.id) { charge in
          NavigationLink(value: PaymentRoute.charge(charge.id)) {
            ChargeRow(charge: charge)
          }
        }
      case .refunds:
        ForEach(model.refunds, id: \.id) { refund in
          NavigationLink(value: PaymentRoute.refund(refund.id)) {
            RefundRow(refund: refund)
          }
        }
      case .setupIntents:
        ForEach(model.setupIntents, id: \.id) { intent in
          NavigationLink(value: PaymentRoute.setupIntent(intent.id)) {
            SetupIntentRow(intent: intent)
          }
        }
      case .paymentMethods:
        ForEach(model.paymentMethods, id: \.id) { method in
          NavigationLink(value: PaymentRoute.paymentMethod(method.id)) {
            PaymentMethodRow(method: method)
          }
        }
      case .paymentLinks:
        ForEach(model.paymentLinks, id: \.id) { link in
          NavigationLink(value: PaymentRoute.paymentLink(link.id)) {
            PaymentLinkRow(link: link)
          }
        }
      }
    }
    .overlay(alignment: .top) {
      if model.phase == .loading { ProgressView().padding(.top, 4) }
    }
    .navigationDestination(for: PaymentRoute.self) { route in
      PaymentDetailView(route: route, backend: backend, writer: writer)
    }
  }

  private func empty(_ model: PaymentsModel) -> Bool {
    switch segment {
    case .paymentIntents: return model.paymentIntents.isEmpty
    case .charges: return model.charges.isEmpty
    case .refunds: return model.refunds.isEmpty
    case .setupIntents: return model.setupIntents.isEmpty
    case .paymentMethods: return model.paymentMethods.isEmpty
    case .paymentLinks: return model.paymentLinks.isEmpty
    }
  }
}

/// Routes a tapped row to the right detail screen, fetching by ID.
struct PaymentDetailView: View {
  let route: PaymentRoute
  let backend: any PaymentsBackend
  let writer: PaymentsWriteService?

  var body: some View {
    switch route {
    case .intent(let id):
      PaymentIntentDetailView(intentID: id, backend: backend, writer: writer)
    case .charge(let id):
      ChargeDetailView(chargeID: id, backend: backend, writer: writer)
    case .refund(let id):
      RefundDetailView(refundID: id, backend: backend, writer: writer)
    case .setupIntent(let id):
      SetupIntentDetailView(intentID: id, backend: backend)
    case .paymentMethod(let id):
      PaymentMethodDetailView(methodID: id, backend: backend)
    case .paymentLink(let id):
      PaymentLinkDetailView(linkID: id, backend: backend)
    }
  }
}
