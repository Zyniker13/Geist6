// SubscriptionWriteTests.swift — TestsApp
// The M6 subscription writes: refuse in dashboard mode before any network
// traffic, carry an idempotency key, encode their parameters, decode the
// stripe-mock response shapes, and record the attempt in the audit log.
// Stubbed transport; no real network is touched.

import XCTest

@testable import GeistData
@testable import StripeClient
import StripeModels

@MainActor
final class SubscriptionWriteTests: XCTestCase {

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

  private func makeService(
    mode: StripeClient.Mode,
    dashboardLocked: @escaping @MainActor @Sendable () async -> Bool
  ) -> BillingWriteService {
    let client = StripeClient(
      apiKey: "sk_test_fake", mode: mode,
      baseURL: URL(string: "http://127.0.0.1:1")!, session: Self.stubSession)
    return BillingWriteService(
      client: client, accountID: "acct_test_123", accountName: "Shot Store", audit: audit,
      dashboardLocked: dashboardLocked)
  }

  // MARK: - Create and update

  func testCreateSubscriptionEncodesCustomerAndItems() async throws {
    let service = makeService(mode: .management, dashboardLocked: { false })
    WriteStub.install(status: 200, json: subscriptionWriteFixture)
    let sub = try await service.createSubscription(
      draft: .init(
        customer: "cus_123",
        items: [.init(
          price: "price_123", quantity: 2, currency: nil, product: nil,
          unitAmount: nil, interval: nil)],
        description: nil, metadata: ["note": "gift"], cancelAtPeriodEnd: nil,
        collectionMethod: nil, daysUntilDue: nil, trialPeriodDays: nil,
        prorationBehavior: nil),
      summary: "Create subscription")
    XCTAssertEqual(sub.id, "sub_123")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/subscriptions"))
    XCTAssertEqual(
      try XCTUnwrap(WriteStub.firstBodyString()),
      "customer=cus_123&items%5B0%5D%5Bprice%5D=price_123&items%5B0%5D%5Bquantity%5D=2&metadata%5Bnote%5D=gift")
  }

  func testUpdateSubscriptionEncodesOnlySetFields() async throws {
    let service = makeService(mode: .management, dashboardLocked: { false })
    WriteStub.install(status: 200, json: subscriptionWriteFixture)
    let sub = try await service.updateSubscription(
      id: "sub_123",
      update: .init(
        description: nil, metadata: ["note": "gift"], cancelAtPeriodEnd: true,
        collectionMethod: nil, daysUntilDue: nil, pauseCollection: nil,
        prorationBehavior: nil, prorationDate: nil, cancellationDetails: nil),
      summary: "Update subscription")
    XCTAssertEqual(sub.id, "sub_123")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/subscriptions/sub_123"))
    XCTAssertEqual(
      try XCTUnwrap(WriteStub.firstBodyString()),
      "cancel_at_period_end=true&metadata%5Bnote%5D=gift")
  }

  // MARK: - Pause and resume

  func testPauseSubscriptionSendsEmptyBody() async throws {
    let service = makeService(mode: .management, dashboardLocked: { false })
    WriteStub.install(status: 200, json: subscriptionWriteFixture)
    _ = try await service.pauseSubscription(
      id: "sub_123",
      pause: .init(
        billForOutstandingUsageThrough: nil, invoicingBehavior: nil, type: nil),
      summary: "Pause subscription")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/subscriptions/sub_123/pause"))
    XCTAssertNil(
      WriteStub.firstBodyString(), "pause takes no parameters and sends an empty body")
  }

  func testResumeSubscriptionSendsEmptyBody() async throws {
    let service = makeService(mode: .management, dashboardLocked: { false })
    WriteStub.install(status: 200, json: subscriptionWriteFixture)
    _ = try await service.resumeSubscription(
      id: "sub_123",
      resume: .init(
        billingCycleAnchor: nil, paymentBehavior: nil, prorationBehavior: nil,
        prorationDate: nil),
      summary: "Resume subscription")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/subscriptions/sub_123/resume"))
    XCTAssertNil(
      WriteStub.firstBodyString(), "resume takes no parameters and sends an empty body")
  }

  // MARK: - Migrate

  func testMigrateSubscriptionEncodesBillingMode() async throws {
    let service = makeService(mode: .management, dashboardLocked: { false })
    WriteStub.install(status: 200, json: subscriptionWriteFixture)
    _ = try await service.migrateSubscription(
      id: "sub_123",
      migrate: .init(type: .flexible, prorationDiscounts: .itemized),
      summary: "Migrate subscription")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/subscriptions/sub_123/migrate"))
    XCTAssertEqual(
      try XCTUnwrap(WriteStub.firstBodyString()),
      "billing_mode%5Bflexible%5D%5Bproration_discounts%5D=itemized&billing_mode%5Btype%5D=flexible")
  }

  // MARK: - Cancel

  func testCancelSubscriptionDecodesCanceledObject() async throws {
    let service = makeService(mode: .management, dashboardLocked: { false })
    WriteStub.install(status: 200, json: subscriptionCanceledFixture)
    let sub = try await service.cancelSubscription(
      id: "sub_123",
      cancel: .init(cancellationDetails: nil, invoiceNow: nil, prorate: nil),
      summary: "Cancel subscription")
    XCTAssertEqual(sub.status.rawValue, "canceled")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertEqual(request.httpMethod, "DELETE")
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/subscriptions/sub_123"))
    XCTAssertNil(
      WriteStub.firstBodyString(), "cancel takes no parameters and sends an empty body")
  }

  // MARK: - Items

  func testAddSubscriptionItemEncodesPriceAndQuantity() async throws {
    let service = makeService(mode: .management, dashboardLocked: { false })
    WriteStub.install(status: 200, json: subscriptionItemFixture)
    let item = try await service.addSubscriptionItem(
      id: "sub_123",
      item: .init(
        price: "price_123", quantity: 2, currency: nil, product: nil,
        unitAmount: nil, interval: nil),
      summary: "Add item")
    XCTAssertEqual(item.id, "si_123")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/subscription_items"))
    XCTAssertEqual(
      try XCTUnwrap(WriteStub.firstBodyString()),
      "price=price_123&proration_behavior=always_invoice&quantity=2&subscription=sub_123")
  }

  // MARK: - Discount

  func testDeleteSubscriptionDiscountDecodesDeletedObject() async throws {
    let service = makeService(mode: .management, dashboardLocked: { false })
    WriteStub.install(status: 200, json: deletedDiscountFixture)
    let deleted = try await service.deleteDiscountSubscription(
      id: "sub_123", summary: "Remove discount")
    XCTAssertTrue(deleted.deleted)
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertEqual(request.httpMethod, "DELETE")
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/subscriptions/sub_123/discount"))
    XCTAssertNil(
      WriteStub.firstBodyString(), "delete takes no parameters and sends an empty body")
  }

  // MARK: - Dashboard lock

  func testDashboardModeRefusesCreateSubscriptionBeforeNetwork() async throws {
    let service = makeService(mode: .dashboard, dashboardLocked: { false })
    do {
      _ = try await service.createSubscription(
        draft: .init(
          customer: "cus_123",
          items: [.init(
            price: "price_123", quantity: 1, currency: nil, product: nil,
            unitAmount: nil, interval: nil)],
          description: nil, metadata: nil, cancelAtPeriodEnd: nil,
          collectionMethod: nil, daysUntilDue: nil, trialPeriodDays: nil,
          prorationBehavior: nil),
        summary: "Create subscription")
      XCTFail("dashboard-mode write should throw")
    } catch let error as BillingWriteError {
      XCTAssertEqual(error, .dashboardMode)
    } catch {
      XCTFail("Expected BillingWriteError.dashboardMode, got \(error)")
    }
    XCTAssertTrue(
      WriteStubURLProtocol.recordedRequests.isEmpty,
      "a dashboard-mode subscription create reached the network")
    let entries = await audit.entries(limit: 10)
    XCTAssertEqual(entries.count, 1)
    XCTAssertEqual(entries[0].outcome, "refused: dashboard mode")
    XCTAssertEqual(entries[0].path, "/v1/subscriptions")
  }

  func testDashboardModeRefusesCancelSubscriptionBeforeNetwork() async throws {
    let service = makeService(mode: .dashboard, dashboardLocked: { false })
    do {
      _ = try await service.cancelSubscription(
        id: "sub_123",
        cancel: .init(cancellationDetails: nil, invoiceNow: nil, prorate: nil),
        summary: "Cancel subscription")
      XCTFail("dashboard-mode write should throw")
    } catch let error as BillingWriteError {
      XCTAssertEqual(error, .dashboardMode)
    } catch {
      XCTFail("Expected BillingWriteError.dashboardMode, got \(error)")
    }
    XCTAssertTrue(
      WriteStubURLProtocol.recordedRequests.isEmpty,
      "a dashboard-mode subscription cancel reached the network")
    let entries = await audit.entries(limit: 10)
    XCTAssertEqual(entries.count, 1)
    XCTAssertEqual(entries[0].outcome, "refused: dashboard mode")
    XCTAssertEqual(entries[0].method, "DELETE")
    XCTAssertEqual(entries[0].path, "/v1/subscriptions/sub_123")
  }

  // MARK: - Failure recording

  func testAPIFailureIsRecordedInAuditAndRethrown() async throws {
    let service = makeService(mode: .management, dashboardLocked: { false })
    WriteStub.install(status: 400, json: [
      "error": [
        "type": "invalid_request_error",
        "message": "Subscription sub_123 has no pending invoice.",
      ]
    ])
    do {
      _ = try await service.createSubscription(
        draft: .init(
          customer: "cus_123",
          items: [.init(
            price: "price_123", quantity: 1, currency: nil, product: nil,
            unitAmount: nil, interval: nil)],
          description: nil, metadata: nil, cancelAtPeriodEnd: nil,
          collectionMethod: nil, daysUntilDue: nil, trialPeriodDays: nil,
          prorationBehavior: nil),
        summary: "Create subscription")
      XCTFail("a 400 write should throw")
    } catch let error as StripeAPIError {
      XCTAssertEqual(error.status, 400)
      XCTAssertEqual(error.detail.message, "Subscription sub_123 has no pending invoice.")
    } catch {
      XCTFail("Expected StripeAPIError, got \(error)")
    }
    let entries = await audit.entries(limit: 10)
    XCTAssertEqual(entries.count, 1)
    XCTAssertTrue(entries[0].outcome.hasPrefix("failed:"))
    XCTAssertTrue(
      entries[0].outcome.contains("has no pending invoice"),
      "audit entry should carry the API message, got \(entries[0].outcome)")
  }

  // MARK: - Every write carries a key

  /// Every write verb the service exposes sends a non-empty idempotency
  /// key. Loops over all verbs against per-verb fixtures and checks each
  /// recorded request.
  func testEveryWriteVerbCarriesIdempotencyKey() async throws {
    let service = makeService(mode: .management, dashboardLocked: { false })

    func keyOf(_ request: URLRequest) -> String? {
      request.value(forHTTPHeaderField: "Idempotency-Key")
    }

    WriteStub.install(status: 200, json: subscriptionWriteFixture)
    _ = try await service.createSubscription(
      draft: .init(
        customer: "cus_123",
        items: [.init(
          price: "price_123", quantity: 1, currency: nil, product: nil,
          unitAmount: nil, interval: nil)],
        description: nil, metadata: nil, cancelAtPeriodEnd: nil,
        collectionMethod: nil, daysUntilDue: nil, trialPeriodDays: nil,
        prorationBehavior: nil),
      summary: "s")
    WriteStub.install(status: 200, json: subscriptionWriteFixture)
    _ = try await service.updateSubscription(
      id: "sub_123",
      update: .init(
        description: nil, metadata: nil, cancelAtPeriodEnd: true,
        collectionMethod: nil, daysUntilDue: nil, pauseCollection: nil,
        prorationBehavior: nil, prorationDate: nil, cancellationDetails: nil),
      summary: "s")
    WriteStub.install(status: 200, json: subscriptionWriteFixture)
    _ = try await service.pauseSubscription(
      id: "sub_123",
      pause: .init(
        billForOutstandingUsageThrough: nil, invoicingBehavior: nil, type: nil),
      summary: "s")
    WriteStub.install(status: 200, json: subscriptionWriteFixture)
    _ = try await service.resumeSubscription(
      id: "sub_123",
      resume: .init(
        billingCycleAnchor: nil, paymentBehavior: nil, prorationBehavior: nil,
        prorationDate: nil),
      summary: "s")
    WriteStub.install(status: 200, json: subscriptionWriteFixture)
    _ = try await service.migrateSubscription(
      id: "sub_123",
      migrate: .init(type: .flexible, prorationDiscounts: .itemized),
      summary: "s")
    WriteStub.install(status: 200, json: subscriptionCanceledFixture)
    _ = try await service.cancelSubscription(
      id: "sub_123",
      cancel: .init(cancellationDetails: nil, invoiceNow: nil, prorate: nil),
      summary: "s")
    WriteStub.install(status: 200, json: subscriptionItemFixture)
    _ = try await service.addSubscriptionItem(
      id: "sub_123",
      item: .init(
        price: "price_123", quantity: 1, currency: nil, product: nil,
        unitAmount: nil, interval: nil),
      summary: "s")
    WriteStub.install(status: 200, json: deletedDiscountFixture)
    _ = try await service.deleteDiscountSubscription(id: "sub_123", summary: "s")

    let requests = WriteStubURLProtocol.recordedRequests
    XCTAssertEqual(requests.count, 8, "one request per verb")
    for (index, request) in requests.enumerated() {
      let key = try XCTUnwrap(keyOf(request), "request \(index) carries no idempotency key")
      XCTAssertFalse(key.isEmpty, "request \(index) carries an empty idempotency key")
    }
    let entries = await audit.entries(limit: 16)
    XCTAssertEqual(entries.count, 8)
    let auditedKeys = Set(entries.map(\.idempotencyKey))
    let sentKeys = Set(requests.compactMap(keyOf))
    XCTAssertEqual(auditedKeys, sentKeys, "audit keys must match the sent keys exactly")
  }

  // MARK: - Audit linkage

  func testAuditEntryCarriesAccountAndSummary() async throws {
    let service = makeService(mode: .management, dashboardLocked: { false })
    WriteStub.install(
      status: 200, json: subscriptionWriteFixture, headers: ["Request-Id": "req_test_123"])
    _ = try await service.createSubscription(
      draft: .init(
        customer: "cus_123",
        items: [.init(
          price: "price_123", quantity: 1, currency: nil, product: nil,
          unitAmount: nil, interval: nil)],
        description: nil, metadata: nil, cancelAtPeriodEnd: nil,
        collectionMethod: nil, daysUntilDue: nil, trialPeriodDays: nil,
        prorationBehavior: nil),
      summary: "Create subscription")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    let headerKey = try XCTUnwrap(request.value(forHTTPHeaderField: "Idempotency-Key"))
    let entries = await audit.entries(limit: 10)
    XCTAssertEqual(entries[0].idempotencyKey, headerKey, "audit key must match the sent key")
    XCTAssertEqual(entries[0].requestID, "req_test_123")
    XCTAssertEqual(entries[0].outcome, "succeeded")
    XCTAssertEqual(entries[0].accountID, "acct_test_123")
    XCTAssertEqual(entries[0].accountName, "Shot Store")
    XCTAssertEqual(entries[0].summary, "Create subscription")
  }
}
