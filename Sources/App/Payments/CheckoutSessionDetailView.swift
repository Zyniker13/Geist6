// CheckoutSessionDetailView.swift — App/Payments
// The checkout-session detail screen (M4c-6): a read-only summary of the
// session's mode, status, amounts, and line items, plus the one lifecycle
// write a session supports: expiring an open session. The write lives
// behind the management-mode gate (writer is nil in dashboard mode) and
// carries an idempotency key like every other write.

import GeistData
import StripeModels
import SwiftUI

struct CheckoutSessionDetailView: View {
  enum Phase: Equatable {
    case loading
    case loaded
    case failed(String)
  }

  let sessionID: String
  let backend: any PaymentsBackend
  /// Nil for dashboard-locked accounts: no write controls are shown.
  let writer: PaymentsWriteService?

  @State private var phase: Phase = .loading
  @State private var session: CheckoutSession?
  @State private var items: [Item] = []
  @State private var expirePresented = false
  @State private var writeResult: WriteResult?

  var body: some View {
    Group {
      switch phase {
      case .loading:
        ProgressView()
      case .failed(let message):
        ContentUnavailableView(
          "Couldn't load checkout session",
          systemImage: "exclamationmark.triangle",
          description: Text(message)
        )
      case .loaded:
        if let session {
          details(session)
        }
      }
    }
    .navigationTitle("Checkout session")
    .navigationBarTitleDisplayMode(.inline)
    .task(id: sessionID) { await load() }
    .toolbar { expireToolbar }
    .confirmationDialog(
      "Expire this open session? It can no longer be completed.",
      isPresented: $expirePresented, titleVisibility: .visible
    ) {
      Button("Expire session", role: .destructive) {
        Task { await runExpire() }
      }
      .accessibilityIdentifier("payments.checkoutDetail.expireRun")
      Button("Keep session", role: .cancel) {}
    }
    .writeResultAlert($writeResult)
  }

  @ToolbarContentBuilder
  private var expireToolbar: some ToolbarContent {
    ToolbarItem(placement: .primaryAction) {
      if let writer, let session, session.status.valueOrNil == .open {
        Button("Expire…") { expirePresented = true }
          .accessibilityIdentifier("payments.checkoutDetail.expire")
      }
    }
  }

  private func load() async {
    phase = .loading
    do {
      let loaded = try await backend.retrieveCheckoutSession(id: sessionID)
      items = (try? await backend.checkoutSessionLineItems(id: sessionID)) ?? []
      session = loaded
      phase = .loaded
    } catch {
      phase = .failed(String(describing: error))
    }
  }

  private func runExpire() async {
    guard let writer, let session else { return }
    do {
      let expired = try await writer.expireCheckoutSession(
        id: session.id, summary: "Expire checkout session \(session.id)")
      // Reload first, then surface the result: setting writeResult before the
      // phase swap cancels the pending alert presentation.
      await load()
      writeResult = WriteResult(
        title: "Session expired", message: "Checkout session \(expired.id) can no longer be completed.")
    } catch {
      writeResult = WriteResult(title: "Write failed", message: writeErrorMessage(error))
    }
  }

  @ViewBuilder
  private func details(_ session: CheckoutSession) -> some View {
    List {
      Section {
        HStack(alignment: .firstTextBaseline) {
          Text(title(session))
            .font(.largeTitle.weight(.bold))
          Spacer(minLength: 8)
          PaymentStatusBadge(text: session.status.valueOrNil?.rawValue ?? "unknown")
        }
        Text(verbatim: session.id)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      amounts(session)
      facts(session)
      if !items.isEmpty {
        Section("Line items") {
          ForEach(items, id: \.id) { item in
            HStack(alignment: .firstTextBaseline) {
              VStack(alignment: .leading, spacing: 2) {
                Text(item.description.valueOrNil ?? "Item")
                Text("×\(item.quantity.valueOrNil ?? 0)")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
              Spacer(minLength: 8)
              Text(MoneyFormat.amount(item.amountTotal, currency: item.currency))
            }
          }
        }
      }
      if let intentID {
        Section {
          NavigationLink(value: PaymentRoute.intent(intentID)) {
            Label("Payment intent", systemImage: "creditcard")
          }
          .accessibilityIdentifier("payments.checkoutDetail.intentLink")
        }
      }
    }
  }

  /// Amounts only exist once the session has been completed; before that
  /// the section is skipped rather than showing null rows.
  @ViewBuilder
  private func amounts(_ session: CheckoutSession) -> some View {
    if let amount = session.amountTotal.valueOrNil, let currency = session.currency.valueOrNil {
      Section("Amounts") {
        row("Total", MoneyFormat.amount(amount, currency: currency))
        if let subtotal = session.amountSubtotal.valueOrNil {
          row("Subtotal", MoneyFormat.amount(subtotal, currency: currency))
        }
        if let details = session.totalDetails.valueOrNil {
          if details.amountDiscount != 0 {
            row("Discount", "−" + MoneyFormat.amount(details.amountDiscount, currency: currency))
          }
          if let shipping = details.amountShipping.valueOrNil, shipping != 0 {
            row("Shipping", MoneyFormat.amount(shipping, currency: currency))
          }
          if details.amountTax != 0 {
            row("Tax", MoneyFormat.amount(details.amountTax, currency: currency))
          }
        }
      }
    }
  }

  @ViewBuilder
  private func facts(_ session: CheckoutSession) -> some View {
    Section("Session") {
      row("Mode", session.mode.rawValue)
      row("Payment status", session.paymentStatus.rawValue)
      row("Created", session.created.date.formatted(date: .abbreviated, time: .shortened))
      row("Expires", session.expiresAt.date.formatted(date: .abbreviated, time: .shortened))
      if let customer = customerID(session.customer.valueOrNil) {
        row("Customer", customer)
      }
      if let email = session.customerDetails.valueOrNil?.email.valueOrNil
        ?? session.customerEmail.valueOrNil, !email.isEmpty {
        row("Email", email)
      }
      if let url = session.url.valueOrNil {
        Link(destination: URL(string: url) ?? URL(fileURLWithPath: "/")) {
          Label("Hosted checkout page", systemImage: "link")
            .lineLimit(1)
        }
      }
    }
  }

  private var intentID: String? {
    guard let session else { return nil }
    switch session.paymentIntent.valueOrNil {
    case .id(let id): return id
    case .object(let intent): return intent.id
    case .none: return nil
    }
  }

  /// The session's customer ID, or nil when absent or unexpandable.
  private func customerID(_ customer: CheckoutSessionCustomer?) -> String? {
    switch customer {
    case .string(let id): return id
    case .customer(let customer): return customer.id
    case .deletedCustomer(let deleted): return deleted.id
    case .none, .other: return nil
    }
  }

  private func title(_ session: CheckoutSession) -> String {
    if let amount = session.amountTotal.valueOrNil, let currency = session.currency.valueOrNil {
      return MoneyFormat.amount(amount, currency: currency)
    }
    return session.mode.rawValue
  }

  private func row(_ label: String, _ value: String) -> some View {
    HStack(alignment: .firstTextBaseline) {
      Text(label)
      Spacer(minLength: 12)
      Text(value)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.trailing)
    }
  }
}
