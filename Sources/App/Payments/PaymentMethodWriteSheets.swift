// PaymentMethodWriteSheets.swift — App/Payments
// The M4c-3 payment method write sheets: create, update billing details,
// attach to a customer. Detach needs no sheet (plain confirmation on the
// detail screen). Same contract as WriteSheets.swift: the service refuses
// in dashboard mode, every attempt carries an idempotency key, and API
// failures surface inside the sheet.

import GeistData
import StripeModels
import SwiftUI

// MARK: - Create payment method

/// Creates a payment method. Tier-1 covers cards (number, expiry, CVC) and
/// type-only methods; deeper per-type fields belong to the API explorer.
struct CreatePaymentMethodSheet: View {
  let writer: PaymentsWriteService
  let onFinished: (WriteResult) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var type = "card"
  @State private var cardNumber = ""
  @State private var expMonth = ""
  @State private var expYear = ""
  @State private var cvc = ""
  @State private var confirmPresented = false
  @State private var running = false
  @State private var failureText: String?

  static let types = ["card", "us_bank_account", "sepa_debit", "ideal"]

  private var expMonthValue: Int? {
    guard let month = Int(expMonth), (1...12).contains(month) else { return nil }
    return month
  }

  private var expYearValue: Int? {
    guard let year = Int(expYear), (2024...2099).contains(year) else { return nil }
    return year
  }

  private var numberValue: String? {
    let digits = cardNumber.trimmingCharacters(in: .whitespaces)
    guard digits.count >= 12, digits.allSatisfy({ $0.isNumber }) else { return nil }
    return digits
  }

  private var inputIsValid: Bool {
    if type == "card" {
      return numberValue != nil && expMonthValue != nil && expYearValue != nil
        && cvc.count >= 3
    }
    return true
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Picker("Type", selection: $type) {
            ForEach(Self.types, id: \.self) { name in
              Text(name).tag(name)
            }
          }
          .accessibilityIdentifier("payments.methodCreate.type")
          if type == "card" {
            TextField("Card number (test: 4242…)", text: $cardNumber)
              .keyboardType(.numberPad)
              .accessibilityIdentifier("payments.methodCreate.number")
            TextField("Exp month (1-12)", text: $expMonth)
              .keyboardType(.numberPad)
              .accessibilityIdentifier("payments.methodCreate.expMonth")
            TextField("Exp year (e.g. 2030)", text: $expYear)
              .keyboardType(.numberPad)
              .accessibilityIdentifier("payments.methodCreate.expYear")
            TextField("CVC", text: $cvc)
              .keyboardType(.numberPad)
              .accessibilityIdentifier("payments.methodCreate.cvc")
          }
        } header: {
          Text("New payment method")
        } footer: {
          Text(
            "Test mode accepts Stripe's published test card numbers. Real "
              + "cards should be collected with Stripe's SDKs, not typed here."
          )
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
      .navigationTitle("New payment method")
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
          .accessibilityIdentifier("payments.methodCreate.submit")
        }
      }
      .confirmationDialog(
        "Create a " + type + " payment method?", isPresented: $confirmPresented,
        titleVisibility: .visible
      ) {
        Button("Create") {
          Task { await run() }
        }
        .accessibilityIdentifier("payments.methodCreate.confirm")
        Button("Cancel", role: .cancel) {}
      }
    }
  }

  private func run() async {
    running = true
    failureText = nil
    do {
      let isCard = type == "card"
      let method = try await writer.createPaymentMethod(
        type: type,
        cardNumber: isCard ? numberValue : nil,
        expMonth: isCard ? expMonthValue : nil,
        expYear: isCard ? expYearValue : nil,
        cvc: isCard && !cvc.isEmpty ? cvc : nil,
        summary: "Create payment method (" + type + ")")
      onFinished(
        WriteResult(title: "Method created", message: method.id + " is ready."))
    } catch {
      running = false
      failureText = writeErrorMessage(error)
    }
  }
}

// MARK: - Update payment method

/// Updates a payment method's billing name and email. An empty field means
/// "no change".
struct UpdatePaymentMethodSheet: View {
  let method: PaymentMethod
  let writer: PaymentsWriteService
  let onFinished: (WriteResult) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var name: String
  @State private var email: String
  @State private var confirmPresented = false
  @State private var running = false
  @State private var failureText: String?

  init(
    method: PaymentMethod, writer: PaymentsWriteService,
    onFinished: @escaping (WriteResult) -> Void
  ) {
    self.method = method
    self.writer = writer
    self.onFinished = onFinished
    _name = State(initialValue: method.billingDetails.name.valueOrNil ?? "")
    _email = State(initialValue: method.billingDetails.email.valueOrNil ?? "")
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Billing details") {
          LabeledContent("Method", value: method.id)
          TextField("Name", text: $name)
            .accessibilityIdentifier("payments.methodUpdate.name")
          TextField("Email", text: $email)
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .accessibilityIdentifier("payments.methodUpdate.email")
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
      .navigationTitle("Edit billing")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            failureText = nil
            confirmPresented = true
          }
          .disabled(running)
          .accessibilityIdentifier("payments.methodUpdate.submit")
        }
      }
      .confirmationDialog(
        "Update the billing details of " + method.id + "?", isPresented: $confirmPresented,
        titleVisibility: .visible
      ) {
        Button("Save details") {
          Task { await run() }
        }
        .accessibilityIdentifier("payments.methodUpdate.confirm")
        Button("Cancel", role: .cancel) {}
      }
    }
  }

  private func run() async {
    running = true
    failureText = nil
    do {
      _ = try await writer.updatePaymentMethod(
        id: method.id,
        billingName: name.isEmpty ? nil : name,
        billingEmail: email.isEmpty ? nil : email,
        summary: "Update billing details on " + method.id)
      onFinished(
        WriteResult(title: "Details updated", message: method.id + " saved."))
    } catch {
      running = false
      failureText = writeErrorMessage(error)
    }
  }
}

// MARK: - Attach payment method

/// Attaches a payment method to a customer so it can be reused.
struct AttachPaymentMethodSheet: View {
  let method: PaymentMethod
  let writer: PaymentsWriteService
  let onFinished: (WriteResult) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var customer = ""
  @State private var confirmPresented = false
  @State private var running = false
  @State private var failureText: String?

  private var inputIsValid: Bool {
    customer.hasPrefix("cus_") && customer.count > 4
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Attach to customer") {
          LabeledContent("Method", value: method.id)
          TextField("Customer ID (cus_…)", text: $customer)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .accessibilityIdentifier("payments.methodAttach.customer")
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
      .navigationTitle("Attach")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Attach") {
            if inputIsValid {
              failureText = nil
              confirmPresented = true
            } else {
              failureText = "Enter a customer ID starting with cus_."
            }
          }
          .disabled(running || !inputIsValid)
          .accessibilityIdentifier("payments.methodAttach.submit")
        }
      }
      .confirmationDialog(
        "Attach " + method.id + " to " + customer + "?", isPresented: $confirmPresented,
        titleVisibility: .visible
      ) {
        Button("Attach") {
          Task { await run() }
        }
        .accessibilityIdentifier("payments.methodAttach.confirm")
        Button("Cancel", role: .cancel) {}
      }
    }
  }

  private func run() async {
    running = true
    failureText = nil
    do {
      _ = try await writer.attachPaymentMethod(
        id: method.id, customer: customer,
        summary: "Attach " + method.id + " to " + customer)
      onFinished(
        WriteResult(title: "Method attached", message: method.id + " → " + customer + "."))
    } catch {
      running = false
      failureText = writeErrorMessage(error)
    }
  }
}
