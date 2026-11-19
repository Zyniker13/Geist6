// SetupIntentWriteSheets.swift — App/Payments
// The M4c-2 setup intent write sheets: create, update, confirm, cancel.
// Same contract as WriteSheets.swift: the service refuses in dashboard mode,
// every attempt carries an idempotency key, and API failures surface inside
// the sheet. Microdeposit verification reuses VerifyMicrodepositsSheet.

import GeistData
import StripeModels
import SwiftUI

// MARK: - Create setup intent

/// Creates a setup intent. The customer is optional per the API but is what
/// a saved payment method attaches to, so the sheet nudges toward filling it.
struct CreateSetupIntentSheet: View {
  let writer: PaymentsWriteService
  let onFinished: (WriteResult) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var customer = ""
  @State private var descriptionText = ""
  @State private var usage = 0  // 0 default, 1 on_session, 2 off_session
  @State private var confirmPresented = false
  @State private var running = false
  @State private var failureText: String?

  private var inputIsValid: Bool {
    customer.isEmpty || customer.hasPrefix("cus_")
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("Customer ID (cus_…)", text: $customer)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .accessibilityIdentifier("payments.setupCreate.customer")
          TextField("Description (optional)", text: $descriptionText)
            .accessibilityIdentifier("payments.setupCreate.description")
          Picker("Usage", selection: $usage) {
            Text("Stripe default").tag(0)
            Text("On session").tag(1)
            Text("Off session").tag(2)
          }
          .accessibilityIdentifier("payments.setupCreate.usage")
        } header: {
          Text("New setup intent")
        } footer: {
          Text("A setup intent saves a payment method for later use.")
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
      .navigationTitle("New setup intent")
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
          .accessibilityIdentifier("payments.setupCreate.submit")
        }
      }
      .confirmationDialog(
        "Create a setup intent for " + (customer.isEmpty ? "no customer" : customer) + "?",
        isPresented: $confirmPresented, titleVisibility: .visible
      ) {
        Button("Create intent") {
          Task { await run() }
        }
        .accessibilityIdentifier("payments.setupCreate.confirm")
        Button("Cancel", role: .cancel) {}
      }
    }
  }

  private func run() async {
    running = true
    failureText = nil
    do {
      let usageValue: String? = {
        switch usage {
        case 0: return nil
        case 1: return "on_session"
        default: return "off_session"
        }
      }()
      let intent = try await writer.createSetupIntent(
        customer: customer.isEmpty ? nil : customer,
        description: descriptionText.isEmpty ? nil : descriptionText,
        usage: usageValue,
        summary: "Create setup intent")
      onFinished(
        WriteResult(title: "Intent created", message: intent.id + " is ready."))
    } catch {
      running = false
      failureText = writeErrorMessage(error)
    }
  }
}

// MARK: - Update setup intent

/// Updates a setup intent's description.
struct UpdateSetupIntentSheet: View {
  let intent: SetupIntent
  let writer: PaymentsWriteService
  let onFinished: (WriteResult) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var descriptionText: String
  @State private var confirmPresented = false
  @State private var running = false
  @State private var failureText: String?

  init(
    intent: SetupIntent, writer: PaymentsWriteService,
    onFinished: @escaping (WriteResult) -> Void
  ) {
    self.intent = intent
    self.writer = writer
    self.onFinished = onFinished
    _descriptionText = State(initialValue: intent.description.valueOrNil ?? "")
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Edit setup intent") {
          LabeledContent("Intent", value: intent.id)
          TextField("Description", text: $descriptionText)
            .accessibilityIdentifier("payments.setupUpdate.description")
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
      .navigationTitle("Edit")
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
          .accessibilityIdentifier("payments.setupUpdate.submit")
        }
      }
      .confirmationDialog(
        "Update the description of " + intent.id + "?", isPresented: $confirmPresented,
        titleVisibility: .visible
      ) {
        Button("Save description") {
          Task { await run() }
        }
        .accessibilityIdentifier("payments.setupUpdate.confirm")
        Button("Cancel", role: .cancel) {}
      }
    }
  }

  private func run() async {
    running = true
    failureText = nil
    do {
      _ = try await writer.updateSetupIntent(
        id: intent.id,
        description: descriptionText.isEmpty ? nil : descriptionText,
        summary: "Update setup intent " + intent.id)
      onFinished(
        WriteResult(title: "Description updated", message: intent.id + " saved."))
    } catch {
      running = false
      failureText = writeErrorMessage(error)
    }
  }
}

// MARK: - Confirm setup intent

/// Confirms a setup intent, optionally attaching a payment method ID. With
/// no field entered, Stripe uses the method already attached to the intent.
struct ConfirmSetupIntentSheet: View {
  let intent: SetupIntent
  let writer: PaymentsWriteService
  let onFinished: (WriteResult) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var paymentMethod = ""
  @State private var confirmPresented = false
  @State private var running = false
  @State private var failureText: String?

  var body: some View {
    NavigationStack {
      Form {
        Section {
          LabeledContent("Intent", value: intent.id)
          TextField("Payment method ID (optional, pm_…)", text: $paymentMethod)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .accessibilityIdentifier("payments.setupConfirm.paymentMethod")
        } header: {
          Text("Confirm setup intent")
        } footer: {
          Text(
            "Confirming attaches and verifies the payment method. Leave the "
              + "field empty to use the intent's attached method."
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
      .navigationTitle("Confirm")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Confirm") {
            failureText = nil
            confirmPresented = true
          }
          .disabled(running)
          .accessibilityIdentifier("payments.setupConfirm.submit")
        }
      }
      .confirmationDialog(
        "Confirm " + intent.id + " now?", isPresented: $confirmPresented,
        titleVisibility: .visible
      ) {
        Button("Confirm now") {
          Task { await run() }
        }
        .accessibilityIdentifier("payments.setupConfirm.confirm")
        Button("Cancel", role: .cancel) {}
      }
    }
  }

  private func run() async {
    running = true
    failureText = nil
    do {
      _ = try await writer.confirmSetupIntent(
        id: intent.id,
        paymentMethod: paymentMethod.isEmpty ? nil : paymentMethod,
        summary: "Confirm setup intent " + intent.id)
      onFinished(
        WriteResult(
          title: "Setup confirmed",
          message: "Confirm request sent for " + intent.id + "."))
    } catch {
      running = false
      failureText = writeErrorMessage(error)
    }
  }
}

// MARK: - Cancel setup intent

/// Cancels a setup intent with an optional reason. Stripe's setup intent
/// reasons are abandoned, duplicate, and requested_by_customer.
struct CancelSetupIntentSheet: View {
  let intent: SetupIntent
  let writer: PaymentsWriteService
  let onFinished: (WriteResult) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var reason: WriteReasonOption = .none
  @State private var confirmPresented = false
  @State private var running = false
  @State private var failureText: String?

  /// Setup intents have no "fraudulent" cancellation reason.
  private var reasonOptions: [WriteReasonOption] {
    WriteReasonOption.allCases.filter { $0 != .fraudulent }
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Cancel setup intent") {
          LabeledContent("Intent", value: intent.id)
          Picker("Reason", selection: $reason) {
            ForEach(reasonOptions) { option in
              Text(option.rawValue).tag(option)
            }
          }
          .accessibilityIdentifier("payments.setupCancel.reason")
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
      .navigationTitle("Cancel")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Dismiss") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Cancel intent", role: .destructive) {
            failureText = nil
            confirmPresented = true
          }
          .disabled(running)
          .accessibilityIdentifier("payments.setupCancel.submit")
        }
      }
      .confirmationDialog(
        "Cancel " + intent.id + "? This cannot be undone.",
        isPresented: $confirmPresented, titleVisibility: .visible
      ) {
        Button("Cancel intent", role: .destructive) {
          Task { await run() }
        }
        .accessibilityIdentifier("payments.setupCancel.confirm")
        Button("Keep", role: .cancel) {}
      }
    }
  }

  private func run() async {
    running = true
    failureText = nil
    do {
      _ = try await writer.cancelSetupIntent(
        id: intent.id, reason: reason.apiValue,
        summary: "Cancel setup intent " + intent.id)
      onFinished(
        WriteResult(title: "Intent canceled", message: intent.id + " canceled."))
    } catch {
      running = false
      failureText = writeErrorMessage(error)
    }
  }
}
