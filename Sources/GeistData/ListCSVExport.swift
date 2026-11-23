// ListCSVExport.swift — Sources/GeistData
// CSV export of any list (M7). The exporter is pure: it takes already-
// filtered row values and renders RFC 4180 CSV, so every Payments segment
// can export exactly what its list currently shows, filter included. No
// network, no state; the app layer supplies the rows.

import Foundation
import StripeModels

public enum ListCSVExporter {
  // MARK: Public row models — one per exportable Payments segment

  public struct ChargeRow: Sendable {
    public let id: String
    public let amount: Int
    public let currency: String
    public let status: String
    public let customer: String?
    public let created: Int
    public let description: String?
    public let paymentIntent: String?

    public init(
      id: String, amount: Int, currency: String, status: String, customer: String?,
      created: Int, description: String?, paymentIntent: String?
    ) {
      self.id = id
      self.amount = amount
      self.currency = currency
      self.status = status
      self.customer = customer
      self.created = created
      self.description = description
      self.paymentIntent = paymentIntent
    }

    public static let headers = [
      "ID", "Amount", "Currency", "Status", "Customer", "Created", "Description",
      "PaymentIntent",
    ]

    public var values: [String] {
      [
        id,
        ListCSVExporter.money(amount, currency: currency),
        currency,
        status,
        customer ?? "",
        String(created),
        description ?? "",
        paymentIntent ?? "",
      ]
    }
  }

  public struct PayoutRow: Sendable {
    public let id: String
    public let amount: Int
    public let currency: String
    public let status: String
    public let arrivalDate: Int
    public let created: Int
    public let description: String?

    public init(
      id: String, amount: Int, currency: String, status: String, arrivalDate: Int,
      created: Int, description: String?
    ) {
      self.id = id
      self.amount = amount
      self.currency = currency
      self.status = status
      self.arrivalDate = arrivalDate
      self.created = created
      self.description = description
    }

    public static let headers = [
      "ID", "Amount", "Currency", "Status", "ArrivalDate", "Created", "Description",
    ]

    public var values: [String] {
      [
        id,
        ListCSVExporter.money(amount, currency: currency),
        currency,
        status,
        String(arrivalDate),
        String(created),
        description ?? "",
      ]
    }
  }

  /// The customer ID behind a charge's expandable customer field: the raw
  /// string, an expanded object's ID, or a deleted marker's ID.
  private static func customerID(_ customer: ChargeCustomer) -> String? {
    switch customer {
    case .string(let id): return id
    case .customer(let object): return object.id
    case .deletedCustomer(let deleted): return deleted.id
    case .other: return nil
    }
  }

  // MARK: Mapping generated models to rows

  /// The one generic row shape the non-money segments share: an ID, a
  /// display amount (or empty), a currency (or empty), a status, a free
  /// detail string, and the created timestamp.
  public struct GenericRow: Sendable {
    public let id: String
    public let amount: String
    public let currency: String
    public let status: String
    public let secondary: String
    public let created: String

    public init(
      id: String, amount: String, currency: String, status: String, secondary: String,
      created: String
    ) {
      self.id = id
      self.amount = amount
      self.currency = currency
      self.status = status
      self.secondary = secondary
      self.created = created
    }

    public static let headers = [
      "ID", "Amount", "Currency", "Status", "Detail", "Created",
    ]

    public var values: [String] {
      [id, amount, currency, status, secondary, created]
    }
  }

  public struct ReportRunRow: Sendable {
    public let id: String
    public let reportType: String
    public let status: String
    public let created: Int
    public let resultFile: String

    public init(
      id: String, reportType: String, status: String, created: Int, resultFile: String
    ) {
      self.id = id
      self.reportType = reportType
      self.status = status
      self.created = created
      self.resultFile = resultFile
    }

    public static let headers = [
      "ID", "ReportType", "Status", "Created", "ResultFile",
    ]

    public var values: [String] {
      [id, reportType, status, String(created), resultFile]
    }
  }

  /// Maps a fetched, already-filtered charge list to export rows.
  public static func rows(fromCharges charges: [Charge]) -> [[String]] {
    charges.map { charge in
      ChargeRow(
        id: charge.id,
        amount: charge.amount,
        currency: charge.currency,
        status: String(describing: charge.status),
        customer: charge.customer.valueOrNil.flatMap(customerID),
        created: charge.created.seconds,
        description: charge.description.valueOrNil,
        paymentIntent: charge.paymentIntent.valueOrNil?.idOrNil
      ).values
    }
  }

  /// Maps a fetched, already-filtered payout list to export rows.
  public static func rows(fromPayouts payouts: [Payout]) -> [[String]] {
    payouts.map { payout in
      PayoutRow(
        id: payout.id,
        amount: payout.amount,
        currency: payout.currency,
        status: payout.status,
        arrivalDate: payout.arrivalDate.seconds,
        created: payout.created.seconds,
        description: payout.description.valueOrNil
      ).values
    }
  }

  // MARK: Rendering

  /// Renders the export: a `#` comment line naming the list and its
  /// generation time, the header row, then one row per record. Rows shorter
  /// than the header are padded with empty strings.
  public static func export(
    title: String, headers: [String], rows: [[String]], generatedAt: Date = Date()
  ) -> String {
    var lines: [String] = []
    lines.append(
      "# Geist6 export: \(title); generated \(String(format: "%.0f", generatedAt.timeIntervalSince1970))")
    lines.append(renderLine(headers))
    for row in rows {
      var padded = row
      if padded.count < headers.count {
        padded.append(contentsOf: Array(repeating: "", count: headers.count - padded.count))
      }
      lines.append(renderLine(padded))
    }
    return lines.joined(separator: "\n") + "\n"
  }

  private static func renderLine(_ fields: [String]) -> String {
    fields.map(escape).joined(separator: ",")
  }

  /// RFC 4180: quote a field when it contains a comma, quote, or newline,
  /// doubling embedded quotes.
  private static func escape(_ field: String) -> String {
    if field.contains(",") || field.contains("\"") || field.contains("\n")
      || field.contains("\r")
    {
      let doubled = field.replacingOccurrences(of: "\"", with: "\"\"")
      return "\"\(doubled)\""
    }
    return field
  }

  /// Money as a decimal string with the standard two-place rendering.
  /// (Zero- and three-decimal currency handling stays with the shared
  /// money formatter at the UI layer; the CSV keeps the plain decimal.)
  static func money(_ amount: Int, currency: String) -> String {
    let negative = amount < 0
    let magnitude = abs(amount)
    return String(format: "%@%.2f", negative ? "-" : "", Double(magnitude) / 100.0)
  }

  // MARK: Parsing — round-trip verification for tests and previews

  /// Parses RFC 4180 CSV back into rows, for tests to assert on exports.
  /// Skips the exporter's `#` comment lines. Every loop path advances the
  /// index past the bytes it consumes: a `continue` without an advance in
  /// a plain `while` never moves and hangs the caller (this suite hung on
  /// exactly that before the rewrite).
  public static func parse(_ csv: String) throws -> [[String]] {
    var rows: [[String]] = []
    var field = ""
    var row: [String] = []
    var inQuotes = false
    var pendingQuote = false
    var atLineStart = true
    let chars = Array(csv)
    var i = 0
    while i < chars.count {
      let ch = chars[i]
      if inQuotes {
        if ch == "\"" {
          if pendingQuote {
            field.append("\"")
            pendingQuote = false
          } else {
            pendingQuote = true
          }
        } else if pendingQuote {
          // A character after the closing quote ends the field.
          inQuotes = false
          row.append(field)
          field = ""
          pendingQuote = false
          if ch == "\n" || ch == "\r" {
            rows.append(row)
            row = []
            atLineStart = (ch == "\n")
            i += 1
            continue
          }
          if ch != "," { field.append(ch) }
        } else {
          field.append(ch)
        }
      } else {
        if ch == "\"" {
          inQuotes = true
        } else if ch == "," {
          row.append(field)
          field = ""
        } else if ch == "\n" {
          row.append(field)
          field = ""
          rows.append(row)
          row = []
          atLineStart = true
          i += 1
          continue
        } else if ch == "\r" {
          // Swallow; the following \n closes the row.
        } else if atLineStart && ch == "#" {
          // Skip the exporter's comment line, including its newline.
          while i < chars.count, chars[i] != "\n" { i += 1 }
          if i < chars.count { i += 1 }
          atLineStart = true
          continue
        } else {
          atLineStart = false
          field.append(ch)
        }
      }
      atLineStart = false
      i += 1
    }
    if !field.isEmpty || !row.isEmpty {
      row.append(field)
      rows.append(row)
    }
    return rows
  }
}
