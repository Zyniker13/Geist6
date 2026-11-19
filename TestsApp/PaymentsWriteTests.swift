// PaymentsWriteTests.swift — Tests/GeistDataTests
// Every write the service makes must: refuse in dashboard mode before any
// network traffic, carry an idempotency key, encode its parameters, and
// record the attempt in the audit log. Proven here against a stubbed
// transport; no real network is touched (base URL is unreachable port 1).

import XCTest

@testable import GeistData
@testable import StripeClient
import StripeModels

@MainActor
final class PaymentsWriteTests: XCTestCase {

  private var audit: InMemoryAuditStore!

  // Fixture rule for this file: inside a `[String: Any]` fixture literal,
  // write empty collections as `NSDictionary()` / `NSArray()` — never the
  // bare `{}` / `[]` literals. Boxing an empty Swift collection into
  // `Any` corrupts the heap on this toolchain ("freed pointer was not
  // the last allocation", abort surfaces later in whatever allocator
  // context runs next, e.g. inside JSONSerialization). Non-empty Swift
  // literals are fine. The stub also copies fixtures through a Cocoa
  // tree before serializing as a second layer of defense.

  override func setUp() async throws {
    WriteStubURLProtocol.reset()
    audit = InMemoryAuditStore()
  }

  /// One shared session for the whole class. A per-test session would be
  /// deallocated mid-run without `finishTasksAndInvalidate`, and orphaned
  /// CFNetwork sessions corrupt the heap and crash the test host.
  private static let stubSession: URLSession = {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [WriteStubURLProtocol.self]
    return URLSession(configuration: config)
  }()

  private func makeService(
    mode: StripeClient.Mode,
    locked: @escaping PaymentsWriteService.DashboardLockProvider = { false },
  ) -> PaymentsWriteService {
    let client = StripeClient(
      apiKey: "sk_test_fake", mode: mode,
      baseURL: URL(string: "http://127.0.0.1:1")!, session: Self.stubSession)
    return PaymentsWriteService(
      client: client, accountID: "acct_test_123", accountName: "Shot Store", audit: audit,
      dashboardLocked: locked)
  }

  /// Gate 2 must read the lock LIVE: a writer built while the account is
  /// unlocked must still refuse once the account is locked mid-session.
  func testMidSessionLockRefusesWrite() async throws {
    let lock = LockState()
    let service = makeService(mode: .management) { await lock.isLocked }
    WriteStub.install(status: 200, json: [
      "amount": 1500, "balance_transaction": NSNull(), "charge": "ch_test_123",
      "created": 1_700_000_000, "currency": "usd", "id": "re_test_128",
      "livemode": false, "object": "refund", "status": "succeeded",
    ])
    _ = try await service.createRefund(charge: "ch_test_123", amount: nil, reason: nil, summary: "s")
    XCTAssertEqual(WriteStubURLProtocol.recordedRequests.count, 1)

    await MainActor.run { lock.isLocked = true }
    do {
      _ = try await service.createRefund(charge: "ch_test_123", amount: nil, reason: nil, summary: "s")
      XCTFail("a write after a mid-session lock should throw")
    } catch let error as PaymentsWriteError {
      XCTAssertEqual(error, .dashboardMode)
    } catch {
      XCTFail("Expected PaymentsWriteError.dashboardMode, got \(error)")
    }
    XCTAssertEqual(WriteStubURLProtocol.recordedRequests.count, 1, "the refused write reached the network")
    let entries = await audit.entries(limit: 10)
    XCTAssertEqual(entries.count, 2)
    XCTAssertEqual(entries[0].outcome, "refused: dashboard mode", "newest first")
  }

  // MARK: - Dashboard mode: refuse before the network

  /// The floor gate: in dashboard mode the service refuses before any
  /// network traffic happens and records the refusal.
  func testDashboardModeRefusesRefundBeforeNetwork() async throws {
    let service = makeService(mode: .dashboard)
    do {
      _ = try await service.createRefund(
        charge: "ch_test_123", amount: 500, reason: "duplicate", summary: "Refund ch_test_123")
      XCTFail("dashboard-mode write should throw")
    } catch let error as PaymentsWriteError {
      XCTAssertEqual(error, .dashboardMode)
    } catch {
      XCTFail("Expected PaymentsWriteError.dashboardMode, got \(error)")
    }
    XCTAssertTrue(WriteStubURLProtocol.recordedRequests.isEmpty, "a dashboard-mode write reached the network")
    let entries = await audit.entries(limit: 10)
    XCTAssertEqual(entries.count, 1)
    XCTAssertEqual(entries[0].outcome, "refused: dashboard mode")
    XCTAssertEqual(entries[0].method, "POST")
    XCTAssertEqual(entries[0].path, "/v1/refunds")
  }

  // MARK: - Refund creation

  func testCreateFullRefundEncodesChargeOnly() async throws {
    let service = makeService(mode: .management)
    WriteStub.install(status: 200, json: [
      "amount": 1500, "balance_transaction": NSNull(), "charge": "ch_test_123",
      "created": 1_700_000_000, "currency": "usd", "id": "re_test_123",
      "livemode": false, "object": "refund", "status": "succeeded",
    ])
    let refund = try await service.createRefund(
      charge: "ch_test_123", amount: nil, reason: nil, summary: "Full refund")
    XCTAssertEqual(refund.id, "re_test_123")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/refunds"))
    let body = try XCTUnwrap(WriteStub.firstBodyString())
    XCTAssertEqual(body, "charge=ch_test_123")
  }

  func testCreatePartialRefundEncodesAmountAndReason() async throws {
    let service = makeService(mode: .management)
    WriteStub.install(status: 200, json: [
      "amount": 500, "balance_transaction": NSNull(), "charge": "ch_test_123",
      "created": 1_700_000_000, "currency": "usd", "id": "re_test_124",
      "livemode": false, "object": "refund", "reason": "duplicate", "status": "succeeded",
    ])
    let refund = try await service.createRefund(
      charge: "ch_test_123", amount: 500, reason: "duplicate", summary: "Partial refund")
    XCTAssertEqual(refund.reason.valueOrNil, .duplicate)
    let body = try XCTUnwrap(WriteStub.firstBodyString())
    XCTAssertEqual(body, "amount=500&charge=ch_test_123&reason=duplicate")
  }

  func testRefundRequestCarriesIdempotencyKeyInHeaderAndAudit() async throws {
    let service = makeService(mode: .management)
    WriteStub.install(status: 200, json: [
      "amount": 1500, "balance_transaction": NSNull(), "charge": "ch_test_123",
      "created": 1_700_000_000, "currency": "usd", "id": "re_test_123",
      "livemode": false, "object": "refund", "status": "succeeded",
    ], headers: ["Request-Id": "req_test_123"])
    _ = try await service.createRefund(
      charge: "ch_test_123", amount: nil, reason: nil, summary: "Full refund")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    let headerKey = try XCTUnwrap(request.value(forHTTPHeaderField: "Idempotency-Key"))
    XCTAssertFalse(headerKey.isEmpty)
    let entries = await audit.entries(limit: 10)
    XCTAssertEqual(entries.count, 1)
    XCTAssertEqual(entries[0].idempotencyKey, headerKey, "audit key must match the sent key")
    XCTAssertEqual(entries[0].requestID, "req_test_123")
    XCTAssertEqual(entries[0].outcome, "succeeded")
    XCTAssertEqual(entries[0].accountID, "acct_test_123")
    XCTAssertEqual(entries[0].accountName, "Shot Store")
    XCTAssertEqual(entries[0].summary, "Full refund")
  }

  func testRefundUpdateCancelExpirePaths() async throws {
    let service = makeService(mode: .management)
    let refundJSON: [String: Any] = [
      "amount": 500, "balance_transaction": NSNull(), "charge": "ch_test_123",
      "created": 1_700_000_000, "currency": "usd", "id": "re_test_125",
      "livemode": false, "object": "refund", "status": "pending",
    ]
    WriteStub.install(status: 200, json: refundJSON)
    _ = try await service.updateRefund(id: "re_test_125", metadata: ["note": "gift"], summary: "Update refund")
    var request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.last)
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/refunds/re_test_125"))
    XCTAssertEqual(try XCTUnwrap(WriteStub.firstBodyString()), "metadata%5Bnote%5D=gift")

    WriteStub.install(status: 200, json: refundJSON)
    _ = try await service.cancelRefund(id: "re_test_125", summary: "Cancel refund")
    request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.last)
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/refunds/re_test_125/cancel"))

    WriteStub.install(status: 200, json: refundJSON)
    _ = try await service.expireRefund(id: "re_test_125", summary: "Expire refund")
    request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.last)
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/refunds/re_test_125/expire"))
  }

  // MARK: - Charge capture and update

  func testCaptureChargeEncodesAmountAndReceiptEmail() async throws {
    let service = makeService(mode: .management)
    WriteStub.install(status: 200, json: [
      "amount": 1500, "amount_captured": 1500, "amount_refunded": 0, "billing_details": NSDictionary(),
      "captured": true, "created": 1_700_000_000, "currency": "usd", "disputed": false,
      "id": "ch_test_123", "livemode": false, "metadata": NSDictionary(), "object": "charge",
      "paid": true, "refunded": false, "status": "succeeded",
    ])
    let charge = try await service.captureCharge(
      id: "ch_test_123", amount: 1500, receiptEmail: "alice@example.com", summary: "Capture")
    XCTAssertEqual(charge.id, "ch_test_123")
    XCTAssertTrue(charge.captured)
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/charges/ch_test_123/capture"))
    let body = try XCTUnwrap(WriteStub.firstBodyString())
    XCTAssertEqual(body, "amount=1500&receipt_email=alice%40example.com")
  }

  func testUpdateChargeEncodesDescriptionAndReceiptEmail() async throws {
    let service = makeService(mode: .management)
    WriteStub.install(status: 200, json: [
      "amount": 1500, "amount_captured": 1500, "amount_refunded": 0, "billing_details": NSDictionary(),
      "captured": true, "created": 1_700_000_000, "currency": "usd", "description": "Desk lamp",
      "disputed": false, "id": "ch_test_123", "livemode": false, "metadata": NSDictionary(),
      "object": "charge", "paid": true, "refunded": false, "status": "succeeded",
    ])
    let charge = try await service.updateCharge(
      id: "ch_test_123", description: "Desk lamp", receiptEmail: "alice@example.com",
      summary: "Update charge")
    XCTAssertEqual(charge.description.valueOrNil, "Desk lamp")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/charges/ch_test_123"))
    let body = try XCTUnwrap(WriteStub.firstBodyString())
    // The encoder maps form-urlencoded canon: space is `+` (Stripe accepts
    // both `+` and `%20`; the canon mapping is pinned in FormEncoding).
    XCTAssertEqual(body, "description=Desk+lamp&receipt_email=alice%40example.com")
  }

  // MARK: - Payment intent lifecycle

  func testCapturePaymentIntentEncodesAmountToCapture() async throws {
    let service = makeService(mode: .management)
    WriteStub.install(status: 200, json: [
      "amount": 1500, "amount_capturable": 0, "amount_received": 1500,
      "capture_method": "automatic", "confirmation_method": "automatic",
      "created": 1_700_000_000, "currency": "usd", "id": "pi_test_123",
      "livemode": false, "metadata": NSDictionary(), "object": "payment_intent",
      "payment_method_types": ["card"], "status": "succeeded",
    ])
    let intent = try await service.capturePaymentIntent(
      id: "pi_test_123", amountToCapture: 1200, summary: "Capture intent")
    XCTAssertEqual(intent.id, "pi_test_123")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/payment_intents/pi_test_123/capture"))
    XCTAssertEqual(try XCTUnwrap(WriteStub.firstBodyString()), "amount_to_capture=1200")
  }

  func testCancelPaymentIntentEncodesReason() async throws {
    let service = makeService(mode: .management)
    WriteStub.install(status: 200, json: [
      "amount": 1500, "amount_capturable": 0, "amount_received": 0,
      "capture_method": "automatic", "confirmation_method": "automatic",
      "created": 1_700_000_000, "currency": "usd", "id": "pi_test_123",
      "livemode": false, "metadata": NSDictionary(), "object": "payment_intent",
      "payment_method_types": ["card"], "status": "canceled",
    ])
    let intent = try await service.cancelPaymentIntent(
      id: "pi_test_123", reason: "requested_by_customer", summary: "Cancel intent")
    XCTAssertEqual(intent.status, .canceled)
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/payment_intents/pi_test_123/cancel"))
    XCTAssertEqual(
      try XCTUnwrap(WriteStub.firstBodyString()), "cancellation_reason=requested_by_customer")
  }

  func testConfirmPaymentIntent() async throws {
    let service = makeService(mode: .management)
    WriteStub.install(status: 200, json: [
      "amount": 1500, "amount_capturable": 1500, "amount_received": 0,
      "capture_method": "automatic", "confirmation_method": "automatic",
      "created": 1_700_000_000, "currency": "usd", "id": "pi_test_123",
      "livemode": false, "metadata": NSDictionary(), "object": "payment_intent",
      "payment_method_types": ["card"], "status": "requires_capture",
    ])
    let intent = try await service.confirmPaymentIntent(id: "pi_test_123", summary: "Confirm intent")
    XCTAssertEqual(intent.status, .requiresCapture)
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/payment_intents/pi_test_123/confirm"))
    XCTAssertNil(WriteStub.firstBodyString(), "confirm with no params must send an empty body")
  }

  // MARK: - Failure recording

  func testAPIFailureIsRecordedInAuditAndRethrown() async throws {
    let service = makeService(mode: .management)
    WriteStub.install(status: 400, json: [
      "error": [
        "type": "invalid_request_error",
        "message": "Charge ch_test_123 has already been refunded.",
      ]
    ])
    do {
      _ = try await service.createRefund(
        charge: "ch_test_123", amount: nil, reason: nil, summary: "Full refund")
      XCTFail("a 400 write should throw")
    } catch let error as StripeAPIError {
      XCTAssertEqual(error.status, 400)
      XCTAssertEqual(error.detail.message, "Charge ch_test_123 has already been refunded.")
    } catch {
      XCTFail("Expected StripeAPIError, got \(error)")
    }
    let entries = await audit.entries(limit: 10)
    XCTAssertEqual(entries.count, 1)
    XCTAssertTrue(entries[0].outcome.hasPrefix("failed:"))
    XCTAssertTrue(
      entries[0].outcome.contains("has already been refunded"),
      "audit entry should carry the API message, got \(entries[0].outcome)")
  }

  // MARK: - Every write carries a key

  /// Every write verb the service exposes sends a non-empty idempotency
  /// key. Loops over all verbs against a single stub and checks each
  /// recorded request.
  func testEveryWriteVerbCarriesIdempotencyKey() async throws {
    let service = makeService(mode: .management)
    let refundJSON: [String: Any] = [
      "amount": 500, "balance_transaction": NSNull(), "charge": "ch_test_123",
      "created": 1_700_000_000, "currency": "usd", "id": "re_test_126",
      "livemode": false, "object": "refund", "status": "succeeded",
    ]
    let chargeJSON: [String: Any] = [
      "amount": 1500, "amount_captured": 1500, "amount_refunded": 0, "billing_details": NSDictionary(),
      "captured": true, "created": 1_700_000_000, "currency": "usd", "disputed": false,
      "id": "ch_test_123", "livemode": false, "metadata": NSDictionary(), "object": "charge",
      "paid": true, "refunded": false, "status": "succeeded",
    ]
    let intentJSON: [String: Any] = [
      "amount": 1500, "amount_capturable": 0, "amount_received": 0,
      "capture_method": "automatic", "confirmation_method": "automatic",
      "created": 1_700_000_000, "currency": "usd", "id": "pi_test_123",
      "livemode": false, "metadata": NSDictionary(), "object": "payment_intent",
      "payment_method_types": ["card"], "status": "succeeded",
    ]

    func keyOf(_ request: URLRequest) -> String? {
      request.value(forHTTPHeaderField: "Idempotency-Key")
    }

    WriteStub.install(status: 200, json: refundJSON)
    _ = try await service.createRefund(charge: "ch_test_123", amount: 500, reason: nil, summary: "s")
    WriteStub.install(status: 200, json: refundJSON)
    _ = try await service.updateRefund(id: "re_test_126", metadata: nil, summary: "s")
    WriteStub.install(status: 200, json: refundJSON)
    _ = try await service.cancelRefund(id: "re_test_126", summary: "s")
    WriteStub.install(status: 200, json: refundJSON)
    _ = try await service.expireRefund(id: "re_test_126", summary: "s")
    WriteStub.install(status: 200, json: chargeJSON)
    _ = try await service.captureCharge(id: "ch_test_123", amount: nil, receiptEmail: nil, summary: "s")
    WriteStub.install(status: 200, json: chargeJSON)
    _ = try await service.updateCharge(id: "ch_test_123", description: nil, receiptEmail: nil, summary: "s")
    WriteStub.install(status: 200, json: intentJSON)
    _ = try await service.capturePaymentIntent(id: "pi_test_123", amountToCapture: nil, summary: "s")
    WriteStub.install(status: 200, json: intentJSON)
    _ = try await service.cancelPaymentIntent(id: "pi_test_123", reason: nil, summary: "s")
    WriteStub.install(status: 200, json: intentJSON)
    _ = try await service.confirmPaymentIntent(id: "pi_test_123", summary: "s")

    let requests = WriteStubURLProtocol.recordedRequests
    XCTAssertEqual(requests.count, 9, "one request per verb")
    for (index, request) in requests.enumerated() {
      let key = try XCTUnwrap(keyOf(request), "request \(index) carries no idempotency key")
      XCTAssertFalse(key.isEmpty, "request \(index) carries an empty idempotency key")
    }
    let entries = await audit.entries(limit: 20)
    XCTAssertEqual(entries.count, 9)
    let auditedKeys = Set(entries.map(\.idempotencyKey))
    let sentKeys = Set(requests.compactMap(keyOf))
    XCTAssertEqual(auditedKeys, sentKeys, "audit keys must match the sent keys exactly")
  }

  // MARK: - Distinct keys per attempt

  func testSeparateAttemptsGetDistinctKeys() async throws {
    let service = makeService(mode: .management)
    WriteStub.install(status: 200, json: [
      "amount": 500, "balance_transaction": NSNull(), "charge": "ch_test_123",
      "created": 1_700_000_000, "currency": "usd", "id": "re_test_127",
      "livemode": false, "object": "refund", "status": "succeeded",
    ])
    _ = try await service.createRefund(charge: "ch_test_123", amount: nil, reason: nil, summary: "s")
    _ = try await service.createRefund(charge: "ch_test_123", amount: nil, reason: nil, summary: "s")
    let requests = WriteStubURLProtocol.recordedRequests
    XCTAssertEqual(requests.count, 2)
    let first = try XCTUnwrap(requests.first?.value(forHTTPHeaderField: "Idempotency-Key"))
    let second = try XCTUnwrap(requests.last?.value(forHTTPHeaderField: "Idempotency-Key"))
    XCTAssertNotEqual(first, second, "each user action must mint its own key")
  }
}

// MARK: - Lock provider state

/// A tiny mutable flag shared between the test and the lock provider.
@MainActor
final class LockState {
  var isLocked = false
}

// MARK: - Audit log stores

@MainActor
final class AuditStoreTests: XCTestCase {

  func testInMemoryStoreNewestFirstWithLimit() async {
    let store = InMemoryAuditStore()
    for index in 0..<5 {
      await store.record(
        AuditEntry(
          accountID: "acct_test_123", accountName: "Shot Store", summary: "write \(index)",
          method: "POST", path: "/v1/refunds", idempotencyKey: "key-\(index)", outcome: "succeeded"))
    }
    let entries = await store.entries(limit: 3)
    XCTAssertEqual(entries.map(\.summary), ["write 4", "write 3", "write 2"], "newest first")
    XCTAssertEqual(entries.map(\.idempotencyKey), ["key-4", "key-3", "key-2"])
  }

  func testFileStoreRoundTripAndLimit() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("geist6-audit-tests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = FileAuditStore(directory: directory)
    for index in 0..<5 {
      await store.record(
        AuditEntry(
          accountID: "acct_test_123", accountName: "Shot Store", summary: "write \(index)",
          method: "POST", path: "/v1/refunds", idempotencyKey: "key-\(index)",
          requestID: index == 4 ? "req_test_1" : nil,
          outcome: index == 3 ? "failed: HTTP 400" : "succeeded"))
    }
    let entries = await store.entries(limit: 2)
    XCTAssertEqual(entries.count, 2)
    XCTAssertEqual(entries[0].summary, "write 4", "newest first")
    XCTAssertEqual(entries[0].requestID, "req_test_1")
    XCTAssertEqual(entries[1].outcome, "failed: HTTP 400")
    // Reopening the store over the same directory reads the same file.
    let reopened = FileAuditStore(directory: directory)
    let all = await reopened.entries(limit: 10)
    XCTAssertEqual(all.count, 5)
  }
}
