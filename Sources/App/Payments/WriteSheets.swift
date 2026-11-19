import GeistData
import StripeClient
import StripeModels
import SwiftUI

// MARK: - Shared write-flow plumbing

/// The outcome of a completed write, surfaced as an alert by the parent view.
struct WriteResult: Identifiable {
  let id = UUID()
  let title: String
  let message: String
}

/// A human-readable message for a failed write. Mirrors the service's
/// audit-log mapping: API errors first, then localized errors.
func writeErrorMessage(_ error: Error) -> String {
  if let api = error as? StripeAPIError { return api.description }
  if let localized = error as? LocalizedError, let text = localized.errorDescription {
    return text
  }
  return String(describing: error)
}

extension View {
  /// Shows one success/failure alert driven by an optional result.
  func writeResultAlert(_ result: Binding<WriteResult?>) -> some View {
    alert(
      result.wrappedValue?.title ?? "",
      isPresented: Binding(
        get: { result.wrappedValue != nil },
        set: { if !$0 { result.wrappedValue = nil } }
      ),
      presenting: result.wrappedValue
    ) { _ in
      Button("OK", role: .cancel) {}
    } message: { shown in
      Text(shown.message)
    }
  }
}

/// A cancellable reason choice shared by the refund and cancel sheets.
enum WriteReasonOption: String, CaseIterable, Identifiable {
  case none = "No reason"
  case abandoned = "Abandoned"
  case duplicate = "Duplicate"
  case fraudulent = "Fraudulent"
  case requestedByCustomer = "Requested by customer"

  var id: String { rawValue }

  /// `nil` means "don't send a reason parameter".
  var apiValue: String? {
    switch self {
    case .none: return nil
    case .abandoned: return "abandoned"
    case .duplicate: return "duplicate"
    case .fraudulent: return "fraudulent"
    case .requestedByCustomer: return "requested_by_customer"
    }
  }
}

// MARK: - Refund sheet

/// Creates a refund for a charge: full remaining amount by default, or a
/// partial amount entered in minor units (cents), with an optional reason.
struct RefundSheet: View {
  let charge: Charge
  let writer: PaymentsWriteService
  /// Called once when a write completes. The parent dismisses the sheet,
  /// shows the result alert, and reloads.
  let onFinished: (WriteResult) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var fullAmount = true
  @State private var amountText = ""
  @State private var reason: WriteReasonOption = .none
  @State private var confirmPresented = false
  @State private var running = false
  @State private var failureText: String?

  private var remaining: Int { max(charge.amount - charge.amountRefunded, 0) }
  private var enteredMinor: Int? { Int(amountText) }
  private var effectiveMinor: Int? { fullAmount ? remaining : enteredMinor }
  private var preview: String {
    MoneyFormat.amount(effectiveMinor ?? 0, currency: charge.currency)
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Refund \(MoneyFormat.amount(charge.amount, currency: charge.currency)) charge") {
          LabeledContent("Charge", value: charge.id)
          LabeledContent(
            "Already refunded",
            value: MoneyFormat.amount(charge.amountRefunded, currency: charge.currency))
          Toggle("Refund full remaining amount", isOn: $fullAmount)
          if !fullAmount {
            TextField("Amount in cents", text: $amountText)
              .keyboardType(.numberPad)
              .accessibilityIdentifier("payments.refund.amountField")
          }
          Picker("Reason", selection: $reason) {
            ForEach(WriteReasonOption.allCases) { option in
              Text(option.rawValue).tag(option)
            }
          }
          .accessibilityIdentifier("payments.refund.reason")
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
      .navigationTitle("Refund")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Refund") {
            if validated() { confirmPresented = true }
          }
          .disabled(running || !inputIsValid)
          .accessibilityIdentifier("payments.refund.submit")
        }
      }
      .confirmationDialog(
        "Refund \(preview) from \(charge.id)?", isPresented: $confirmPresented,
        titleVisibility: .visible
      ) {
        Button("Refund \(preview)", role: .destructive) {
          Task { await run() }
        }
        .accessibilityIdentifier("payments.refund.confirm")
        Button("Cancel", role: .cancel) {}
      }
    }
  }

  /// False when the amount field holds something unusable (empty or out of
  /// range); also records the inline failure text.
  private var inputIsValid: Bool {
    if fullAmount { return remaining > 0 }
    guard let minor = enteredMinor, minor > 0, minor <= remaining else { return false }
    return true
  }

  private func validated() -> Bool {
    if inputIsValid { failureText = nil; return true }
    if fullAmount {
      failureText = "Nothing left to refund on this charge."
    } else {
      failureText = "Enter an amount between 1 and \(remaining) cents."
    }
    return false
  }

  private func run() async {
    running = true
    failureText = nil
    do {
      _ = try await writer.createRefund(
        charge: charge.id, amount: fullAmount ? nil : enteredMinor,
        reason: reason.apiValue,
        summary: "Refund \(preview) on \(charge.id)")
      onFinished(
        WriteResult(title: "Refund created", message: "Refunded \(preview)."))
    } catch {
      running = false
      failureText = writeErrorMessage(error)
    }
  }
}

// MARK: - Capture sheet

/// What a capture acts on: a charge or a payment intent.
enum CaptureTarget {
  case charge(Charge)
  case intent(PaymentIntent)
}

/// Captures a previously authorized charge or payment intent, in full or
/// partially (amount in cents). Charges can also set a receipt email.
struct CaptureSheet: View {
  let target: CaptureTarget
  let writer: PaymentsWriteService
  let onFinished: (WriteResult) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var fullAmount = true
  @State private var amountText = ""
  @State private var receiptEmail = ""
  @State private var confirmPresented = false
  @State private var running = false
  @State private var failureText: String?

  private var objectID: String {
    switch target {
    case .charge(let charge): return charge.id
    case .intent(let intent): return intent.id
    }
  }

  private var currency: String {
    switch target {
    case .charge(let charge): return charge.currency
    case .intent(let intent): return intent.currency
    }
  }

  /// The ceiling for a partial capture: the capturable amount.
  private var capturable: Int {
    switch target {
    case .charge(let charge): return max(charge.amount, 0)
    case .intent(let intent): return max(intent.amountCapturable, 0)
    }
  }

  private var enteredMinor: Int? { Int(amountText) }
  private var effectiveMinor: Int? { fullAmount ? capturable : enteredMinor }
  private var preview: String {
    MoneyFormat.amount(effectiveMinor ?? 0, currency: currency)
  }

  private var inputIsValid: Bool {
    if fullAmount { return capturable > 0 }
    guard let minor = enteredMinor, minor > 0, minor <= capturable else { return false }
    return true
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Capture \(preview)") {
          LabeledContent("Object", value: objectID)
          Toggle("Capture full amount", isOn: $fullAmount)
          if !fullAmount {
            TextField("Amount in cents", text: $amountText)
              .keyboardType(.numberPad)
              .accessibilityIdentifier("payments.capture.amountField")
          }
          if case .charge = target {
            TextField("Receipt email (optional)", text: $receiptEmail)
              .keyboardType(.emailAddress)
              .textInputAutocapitalization(.never)
              .autocorrectionDisabled()
              .accessibilityIdentifier("payments.capture.receiptEmail")
          }
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
      .navigationTitle("Capture")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Capture") {
            if inputIsValid {
              failureText = nil
              confirmPresented = true
            } else {
              failureText =
                fullAmount
                ? "Nothing is capturable on this object."
                : "Enter an amount between 1 and \(capturable) cents."
            }
          }
          .disabled(running || !inputIsValid)
          .accessibilityIdentifier("payments.capture.submit")
        }
      }
      .confirmationDialog(
        "Capture \(preview) from \(objectID)?", isPresented: $confirmPresented,
        titleVisibility: .visible
      ) {
        Button("Capture \(preview)", role: .destructive) {
          Task { await run() }
        }
        .accessibilityIdentifier("payments.capture.confirm")
        Button("Cancel", role: .cancel) {}
      }
    }
  }

  private func run() async {
    running = true
    failureText = nil
    do {
      switch target {
      case .charge(let charge):
        _ = try await writer.captureCharge(
          id: charge.id, amount: fullAmount ? nil : enteredMinor,
          receiptEmail: receiptEmail.isEmpty ? nil : receiptEmail,
          summary: "Capture \(preview) on \(charge.id)")
      case .intent(let intent):
        _ = try await writer.capturePaymentIntent(
          id: intent.id, amountToCapture: fullAmount ? nil : enteredMinor,
          summary: "Capture \(preview) on \(intent.id)")
      }
      onFinished(WriteResult(title: "Captured", message: "Captured \(preview)."))
    } catch {
      running = false
      failureText = writeErrorMessage(error)
    }
  }
}

// MARK: - Cancel sheet

/// Cancels a payment intent with an optional reason.
struct CancelIntentSheet: View {
  let intent: PaymentIntent
  let writer: PaymentsWriteService
  let onFinished: (WriteResult) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var reason: WriteReasonOption = .none
  @State private var confirmPresented = false
  @State private var running = false
  @State private var failureText: String?

  var body: some View {
    NavigationStack {
      Form {
        Section("Cancel payment intent") {
          LabeledContent("Intent", value: intent.id)
          LabeledContent(
            "Amount",
            value: MoneyFormat.amount(intent.amount, currency: intent.currency))
          Picker("Reason", selection: $reason) {
            ForEach(reasonOptions) { option in
              Text(option.rawValue).tag(option)
            }
          }
          .accessibilityIdentifier("payments.cancel.reason")
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
      .navigationTitle("Cancel intent")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Keep open") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Cancel intent", role: .destructive) {
            confirmPresented = true
          }
          .disabled(running)
          .accessibilityIdentifier("payments.cancel.submit")
        }
      }
      .confirmationDialog(
        "Cancel \(intent.id)? The customer will not be charged.", isPresented: $confirmPresented,
        titleVisibility: .visible
      ) {
        Button("Cancel intent", role: .destructive) {
          Task { await run() }
        }
        .accessibilityIdentifier("payments.cancel.confirm")
        Button("Keep open", role: .cancel) {}
      }
    }
  }

  /// Abandoned is meaningless without a prior confirmation attempt, so the
  /// picker here omits it.
  private var reasonOptions: [WriteReasonOption] {
    WriteReasonOption.allCases.filter { $0 != .abandoned }
  }

  private func run() async {
    running = true
    failureText = nil
    do {
      _ = try await writer.cancelPaymentIntent(
        id: intent.id, reason: reason.apiValue,
        summary: "Cancel \(intent.id)")
      onFinished(
        WriteResult(title: "Intent canceled", message: "\(intent.id) is now canceled."))
    } catch {
      running = false
      failureText = writeErrorMessage(error)
    }
  }
}
