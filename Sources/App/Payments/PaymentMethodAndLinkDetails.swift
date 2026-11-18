import GeistData
import StripeModels
import SwiftUI

/// The detail screen for one setup intent.
struct SetupIntentDetailView: View {
  enum Phase: Equatable {
    case loading
    case loaded(SetupIntent)
    case failed(String)
  }

  let intentID: String
  let backend: any PaymentsBackend

  @State private var phase: Phase = .loading

  var body: some View {
    Group {
      switch phase {
      case .loading:
        ProgressView()
      case .failed(let message):
        ContentUnavailableView(
          "Couldn't load setup intent",
          systemImage: "exclamationmark.triangle",
          description: Text(message)
        )
      case .loaded(let intent):
        details(intent)
      }
    }
    .navigationTitle("Setup Intent")
    .navigationBarTitleDisplayMode(.inline)
    .task(id: intentID) { await load() }
  }

  @ViewBuilder
  private func details(_ intent: SetupIntent) -> some View {
    List {
      Section {
        HStack(alignment: .firstTextBaseline) {
          Text(intent.status.rawValue)
            .font(.title3.weight(.semibold))
          Spacer(minLength: 8)
          PaymentStatusBadge(text: intent.status.rawValue)
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("payments.setupIntent.status")
      }

      Section("Details") {
        PaymentFactRow(label: "Usage", value: intent.usage)
        PaymentFactRow(label: "Created", value: "\(intent.created.date.formatted(date: .abbreviated, time: .omitted))")
        if let customer = intent.customer.valueOrNil {
          PaymentFactRow(label: "Customer", value: paymentCustomerID(customer))
        }
      }
    }
  }

  private func load() async {
    phase = .loading
    do {
      phase = .loaded(try await backend.retrieveSetupIntent(id: intentID))
    } catch {
      phase = .failed(String(describing: error))
    }
  }
}

/// The detail screen for one payment method.
struct PaymentMethodDetailView: View {
  enum Phase: Equatable {
    case loading
    case loaded(PaymentMethod)
    case failed(String)
  }

  let methodID: String
  let backend: any PaymentsBackend

  @State private var phase: Phase = .loading

  var body: some View {
    Group {
      switch phase {
      case .loading:
        ProgressView()
      case .failed(let message):
        ContentUnavailableView(
          "Couldn't load payment method",
          systemImage: "exclamationmark.triangle",
          description: Text(message)
        )
      case .loaded(let method):
        details(method)
      }
    }
    .navigationTitle("Payment Method")
    .navigationBarTitleDisplayMode(.inline)
    .task(id: methodID) { await load() }
  }

  @ViewBuilder
  private func details(_ method: PaymentMethod) -> some View {
    List {
      Section {
        HStack(alignment: .firstTextBaseline) {
          Text(method.type.rawValue)
            .font(.title3.weight(.semibold))
          Spacer(minLength: 8)
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("payments.method.type")
      }

      Section("Details") {
        PaymentFactRow(label: "Created", value: "\(method.created.date.formatted(date: .abbreviated, time: .omitted))")
        if let card = method.card {
          PaymentFactRow(label: "Card", value: "\(card.brand) •••• \(card.last4)")
        }
        if let customer = method.customer.valueOrNil?.idOrNil {
          PaymentFactRow(label: "Customer", value: customer)
        }
      }
    }
  }

  private func load() async {
    phase = .loading
    do {
      phase = .loaded(try await backend.retrievePaymentMethod(id: methodID))
    } catch {
      phase = .failed(String(describing: error))
    }
  }
}

/// The detail screen for one payment link, including its line items.
struct PaymentLinkDetailView: View {
  enum Phase: Equatable {
    case loading
    case loaded(PaymentLink)
    case failed(String)
  }

  let linkID: String
  let backend: any PaymentsBackend

  @State private var phase: Phase = .loading
  @State private var lineItems: [Item]?
  @State private var itemsFailed = false

  var body: some View {
    Group {
      switch phase {
      case .loading:
        ProgressView()
      case .failed(let message):
        ContentUnavailableView(
          "Couldn't load payment link",
          systemImage: "exclamationmark.triangle",
          description: Text(message)
        )
      case .loaded(let link):
        details(link)
      }
    }
    .navigationTitle("Payment Link")
    .navigationBarTitleDisplayMode(.inline)
    .task(id: linkID) { await load() }
  }

  @ViewBuilder
  private func details(_ link: PaymentLink) -> some View {
    List {
      Section {
        HStack(alignment: .firstTextBaseline) {
          Text(link.active ? "Active" : "Inactive")
            .font(.title3.weight(.semibold))
          Spacer(minLength: 8)
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("payments.link.status")
      }

      Section("URL") {
        Text(link.url)
          .font(.footnote.monospaced())
          .textSelection(.enabled)
      }

      Section("Line Items") {
        if let lineItems {
          ForEach(Array(lineItems.enumerated()), id: \.offset) { _, item in
            HStack(alignment: .firstTextBaseline) {
              Text(item.description.valueOrNil ?? "Item")
                .font(.subheadline)
              Spacer(minLength: 8)
              Text(MoneyFormat.amount(item.amountTotal, currency: item.currency))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
          }
        } else if itemsFailed {
          Text("Couldn't load line items.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        } else {
          ProgressView()
        }
      }
    }
  }

  private func load() async {
    phase = .loading
    lineItems = nil
    itemsFailed = false
    do {
      let link = try await backend.retrievePaymentLink(id: linkID)
      phase = .loaded(link)
      do {
        lineItems = try await backend.paymentLinkLineItems(id: link.id)
      } catch {
        itemsFailed = true
      }
    } catch {
      phase = .failed(String(describing: error))
    }
  }
}
