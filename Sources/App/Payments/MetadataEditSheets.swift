// MetadataEditSheets.swift — App/Payments
// The edit sheets for description, receipt email, active state, and
// metadata on payment intents, charges, and payment links. Same contract
// as the other write sheets: the sheet is only shown when the account has
// a writer, every attempt carries an idempotency key, and API failures
// surface inside the sheet. Metadata is edited as one key=value pair per
// line; saving replaces the object's metadata wholesale, so an emptied
// field clears every key.

import GeistData
import StripeModels
import SwiftUI

// MARK: - Edit payment intent

/// Edits a payment intent's description and metadata.
struct EditPaymentIntentSheet: View {
  let intent: PaymentIntent
  let writer: PaymentsWriteService
  let onFinished: (WriteResult) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var descriptionText: String
  @State private var metadataText: String
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
    _descriptionText = State(initialValue: intent.description.valueOrNil ?? "")
    _metadataText = State(initialValue: formatMetadataLines(intent.metadata))
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Edit payment") {
          LabeledContent("Intent", value: intent.id)
          TextField("Description", text: $descriptionText)
            .accessibilityIdentifier("payments.intentEdit.description")
        }
        Section {
          TextEditor(text: $metadataText)
            .font(.system(.footnote, design: .monospaced))
            .frame(minHeight: 88)
            .accessibilityIdentifier("payments.intentEdit.metadata")
        } header: {
          Text("Metadata")
        } footer: {
          Text(
            "One pair per line: key=value. Saving replaces all metadata; "
              + "an empty field clears every key."
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
          .accessibilityIdentifier("payments.intentEdit.submit")
        }
      }
      .confirmationDialog(
        "Update " + intent.id + "?", isPresented: $confirmPresented,
        titleVisibility: .visible
      ) {
        Button("Save changes") {
          Task { await run() }
        }
        .accessibilityIdentifier("payments.intentEdit.confirm")
        Button("Cancel", role: .cancel) {}
      }
    }
  }

  private func run() async {
    running = true
    failureText = nil
    do {
      let metadata = try MetadataLines.parse(metadataText)
      _ = try await writer.updatePaymentIntent(
        id: intent.id,
        description: descriptionText.isEmpty ? nil : descriptionText,
        metadata: metadata,
        summary: "Update payment " + intent.id)
      onFinished(WriteResult(title: "Payment updated", message: intent.id + " saved."))
    } catch {
      running = false
      failureText = writeErrorMessage(error)
    }
  }
}

// MARK: - Edit charge

/// Edits a charge's description, receipt email, and metadata.
struct EditChargeSheet: View {
  let charge: Charge
  let writer: PaymentsWriteService
  let onFinished: (WriteResult) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var descriptionText: String
  @State private var receiptEmail: String
  @State private var metadataText: String
  @State private var confirmPresented = false
  @State private var running = false
  @State private var failureText: String?

  init(
    charge: Charge, writer: PaymentsWriteService,
    onFinished: @escaping (WriteResult) -> Void
  ) {
    self.charge = charge
    self.writer = writer
    self.onFinished = onFinished
    _descriptionText = State(initialValue: charge.description.valueOrNil ?? "")
    _receiptEmail = State(initialValue: charge.receiptEmail.valueOrNil ?? "")
    _metadataText = State(initialValue: formatMetadataLines(charge.metadata))
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Edit charge") {
          LabeledContent("Charge", value: charge.id)
          TextField("Description", text: $descriptionText)
            .accessibilityIdentifier("payments.chargeEdit.description")
          TextField("Receipt email", text: $receiptEmail)
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .accessibilityIdentifier("payments.chargeEdit.receiptEmail")
        }
        Section {
          TextEditor(text: $metadataText)
            .font(.system(.footnote, design: .monospaced))
            .frame(minHeight: 88)
            .accessibilityIdentifier("payments.chargeEdit.metadata")
        } header: {
          Text("Metadata")
        } footer: {
          Text(
            "One pair per line: key=value. Saving replaces all metadata; "
              + "an empty field clears every key."
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
          .accessibilityIdentifier("payments.chargeEdit.submit")
        }
      }
      .confirmationDialog(
        "Update " + charge.id + "?", isPresented: $confirmPresented,
        titleVisibility: .visible
      ) {
        Button("Save changes") {
          Task { await run() }
        }
        .accessibilityIdentifier("payments.chargeEdit.confirm")
        Button("Cancel", role: .cancel) {}
      }
    }
  }

  private func run() async {
    running = true
    failureText = nil
    do {
      let metadata = try MetadataLines.parse(metadataText)
      _ = try await writer.updateCharge(
        id: charge.id,
        description: descriptionText.isEmpty ? nil : descriptionText,
        receiptEmail: receiptEmail.isEmpty ? nil : receiptEmail,
        metadata: metadata,
        summary: "Update charge " + charge.id)
      onFinished(WriteResult(title: "Charge updated", message: charge.id + " saved."))
    } catch {
      running = false
      failureText = writeErrorMessage(error)
    }
  }
}

// MARK: - Edit payment link

/// Edits a payment link's active state and metadata.
struct EditPaymentLinkSheet: View {
  let link: PaymentLink
  let writer: PaymentsWriteService
  let onFinished: (WriteResult) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var isActive: Bool
  @State private var metadataText: String
  @State private var confirmPresented = false
  @State private var running = false
  @State private var failureText: String?

  init(
    link: PaymentLink, writer: PaymentsWriteService,
    onFinished: @escaping (WriteResult) -> Void
  ) {
    self.link = link
    self.writer = writer
    self.onFinished = onFinished
    _isActive = State(initialValue: link.active)
    _metadataText = State(initialValue: formatMetadataLines(link.metadata))
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Edit payment link") {
          LabeledContent("Link", value: link.id)
          Toggle("Active", isOn: $isActive)
            .accessibilityIdentifier("payments.linkEdit.active")
        }
        Section {
          TextEditor(text: $metadataText)
            .font(.system(.footnote, design: .monospaced))
            .frame(minHeight: 88)
            .accessibilityIdentifier("payments.linkEdit.metadata")
        } header: {
          Text("Metadata")
        } footer: {
          Text(
            "One pair per line: key=value. Saving replaces all metadata; "
              + "an empty field clears every key."
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
          .accessibilityIdentifier("payments.linkEdit.submit")
        }
      }
      .confirmationDialog(
        "Update " + link.id + "?", isPresented: $confirmPresented,
        titleVisibility: .visible
      ) {
        Button("Save changes") {
          Task { await run() }
        }
        .accessibilityIdentifier("payments.linkEdit.confirm")
        Button("Cancel", role: .cancel) {}
      }
    }
  }

  private func run() async {
    running = true
    failureText = nil
    do {
      let metadata = try MetadataLines.parse(metadataText)
      _ = try await writer.updatePaymentLink(
        id: link.id,
        active: isActive,
        metadata: metadata,
        summary: "Update payment link " + link.id)
      onFinished(WriteResult(title: "Payment link updated", message: link.id + " saved."))
    } catch {
      running = false
      failureText = writeErrorMessage(error)
    }
  }
}

// MARK: - Edit refund metadata

/// Edits a refund's metadata. Refunds have no other mutable fields.
struct EditRefundMetadataSheet: View {
  let refund: Refund
  let writer: PaymentsWriteService
  let onFinished: (WriteResult) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var metadataText: String
  @State private var confirmPresented = false
  @State private var running = false
  @State private var failureText: String?

  init(
    refund: Refund, writer: PaymentsWriteService,
    onFinished: @escaping (WriteResult) -> Void
  ) {
    self.refund = refund
    self.writer = writer
    self.onFinished = onFinished
    _metadataText = State(initialValue: formatMetadataLines(refund.metadata.valueOrNil ?? [:]))
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Edit refund") {
          LabeledContent("Refund", value: refund.id)
        }
        Section {
          TextEditor(text: $metadataText)
            .font(.system(.footnote, design: .monospaced))
            .frame(minHeight: 88)
            .accessibilityIdentifier("payments.refundEdit.metadata")
        } header: {
          Text("Metadata")
        } footer: {
          Text(
            "One pair per line: key=value. Saving replaces all metadata; "
              + "an empty field clears every key."
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
          .accessibilityIdentifier("payments.refundEdit.submit")
        }
      }
      .confirmationDialog(
        "Update " + refund.id + "?", isPresented: $confirmPresented,
        titleVisibility: .visible
      ) {
        Button("Save changes") {
          Task { await run() }
        }
        .accessibilityIdentifier("payments.refundEdit.confirm")
        Button("Cancel", role: .cancel) {}
      }
    }
  }

  private func run() async {
    running = true
    failureText = nil
    do {
      let metadata = try MetadataLines.parse(metadataText)
      _ = try await writer.updateRefund(
        id: refund.id,
        metadata: metadata,
        summary: "Update refund " + refund.id)
      onFinished(WriteResult(title: "Refund updated", message: refund.id + " saved."))
    } catch {
      running = false
      failureText = writeErrorMessage(error)
    }
  }
}

// MARK: - Metadata display

/// Renders an object's metadata pairs as a detail-view List section, keys in
/// alphabetical order. An empty dictionary shows a single "None" row so the
/// section never disappears between reloads.
struct MetadataSection: View {
  let metadata: [String: String]

  var body: some View {
    Section("Metadata") {
      if metadata.isEmpty {
        Text("None")
          .foregroundStyle(.secondary)
          .accessibilityIdentifier("payments.metadata.empty")
      } else {
        ForEach(metadata.sorted { $0.key < $1.key }, id: \.key) { key, value in
          VStack(alignment: .leading, spacing: 2) {
            Text(key)
              .font(.footnote)
              .foregroundStyle(.secondary)
            Text(value)
              .font(.subheadline)
              .textSelection(.enabled)
          }
          .accessibilityElement(children: .combine)
          .accessibilityIdentifier("payments.metadata.row")
        }
      }
    }
  }
}

// MARK: - Metadata text helpers

/// App-side helpers around the GeistData metadata-line functions.
enum MetadataLines {
  /// Parses the edited metadata text. An empty field parses to an empty
  /// dictionary (clearing all metadata); malformed text throws and the
  /// sheet shows the reason.
  static func parse(_ text: String) throws -> [String: String] {
    guard let parsed = parseMetadataLines(text) else {
      throw MetadataFormatError()
    }
    return parsed
  }
}

/// Thrown when the edited metadata text has a line without "key=value".
struct MetadataFormatError: LocalizedError {
  var errorDescription: String? {
    "Each metadata line needs a key and a value, separated by \"=\", "
      + "for example order_id=12345."
  }
}
