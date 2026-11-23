// ReportRunTests.swift — Tests/GeistDataTests
// The report-run/report-type slice (M7, decision 0031). Decodes mirror the
// responses stripe-mock 0.206.0 actually serves for the five reporting
// endpoints (probed against the decision 0029 overlay): a list with one
// `succeeded` run whose embedded result File carries `url: null`, and a
// report type with default columns. Fake IDs throughout.

import Foundation
import StripeModels
import XCTest
@testable import GeistData

final class ReportRunTests: XCTestCase {
    private let decoder = JSONDecoder()

    // MARK: Fixtures (the exact shapes the mock returns)

    private func reportRunJSON(
        id: String = "frr_test_123",
        status: String = "succeeded",
        url: String? = "https://files.example.com/report.csv"
    ) -> Data {
        let resultFile: String
        if let url {
            resultFile = """
            {
              "id": "file_test_123",
              "object": "file",
              "created": 1234567890,
              "expires_at": null,
              "filename": "balance.summary.csv",
              "links": null,
              "purpose": "reporting.report_run",
              "size": 353,
              "title": null,
              "type": null,
              "url": "\(url)"
            }
            """
        } else {
            resultFile = """
            {
              "id": "file_test_123",
              "object": "file",
              "created": 1234567890,
              "expires_at": null,
              "filename": null,
              "links": null,
              "purpose": "reporting.report_run",
              "size": 353,
              "title": null,
              "type": null,
              "url": null
            }
            """
        }
        let json = """
        {
          "id": "\(id)",
          "object": "reporting.report_run",
          "created": 1234567890,
          "error": null,
          "livemode": false,
          "parameters": {
            "interval_end": 1525132800,
            "interval_start": 1522540800
          },
          "report_type": "balance.summary.1",
          "result": \(resultFile),
          "status": "\(status)",
          "succeeded_at": \(status == "succeeded" ? "1234567890" : "null")
        }
        """
        return Data(json.utf8)
    }

    private func reportTypeJSON() -> Data {
        let json = """
        {
          "id": "balance.summary.1",
          "object": "reporting.report_type",
          "data_available_end": 1234567890,
          "data_available_start": 1234567890,
          "default_columns": ["category", "currency", "description", "net_amount"],
          "livemode": false,
          "name": "Balance summary",
          "updated": 1234567890,
          "version": 1
        }
        """
        return Data(json.utf8)
    }

    // MARK: Decode

    func testDecodesRunStripeMockShape() throws {
        let run = try decoder.decode(ReportingReportRun.self, from: reportRunJSON())
        XCTAssertEqual(run.id, "frr_test_123")
        XCTAssertEqual(run.status, "succeeded")
        XCTAssertEqual(run.reportType, "balance.summary.1")
        XCTAssertEqual(run.parameters.intervalStart?.seconds, 1522540800)
        XCTAssertEqual(run.parameters.intervalEnd?.seconds, 1525132800)
        XCTAssertEqual(run.succeededAt.valueOrNil?.seconds, 1234567890)
        XCTAssertEqual(run.error.valueOrNil, nil)
        XCTAssertEqual(run.livemode, false)
    }

    func testRunResultFileCarriesURL() throws {
        let run = try decoder.decode(ReportingReportRun.self, from: reportRunJSON())
        let file = try XCTUnwrap(run.result.valueOrNil)
        XCTAssertEqual(file.id, "file_test_123")
        XCTAssertEqual(file.url.valueOrNil, "https://files.example.com/report.csv")
    }

    /// stripe-mock's canned runs carry `url: null` (its response builder
    /// strips unknown fields); the decode must survive that and surface it.
    func testRunResultURLNilDecodes() throws {
        let run = try decoder.decode(
            ReportingReportRun.self, from: reportRunJSON(url: nil))
        let file = try XCTUnwrap(run.result.valueOrNil)
        XCTAssertNil(file.url.valueOrNil, "the mock's url must decode as nil")
    }

    func testRunPendingHasNoSucceededAt() throws {
        let run = try decoder.decode(
            ReportingReportRun.self, from: reportRunJSON(status: "pending"))
        XCTAssertEqual(run.status, "pending")
        XCTAssertNil(run.succeededAt.valueOrNil)
    }

    func testDecodesReportTypeStripeMockShape() throws {
        let type = try decoder.decode(ReportingReportType.self, from: reportTypeJSON())
        XCTAssertEqual(type.id, "balance.summary.1")
        XCTAssertEqual(type.name, "Balance summary")
        XCTAssertEqual(type.version, 1)
        XCTAssertEqual(
            type.defaultColumns.valueOrNil,
            ["category", "currency", "description", "net_amount"])
    }
}
