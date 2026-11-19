// PaymentMethodWriteTests.swift — TestsApp
// The M4c-3 payment method writes: refuse in dashboard mode before any
// network traffic, carry an idempotency key, encode their parameters, and
// record the attempt in the audit log. Stubbed transport; no real network
// is touched.

import XCTest

@testable import GeistData
@testable import StripeClient
import StripeModels

@MainActor
final class PaymentMethodWriteTests: XCTestCase {

  private var audit: InMemoryAuditStore!

  // Fixture rule: empty collections inside [String: Any] literals must be
  // NSDictionary() / NSArray() — see PaymentsWriteTests for the full story.
  // Non-empty Swift literals are fine.

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

  // MARK: - Creation

  func testCreatePaymentMethodEncodesCardFields() async throws {
    let service = makeService(mode: .management)
    WriteStub.install(status: 200, json: [
      "billing_details": NSDictionary(),
      "card": ["brand": "visa", "exp_month": 12, "exp_year": 2030, "funding": "credit",
               "last4": "4242"],
      "created": 1_700_000_000, "id": "pm_test_124", "livemode": false,
      "object": "payment_method", "type": "card",
    ])
    let method = try await service.createPaymentMethod(
      type: "card", cardNumber: "4242424242424242", expMonth: 12, expYear: 2030,
      cvc: "123", summary: "Create payment method")
    XCTAssertEqual(method.id, "pm_test_124")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/payment_methods"))
    XCTAssertEqual(
      try XCTUnwrap(WriteStub.firstBodyString()),
      "card%5Bcvc%5D=123&card%5Bexp_month%5D=12&card%5Bexp_year%5D=2030"
        + "&card%5Bnumber%5D=4242424242424242&type=card")
  }

  func testCreatePaymentMethodTypeOnlySendsType() async throws {
    let service = makeService(mode: .management)
    WriteStub.install(status: 200, json: [
      "billing_details": NSDictionary(), "created": 1_700_000_000,
      "id": "pm_test_125", "livemode": false, "object": "payment_method",
      "type": "us_bank_account",
    ])
    _ = try await service.createPaymentMethod(
      type: "us_bank_account", cardNumber: nil, expMonth: nil, expYear: nil, cvc: nil,
      summary: "Create payment method")
    XCTAssertEqual(
      try XCTUnwrap(WriteStub.firstBodyString()), "type=us_bank_account")
  }

  func testDashboardModeRefusesCreatePaymentMethodBeforeNetwork() async throws {
    let service = makeService(mode: .dashboard)
    do {
      _ = try await service.createPaymentMethod(
        type: "card", cardNumber: nil, expMonth: nil, expYear: nil, cvc: nil,
        summary: "Create payment method")
      XCTFail("dashboard-mode write should throw")
    } catch let error as PaymentsWriteError {
      XCTAssertEqual(error, .dashboardMode)
    } catch {
      XCTFail("Expected PaymentsWriteError.dashboardMode, got \(error)")
    }
    XCTAssertTrue(
      WriteStubURLProtocol.recordedRequests.isEmpty,
      "a dashboard-mode payment method create reached the network")
    let entries = await audit.entries(limit: 10)
    XCTAssertEqual(entries.count, 1)
    XCTAssertEqual(entries[0].outcome, "refused: dashboard mode")
    XCTAssertEqual(entries[0].path, "/v1/payment_methods")
  }

  // MARK: - Update, attach, detach

  func testUpdatePaymentMethodEncodesBillingDetails() async throws {
    let service = makeService(mode: .management)
    WriteStub.install(status: 200, json: [
      "billing_details": ["email": "alice@example.com", "name": "Alice"],
      "created": 1_700_000_000, "id": "pm_test_123", "livemode": false,
      "object": "payment_method", "type": "card",
    ])
    let method = try await service.updatePaymentMethod(
      id: "pm_test_123", billingName: "Alice", billingEmail: "alice@example.com",
      summary: "Update billing details")
    XCTAssertEqual(method.billingDetails.name.valueOrNil, "Alice")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/payment_methods/pm_test_123"))
    XCTAssertEqual(
      try XCTUnwrap(WriteStub.firstBodyString()),
      "billing_details%5Bemail%5D=alice%40example.com&billing_details%5Bname%5D=Alice")
  }

  func testAttachPaymentMethodEncodesCustomer() async throws {
    let service = makeService(mode: .management)
    WriteStub.install(status: 200, json: [
      "billing_details": NSDictionary(), "created": 1_700_000_000,
      "customer": "cus_test_123", "id": "pm_test_123", "livemode": false,
      "object": "payment_method", "type": "card",
    ])
    let method = try await service.attachPaymentMethod(
      id: "pm_test_123", customer: "cus_test_123", summary: "Attach payment method")
    XCTAssertEqual(method.customer.valueOrNil?.idOrNil, "cus_test_123")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertTrue(
      request.url!.path.hasSuffix("/v1/payment_methods/pm_test_123/attach"))
    XCTAssertEqual(
      try XCTUnwrap(WriteStub.firstBodyString()), "customer=cus_test_123")
  }

  func testDetachPaymentMethodSendsEmptyBody() async throws {
    let service = makeService(mode: .management)
    WriteStub.install(status: 200, json: [
      "billing_details": NSDictionary(), "created": 1_700_000_000,
      "customer": NSNull(), "id": "pm_test_123", "livemode": false,
      "object": "payment_method", "type": "card",
    ])
    let method = try await service.detachPaymentMethod(
      id: "pm_test_123", summary: "Detach payment method")
    XCTAssertNil(method.customer.valueOrNil?.idOrNil)
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertTrue(
      request.url!.path.hasSuffix("/v1/payment_methods/pm_test_123/detach"))
    XCTAssertNil(
      WriteStub.firstBodyString(), "detach takes no parameters and sends an empty body")
  }
}
