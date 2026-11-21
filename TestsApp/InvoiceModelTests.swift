// InvoiceModelTests.swift — TestsApp
// Invoice model behavior: decode of the stripe-mock response shape and the
// display helpers the invoice screens use. All values are obviously fake
// (`in_123`, `il_123`, `cus_123`, example.com).

import XCTest
@testable import GeistData
import StripeModels

final class InvoiceModelTests: XCTestCase {
  private let decoder = JSONDecoder()

  private func decodeInvoice() throws -> Invoice {
    try decoder.decode(Invoice.self, from: Data(invoiceWriteFixtureJSON.utf8))
  }

  /// Decodes a copy of the fixture JSON with a top-level key removed, so
  /// tests can exercise the missing-key path without a second fixture.
  private func decodeInvoiceWithout(_ key: String) throws -> Invoice {
    var dict = invoiceWriteFixture
    dict.removeValue(forKey: key)
    let data = try JSONSerialization.data(withJSONObject: dict)
    return try decoder.decode(Invoice.self, from: data)
  }

  // MARK: - Decode

  func testInvoiceDecodesStripeMockShape() throws {
    let invoice = try decodeInvoice()
    XCTAssertEqual(invoice.id, "in_123")
    XCTAssertEqual(invoice.status.valueOrNil, .draft)
    XCTAssertEqual(invoice.total, 1000)
    XCTAssertEqual(invoice.amountDue, 1000)
    XCTAssertEqual(invoice.currency, "usd")
    XCTAssertEqual(invoice.customerEmail.valueOrNil, "alice@example.com")
    XCTAssertEqual(invoice.number.valueOrNil, nil)
    XCTAssertEqual(invoice.lines.data.count, 1)
    XCTAssertEqual(invoice.lines.data.first?.description.valueOrNil, "Test line")
    XCTAssertEqual(invoice.lines.data.first?.quantity.valueOrNil, 1)
  }

  func testInvoiceWithoutOptionalKeysDecodes() throws {
    let invoice = try decodeInvoiceWithout("status")
    XCTAssertNil(invoice.status.valueOrNil)
    let invoice2 = try decodeInvoiceWithout("due_date")
    XCTAssertNil(invoice2.dueDate.valueOrNil)
    let invoice3 = try decodeInvoiceWithout("number")
    XCTAssertNil(invoice3.number.valueOrNil)
  }

  // MARK: - Status display

  func testStatusDisplayLabel() {
    XCTAssertEqual(InvoiceStatus.draft.displayLabel, "Draft")
    XCTAssertEqual(InvoiceStatus.open.displayLabel, "Open")
    XCTAssertEqual(InvoiceStatus.paid.displayLabel, "Paid")
    XCTAssertEqual(InvoiceStatus.uncollectible.displayLabel, "Uncollectible")
    XCTAssertEqual(InvoiceStatus.void.displayLabel, "Void")
    XCTAssertEqual(InvoiceStatus(rawValue: "new_state").displayLabel, "new_state")
  }

  func testInvoiceStatusDisplay() throws {
    XCTAssertEqual(try decodeInvoice().statusDisplay, "Draft")
    XCTAssertEqual(try decodeInvoiceWithout("status").statusDisplay, "—")
  }

  // MARK: - Due date display

  func testDueDateDisplay() throws {
    XCTAssertEqual(try decodeInvoice().dueDateDisplay, "Feb 13, 2009")
    XCTAssertEqual(try decodeInvoiceWithout("due_date").dueDateDisplay, "—")
  }
}
