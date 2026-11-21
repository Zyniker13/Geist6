import GeistData
import StripeModels
import SwiftUI

/// Detail view for a single invoice: status, total, customer, dates, and
/// line items. Write actions (finalize, send, pay, void, and friends) are
/// layered on in later slices; the read screen stands on its own.
struct InvoiceDetailView: View {
  let invoiceID: String
  let backend: any BillingBackend
  /// Nil for dashboard-locked accounts: no write UI exists at all.
  let writer: BillingWriteService?

  @State private var invoice: Invoice?
  @State private var loadingError: String?

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
  }

  private func loadInvoice() async {
    do {
      invoice = try await backend.retrieveInvoice(id: invoiceID)
      loadingError = nil
    } catch {
      loadingError = writeErrorMessage(error)
    }
  }

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
          lineRow(line)
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
    parts.append(MoneyFormat.amount(line.amount, currency: invoice?.currency ?? "usd"))
    return parts.joined(separator: " · ")
  }
}
