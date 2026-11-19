// LinkChargeWriteTests.swift — TestsApp
// The M4c-4 writes: create a payment link and create a charge. Refuse in
// dashboard mode before any network traffic, carry an idempotency key,
// encode their parameters, and record the attempt in the audit log.
// Stubbed transport; fixtures are stripe-mock responses with obviously
// fake values. No real network is touched.

import XCTest

@testable import GeistData
@testable import StripeClient
import StripeModels

@MainActor
final class LinkChargeWriteTests: XCTestCase {

  private var audit: InMemoryAuditStore!

  override func setUp() async throws {
    WriteStubURLProtocol.reset()
    audit = InMemoryAuditStore()
  }

  private static let stubSession: URLSession = {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [WriteStubURLProtocol.self]
    return URLSession(configuration: config)
  }()

  private func makeService(mode: StripeClient.Mode) -> PaymentsWriteService {
    let client = StripeClient(
      apiKey: "sk_test_fake", mode: mode,
      baseURL: URL(string: "http://127.0.0.1:1")!, session: Self.stubSession)
    return PaymentsWriteService(
      client: client, accountID: "acct_test_123", accountName: "Shot Store", audit: audit,
      dashboardLocked: { false })
  }

  // MARK: - Create payment link

  func testCreatePaymentLinkEncodesLineItem() async throws {
    let service = makeService(mode: .management)
    WriteStub.install(status: 200, json: plinkWriteFixture)
    let link = try await service.createPaymentLink(
      price: "price_test_123", quantity: 2, summary: "Create payment link")
    XCTAssertEqual(link.id, "plink_test_123")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/payment_links"))
    XCTAssertEqual(
      try XCTUnwrap(WriteStub.firstBodyString()),
      "line_items%5B0%5D%5Bprice%5D=price_test_123&line_items%5B0%5D%5Bquantity%5D=2")
  }

  func testDashboardModeRefusesCreatePaymentLinkBeforeNetwork() async throws {
    let service = makeService(mode: .dashboard)
    do {
      _ = try await service.createPaymentLink(
        price: "price_test_123", quantity: 1, summary: "Create payment link")
      XCTFail("dashboard-mode write should throw")
    } catch let error as PaymentsWriteError {
      XCTAssertEqual(error, .dashboardMode)
    } catch {
      XCTFail("Expected PaymentsWriteError.dashboardMode, got \(error)")
    }
    XCTAssertTrue(
      WriteStubURLProtocol.recordedRequests.isEmpty,
      "a dashboard-mode payment link create reached the network")
    let entries = await audit.entries(limit: 10)
    XCTAssertEqual(entries.count, 1)
    XCTAssertEqual(entries[0].outcome, "refused: dashboard mode")
    XCTAssertEqual(entries[0].path, "/v1/payment_links")
  }

  // MARK: - Create charge

  func testCreateChargeEncodesFields() async throws {
    let service = makeService(mode: .management)
    WriteStub.install(status: 200, json: chargeWriteFixture)
    let charge = try await service.createCharge(
      amount: 1000, currency: "usd", source: "pm_test_123", description: "Test charge",
      summary: "Create charge")
    XCTAssertEqual(charge.id, "ch_test_123")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/charges"))
    XCTAssertEqual(
      try XCTUnwrap(WriteStub.firstBodyString()),
      "amount=1000&currency=usd&description=Test+charge&source=pm_test_123")
  }

  func testCreateChargeOmitsEmptyDescription() async throws {
    let service = makeService(mode: .management)
    WriteStub.install(status: 200, json: chargeWriteFixture)
    _ = try await service.createCharge(
      amount: 500, currency: "eur", source: "pm_test_123", description: nil,
      summary: "Create charge")
    XCTAssertEqual(
      try XCTUnwrap(WriteStub.firstBodyString()),
      "amount=500&currency=eur&source=pm_test_123")
  }

  func testDashboardModeRefusesCreateChargeBeforeNetwork() async throws {
    let service = makeService(mode: .dashboard)
    do {
      _ = try await service.createCharge(
        amount: 1000, currency: "usd", source: "pm_test_123", description: nil,
        summary: "Create charge")
      XCTFail("dashboard-mode write should throw")
    } catch let error as PaymentsWriteError {
      XCTAssertEqual(error, .dashboardMode)
    } catch {
      XCTFail("Expected PaymentsWriteError.dashboardMode, got \(error)")
    }
    XCTAssertTrue(
      WriteStubURLProtocol.recordedRequests.isEmpty,
      "a dashboard-mode charge create reached the network")
    let entries = await audit.entries(limit: 10)
    XCTAssertEqual(entries.count, 1)
    XCTAssertEqual(entries[0].outcome, "refused: dashboard mode")
    XCTAssertEqual(entries[0].path, "/v1/charges")
  }
}
