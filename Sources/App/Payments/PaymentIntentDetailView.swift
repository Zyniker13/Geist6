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
  /// Nil for dashboard-locked accounts: no write controls are shown.
  let writer: PaymentsWriteService?

  @State private var phase: Phase = .loading
  @State private var timeline: PaymentTimeline?
  @State private var timelineFailed = false
  @State private var lineItems: [PaymentIntentAmountDetailsLineItem]?
  @State private var capturePresented = false
  @State private var cancelPresented = false
  @State private var confirmPresented = false
  @State private var applyBalancePresented = false
  @State private var incrementPresented = false
  @State private var verifyDepositsPresented = false
  @State private var editPresented = false
  @State private var writeResult: WriteResult?

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
    .toolbar { actionsToolbar }
    .sheet(isPresented: $capturePresented) {
      if case .loaded(let intent) = phase, let writer {
        CaptureSheet(target: .intent(intent), writer: writer, onFinished: handleWriteFinished)
      }
    }
    .sheet(isPresented: $cancelPresented) {
      if case .loaded(let intent) = phase, let writer {
        CancelIntentSheet(intent: intent, writer: writer, onFinished: handleWriteFinished)
      }
    }
    .sheet(isPresented: $applyBalancePresented) {
      if case .loaded(let intent) = phase, let writer {
        ApplyCustomerBalanceSheet(
          intent: intent, writer: writer, onFinished: handleWriteFinished)
      }
    }
    .sheet(isPresented: $incrementPresented) {
      if case .loaded(let intent) = phase, let writer {
        IncrementAuthorizationSheet(
          intent: intent, writer: writer, onFinished: handleWriteFinished)
      }
    }
    .sheet(isPresented: $verifyDepositsPresented) {
      if case .loaded(let intent) = phase, let writer {
        VerifyMicrodepositsSheet(
          target: .paymentIntent(intent), writer: writer, onFinished: handleWriteFinished)
      }
    }
    .sheet(isPresented: $editPresented) {
      if case .loaded(let intent) = phase, let writer {
        EditPaymentIntentSheet(intent: intent, writer: writer, onFinished: handleWriteFinished)
      }
    }
    .confirmationDialog(
      "Confirm this payment now? The customer's payment method will be charged.",
      isPresented: $confirmPresented, titleVisibility: .visible
    ) {
      Button("Confirm now") {
        Task { await runConfirm() }
      }
      .accessibilityIdentifier("payments.intent.confirmRun")
      Button("Cancel", role: .cancel) {}
    }
    .writeResultAlert($writeResult)
  }

  @ToolbarContentBuilder
  private var actionsToolbar: some ToolbarContent {
    ToolbarItem(placement: .primaryAction) {
      if let writer, case .loaded(let intent) = phase {
        Menu {
          if intent.status == .requiresConfirmation {
            Button("Confirm…") { confirmPresented = true }
              .accessibilityIdentifier("payments.intent.confirm")
          }
          if intent.status == .requiresCapture, intent.amountCapturable > 0 {
            Button("Capture…") { capturePresented = true }
              .accessibilityIdentifier("payments.intent.capture")
          }
          if intent.status == .requiresPaymentMethod {
            Button("Apply customer balance…") { applyBalancePresented = true }
              .accessibilityIdentifier("payments.intent.applyBalance")
          }
          if intent.status == .requiresCapture {
            Button("Increment authorization…") { incrementPresented = true }
              .accessibilityIdentifier("payments.intent.increment")
          }
          if isCancellable(intent.status),
            intent.paymentMethodTypes.contains("us_bank_account") {
            Button("Verify microdeposits…") { verifyDepositsPresented = true }
              .accessibilityIdentifier("payments.intent.verifyDeposits")
          }
          Button("Edit description & metadata…") { editPresented = true }
            .accessibilityIdentifier("payments.intent.edit")
          if isCancellable(intent.status) {
            Button("Cancel intent…", role: .destructive) { cancelPresented = true }
              .accessibilityIdentifier("payments.intent.cancel")
          }
        } label: {
          Label("Actions", systemImage: "ellipsis.circle")
        }
        .accessibilityIdentifier("payments.intent.actions")
      }
    }
  }

  /// Stripe cancels intents in these (interactive) statuses.
  private func isCancellable(_ status: PaymentIntentStatus) -> Bool {
    switch status {
    case .requiresPaymentMethod, .requiresConfirmation, .requiresCapture, .requiresAction,
      .processing:
      return true
    case .canceled, .succeeded, .undocumented:
      return false
    }
  }

  private func handleWriteFinished(_ result: WriteResult) {
    capturePresented = false
    cancelPresented = false
    applyBalancePresented = false
    incrementPresented = false
    verifyDepositsPresented = false
    editPresented = false
    writeResult = result
    Task { await load() }
  }

  private func runConfirm() async {
    guard let writer, case .loaded(let intent) = phase else { return }
    do {
      _ = try await writer.confirmPaymentIntent(
        id: intent.id, summary: "Confirm \(intent.id)")
      writeResult = WriteResult(
        title: "Payment confirmed", message: "Confirm request sent for \(intent.id).")
      await load()
    } catch {
      writeResult = WriteResult(
        title: "Write failed", message: writeErrorMessage(error))
    }
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

      if let lineItems, !lineItems.isEmpty {
        Section("Line items") {
          ForEach(Array(lineItems.enumerated()), id: \.offset) { pair in
            let item = pair.element
            VStack(alignment: .leading, spacing: 2) {
              HStack(alignment: .firstTextBaseline) {
                Text(item.productName)
                  .font(.subheadline.weight(.medium))
                Spacer(minLength: 8)
                Text(
                  MoneyFormat.amount(
                    item.unitCost * item.quantity, currency: intent.currency))
              }
              HStack(alignment: .firstTextBaseline) {
                Text(
                  "\(item.quantity) \u{00d7} "
                    + MoneyFormat.amount(item.unitCost, currency: intent.currency))
                  .font(.caption)
                  .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                if let tax = item.tax.valueOrNil, tax.totalTaxAmount > 0 {
                  Text(
                    "tax "
                      + MoneyFormat.amount(tax.totalTaxAmount, currency: intent.currency))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
              }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("payments.intent.lineItem.\(pair.offset)")
          }
        }
      }

      MetadataSection(metadata: intent.metadata)
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
    lineItems = nil
    do {
      let intent = try await backend.retrievePaymentIntent(id: intentID)
      phase = .loaded(intent)
      do {
        timeline = try await PaymentTimelineLoader(backend: backend).load(intent: intent)
      } catch {
        timelineFailed = true
      }
      // Amount-details line items are a best-effort companion: the
      // endpoint only carries data when the intent was created with
      // amount_details.line_items, so failures just leave the section off.
      lineItems = try? await backend.intentLineItems(intent: intent.id)
    } catch {
      phase = .failed(String(describing: error))
    }
  }
}
