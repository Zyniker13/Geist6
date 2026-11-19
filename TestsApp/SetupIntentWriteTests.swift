// SetupIntentWriteTests.swift — TestsApp
// The M4c-2 setup intent writes: refuse in dashboard mode before any network
// traffic, carry an idempotency key, encode their parameters, and record the
// attempt in the audit log. Stubbed transport; no real network is touched.
// (Split from PaymentsWriteTests to keep each class under SwiftLint's
// type-body-length limit.)

import XCTest

@testable import GeistData
@testable import StripeClient
import StripeModels

@MainActor
final class SetupIntentWriteTests: XCTestCase {

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

  // MARK: - Setup intent writes (M4c-2)

  func testCreateSetupIntentEncodesFields() async throws {
    let service = makeService(mode: .management)
    WriteStub.install(status: 200, json: [
      "created": 1_700_000_000, "customer": "cus_test_123", "description": "Desk lamp",
      "id": "seti_test_124", "livemode": false, "metadata": NSDictionary(),
      "object": "setup_intent", "payment_method_types": ["card"],
      "status": "requires_confirmation", "usage": "off_session",
    ])
    let intent = try await service.createSetupIntent(
      customer: "cus_test_123", description: "Desk lamp", usage: "off_session",
      summary: "Create setup intent")
    XCTAssertEqual(intent.id, "seti_test_124")
    XCTAssertEqual(intent.status, .requiresConfirmation)
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/setup_intents"))
    XCTAssertEqual(
      try XCTUnwrap(WriteStub.firstBodyString()),
      "customer=cus_test_123&description=Desk+lamp&usage=off_session")
  }

  func testCreateSetupIntentWithNoFieldsSendsEmptyBody() async throws {
    let service = makeService(mode: .management)
    WriteStub.install(status: 200, json: [
      "created": 1_700_000_000, "id": "seti_test_125", "livemode": false,
      "metadata": NSDictionary(), "object": "setup_intent",
      "payment_method_types": ["card"], "status": "requires_payment_method",
      "usage": "on_session",
    ])
    _ = try await service.createSetupIntent(
      customer: nil, description: nil, usage: nil, summary: "Create setup intent")
    XCTAssertNil(WriteStub.firstBodyString(), "no fields must send an empty body")
  }

  func testDashboardModeRefusesCreateSetupIntentBeforeNetwork() async throws {
    let service = makeService(mode: .dashboard)
    do {
      _ = try await service.createSetupIntent(
        customer: nil, description: nil, usage: nil, summary: "Create setup intent")
      XCTFail("dashboard-mode write should throw")
    } catch let error as PaymentsWriteError {
      XCTAssertEqual(error, .dashboardMode)
    } catch {
      XCTFail("Expected PaymentsWriteError.dashboardMode, got \(error)")
    }
    XCTAssertTrue(
      WriteStubURLProtocol.recordedRequests.isEmpty,
      "a dashboard-mode setup intent create reached the network")
    let entries = await audit.entries(limit: 10)
    XCTAssertEqual(entries.count, 1)
    XCTAssertEqual(entries[0].outcome, "refused: dashboard mode")
    XCTAssertEqual(entries[0].path, "/v1/setup_intents")
  }

  func testUpdateSetupIntentEncodesDescription() async throws {
    let service = makeService(mode: .management)
    WriteStub.install(status: 200, json: [
      "created": 1_700_000_000, "description": "Renewal card", "id": "seti_test_123",
      "livemode": false, "metadata": NSDictionary(), "object": "setup_intent",
      "payment_method_types": ["card"], "status": "requires_payment_method",
      "usage": "on_session",
    ])
    let intent = try await service.updateSetupIntent(
      id: "seti_test_123", description: "Renewal card", summary: "Update setup intent")
    XCTAssertEqual(intent.description.valueOrNil, "Renewal card")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/setup_intents/seti_test_123"))
    XCTAssertEqual(try XCTUnwrap(WriteStub.firstBodyString()), "description=Renewal+card")
  }

  func testCancelSetupIntentEncodesReason() async throws {
    let service = makeService(mode: .management)
    WriteStub.install(status: 200, json: [
      "cancellation_reason": "requested_by_customer", "created": 1_700_000_000,
      "id": "seti_test_123", "livemode": false, "metadata": NSDictionary(),
      "object": "setup_intent", "payment_method_types": ["card"],
      "status": "canceled", "usage": "on_session",
    ])
    let intent = try await service.cancelSetupIntent(
      id: "seti_test_123", reason: "requested_by_customer", summary: "Cancel setup intent")
    XCTAssertEqual(intent.status, .canceled)
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/setup_intents/seti_test_123/cancel"))
    XCTAssertEqual(
      try XCTUnwrap(WriteStub.firstBodyString()),
      "cancellation_reason=requested_by_customer")
  }

  func testConfirmSetupIntentEncodesOptionalPaymentMethod() async throws {
    let service = makeService(mode: .management)
    WriteStub.install(status: 200, json: [
      "created": 1_700_000_000, "id": "seti_test_123", "livemode": false,
      "metadata": NSDictionary(), "object": "setup_intent",
      "payment_method": "pm_test_123", "payment_method_types": ["card"],
      "status": "succeeded", "usage": "on_session",
    ])
    let intent = try await service.confirmSetupIntent(
      id: "seti_test_123", paymentMethod: "pm_test_123", summary: "Confirm setup intent")
    XCTAssertEqual(intent.status, .succeeded)
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/setup_intents/seti_test_123/confirm"))
    XCTAssertEqual(
      try XCTUnwrap(WriteStub.firstBodyString()), "payment_method=pm_test_123")
  }

  func testConfirmSetupIntentWithoutMethodSendsEmptyBody() async throws {
    let service = makeService(mode: .management)
    WriteStub.install(status: 200, json: [
      "created": 1_700_000_000, "id": "seti_test_123", "livemode": false,
      "metadata": NSDictionary(), "object": "setup_intent",
      "payment_method_types": ["card"], "status": "succeeded", "usage": "on_session",
    ])
    _ = try await service.confirmSetupIntent(
      id: "seti_test_123", paymentMethod: nil, summary: "Confirm setup intent")
    XCTAssertNil(
      WriteStub.firstBodyString(), "confirm without a method must send an empty body")
  }

  func testVerifyMicrodepositsSetupIntentEncodesIndexedAmounts() async throws {
    let service = makeService(mode: .management)
    WriteStub.install(status: 200, json: [
      "created": 1_700_000_000, "id": "seti_test_126", "livemode": false,
      "metadata": NSDictionary(), "object": "setup_intent",
      "payment_method_types": ["us_bank_account"], "status": "succeeded",
      "usage": "on_session",
    ])
    let intent = try await service.verifyMicrodepositsSetupIntent(
      id: "seti_test_126", amounts: [32, 45], descriptorCode: nil,
      summary: "Verify microdeposits")
    XCTAssertEqual(intent.id, "seti_test_126")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertTrue(
      request.url!.path.hasSuffix("/v1/setup_intents/seti_test_126/verify_microdeposits"))
    XCTAssertEqual(
      try XCTUnwrap(WriteStub.firstBodyString()), "amounts%5B0%5D=32&amounts%5B1%5D=45")
  }

  func testVerifyMicrodepositsSetupIntentEncodesDescriptorCode() async throws {
    let service = makeService(mode: .management)
    WriteStub.install(status: 200, json: [
      "created": 1_700_000_000, "id": "seti_test_126", "livemode": false,
      "metadata": NSDictionary(), "object": "setup_intent",
      "payment_method_types": ["us_bank_account"], "status": "succeeded",
      "usage": "on_session",
    ])
    _ = try await service.verifyMicrodepositsSetupIntent(
      id: "seti_test_126", amounts: nil, descriptorCode: "SMT85QTW6VE",
      summary: "Verify microdeposits")
    XCTAssertEqual(
      try XCTUnwrap(WriteStub.firstBodyString()), "descriptor_code=SMT85QTW6VE")
  }
}
