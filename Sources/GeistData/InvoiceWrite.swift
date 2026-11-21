// InvoiceWrite.swift — GeistData
// The M6 invoice write verbs on BillingWriteService: draft edits, line
// edits, lifecycle verbs, and deletion. Every request goes through `run`,
// which refuses writes in dashboard mode, attaches an idempotency key, and
// records the attempt in the audit log.

import Foundation
import StripeClient
import StripeModels

extension BillingWriteService {
  // MARK: - Draft edits

  /// A new draft invoice. `metadata == nil` leaves metadata unset; a
  /// non-nil value is sent wholesale.
  public struct InvoiceDraft: Sendable {
    public let customer: String?
    public let description: String?
    public let footer: String?
    public let metadata: [String: String]?

    public init(
      customer: String?, description: String?, footer: String?,
      metadata: [String: String]?
    ) {
      self.customer = customer
      self.description = description
      self.footer = footer
      self.metadata = metadata
    }
  }

  /// Creates a draft invoice from `draft`.
  public func createInvoice(
    draft: InvoiceDraft, summary: String
  ) async throws -> Invoice {
    var params = InvoiceCreateParams()
    params.customer = draft.customer
    params.description = draft.description
    params.footer = draft.footer
    if let metadata = draft.metadata {
      params.metadata = .value(metadata)
    }
    return try await run(
      Invoice.self, method: "POST", path: "/v1/invoices", params: params,
      key: Self.key(), summary: summary)
  }

  /// The editable fields of an invoice update. `nil` fields are left
  /// untouched; a non-nil `metadata` replaces it wholesale (an empty
  /// dictionary clears it).
  public struct InvoiceUpdate: Sendable {
    public let description: String?
    public let footer: String?
    public let metadata: [String: String]?

    public init(description: String?, footer: String?, metadata: [String: String]?) {
      self.description = description
      self.footer = footer
      self.metadata = metadata
    }
  }

  /// Updates the editable fields of an invoice.
  public func updateInvoice(
    id: String, update: InvoiceUpdate, summary: String
  ) async throws -> Invoice {
    var params = InvoiceUpdateParams()
    params.description = update.description
    params.footer = update.footer
    if let metadata = update.metadata {
      params.metadata = .value(metadata)
    }
    return try await run(
      Invoice.self, method: "POST", path: "/v1/invoices/\(id)", params: params,
      key: Self.key(), summary: summary)
  }

  /// A line to add to a draft invoice.
  public struct InvoiceLineDraft: Sendable {
    public let description: String?
    public let amount: Int?
    public let quantity: Int?

    public init(description: String?, amount: Int?, quantity: Int?) {
      self.description = description
      self.amount = amount
      self.quantity = quantity
    }
  }

  /// Adds a line item to a draft invoice.
  public func addInvoiceLine(
    invoice: String, line: InvoiceLineDraft, summary: String
  ) async throws -> Invoice {
    let params = InvoiceAddLinesParams(
      lines: [
        InvoiceAddLinesParamsLinesItem(
          amount: line.amount, description: line.description, quantity: line.quantity)
      ])
    return try await run(
      Invoice.self, method: "POST", path: "/v1/invoices/\(invoice)/add_lines",
      params: params, key: Self.key(), summary: summary)
  }

  /// Updates one line item of a draft invoice; `nil` fields are untouched.
  public func updateInvoiceLine(
    invoice: String, lineID: String, description: String?, quantity: Int?,
    summary: String
  ) async throws -> Invoice {
    let params = InvoiceUpdateLinesParams(
      lines: [
        InvoiceUpdateLinesParamsLinesItem(
          description: description, id: lineID, quantity: quantity)
      ])
    return try await run(
      Invoice.self, method: "POST", path: "/v1/invoices/\(invoice)/update_lines",
      params: params, key: Self.key(), summary: summary)
  }

  /// Removes one line item from a draft invoice, deleting it; draft lines
  /// carry no lifecycle of their own.
  public func removeInvoiceLine(
    invoice: String, lineID: String, summary: String
  ) async throws -> Invoice {
    let params = InvoiceRemoveLinesParams(
      lines: [
        InvoiceRemoveLinesParamsLinesItem(behavior: .delete, id: lineID)
      ])
    return try await run(
      Invoice.self, method: "POST", path: "/v1/invoices/\(invoice)/remove_lines",
      params: params, key: Self.key(), summary: summary)
  }

  // MARK: - Lifecycle

  /// Finalizes a draft invoice so it can be sent and paid.
  public func finalizeInvoice(id: String, summary: String) async throws -> Invoice {
    return try await run(
      Invoice.self, method: "POST", path: "/v1/invoices/\(id)/finalize",
      params: InvoiceFinalizeInvoiceParams(), key: Self.key(), summary: summary)
  }

  /// Sends a finalized invoice to the customer by email.
  public func sendInvoice(id: String, summary: String) async throws -> Invoice {
    return try await run(
      Invoice.self, method: "POST", path: "/v1/invoices/\(id)/send",
      params: InvoiceSendInvoiceParams(), key: Self.key(), summary: summary)
  }

  /// Marks a finalized invoice as paid out of band.
  public func payInvoice(id: String, summary: String) async throws -> Invoice {
    return try await run(
      Invoice.self, method: "POST", path: "/v1/invoices/\(id)/pay",
      params: InvoicePayParams(), key: Self.key(), summary: summary)
  }

  /// Voids a finalized invoice.
  public func voidInvoice(id: String, summary: String) async throws -> Invoice {
    return try await run(
      Invoice.self, method: "POST", path: "/v1/invoices/\(id)/void",
      params: InvoiceVoidInvoiceParams(), key: Self.key(), summary: summary)
  }

  /// Marks a finalized invoice as uncollectible.
  public func markInvoiceUncollectible(id: String, summary: String) async throws -> Invoice {
    return try await run(
      Invoice.self, method: "POST", path: "/v1/invoices/\(id)/mark_uncollectible",
      params: InvoiceMarkUncollectibleParams(), key: Self.key(), summary: summary)
  }

  /// Deletes a draft invoice.
  public func deleteInvoice(id: String, summary: String) async throws -> DeletedInvoice {
    return try await run(
      DeletedInvoice.self, method: "DELETE", path: "/v1/invoices/\(id)",
      params: InvoiceDeleteParams(), key: Self.key(), summary: summary)
  }
}
