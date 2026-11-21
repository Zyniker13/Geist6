// InvoiceDisplay.swift — Sources/GeistData
// Display labels for invoices, shared by the invoice list and detail
// screens. Pure data: no UIKit or SwiftUI, so `swift test` covers it.

import Foundation
import StripeModels

extension InvoiceStatus {
  /// The human-facing label for an invoice's status. An undocumented
  /// status falls through as its raw value so a Stripe addition shows
  /// up verbatim instead of crashing or hiding.
  public var displayLabel: String {
    switch self {
    case .draft: "Draft"
    case .open: "Open"
    case .paid: "Paid"
    case .uncollectible: "Uncollectible"
    case .void: "Void"
    case .undocumented(let raw): raw
    }
  }
}

extension Invoice {
  /// The status label, or an em dash when the invoice has none.
  public var statusDisplay: String {
    status.valueOrNil?.displayLabel ?? "—"
  }

  /// The due date as "Feb 13, 2009", pinned to en_US_POSIX and UTC so the
  /// output is identical in every locale and test environment; an em dash
  /// when the invoice has no due date.
  public var dueDateDisplay: String {
    guard let due = dueDate.valueOrNil else { return "—" }
    return DueDateFormatter.shared.string(from: due.date)
  }
}

private enum DueDateFormatter {
  static let shared: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "UTC")
    formatter.dateFormat = "MMM d, yyyy"
    return formatter
  }()
}
