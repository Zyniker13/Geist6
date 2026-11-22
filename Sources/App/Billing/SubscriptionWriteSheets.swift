import GeistData
import StripeModels
import SwiftUI

// The subscription write sheets: edit, cancel, pause, and add item. Each
// follows the InvoiceWriteSheets pattern — a Form, a submit button gated on
// `running`, failures shown inline, and an `onFinished` callback that the
// detail view turns into a result alert plus a reload. Every request runs
// through `BillingWriteService`, which refuses in dashboard mode before any
// network traffic.

// MARK: - Edit subscription sheet

/// Edits a subscription's description, metadata, collection method, and
/// due days, and toggles cancel-at-period-end. The metadata box replaces
/// metadata wholesale (empty clears it).
struct EditSubscriptionSheet: View {
  let subscription: Subscription
  let writer: BillingWriteService
  let onFinished: (WriteResult) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var descriptionText: String
  @State private var metadataText: String
  @State private var cancelAtPeriodEnd: Bool
  @State private var collectionMethod: CollectionMethodChoice
  @State private var daysUntilDueText: String
  @State private var running = false
  @State private var failureText: String?

  init(
    subscription: Subscription, writer: BillingWriteService,
    onFinished: @escaping (WriteResult) -> Void
  ) {
    self.subscription = subscription
    self.writer = writer
    self.onFinished = onFinished
    _descriptionText = State(initialValue: subscription.description.valueOrNil ?? "")
    _metadataText = State(initialValue: formatMetadataLines(subscription.metadata))
    _cancelAtPeriodEnd = State(initialValue: subscription.cancelAtPeriodEnd)
    _collectionMethod = State(initialValue: CollectionMethodChoice(subscription.collectionMethod))
    _daysUntilDueText = State(
      initialValue: subscription.daysUntilDue.valueOrNil.map(String.init) ?? "")
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Edit subscription") {
          LabeledContent("Subscription", value: subscription.id)
          TextField("Description", text: $descriptionText)
            .accessibilityIdentifier("billing.subscription.edit.description")
          Toggle("Cancel at period end", isOn: $cancelAtPeriodEnd)
            .accessibilityIdentifier("billing.subscription.edit.cancelAtPeriodEnd")
          Picker("Collection method", selection: $collectionMethod) {
            ForEach(CollectionMethodChoice.allCases, id: \.self) { choice in
              Text(choice.label).tag(choice)
            }
          }
          .accessibilityIdentifier("billing.subscription.edit.collectionMethod")
          if collectionMethod == .sendInvoice {
            TextField("Days until due", text: $daysUntilDueText)
              .keyboardType(.numberPad)
              .accessibilityIdentifier("billing.subscription.edit.daysUntilDue")
          }
        }
        metadataEditor($metadataText, id: "billing.subscription.edit.metadata")
        if let failureText {
          failureSection(failureText, id: "billing.write.error")
        }
      }
      .navigationTitle("Edit subscription")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") { run() }
            .disabled(running)
            .accessibilityIdentifier("billing.subscription.edit.submit")
        }
      }
    }
  }

  private func run() {
    running = true
    failureText = nil
    let description = descriptionText.trimmingCharacters(in: .whitespaces)
    let daysUntilDue = daysUntilDueText.isEmpty ? nil : Int(daysUntilDueText)
    Task {
      do {
        let metadata = try MetadataLines.parse(metadataText)
        let updated = try await writer.updateSubscription(
          id: subscription.id,
          update: BillingWriteService.SubscriptionUpdate(
            description: description.isEmpty ? nil : description,
            metadata: metadata,
            cancelAtPeriodEnd: cancelAtPeriodEnd,
            collectionMethod: collectionMethod.value,
            daysUntilDue: collectionMethod == .sendInvoice ? daysUntilDue : nil,
            pauseCollection: nil,
            prorationBehavior: nil,
            prorationDate: nil,
            cancellationDetails: nil),
          summary: "Update subscription \(subscription.id)")
        await MainActor.run {
          onFinished(
            WriteResult(
              title: "Subscription updated",
              message: "\(updated.id) updated."))
        }
      } catch {
        await MainActor.run {
          running = false
          failureText = writeErrorMessage(error)
        }
      }
    }
  }
}

/// The collection-method picker's cases; each maps to the API value it sends.
enum CollectionMethodChoice: CaseIterable, Hashable {
  case chargeAutomatically
  case sendInvoice

  init(_ value: InvoiceCollectionMethod) {
    switch value {
    case .chargeAutomatically: self = .chargeAutomatically
    case .sendInvoice: self = .sendInvoice
    case .undocumented: self = .chargeAutomatically
    }
  }

  var label: String {
    switch self {
    case .chargeAutomatically: return "Charge automatically"
    case .sendInvoice: return "Send invoice"
    }
  }

  var value: InvoiceCollectionMethod? {
    switch self {
    case .chargeAutomatically: return .chargeAutomatically
    case .sendInvoice: return .sendInvoice
    }
  }
}

// MARK: - Cancel subscription sheet

/// Cancels a subscription immediately, with optional cancellation feedback.
struct CancelSubscriptionSheet: View {
  let subscriptionID: String
  let writer: BillingWriteService
  let onFinished: (WriteResult) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var commentText = ""
  @State private var feedback: FeedbackChoice?
  @State private var invoiceNow = false
  @State private var prorate = true
  @State private var running = false
  @State private var failureText: String?

  var body: some View {
    NavigationStack {
      Form {
        Section("Cancel \(subscriptionID)") {
          Picker("Feedback", selection: $feedback) {
            Text("None").tag(Optional<FeedbackChoice>.none)
            ForEach(FeedbackChoice.allCases, id: \.self) { choice in
              Text(choice.label).tag(Optional(choice))
            }
          }
          .accessibilityIdentifier("billing.subscription.cancel.feedback")
          if feedback != nil {
            TextField("Comment (optional)", text: $commentText)
              .accessibilityIdentifier("billing.subscription.cancel.comment")
          }
          Toggle("Invoice now", isOn: $invoiceNow)
            .accessibilityIdentifier("billing.subscription.cancel.invoiceNow")
          Toggle("Prorate", isOn: $prorate)
            .accessibilityIdentifier("billing.subscription.cancel.prorate")
        }
        if let failureText {
          failureSection(failureText, id: "billing.write.error")
        }
      }
      .navigationTitle("Cancel subscription")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Keep subscription") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Cancel subscription", role: .destructive) { run() }
            .disabled(running)
            .accessibilityIdentifier("billing.subscription.cancel.submit")
        }
      }
    }
  }

  private func run() {
    running = true
    failureText = nil
    let comment = commentText.trimmingCharacters(in: .whitespaces)
    Task {
      do {
        let details: BillingWriteService.SubscriptionCancellationDetails? =
          feedback == nil && comment.isEmpty
            ? nil
            : BillingWriteService.SubscriptionCancellationDetails(
              comment: comment.isEmpty ? nil : comment,
              feedback: feedback?.value,
              feedbackOption: nil)
        let canceled = try await writer.cancelSubscription(
          id: subscriptionID,
          cancel: BillingWriteService.SubscriptionCancel(
            cancellationDetails: details,
            invoiceNow: invoiceNow ? true : nil,
            prorate: prorate ? nil : false),
          summary: "Cancel subscription \(subscriptionID)")
        await MainActor.run {
          onFinished(
            WriteResult(
              title: "Subscription canceled",
              message: "\(canceled.id) is canceled."))
        }
      } catch {
        await MainActor.run {
          running = false
          failureText = writeErrorMessage(error)
        }
      }
    }
  }
}

/// The cancellation-feedback picker's cases; each maps to the API value.
enum FeedbackChoice: CaseIterable, Hashable {
  case other
  case tooExpensive
  case missingFeatures
  case switchedService
  case unused
  case tooComplex
  case lowQuality
  case customerService

  var label: String {
    switch self {
    case .other: return "Other"
    case .tooExpensive: return "Too expensive"
    case .missingFeatures: return "Missing features"
    case .switchedService: return "Switched service"
    case .unused: return "Unused"
    case .tooComplex: return "Too complex"
    case .lowQuality: return "Low quality"
    case .customerService: return "Customer service"
    }
  }

  var value: SubscriptionCancelParamsCancellationDetailsFeedback {
    switch self {
    case .other: return .other
    case .tooExpensive: return .tooExpensive
    case .missingFeatures: return .missingFeatures
    case .switchedService: return .switchedService
    case .unused: return .unused
    case .tooComplex: return .tooComplex
    case .lowQuality: return .lowQuality
    case .customerService: return .customerService
    }
  }
}

// MARK: - Pause subscription sheet

/// Pauses a subscription via the dedicated pause verb. Stripe defaults
/// apply (collection, billing, and servicing pause; pending invoice items
/// carry forward), so the sheet is a bare confirmation — the mock and the
/// pinned probes pin the verb to an empty body.
struct PauseSubscriptionSheet: View {
  let subscriptionID: String
  let writer: BillingWriteService
  let onFinished: (WriteResult) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var running = false
  @State private var failureText: String?

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Text(
            "Pausing stops future invoices and billing-period advances for"
              + " \(subscriptionID). Past invoices stay untouched; the"
              + " subscription can be resumed later."
          )
          .font(.footnote)
          .foregroundStyle(.secondary)
        }
        if let failureText {
          failureSection(failureText, id: "billing.write.error")
        }
      }
      .navigationTitle("Pause subscription")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Pause") { run() }
            .disabled(running)
            .accessibilityIdentifier("billing.subscription.pause.submit")
        }
      }
    }
  }

  private func run() {
    running = true
    failureText = nil
    Task {
      do {
        let paused = try await writer.pauseSubscription(
          id: subscriptionID,
          pause: BillingWriteService.SubscriptionPause(
            billForOutstandingUsageThrough: nil,
            invoicingBehavior: nil,
            type: nil),
          summary: "Pause subscription \(subscriptionID)")
        await MainActor.run {
          onFinished(
            WriteResult(
              title: "Subscription paused",
              message: "\(paused.id) is paused."))
        }
      } catch {
        await MainActor.run {
          running = false
          failureText = writeErrorMessage(error)
        }
      }
    }
  }
}

// MARK: - Add item sheet

/// Adds a line to a subscription: an existing price plus quantity, or an
/// ad-hoc price (currency, product, unit amount, interval).
struct AddSubscriptionItemSheet: View {
  let subscriptionID: String
  let writer: BillingWriteService
  let onFinished: (WriteResult) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var priceID = ""
  @State private var quantityText = "1"
  @State private var useAdHocPrice = false
  @State private var currency = "usd"
  @State private var productID = ""
  @State private var unitAmountText = ""
  @State private var interval: IntervalChoice = .month
  @State private var running = false
  @State private var failureText: String?

  private var quantity: Int? { Int(quantityText) }

  var body: some View {
    NavigationStack {
      Form {
        Section("New item") {
          if !useAdHocPrice {
            TextField("Price ID (price_123)", text: $priceID)
              .textInputAutocapitalization(.never)
              .autocorrectionDisabled()
              .accessibilityIdentifier("billing.subscription.item.add.price")
          }
          TextField("Quantity", text: $quantityText)
            .keyboardType(.numberPad)
            .accessibilityIdentifier("billing.subscription.item.add.quantity")
          Toggle("Ad-hoc price", isOn: $useAdHocPrice)
            .accessibilityIdentifier("billing.subscription.item.add.adhoc")
          if useAdHocPrice {
            TextField("Currency (usd)", text: $currency)
              .textInputAutocapitalization(.never)
              .autocorrectionDisabled()
              .accessibilityIdentifier("billing.subscription.item.add.currency")
            TextField("Product ID (prod_123)", text: $productID)
              .textInputAutocapitalization(.never)
              .autocorrectionDisabled()
              .accessibilityIdentifier("billing.subscription.item.add.product")
            TextField("Unit amount in cents (e.g. 1500)", text: $unitAmountText)
              .keyboardType(.numberPad)
              .accessibilityIdentifier("billing.subscription.item.add.unitAmount")
            Picker("Interval", selection: $interval) {
              ForEach(IntervalChoice.allCases, id: \.self) { choice in
                Text(choice.label).tag(choice)
              }
            }
            .accessibilityIdentifier("billing.subscription.item.add.interval")
          }
        }
        if let failureText {
          failureSection(failureText, id: "billing.write.error")
        }
      }
      .navigationTitle("Add item")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Add") { run() }
            .disabled(running || !isValid)
            .accessibilityIdentifier("billing.subscription.item.add.submit")
        }
      }
    }
  }

  private var isValid: Bool {
    if useAdHocPrice {
      return !productID.trimmingCharacters(in: .whitespaces).isEmpty
        && (Int(unitAmountText) ?? 0) > 0
        && (quantity ?? 0) > 0
    }
    return !priceID.trimmingCharacters(in: .whitespaces).isEmpty && (quantity ?? 0) > 0
  }

  private func run() {
    running = true
    failureText = nil
    let price = priceID.trimmingCharacters(in: .whitespaces)
    let product = productID.trimmingCharacters(in: .whitespaces)
    let currencyCode = currency.trimmingCharacters(in: .whitespaces).lowercased()
    let unitAmount = Int(unitAmountText)
    Task {
      do {
        let item = BillingWriteService.SubscriptionItemDraft(
          price: useAdHocPrice ? nil : price,
          quantity: quantity,
          currency: useAdHocPrice ? currencyCode : nil,
          product: useAdHocPrice ? product : nil,
          unitAmount: useAdHocPrice ? unitAmount : nil,
          interval: useAdHocPrice ? interval.value : nil)
        let added = try await writer.addSubscriptionItem(
          id: subscriptionID, item: item, summary: "Add item to \(subscriptionID)")
        await MainActor.run {
          onFinished(
            WriteResult(
              title: "Item added",
              message: "\(added.id) added to \(subscriptionID)."))
        }
      } catch {
        await MainActor.run {
          running = false
          failureText = writeErrorMessage(error)
        }
      }
    }
  }
}

/// The interval picker's cases; each maps to the API value.
enum IntervalChoice: CaseIterable, Hashable {
  case day
  case week
  case month
  case year

  var label: String {
    switch self {
    case .day: return "Daily"
    case .week: return "Weekly"
    case .month: return "Monthly"
    case .year: return "Yearly"
    }
  }

  var value: PlanInterval {
    switch self {
    case .day: return .day
    case .week: return .week
    case .month: return .month
    case .year: return .year
    }
  }
}
