// ListExportModelTests.swift — TestsApp
// The PaymentsModel export path (M7 CSV export): the model renders the
// active segment's currently loaded (already filtered) list to CSV and
// hands back the file URL in Documents. Tests use obviously fake values.

import Foundation
import GeistData
import StripeModels
import XCTest
@testable import Geist6

@MainActor
final class ListExportModelTests: XCTestCase {
  // MARK: Row mapping per segment

  func testChargeSegmentExport() async throws {
    let model = PaymentsModel(backend: StubListBackend(charges: [
      try FilterFixtures.charge(
        id: "ch_test_1", created: 1_234_567_890, status: "succeeded", amount: 1_900,
        customer: "cus_test_1"
      ),
    ]))
    await model.load(.charges)

    let csv = try model.exportCSV(.charges, generatedAt: Date(timeIntervalSince1970: 1_700_000_000))
    let lines = csv.split(separator: "\n").map(String.init)
    XCTAssertEqual(lines.count, 3)  // comment + header + 1 row
    XCTAssertTrue(lines[0].hasPrefix("# Geist6 export: charges;"), lines[0])
    XCTAssertEqual(lines[1], "ID,Amount,Currency,Status,Customer,Created,Description,PaymentIntent")
    XCTAssertEqual(lines[2], "ch_test_1,19.00,usd,succeeded,cus_test_1,1234567890,,")
  }

  func testPayoutSegmentExport() async throws {
    let model = PaymentsModel(backend: StubListBackend(payouts: [
      try FilterFixtures.payout(
        id: "po_test_1", created: 1_234_567_890, status: "paid", amount: 500
      ),
    ]))
    await model.load(.payouts)

    let csv = try model.exportCSV(.payouts, generatedAt: Date(timeIntervalSince1970: 1_700_000_000))
    let lines = csv.split(separator: "\n").map(String.init)
    XCTAssertEqual(lines[2], "po_test_1,5.00,usd,paid,1234654290,1234567890,")
  }

  func testReportsSegmentExport() async throws {
    let model = PaymentsModel(backend: StubListBackend())
    await model.load(.reports)

    let csv = try model.exportCSV(.reports, generatedAt: Date(timeIntervalSince1970: 1_700_000_000))
    let lines = csv.split(separator: "\n").map(String.init)
    XCTAssertEqual(lines.count, 2)  // comment + header, the stub list is empty
    XCTAssertEqual(lines[1], "ID,ReportType,Status,Created,ResultFile")
  }

  func testExportOnUnloadedSegmentThrows() async throws {
    let model = PaymentsModel(backend: StubListBackend())
    XCTAssertThrowsError(try model.exportCSV(.charges)) { error in
      guard case PaymentsModel.ExportError.notLoaded(let segment) = error else {
        return XCTFail("\(error)")
      }
      XCTAssertEqual(segment, .charges)
    }
  }
}

/// A backend serving fixed lists for the export tests. Every method returns
/// an empty list unless a fixture was provided.
private struct StubListBackend: PaymentsBackend {
  var charges: [Charge] = []
  var payouts: [Payout] = []
  var reportRuns: [ReportingReportRun] = []

  func paymentIntents(created: DateInterval?, customer: String?) async throws -> [PaymentIntent] { [] }
  func charges(created: DateInterval?, customer: String?, paymentIntent: String?) async throws -> [Charge] { charges }
  func refunds(charge: String?) async throws -> [Refund] { [] }
  func disputes(charge: String?) async throws -> [Dispute] { [] }
  func setupIntents(created: DateInterval?, customer: String?) async throws -> [SetupIntent] { [] }
  func paymentMethods(customer: String?) async throws -> [PaymentMethod] { [] }
  func paymentLinks(active: Bool?) async throws -> [PaymentLink] { [] }
  func checkoutSessions(created: DateInterval?, customer: String?, status: String?) async throws -> [CheckoutSession] { [] }
  func payouts() async throws -> [Payout] { payouts }
  func transfers() async throws -> [Transfer] { [] }
  func topups() async throws -> [Topup] { [] }
  func reportRuns(created: DateInterval?) async throws -> [ReportingReportRun] { reportRuns }
  func reportTypes() async throws -> [ReportingReportType] { [] }
  func retrievePaymentIntent(id: String) async throws -> PaymentIntent { throw StubError.missing }
  func searchPaymentIntents(query: String) async throws -> [PaymentIntent] { [] }
  func retrieveCharge(id: String) async throws -> Charge { throw StubError.missing }
  func retrieveRefund(id: String) async throws -> Refund { throw StubError.missing }
  func retrieveSetupIntent(id: String) async throws -> SetupIntent { throw StubError.missing }
  func retrievePaymentMethod(id: String) async throws -> PaymentMethod { throw StubError.missing }
  func retrievePaymentLink(id: String) async throws -> PaymentLink { throw StubError.missing }
  func paymentLinkLineItems(id: String) async throws -> [Item] { [] }
  func retrieveCheckoutSession(id: String) async throws -> CheckoutSession { throw StubError.missing }
  func checkoutSessionLineItems(id: String) async throws -> [Item] { [] }
  func retrieveMandate(id: String) async throws -> Mandate { throw StubError.missing }
  func retrieveConfirmationToken(id: String) async throws -> ConfirmationToken { throw StubError.missing }
  func intentLineItems(intent: String) async throws -> [PaymentIntentAmountDetailsLineItem] { [] }
  func retrieveBalanceTransaction(id: String) async throws -> BalanceTransaction { throw StubError.missing }
  func retrievePayout(id: String) async throws -> Payout { throw StubError.missing }
  func retrieveTransfer(id: String) async throws -> Transfer { throw StubError.missing }
  func retrieveTopup(id: String) async throws -> Topup { throw StubError.missing }
  func retrieveReportRun(id: String) async throws -> ReportingReportRun { throw StubError.missing }
  func retrieveReportType(id: String) async throws -> ReportingReportType { throw StubError.missing }

  // StripeDataBackend (the base protocol)
  func retrieveBalance() async throws -> Balance { throw StubError.missing }
  func balanceTransactions(created: DateInterval?, currency: String?) async throws -> [BalanceTransaction] { [] }
  func balanceTransactions(payout: String) async throws -> [BalanceTransaction] { [] }
  func charges(created: DateInterval?) async throws -> [Charge] { charges }
  func customers(created: DateInterval?, email: String?) async throws -> [Customer] { [] }
  func retrieveCustomer(id: String) async throws -> Customer { throw StubError.missing }
  func transferReversals(transfer: String) async throws -> [TransferReversal] { [] }
  func events(created: DateInterval?) async throws -> [Event] { [] }
  func searchCharges(query: String) async throws -> [Charge] { [] }
  func rawObject(path: String) async throws -> Data { Data() }
}

private enum StubError: Error { case missing }
