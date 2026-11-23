// ListCSVExportModelTests.swift — Tests/GeistDataTests
// The mapping from generated Stripe models to export rows (M7 CSV export).
// Uses obviously fake values built from the generated structs' inits.

import Foundation
import StripeModels
import XCTest
@testable import GeistData

final class ListCSVExportModelTests: XCTestCase {
  // MARK: Charges

  func testChargeMapsToRow() throws {
    let charge = try JSONDecoder().decode(
      Charge.self, from: Data(minimalChargeJSON.utf8))
    let rows = ListCSVExporter.rows(fromCharges: [charge])
    XCTAssertEqual(rows, [["ch_test_1", "19.00", "usd", "succeeded", "cus_test_1",
      "1234567890", "Coffee", "pi_test_1"]])
  }

  func testChargeListProducesHeaderPlusRows() throws {
    let charge = try JSONDecoder().decode(
      Charge.self, from: Data(minimalChargeJSON.utf8))
    let csv = ListCSVExporter.export(
      title: "charges",
      headers: ListCSVExporter.ChargeRow.headers,
      rows: ListCSVExporter.rows(fromCharges: [charge, charge])
    )
    XCTAssertEqual(csv.split(separator: "\n").count, 4)  // comment + header + 2 rows
  }

  // MARK: Payouts

  func testPayoutMapsToRow() throws {
    let payout = try JSONDecoder().decode(
      Payout.self, from: Data(minimalPayoutJSON.utf8))
    let rows = ListCSVExporter.rows(fromPayouts: [payout])
    XCTAssertEqual(
      rows,
      [["po_test_1", "5.00", "usd", "in_transit", "1234567890", "1234567890", ""]])
  }

  // MARK: Fixtures

  /// The fields the row mapping reads, as the mock serves them.
  private var minimalChargeJSON: String {
    """
    {
      "id": "ch_test_1",
      "object": "charge",
      "amount": 1900,
      "amount_captured": 1900,
      "amount_refunded": 0,
      "application": null,
      "application_fee": null,
      "application_fee_amount": null,
      "balance_transaction": null,
      "billing_details": {"address": null, "email": null, "name": null, "phone": null},
      "calculated_statement_descriptor": null,
      "captured": true,
      "created": 1234567890,
      "currency": "usd",
      "customer": "cus_test_1",
      "description": "Coffee",
      "disputed": false,
      "failure_balance_transaction": null,
      "failure_code": null,
      "failure_message": null,
      "fraud_details": null,
      "invoice": null,
      "level3": null,
      "livemode": false,
      "metadata": {},
      "object2": null,
      "on_behalf_of": null,
      "outcome": null,
      "paid": true,
      "payment_intent": "pi_test_1",
      "payment_method": "pm_test_1",
      "payment_method_details": null,
      "receipt_email": null,
      "receipt_number": null,
      "receipt_url": null,
      "refunded": false,
      "refunds": null,
      "review": null,
      "shipping": null,
      "source": null,
      "source_transfer": null,
      "statement_descriptor": null,
      "statement_descriptor_suffix": null,
      "status": "succeeded",
      "transfer": null,
      "transfer_data": null,
      "transfer_group": null
    }
    """
  }

  private var minimalPayoutJSON: String {
    """
    {
      "id": "po_test_1",
      "object": "payout",
      "amount": 500,
      "arrival_date": 1234567890,
      "automatic": false,
      "balance_transaction": null,
      "created": 1234567890,
      "currency": "usd",
      "description": null,
      "destination": null,
      "failure_code": null,
      "failure_message": null,
      "livemode": false,
      "metadata": {},
      "method": "standard",
      "original_payout": null,
      "payout_method": "standard",
      "reconciliation_status": "pending",
      "reversed_by": null,
      "source_type": "card",
      "statement_descriptor": null,
      "status": "in_transit",
      "trace_id": null,
      "type": "bank_account"
    }
    """
  }
}
