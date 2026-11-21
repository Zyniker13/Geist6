import GeistData
import StripeModels
import SwiftUI

// MARK: - Edit invoice sheet

/// Edits a draft invoice's description, footer, and metadata. The metadata
/// box replaces metadata wholesale (empty clears it).
struct EditInvoiceSheet: View {
  let invoice: Invoice
  let writer: BillingWriteService
  let onFinished: (WriteResult) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var descriptionText: String
  @State private var footerText: String
  @State private var metadataText: String
  @State private var running = false
  @State private var failureText: String?

  init(invoice: Invoice, writer: BillingWriteService, onFinished: @escaping (WriteResult) -> Void) {
    self.invoice = invoice
    self.writer = writer
    self.onFinished = onFinished
    _descriptionText = State(initialValue: invoice.description.valueOrNil ?? "")
    _footerText = State(initialValue: invoice.footer.valueOrNil ?? "")
    _metadataText = State(initialValue: formatMetadataLines(invoice.metadata.valueOrNil ?? [:]))
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Edit invoice") {
          LabeledContent("Invoice", value: invoice.id ?? "—")
          TextField("Description", text: $descriptionText)
            .accessibilityIdentifier("billing.invoice.edit.description")
          TextField("Footer", text: $footerText)
            .accessibilityIdentifier("billing.invoice.edit.footer")
        }
        metadataEditor($metadataText, id: "billing.invoice.edit.metadata")
        if let failureText {
          failureSection(failureText, id: "billing.write.error")
        }
      }
      .navigationTitle("Edit invoice")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") { run() }
            .disabled(running)
            .accessibilityIdentifier("billing.invoice.edit.submit")
        }
      }
    }
  }

  private func run() {
    running = true
    failureText = nil
    let description = descriptionText.trimmingCharacters(in: .whitespaces)
    let footer = footerText.trimmingCharacters(in: .whitespaces)
    Task {
      do {
        let metadata = try MetadataLines.parse(metadataText)
        let invoice = try await writer.updateInvoice(
          id: self.invoice.id ?? "",
          update: BillingWriteService.InvoiceUpdate(
            description: description.isEmpty ? nil : description,
            footer: footer.isEmpty ? nil : footer,
            metadata: metadata),
          summary: "Update invoice \(self.invoice.id ?? "")")
        await MainActor.run {
          onFinished(
            WriteResult(title: "Invoice updated", message: "\(invoice.id ?? "") updated."))
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

// MARK: - Add line item sheet

/// Adds a line item to a draft invoice: amount in the invoice currency's
/// minor units, an optional description, and an optional quantity.
struct AddInvoiceLineSheet: View {
  let invoiceID: String
  let writer: BillingWriteService
  let onFinished: (WriteResult) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var descriptionText = ""
  @State private var amountText = ""
  @State private var quantityText = ""
  @State private var running = false
  @State private var failureText: String?

  private var amountMinor: Int? { Int(amountText) }

  var body: some View {
    NavigationStack {
      Form {
        Section("New line item") {
          TextField("Description (optional)", text: $descriptionText)
            .accessibilityIdentifier("billing.invoice.line.add.description")
          TextField("Amount in cents (e.g. 1500)", text: $amountText)
            .keyboardType(.numberPad)
            .accessibilityIdentifier("billing.invoice.line.add.amount")
          TextField("Quantity (optional)", text: $quantityText)
            .keyboardType(.numberPad)
            .accessibilityIdentifier("billing.invoice.line.add.quantity")
        }
        if let failureText {
          failureSection(failureText, id: "billing.write.error")
        }
      }
      .navigationTitle("Add line item")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Add") { run() }
            .disabled(running || (amountMinor ?? 0) <= 0)
            .accessibilityIdentifier("billing.invoice.line.add.submit")
        }
      }
    }
  }

  private func run() {
    running = true
    failureText = nil
    let description = descriptionText.trimmingCharacters(in: .whitespaces)
    Task {
      do {
        let invoice = try await writer.addInvoiceLine(
          invoice: invoiceID,
          line: BillingWriteService.InvoiceLineDraft(
            description: description.isEmpty ? nil : description,
            amount: amountMinor,
            quantity: quantityText.isEmpty ? nil : Int(quantityText)),
          summary: "Add line to invoice \(invoiceID)")
        await MainActor.run {
          onFinished(
            WriteResult(
              title: "Line item added", message: "Added to \(invoice.id ?? invoiceID)."))
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

// MARK: - Update line item sheet

/// Edits one line item of a draft invoice (description, quantity) and
/// offers removal. Blank fields are left untouched by the service.
struct UpdateInvoiceLineSheet: View {
  let invoiceID: String
  let line: LineItem
  let writer: BillingWriteService
  let onFinished: (WriteResult) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var descriptionText: String
  @State private var quantityText: String
  @State private var running = false
  @State private var failureText: String?

  init(
    invoiceID: String, line: LineItem, writer: BillingWriteService,
    onFinished: @escaping (WriteResult) -> Void
  ) {
    self.invoiceID = invoiceID
    self.line = line
    self.writer = writer
    self.onFinished = onFinished
    _descriptionText = State(initialValue: line.description.valueOrNil ?? "")
    _quantityText = State(initialValue: line.quantity.valueOrNil.map(String.init) ?? "")
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Edit line item") {
          LabeledContent("Amount", value: MoneyFormat.amount(line.amount, currency: line.currency))
          TextField("Description", text: $descriptionText)
            .accessibilityIdentifier("billing.invoice.line.update.description")
          TextField("Quantity", text: $quantityText)
            .keyboardType(.numberPad)
            .accessibilityIdentifier("billing.invoice.line.update.quantity")
        }
        if let failureText {
          failureSection(failureText, id: "billing.write.error")
        }
        Section {
          Button("Remove line", role: .destructive) { remove() }
            .disabled(running)
            .accessibilityIdentifier("billing.invoice.line.remove")
        }
      }
      .navigationTitle("Line item")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") { run() }
            .disabled(running)
            .accessibilityIdentifier("billing.invoice.line.update.submit")
        }
      }
    }
  }

  private func run() {
    running = true
    failureText = nil
    let description = descriptionText.trimmingCharacters(in: .whitespaces)
    Task {
      do {
        let invoice = try await writer.updateInvoiceLine(
          invoice: invoiceID, lineID: line.id,
          description: description.isEmpty ? nil : description,
          quantity: quantityText.isEmpty ? nil : Int(quantityText),
          summary: "Update line on invoice \(invoiceID)")
        await MainActor.run {
          onFinished(
            WriteResult(
              title: "Line item updated", message: "Updated on \(invoice.id ?? invoiceID)."))
        }
      } catch {
        await MainActor.run {
          running = false
          failureText = writeErrorMessage(error)
        }
      }
    }
  }

  private func remove() {
    running = true
    failureText = nil
    Task {
      do {
        let invoice = try await writer.removeInvoiceLine(
          invoice: invoiceID, lineID: line.id,
          summary: "Remove line from invoice \(invoiceID)")
        await MainActor.run {
          onFinished(
            WriteResult(
              title: "Line item removed", message: "Removed from \(invoice.id ?? invoiceID)."))
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
