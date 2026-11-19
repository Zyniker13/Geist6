// LinkAndChargeWriteSheets.swift — App/Payments
// The M4c-4 write sheets: create a payment link (single line item) and
// create a charge. Same contract as WriteSheets.swift: the service refuses
// in dashboard mode, every attempt carries an idempotency key, and API
// failures surface inside the sheet.

import GeistData
import StripeModels
import SwiftUI

// MARK: - Create payment link

/// Creates a payment link with one line item (price + quantity).
/// Multi-item and price-data links belong to the API explorer (M10).
struct CreatePaymentLinkSheet: View {
  let writer: PaymentsWriteService
  let onFinished: (WriteResult) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var price = ""
  @State private var quantity = "1"
  @State private var confirmPresented = false
  @State private var running = false
  @State private var failureText: String?

  private var quantityValue: Int? {
    guard let value = Int(quantity), value >= 1 else { return nil }
    return value
  }

  private var inputIsValid: Bool {
    price.hasPrefix("price_") && price.count > 6 && quantityValue != nil
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("Price ID (price_…)", text: $price)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .accessibilityIdentifier("payments.linkCreate.price")
          TextField("Quantity", text: $quantity)
            .keyboardType(.numberPad)
            .accessibilityIdentifier("payments.linkCreate.quantity")
        } header: {
          Text("New payment link")
        } footer: {
          Text(
            "The link sells one line item: the given price at the given "
              + "quantity. More items and custom prices are explorer work (M10)."
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
      .navigationTitle("New payment link")
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
          .accessibilityIdentifier("payments.linkCreate.submit")
        }
      }
      .confirmationDialog(
        "Create a payment link for " + price + "?", isPresented: $confirmPresented,
        titleVisibility: .visible
      ) {
        Button("Create") {
          Task { await run() }
        }
        .accessibilityIdentifier("payments.linkCreate.confirm")
        Button("Cancel", role: .cancel) {}
      }
    }
  }

  private func run() async {
    running = true
    failureText = nil
    do {
      let link = try await writer.createPaymentLink(
        price: price, quantity: quantityValue ?? 1,
        summary: "Create payment link (" + price + ")")
      onFinished(
        WriteResult(title: "Link created", message: link.id + " is ready."))
    } catch {
      running = false
      failureText = writeErrorMessage(error)
    }
  }
}

// MARK: - Create charge

/// Creates a charge against a payment method.
struct CreateChargeSheet: View {
  let writer: PaymentsWriteService
  let onFinished: (WriteResult) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var amount = ""
  @State private var currency = "usd"
  @State private var source = ""
  @State private var description = ""
  @State private var confirmPresented = false
  @State private var running = false
  @State private var failureText: String?

  static let currencies = ["usd", "eur", "gbp", "jpy", "cad", "aud"]

  private var amountValue: Int? {
    guard let value = Int(amount), value > 0 else { return nil }
    return value
  }

  private var inputIsValid: Bool {
    amountValue != nil && source.hasPrefix("pm_") && source.count > 3
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("Amount (in cents)", text: $amount)
            .keyboardType(.numberPad)
            .accessibilityIdentifier("payments.chargeCreate.amount")
          Picker("Currency", selection: $currency) {
            ForEach(Self.currencies, id: \.self) { code in
              Text(code.uppercased()).tag(code)
            }
          }
          .accessibilityIdentifier("payments.chargeCreate.currency")
          TextField("Payment method ID (pm_…)", text: $source)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .accessibilityIdentifier("payments.chargeCreate.source")
          TextField("Description (optional)", text: $description)
            .accessibilityIdentifier("payments.chargeCreate.description")
        } header: {
          Text("New charge")
        } footer: {
          Text(
            "Charges a payment method directly. For customer flows prefer "
              + "payment intents; charges are the low-level primitive."
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
      .navigationTitle("New charge")
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
          .accessibilityIdentifier("payments.chargeCreate.submit")
        }
      }
      .confirmationDialog(
        "Charge " + (amountValue.map(String.init) ?? "0") + " "
          + currency.uppercased() + " from " + source + "?",
        isPresented: $confirmPresented, titleVisibility: .visible
      ) {
        Button("Charge") {
          Task { await run() }
        }
        .accessibilityIdentifier("payments.chargeCreate.confirm")
        Button("Cancel", role: .cancel) {}
      }
    }
  }

  private func run() async {
    running = true
    failureText = nil
    do {
      let charge = try await writer.createCharge(
        amount: amountValue ?? 0, currency: currency, source: source,
        description: description.isEmpty ? nil : description,
        summary: "Create charge (" + (amountValue.map(String.init) ?? "0")
          + " " + currency.uppercased() + ")")
      onFinished(
        WriteResult(title: "Charge created", message: charge.id + " captured."))
    } catch {
      running = false
      failureText = writeErrorMessage(error)
    }
  }
}
