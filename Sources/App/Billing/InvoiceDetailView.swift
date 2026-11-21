import GeistData
import StripeModels
import SwiftUI

/// Detail view for a single invoice: status, total, customer, dates, and
/// line items. Draft invoices can be edited (fields and line items) and
/// finalized; open invoices can be sent, paid, voided, or marked
/// uncollectible. Every action requires a writer, so dashboard-locked
/// accounts get a read-only screen.
struct InvoiceDetailView: View {
  let invoiceID: String
  let backend: any BillingBackend
  /// Nil for dashboard-locked accounts: no write UI exists at all.
  let writer: BillingWriteService?

  @State private var invoice: Invoice?
  @State private var loadingError: String?
  @State private var activeSheet: InvoiceSheet?
  @State private var pendingAction: InvoiceLifecycleAction?
  @State private var writeResult: WriteResult?

  var body: some View {
    Group {
      if let invoice {
        invoiceView(invoice)
      } else if let error = loadingError {
        ContentUnavailableView(
          "Couldn't load invoice",
          systemImage: "exclamationmark.triangle",
          description: Text(error)
        )
      } else {
        ProgressView()
      }
    }
    .navigationTitle("Invoice")
    .task { await loadInvoice() }
    .toolbar { actionsToolbar }
    .sheet(item: $activeSheet) { sheet in
      sheetView(sheet)
    }
    .confirmationDialog(
      "Confirm", isPresented: Binding(
        get: { pendingAction != nil },
        set: { if !$0 { pendingAction = nil } }
      ), titleVisibility: .visible, presenting: pendingAction
    ) { action in
      Button(action.buttonTitle, role: action.isDestructive ? .destructive : nil) {
        Task { await runLifecycle(action) }
      }
      .accessibilityIdentifier("billing.invoice.\(action.rawValue)Run")
      Button("Cancel", role: .cancel) {}
    } message: { action in
      Text(action.message)
    }
    .writeResultAlert($writeResult)
  }

  // MARK: - Loading

  private func loadInvoice() async {
    do {
      invoice = try await backend.retrieveInvoice(id: invoiceID)
      loadingError = nil
    } catch {
      loadingError = writeErrorMessage(error)
    }
  }

  private func handleWriteFinished(_ result: WriteResult) {
    activeSheet = nil
    writeResult = result
    Task { await loadInvoice() }
  }

  // MARK: - Actions menu

  @ToolbarContentBuilder
  private var actionsToolbar: some ToolbarContent {
    ToolbarItem(placement: .primaryAction) {
      if let invoice, writer != nil, hasActions(invoice) {
        Menu {
          if invoice.status.valueOrNil == .draft {
            Button("Finalize invoice…") { pendingAction = .finalize }
              .accessibilityIdentifier("billing.invoice.finalize")
            Button("Edit details…") { activeSheet = .edit }
              .accessibilityIdentifier("billing.invoice.edit")
            Button("Add line item…") { activeSheet = .addLine }
              .accessibilityIdentifier("billing.invoice.addLine")
            Divider()
            Button("Delete draft…", role: .destructive) { pendingAction = .deleteDraft }
              .accessibilityIdentifier("billing.invoice.delete")
          }
          if invoice.status.valueOrNil == .open {
            Button("Send to customer…") { pendingAction = .send }
              .accessibilityIdentifier("billing.invoice.send")
            Button("Record payment…") { pendingAction = .pay }
              .accessibilityIdentifier("billing.invoice.pay")
            Divider()
            Button("Void invoice…", role: .destructive) { pendingAction = .void }
              .accessibilityIdentifier("billing.invoice.void")
            Button("Mark uncollectible…") { pendingAction = .uncollectible }
              .accessibilityIdentifier("billing.invoice.uncollectible")
          }
        } label: {
          Label("Actions", systemImage: "ellipsis.circle")
        }
        .accessibilityIdentifier("billing.invoice.actions")
      }
    }
  }

  /// Only drafts and open invoices offer actions.
  private func hasActions(_ invoice: Invoice) -> Bool {
    invoice.status.valueOrNil == .draft || invoice.status.valueOrNil == .open
  }

  private func runLifecycle(_ action: InvoiceLifecycleAction) async {
    pendingAction = nil
    guard let writer else { return }
    let id = invoiceID
    do {
      switch action {
      case .finalize:
        _ = try await writer.finalizeInvoice(id: id, summary: "Finalize invoice \(id)")
      case .send:
        _ = try await writer.sendInvoice(id: id, summary: "Send invoice \(id)")
      case .pay:
        _ = try await writer.payInvoice(id: id, summary: "Pay invoice \(id)")
      case .void:
        _ = try await writer.voidInvoice(id: id, summary: "Void invoice \(id)")
      case .uncollectible:
        _ = try await writer.markInvoiceUncollectible(
          id: id, summary: "Mark invoice \(id) uncollectible")
      case .deleteDraft:
        _ = try await writer.deleteInvoice(id: id, summary: "Delete invoice \(id)")
      }
      writeResult = WriteResult(
        title: action.successTitle, message: "\(action.successMessage) \(id).")
      await loadInvoice()
    } catch {
      writeResult = WriteResult(
        title: "Write failed", message: writeErrorMessage(error))
    }
  }

  // MARK: - Sheets

  @ViewBuilder
  private func sheetView(_ sheet: InvoiceSheet) -> some View {
    switch sheet {
    case .edit:
      if let invoice, let writer {
        EditInvoiceSheet(
          invoice: invoice, writer: writer, onFinished: handleWriteFinished)
      }
    case .addLine:
      if let writer {
        AddInvoiceLineSheet(
          invoiceID: invoiceID, writer: writer, onFinished: handleWriteFinished)
      }
    case .updateLine(let line):
      if let writer {
        UpdateInvoiceLineSheet(
          invoiceID: invoiceID, line: line, writer: writer,
          onFinished: handleWriteFinished)
      }
    }
  }

  // MARK: - Content

  @ViewBuilder
  private func invoiceView(_ invoice: Invoice) -> some View {
    Form {
      Section("Summary") {
        if let number = invoice.number.valueOrNil, !number.isEmpty {
          Field("Number", number)
        }
        Field("Status", invoice.statusDisplay)
        Field(
          "Total", MoneyFormat.amount(invoice.total, currency: invoice.currency))
        Field("ID", invoice.id ?? "—")
      }

      if let email = invoice.customerEmail.valueOrNil, !email.isEmpty {
        Section("Customer") {
          Field("Email", email)
        }
      }

      Section("Dates") {
        Field(
          "Created",
          invoice.created.date.formatted(date: .abbreviated, time: .shortened))
        if invoice.dueDate.valueOrNil != nil {
          Field("Due", invoice.dueDateDisplay)
        }
      }

      Section("Line items") {
        ForEach(invoice.lines.data, id: \.id) { line in
          if invoice.status.valueOrNil == .draft, writer != nil {
            Button {
              activeSheet = .updateLine(line)
            } label: {
              lineRow(line)
            }
            .accessibilityIdentifier("billing.invoice.line.\(line.id)")
          } else {
            lineRow(line)
          }
        }
        if invoice.status.valueOrNil == .draft, writer != nil {
          Button("Add line item…") { activeSheet = .addLine }
            .accessibilityIdentifier("billing.invoice.lineAddRow")
        }
      }

      if let metadata = invoice.metadata.valueOrNil, !metadata.isEmpty {
        Section("Metadata") {
          ForEach(metadata.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
            Field(key, value)
          }
        }
      }
    }
  }

  @ViewBuilder
  private func lineRow(_ line: LineItem) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(line.description.valueOrNil ?? "Line item")
        .font(.body)
      Text(lineSubtitle(line))
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
    .padding(.vertical, 2)
  }

  private func lineSubtitle(_ line: LineItem) -> String {
    var parts: [String] = []
    if let quantity = line.quantity.valueOrNil {
      parts.append("Qty \(quantity)")
    }
    parts.append(MoneyFormat.amount(line.amount, currency: line.currency))
    return parts.joined(separator: " · ")
  }
}

// MARK: - Sheet and lifecycle types

/// Sheets presented from the invoice detail view.
private enum InvoiceSheet: Identifiable {
  case edit
  case addLine
  case updateLine(LineItem)

  var id: String {
    switch self {
    case .edit: return "edit"
    case .addLine: return "addLine"
    case .updateLine(let line): return "updateLine-\(line.id)"
    }
  }
}

/// A lifecycle action awaiting confirmation.
private enum InvoiceLifecycleAction: String, Identifiable {
  case finalize
  case send
  case pay
  case void
  case uncollectible
  case deleteDraft = "delete"

  var id: String { rawValue }

  var isDestructive: Bool {
    switch self {
    case .void, .deleteDraft: return true
    default: return false
    }
  }

  var buttonTitle: String {
    switch self {
    case .finalize: return "Finalize"
    case .send: return "Send"
    case .pay: return "Record payment"
    case .void: return "Void"
    case .uncollectible: return "Mark uncollectible"
    case .deleteDraft: return "Delete"
    }
  }

  var successTitle: String {
    switch self {
    case .finalize: return "Invoice finalized"
    case .send: return "Invoice sent"
    case .pay: return "Payment recorded"
    case .void: return "Invoice voided"
    case .uncollectible: return "Marked uncollectible"
    case .deleteDraft: return "Invoice deleted"
    }
  }

  var successMessage: String {
    switch self {
    case .finalize: return "Finalized"
    case .send: return "Sent"
    case .pay: return "Paid"
    case .void: return "Voided"
    case .uncollectible: return "Marked"
    case .deleteDraft: return "Deleted"
    }
  }

  var message: String {
    switch self {
    case .finalize:
      return "A finalized invoice can no longer be edited; it becomes open and ready to send."
    case .send:
      return "The invoice will be emailed to the customer."
    case .pay:
      return "The invoice will be marked as paid out of band."
    case .void:
      return "A voided invoice can no longer be paid. This cannot be undone."
    case .uncollectible:
      return "The invoice will be treated as a loss."
    case .deleteDraft:
      return "This draft invoice will be deleted. This cannot be undone."
    }
  }
}
