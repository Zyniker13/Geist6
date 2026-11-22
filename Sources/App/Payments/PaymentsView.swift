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
  case checkoutSession(String)
  case payout(String)
  case transfer(String)
  case topup(String)
}

/// The payments tab: six browsable lists of one account's payment objects.
/// Writes live behind the management-mode gate: lifecycle actions on each
/// object's detail screen, and creating payment intents from the toolbar.
struct PaymentsView: View {
  let account: Account
  let backend: any PaymentsBackend
  /// Nil for dashboard-locked accounts: no write UI exists at all.
  let writer: PaymentsWriteService?

  @State private var model: PaymentsModel?
  @State private var segment: PaymentsModel.Segment = .paymentIntents
  @State private var createPresented = false
  @State private var createSetupPresented = false
  @State private var createMethodPresented = false
  @State private var createLinkPresented = false
  @State private var createChargePresented = false
  @State private var createPayoutPresented = false
  @State private var filterPresented = false
  @State private var writeResult: WriteResult?

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
    .toolbar {
      // Two separate items: a single .primaryAction ToolbarItem renders only
      // one of its children on iPadOS, which hid the create buttons.
      ToolbarItem(placement: .primaryAction) {
        Button {
          filterPresented = true
        } label: {
          Label(
            "Filter",
            systemImage: model?.filter.isEmpty == false
              ? "line.3.horizontal.decrease.circle.fill"
              : "line.3.horizontal.decrease.circle"
          )
        }
        .accessibilityIdentifier("payments.filter")
      }
      ToolbarItem(placement: .primaryAction) {
        if writer != nil, segment == .paymentIntents {
          Button {
            createPresented = true
          } label: {
            Label("New payment intent", systemImage: "plus")
          }
          .accessibilityIdentifier("payments.newIntent")
        }
        if writer != nil, segment == .setupIntents {
          Button {
            createSetupPresented = true
          } label: {
            Label("New setup intent", systemImage: "plus")
          }
          .accessibilityIdentifier("payments.newSetupIntent")
        }
        if writer != nil, segment == .paymentMethods {
          Button {
            createMethodPresented = true
          } label: {
            Label("New payment method", systemImage: "plus")
          }
          .accessibilityIdentifier("payments.newMethod")
        }
        if writer != nil, segment == .paymentLinks {
          Button {
            createLinkPresented = true
          } label: {
            Label("New payment link", systemImage: "plus")
          }
          .accessibilityIdentifier("payments.newLink")
        }
        if writer != nil, segment == .charges {
          Button {
            createChargePresented = true
          } label: {
            Label("New charge", systemImage: "plus")
          }
          .accessibilityIdentifier("payments.newCharge")
        }
        if writer != nil, segment == .payouts {
          Button {
            createPayoutPresented = true
          } label: {
            Label("New payout", systemImage: "plus")
          }
          .accessibilityIdentifier("payments.newPayout")
        }
      }
    }
    .sheet(isPresented: $createPresented) {
      if let writer {
        CreateIntentSheet(writer: writer, onFinished: handleCreateFinished)
      }
    }
    .sheet(isPresented: $createSetupPresented) {
      if let writer {
        CreateSetupIntentSheet(writer: writer, onFinished: handleCreateFinished)
      }
    }
    .sheet(isPresented: $createMethodPresented) {
      if let writer {
        CreatePaymentMethodSheet(writer: writer, onFinished: handleCreateFinished)
      }
    }
    .sheet(isPresented: $createLinkPresented) {
      if let writer {
        CreatePaymentLinkSheet(writer: writer, onFinished: handleCreateFinished)
      }
    }
    .sheet(isPresented: $createChargePresented) {
      if let writer {
        CreateChargeSheet(writer: writer, onFinished: handleCreateFinished)
      }
    }
    .sheet(isPresented: $createPayoutPresented) {
      if let writer {
        CreatePayoutSheet(writer: writer, onFinished: handleCreateFinished)
      }
    }
    .sheet(isPresented: $filterPresented) {
      PaymentsFilterSheet(
        segment: filterSegment,
        current: model?.filter ?? .none
      ) { applied in
        Task { await model?.apply(applied) }
      }
    }
    .writeResultAlert($writeResult)
  }

  private func handleCreateFinished(_ result: WriteResult) {
    createPresented = false
    createSetupPresented = false
    createMethodPresented = false
    createLinkPresented = false
    createChargePresented = false
    writeResult = result
    Task { await model?.load(segment) }
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
          description: Text(emptyDescription(model))
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
      case .checkoutSessions:
        ForEach(model.checkoutSessions, id: \.id) { session in
          NavigationLink(value: PaymentRoute.checkoutSession(session.id)) {
            CheckoutSessionRow(session: session)
          }
        }
      case .payouts:
        ForEach(model.payouts, id: \.id) { payout in
          NavigationLink(value: PaymentRoute.payout(payout.id)) {
            PayoutRow(payout: payout)
          }
        }
      case .transfers:
        ForEach(model.transfers, id: \.id) { transfer in
          NavigationLink(value: PaymentRoute.transfer(transfer.id)) {
            TransferRow(transfer: transfer)
          }
        }
      case .topups:
        ForEach(model.topups, id: \.id) { topup in
          NavigationLink(value: PaymentRoute.topup(topup.id)) {
            TopupRow(topup: topup)
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
    case .checkoutSessions: return model.checkoutSessions.isEmpty
    case .payouts: return model.payouts.isEmpty
    case .transfers: return model.transfers.isEmpty
    case .topups: return model.topups.isEmpty
    }
  }

  /// Distinguishes "nothing exists yet" from "the filter narrowed it away".
  private func emptyDescription(_ model: PaymentsModel) -> String {
    if !model.filter.isEmpty, model.filter.isRelevant(to: filterSegment) {
      return "No results match the filter."
    }
    return "Nothing has been created yet."
  }

  /// The view's segment and the filter's segment enum have the same cases.
  private var filterSegment: PaymentsFilter.Segment {
    PaymentsFilter.Segment(rawValue: segment.rawValue) ?? .paymentIntents
  }
}

/// Routes a tapped row to the right detail screen, fetching by ID.
struct PaymentDetailView: View {
  let route: PaymentRoute
  let backend: any PaymentsBackend
  let writer: PaymentsWriteService?

  var body: some View {
    Group {
      switch route {
      case .intent(let id):
        PaymentIntentDetailView(intentID: id, backend: backend, writer: writer)
      case .charge(let id):
        ChargeDetailView(chargeID: id, backend: backend, writer: writer)
      case .refund(let id):
        RefundDetailView(refundID: id, backend: backend, writer: writer)
      case .setupIntent(let id):
        SetupIntentDetailView(intentID: id, backend: backend, writer: writer)
      case .paymentMethod(let id):
        PaymentMethodDetailView(methodID: id, backend: backend, writer: writer)
      case .paymentLink(let id):
        PaymentLinkDetailView(linkID: id, backend: backend, writer: writer)
      case .checkoutSession(let id):
        CheckoutSessionDetailView(sessionID: id, backend: backend, writer: writer)
      case .payout(let id):
        PayoutDetailView(payoutID: id, backend: backend, writer: writer)
      case .transfer(let id):
        TransferDetailView(transferID: id, backend: backend)
      case .topup(let id):
        TopupDetailView(topupID: id, backend: backend)
      }
    }
  }
}
