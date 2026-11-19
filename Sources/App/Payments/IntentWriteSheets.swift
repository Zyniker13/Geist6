// IntentWriteSheets.swift — App/Payments
// The M4c intent write sheets: create, apply customer balance, increment
// authorization, verify microdeposits. Same contract as WriteSheets.swift:
// the service refuses in dashboard mode, every attempt carries an
// idempotency key, and API failures surface inside the sheet.

import GeistData
import StripeModels
import SwiftUI

// MARK: - Create payment intent

/// Creates a payment intent with the base fields: amount, currency,
/// optional customer and description, and a capture method.
struct CreateIntentSheet: View {
  let writer: PaymentsWriteService
  let onFinished: (WriteResult) -> Void

  enum CaptureMethod: Hashable {
    case stripeDefault
    case automatic
    case automaticAsync
    case manual

    var value: PaymentIntentCaptureMethod? {
      switch self {
      case .stripeDefault: return nil
      case .automatic: return .automatic
      case .automaticAsync: return .automaticAsync
      case .manual: return .manual
      }
    }

    var label: String {
      switch self {
      case .stripeDefault: return "Stripe default"
      case .automatic: return "Automatic"
      case .automaticAsync: return "Automatic (async)"
      case .manual: return "Manual"
      }
    }
  }

  static let currencies = ["usd", "eur", "gbp", "cad", "aud", "jpy"]

  @Environment(\.dismiss) private var dismiss
  @State private var amountText = ""
  @State private var currency = "usd"
  @State private var customer = ""
  @State private var descriptionText = ""
  @State private var captureMethod: CaptureMethod = .stripeDefault
  @State private var confirmPresented = false
  @State private var running = false
  @State private var failureText: String?

  private var amountMinor: Int? {
    guard let minor = Int(amountText), minor > 0 else { return nil }
    return minor
  }

  private var preview: String {
    MoneyFormat.amount(amountMinor ?? 0, currency: currency)
  }

  private var inputIsValid: Bool {
    guard amountMinor != nil else { return false }
    return currency.count == 3 && currency == currency.lowercased()
      && currency.allSatisfy { $0.isLetter }
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Amount") {
          TextField("Amount in cents (e.g. 1500)", text: $amountText)
            .keyboardType(.numberPad)
            .accessibilityIdentifier("payments.create.amountField")
          Picker("Currency", selection: $currency) {
            ForEach(Self.currencies, id: \.self) { code in
              Text(code.uppercased()).tag(code)
            }
          }
          .accessibilityIdentifier("payments.create.currency")
        }
        Section("Details") {
          TextField("Customer ID (optional)", text: $customer)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .accessibilityIdentifier("payments.create.customer")
          TextField("Description (optional)", text: $descriptionText)
            .accessibilityIdentifier("payments.create.description")
          Picker("Capture method", selection: $captureMethod) {
            ForEach(
              [CaptureMethod.stripeDefault, .automatic, .automaticAsync, .manual],
              id: \.self
            ) { method in
              Text(method.label).tag(method)
            }
          }
          .accessibilityIdentifier("payments.create.captureMethod")
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
      .navigationTitle("New payment intent")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Create") {
            failureText = nil
            confirmPresented = true
          }
          .disabled(running || !inputIsValid)
          .accessibilityIdentifier("payments.create.submit")
        }
      }
      .confirmationDialog(
        "Create a payment intent for " + preview + "?", isPresented: $confirmPresented,
        titleVisibility: .visible
      ) {
        Button("Create intent") {
          Task { await run() }
        }
        .accessibilityIdentifier("payments.create.confirm")
        Button("Cancel", role: .cancel) {}
      }
    }
  }

  private func run() async {
    running = true
    failureText = nil
    do {
      let intent = try await writer.createPaymentIntent(
        amount: amountMinor ?? 0, currency: currency,
        customer: customer.isEmpty ? nil : customer,
        description: descriptionText.isEmpty ? nil : descriptionText,
        captureMethod: captureMethod.value,
        summary: "Create intent for " + preview)
      onFinished(
        WriteResult(title: "Intent created", message: intent.id + " is ready."))
    } catch {
      running = false
      failureText = writeErrorMessage(error)
    }
  }
}

// MARK: - Apply customer balance

/// Manually reconciles a customer_balance intent: applies the customer's
/// balance to it. An empty amount applies the customer's remaining balance.
struct ApplyCustomerBalanceSheet: View {
  let intent: PaymentIntent
  let writer: PaymentsWriteService
  let onFinished: (WriteResult) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var amountText = ""
  @State private var currencyText = ""
  @State private var confirmPresented = false
  @State private var running = false
  @State private var failureText: String?

  private var amountMinor: Int? { Int(amountText) }

  private var inputIsValid: Bool {
    amountText.isEmpty || (amountMinor != nil && amountMinor! > 0)
  }

  private var preview: String {
    amountText.isEmpty
      ? "the customer's remaining balance"
      : MoneyFormat.amount(amountMinor ?? 0, currency: currencyText)
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Apply customer balance") {
          LabeledContent("Intent", value: intent.id)
          TextField("Amount in cents (empty = remaining)", text: $amountText)
            .keyboardType(.numberPad)
            .accessibilityIdentifier("payments.applyBalance.amountField")
          TextField(
            "Currency (optional)", text: $currencyText, prompt: Text(intent.currency)
          )
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .accessibilityIdentifier("payments.applyBalance.currency")
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
      .navigationTitle("Apply balance")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Apply") {
            if inputIsValid {
              failureText = nil
              confirmPresented = true
            } else {
              failureText = "Enter an amount above zero, or leave it empty."
            }
          }
          .disabled(running || !inputIsValid)
          .accessibilityIdentifier("payments.applyBalance.submit")
        }
      }
      .confirmationDialog(
        "Apply " + preview + " to " + intent.id + "?", isPresented: $confirmPresented,
        titleVisibility: .visible
      ) {
        Button("Apply balance") {
          Task { await run() }
        }
        .accessibilityIdentifier("payments.applyBalance.confirm")
        Button("Cancel", role: .cancel) {}
      }
    }
  }

  private func run() async {
    running = true
    failureText = nil
    do {
      _ = try await writer.applyCustomerBalancePaymentIntent(
        id: intent.id,
        amount: amountText.isEmpty ? nil : amountMinor,
        currency: currencyText.isEmpty ? nil : currencyText.lowercased(),
        summary: "Apply balance to " + intent.id)
      onFinished(
        WriteResult(
          title: "Balance applied",
          message: "Applied " + preview + " to " + intent.id + "."))
    } catch {
      running = false
      failureText = writeErrorMessage(error)
    }
  }
}

// MARK: - Increment authorization

/// Increments a card-present manual-capture authorization. The parameter is
/// the NEW total authorized amount, so the sheet prefills the intent's
/// current amount and only accepts a higher value.
struct IncrementAuthorizationSheet: View {
  let intent: PaymentIntent
  let writer: PaymentsWriteService
  let onFinished: (WriteResult) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var amountText: String
  @State private var confirmPresented = false
  @State private var running = false
  @State private var failureText: String?

  init(
    intent: PaymentIntent, writer: PaymentsWriteService,
    onFinished: @escaping (WriteResult) -> Void
  ) {
    self.intent = intent
    self.writer = writer
    self.onFinished = onFinished
    _amountText = State(initialValue: String(max(intent.amount, 0)))
  }

  private var newTotal: Int? { Int(amountText) }

  private var preview: String {
    MoneyFormat.amount(newTotal ?? 0, currency: intent.currency)
  }

  private var inputIsValid: Bool {
    guard let total = newTotal else { return false }
    return total > intent.amount
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Increment authorization") {
          LabeledContent("Intent", value: intent.id)
          LabeledContent(
            "Current total",
            value: MoneyFormat.amount(intent.amount, currency: intent.currency))
          TextField("New total amount in cents", text: $amountText)
            .keyboardType(.numberPad)
            .accessibilityIdentifier("payments.increment.amountField")
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
      .navigationTitle("Increment")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Increment") {
            if inputIsValid {
              failureText = nil
              confirmPresented = true
            } else {
              failureText = "The new total must be higher than the current authorization."
            }
          }
          .disabled(running || !inputIsValid)
          .accessibilityIdentifier("payments.increment.submit")
        }
      }
      .confirmationDialog(
        "Increase the authorization on " + intent.id + " to " + preview + "?",
        isPresented: $confirmPresented, titleVisibility: .visible
      ) {
        Button("Increment to " + preview) {
          Task { await run() }
        }
        .accessibilityIdentifier("payments.increment.confirm")
        Button("Cancel", role: .cancel) {}
      }
    }
  }

  private func run() async {
    running = true
    failureText = nil
    do {
      _ = try await writer.incrementAuthorizationPaymentIntent(
        id: intent.id, amount: newTotal ?? 0,
        summary: "Increment authorization on " + intent.id + " to " + preview)
      onFinished(
        WriteResult(
          title: "Authorization increased",
          message: intent.id + " now authorizes " + preview + "."))
    } catch {
      running = false
      failureText = writeErrorMessage(error)
    }
  }
}

// MARK: - Verify microdeposits

/// Verifies microdeposits for a bank-debit intent, either with the two
/// deposit amounts (1-99 cents each) or with the descriptor code printed
/// on the customer's statement.
struct VerifyMicrodepositsSheet: View {
  let intent: PaymentIntent
  let writer: PaymentsWriteService
  let onFinished: (WriteResult) -> Void

  enum Mode: Hashable {
    case amounts
    case descriptorCode
  }

  @Environment(\.dismiss) private var dismiss
  @State private var mode: Mode = .amounts
  @State private var firstAmount = ""
  @State private var secondAmount = ""
  @State private var descriptorCode = ""
  @State private var confirmPresented = false
  @State private var running = false
  @State private var failureText: String?

  private var amounts: [Int]? {
    guard mode == .amounts, let first = Int(firstAmount), let second = Int(secondAmount),
      (1...99).contains(first), (1...99).contains(second)
    else { return nil }
    return [first, second]
  }

  private var code: String? {
    let trimmed = descriptorCode.trimmingCharacters(in: .whitespaces)
    guard mode == .descriptorCode, !trimmed.isEmpty else { return nil }
    return trimmed
  }

  private var inputIsValid: Bool { amounts != nil || code != nil }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Picker("Verify with", selection: $mode) {
            Text("Deposit amounts").tag(Mode.amounts)
            Text("Descriptor code").tag(Mode.descriptorCode)
          }
          .pickerStyle(.segmented)
          .accessibilityIdentifier("payments.verify.mode")
          if mode == .amounts {
            TextField("First amount in cents (1-99)", text: $firstAmount)
              .keyboardType(.numberPad)
              .accessibilityIdentifier("payments.verify.firstAmount")
            TextField("Second amount in cents (1-99)", text: $secondAmount)
              .keyboardType(.numberPad)
              .accessibilityIdentifier("payments.verify.secondAmount")
          } else {
            TextField("Descriptor code (e.g. SMXXXX-YYYY)", text: $descriptorCode)
              .textInputAutocapitalization(.characters)
              .autocorrectionDisabled()
              .accessibilityIdentifier("payments.verify.descriptorCode")
          }
        } header: {
          Text("Verify microdeposits")
        } footer: {
          Text("Stripe sent two small deposits to the customer's bank account.")
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
      .navigationTitle("Verify deposits")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Verify") {
            if inputIsValid {
              failureText = nil
              confirmPresented = true
            } else {
              failureText =
                mode == .amounts
                ? "Enter both deposit amounts, each between 1 and 99 cents."
                : "Enter the descriptor code from the customer's statement."
            }
          }
          .disabled(running || !inputIsValid)
          .accessibilityIdentifier("payments.verify.submit")
        }
      }
      .confirmationDialog(
        "Verify the microdeposits on " + intent.id + "?", isPresented: $confirmPresented,
        titleVisibility: .visible
      ) {
        Button("Verify deposits") {
          Task { await run() }
        }
        .accessibilityIdentifier("payments.verify.confirm")
        Button("Cancel", role: .cancel) {}
      }
    }
  }

  private func run() async {
    running = true
    failureText = nil
    do {
      _ = try await writer.verifyMicrodepositsPaymentIntent(
        id: intent.id,
        amounts: mode == .amounts ? amounts : nil,
        descriptorCode: mode == .descriptorCode ? code : nil,
        summary: "Verify microdeposits on " + intent.id)
      onFinished(
        WriteResult(
          title: "Verification submitted",
          message: intent.id + " microdeposits verified."))
    } catch {
      running = false
      failureText = writeErrorMessage(error)
    }
  }
}
