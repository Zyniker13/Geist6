// ListCSVExportTests.swift — Tests/GeistDataTests
// CSV export of any list (M7's last tier-1 row). The exporter renders the
// rows the Payments screen currently shows — including the active filter's
// effect, which the model applies client-side — so the exporter takes plain
// row values, not Stripe objects. Tests use obviously fake values only.

import Foundation
import XCTest
@testable import GeistData

final class ListCSVExportTests: XCTestCase {
  // MARK: Header + rows

  func testRendersHeaderAndEscapedValues() throws {
    let csv = ListCSVExporter.export(
      title: "charges",
      headers: ["ID", "Amount", "Status", "Note"],
      rows: [
        ["ch_test_1", "100", "succeeded", "plain"],
        ["ch_test_2", "1250", "failed", "has, comma"],
        ["ch_test_3", "-42", "pending", "has \"quote\""],
      ]
    )
    let lines = try ListCSVExporter.parse(csv)
    XCTAssertEqual(lines[0], ["ID", "Amount", "Status", "Note"])
    XCTAssertEqual(lines[1], ["ch_test_1", "100", "succeeded", "plain"])
    // RFC 4180: a field containing a comma is quoted; embedded quotes are
    // doubled.
    XCTAssertEqual(lines[2], ["ch_test_2", "1250", "failed", "has, comma"])
    XCTAssertEqual(lines[3], ["ch_test_3", "-42", "pending", "has \"quote\""])
  }

  func testQuotingSurvivesNewlinesAndCarriageReturns() throws {
    let csv = ListCSVExporter.export(
      title: "charges",
      headers: ["ID", "Note"],
      rows: [["ch_test_1", "line1\nline2"]]
    )
    let lines = try ListCSVExporter.parse(csv)
    XCTAssertEqual(lines.count, 2)
    XCTAssertEqual(lines[0], ["ID", "Note"])
    XCTAssertEqual(lines[1], ["ch_test_1", "line1\nline2"])
  }

  func testParseHandlesQuotedFieldWithComma() throws {
    let csv = "ID,Note\n\"a,b\",\"say \"\"hi\"\"\"\n"
    let lines = try ListCSVExporter.parse(csv)
    XCTAssertEqual(lines.count, 2)
    XCTAssertEqual(lines[0], ["ID", "Note"])
    XCTAssertEqual(lines[1], ["a,b", "say \"hi\""])
  }

  // MARK: Padding and metadata

  func testRowsWithFewerColumnsArePaddedToHeaderWidth() throws {
    let csv = ListCSVExporter.export(
      title: "charges",
      headers: ["ID", "Amount", "Status"],
      rows: [["ch_test_1", "100"]]
    )
    let lines = try ListCSVExporter.parse(csv)
    XCTAssertEqual(lines[1], ["ch_test_1", "100", ""])
  }

  func testHeaderCarriesTitleAndGeneratedAt() throws {
    let csv = ListCSVExporter.export(
      title: "charges",
      headers: ["ID"],
      rows: [["ch_test_1"]],
      generatedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
    let first = String(csv.split(separator: "\n", omittingEmptySubsequences: false).first ?? "")
    XCTAssertTrue(first.hasPrefix("# Geist6 export: charges; generated "), first)
    // The fixed timestamp renders as a Unix epoch in the comment line.
    XCTAssertTrue(first.contains("1700000000"), first)
  }

  func testEmptyRowsProduceHeaderOnly() throws {
    let csv = ListCSVExporter.export(
      title: "payouts", headers: ["ID", "Amount"], rows: [])
    let lines = try ListCSVExporter.parse(csv)
    XCTAssertEqual(lines.count, 1)
    XCTAssertEqual(lines[0], ["ID", "Amount"])
  }

  // MARK: The row models each segment exports

  func testChargeRowFields() {
    let row = ListCSVExporter.ChargeRow(
      id: "ch_test_1", amount: 1000, currency: "usd", status: "succeeded",
      customer: "cus_test_1", created: 1_234_567_890, description: "Test charge",
      paymentIntent: "pi_test_1")
    let values = row.values
    XCTAssertEqual(
      values,
      ["ch_test_1", "10.00", "usd", "succeeded", "cus_test_1", "1234567890", "Test charge",
        "pi_test_1"])
  }

  func testPayoutRowFields() {
    let row = ListCSVExporter.PayoutRow(
      id: "po_test_1", amount: 500, currency: "usd", status: "paid",
      arrivalDate: 1_234_567_890, created: 1_234_000_000, description: nil)
    XCTAssertEqual(
      row.values,
      ["po_test_1", "5.00", "usd", "paid", "1234567890", "1234000000", ""])
  }

  // MARK: The remaining segments' row shapes

  func testGenericRowFields() {
    let row = ListCSVExporter.GenericRow(
      id: "pi_test_1", amount: "12.00", currency: "usd", status: "succeeded",
      secondary: "cus_test_1", created: "1234567890")
    XCTAssertEqual(
      row.values,
      ["pi_test_1", "12.00", "usd", "succeeded", "cus_test_1", "1234567890"])
    XCTAssertEqual(
      ListCSVExporter.GenericRow.headers,
      ["ID", "Amount", "Currency", "Status", "Detail", "Created"])
  }

  func testReportRunRowFields() {
    let row = ListCSVExporter.ReportRunRow(
      id: "frr_test_1", reportType: "balance.summary", status: "succeeded",
      created: 1_234_567_890, resultFile: "file_test_1")
    XCTAssertEqual(
      row.values,
      ["frr_test_1", "balance.summary", "succeeded", "1234567890", "file_test_1"])
    XCTAssertEqual(
      ListCSVExporter.ReportRunRow.headers,
      ["ID", "ReportType", "Status", "Created", "ResultFile"])
  }
}
