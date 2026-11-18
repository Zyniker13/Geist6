import GeistData
import StripeModels
import SwiftUI

/// One labeled fact line in a detail view.
struct PaymentFactRow: View {
  let label: String
  let value: String

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      Text(label)
        .font(.footnote)
        .foregroundStyle(.secondary)
      Spacer(minLength: 12)
      Text(value)
        .font(.footnote.weight(.medium))
        .multilineTextAlignment(.trailing)
        .textSelection(.enabled)
    }
  }
}

/// The detail screen for one payment intent, with its full timeline.
struct PaymentIntentDetailView: View {
  enum Phase: Equatable {
    case loading
    case loaded(PaymentIntent)
    case failed(String)
  }

  let intentID: String
  let backend: any PaymentsBackend

  @State private var phase: Phase = .loading
  @State private var timeline: PaymentTimeline?
  @State private var timelineFailed = false

  var body: some View {
    Group {
      switch phase {
      case .loading:
        ProgressView()
      case .failed(let message):
        ContentUnavailableView(
          "Couldn't load payment",
          systemImage: "exclamationmark.triangle",
          description: Text(message)
        )
      case .loaded(let intent):
        details(intent)
      }
    }
    .navigationTitle("Payment")
    .navigationBarTitleDisplayMode(.inline)
    .task(id: intentID) { await load() }
  }

  @ViewBuilder
  private func details(_ intent: PaymentIntent) -> some View {
    List {
      Section {
        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .firstTextBaseline) {
            Text(MoneyFormat.amount(intent.amount, currency: intent.currency))
              .font(.largeTitle.weight(.bold))
            Spacer(minLength: 8)
            PaymentStatusBadge(text: intent.status.rawValue)
          }
          Text(intent.id)
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .textSelection(.enabled)
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("payments.intent.amount")
      }

      Section("Details") {
        PaymentFactRow(label: "Status", value: intent.status.rawValue)
        PaymentFactRow(label: "Created", value: "\(intent.created.date.formatted(date: .abbreviated, time: .omitted))")
        if let customer = intent.customer.valueOrNil {
          PaymentFactRow(label: "Customer", value: paymentCustomerID(customer))
        }
        if let description = intent.description.valueOrNil {
          PaymentFactRow(label: "Description", value: description)
        }
        if let latestCharge = intent.latestCharge.valueOrNil?.idOrNil {
          PaymentFactRow(label: "Latest charge", value: latestCharge)
        }
      }

      Section("Timeline") {
        if let timeline {
          ForEach(timeline.entries) { entry in
            PaymentTimelineRow(entry: entry)
          }
        } else if timelineFailed {
          Text("Couldn't load the timeline.")
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
    timeline = nil
    timelineFailed = false
    do {
      let intent = try await backend.retrievePaymentIntent(id: intentID)
      phase = .loaded(intent)
      do {
        timeline = try await PaymentTimelineLoader(backend: backend).load(intent: intent)
      } catch {
        timelineFailed = true
      }
    } catch {
      phase = .failed(String(describing: error))
    }
  }
}
