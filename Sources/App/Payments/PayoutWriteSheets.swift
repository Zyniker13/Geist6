import GeistData
import StripeModels
import SwiftUI

/// Creates a payout from the available balance. Money-moving: the sheet
/// restates the exact amount and currency on the confirmation step before
/// the write runs, and the write carries an idempotency key.
struct CreatePayoutSheet: View {
  let writer: PaymentsWriteService
  let onFinished: (WriteResult) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var amount = ""
  @State private var currency = "usd"
  @State private var description = ""
  @State private var confirmPresented = false
  @State private var running = false
  @State private var failureText: String?

  static let currencies = ["usd", "eur", "gbp", "jpy", "cad", "aud"]

  private var amountValue: Int? {
    guard let value = Int(amount), value > 0 else { return nil }
    return value
  }

  private var inputIsValid: Bool { amountValue != nil }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("Amount (in cents)", text: $amount)
            .keyboardType(.numberPad)
            .accessibilityIdentifier("payments.payoutCreate.amount")
          Picker("Currency", selection: $currency) {
            ForEach(Self.currencies, id: \.self) { code in
              Text(code.uppercased()).tag(code)
            }
          }
          .accessibilityIdentifier("payments.payoutCreate.currency")
          TextField("Description (optional)", text: $description)
            .accessibilityIdentifier("payments.payoutCreate.description")
        } header: {
          Text("New payout")
        } footer: {
          Text(
            "Moves money from the account's available balance to its bank "
              + "account. Stripe pays out everything unless an amount is set."
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
      .navigationTitle("New payout")
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
          .accessibilityIdentifier("payments.payoutCreate.submit")
        }
      }
      .confirmationDialog(
        "Pay out " + (amountValue.map(String.init) ?? "0") + " "
          + currency.uppercased() + "?",
        isPresented: $confirmPresented, titleVisibility: .visible
      ) {
        Button("Pay out") {
          Task { await run() }
        }
        .accessibilityIdentifier("payments.payoutCreate.confirm")
        Button("Cancel", role: .cancel) {}
      }
    }
  }

  private func run() async {
    running = true
    failureText = nil
    do {
      let payout = try await writer.createPayout(
        amount: amountValue ?? 0, currency: currency,
        description: description.isEmpty ? nil : description,
        summary: "Create payout (" + (amountValue.map(String.init) ?? "0")
          + " " + currency.uppercased() + ")")
      onFinished(
        WriteResult(title: "Payout created", message: payout.id + " is on its way."))
    } catch {
      running = false
      failureText = writeErrorMessage(error)
    }
  }
}
