// BillingWriteTests.swift — TestsApp
// The M6 billing writes (products and prices): refuse in dashboard mode
// before any network traffic, carry an idempotency key, encode their
// parameters, decode the stripe-mock response shapes, and record the
// attempt in the audit log. Stubbed transport; no real network is touched.

import XCTest

@testable import GeistData
@testable import StripeClient
import StripeModels

@MainActor
final class BillingWriteTests: XCTestCase {

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

  // MARK: - Products

  func testCreateProductEncodesNameAndMetadata() async throws {
    let service = makeService(mode: .management, dashboardLocked: { false })
    WriteStub.install(status: 200, json: productWriteFixture)
    let product = try await service.createProduct(
      name: "Hoodie", description: "cozy", active: nil, metadata: ["note": "gift"],
      summary: "Create product")
    XCTAssertEqual(product.id, "prod_123")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/products"))
    XCTAssertEqual(
      try XCTUnwrap(WriteStub.firstBodyString()),
      "description=cozy&metadata%5Bnote%5D=gift&name=Hoodie")
  }

  func testUpdateProductEncodesOnlySetFields() async throws {
    let service = makeService(mode: .management, dashboardLocked: { false })
    WriteStub.install(status: 200, json: productWriteFixture)
    let product = try await service.updateProduct(
      id: "prod_123",
      update: .init(name: "Hoodie-XL", description: nil, active: nil, metadata: ["note": "gift"]),
      summary: "Update product")
    XCTAssertEqual(product.id, "prod_123")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/products/prod_123"))
    XCTAssertEqual(
      try XCTUnwrap(WriteStub.firstBodyString()),
      "metadata%5Bnote%5D=gift&name=Hoodie-XL")
  }

  func testDeleteProductSendsEmptyBodyAndDecodesDeletedObject() async throws {
    let service = makeService(mode: .management, dashboardLocked: { false })
    WriteStub.install(status: 200, json: productDeleteFixture)
    let deleted = try await service.deleteProduct(id: "prod_123", summary: "Delete product")
    XCTAssertEqual(deleted.id, "prod_123")
    XCTAssertTrue(deleted.deleted)
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertEqual(request.httpMethod, "DELETE")
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/products/prod_123"))
    XCTAssertNil(
      WriteStub.firstBodyString(),
      "delete takes no parameters")
  }

  // MARK: - Prices

  func testCreatePriceEncodesRecurringIntervalAndAmount() async throws {
    let service = makeService(mode: .management, dashboardLocked: { false })
    WriteStub.install(status: 200, json: priceWriteFixture)
    let price = try await service.createPrice(
      draft: .init(
        product: "prod_123", currency: "usd", unitAmount: 2000, nickname: "Hoodie Monthly",
        recurringInterval: "month", recurringIntervalCount: 1, active: nil,
        metadata: ["note": "gift"]),
      summary: "Create price")
    XCTAssertEqual(price.id, "price_123")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/prices"))
    XCTAssertEqual(
      try XCTUnwrap(WriteStub.firstBodyString()),
      "currency=usd&metadata%5Bnote%5D=gift&nickname=Hoodie+Monthly&product=prod_123"
        + "&recurring%5Binterval%5D=month&recurring%5Binterval_count%5D=1"
        + "&unit_amount=2000")
  }

  func testCreatePriceOneTimeOmitsRecurring() async throws {
    let service = makeService(mode: .management, dashboardLocked: { false })
    WriteStub.install(status: 200, json: oneTimePriceWriteFixture)
    let price = try await service.createPrice(
      draft: .init(
        product: "prod_123", currency: "usd", unitAmount: 500, nickname: nil,
        recurringInterval: nil, recurringIntervalCount: nil, active: nil,
        metadata: ["note": "gift"]),
      summary: "Create one-time price")
    XCTAssertEqual(price.id, "price_456")
    XCTAssertEqual(
      try XCTUnwrap(WriteStub.firstBodyString()),
      "currency=usd&metadata%5Bnote%5D=gift&product=prod_123&unit_amount=500")
  }

  func testCreatePricePassesIntervalStringThroughLosslessEnum() async throws {
    let service = makeService(mode: .management, dashboardLocked: { false })
    WriteStub.install(status: 200, json: priceWriteFixture)
    // Stripe interval names ride in a lossless enum; the raw value is
    // encoded as-is and the server validates it.
    _ = try await service.createPrice(
      draft: .init(
        product: "prod_123", currency: "usd", unitAmount: 2000, nickname: nil,
        recurringInterval: "month", recurringIntervalCount: nil, active: nil, metadata: nil),
      summary: "s")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertEqual(
      try XCTUnwrap(WriteStub.firstBodyString()),
      "currency=usd&product=prod_123&recurring%5Binterval%5D=month&unit_amount=2000")
  }

  func testUpdatePriceEncodesOnlySetFields() async throws {
    let service = makeService(mode: .management, dashboardLocked: { false })
    WriteStub.install(status: 200, json: priceWriteFixture)
    let price = try await service.updatePrice(
      id: "price_123", nickname: "Hoodie-Monthly", active: true,
      metadata: ["note": "gift"], summary: "Update price")
    XCTAssertEqual(price.id, "price_123")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/prices/price_123"))
    XCTAssertEqual(
      try XCTUnwrap(WriteStub.firstBodyString()),
      "active=true&metadata%5Bnote%5D=gift&nickname=Hoodie-Monthly")
  }

  // MARK: - Coupons

  func testCreateCouponEncodesPercentOffAndMetadata() async throws {
    let service = makeService(mode: .management, dashboardLocked: { false })
    WriteStub.install(status: 200, json: couponWriteFixture)
    let coupon = try await service.createCoupon(
      draft: .init(
        name: "TEN-OFF", percentOff: 50, amountOff: nil, currency: nil,
        duration: "once", durationInMonths: nil, redeemBy: nil,
        maxRedemptions: nil, metadata: ["note": "gift"]),
      summary: "Create coupon")
    XCTAssertEqual(coupon.id, "coupon_test_123")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/coupons"))
    XCTAssertEqual(
      try XCTUnwrap(WriteStub.firstBodyString()),
      "duration=once&metadata%5Bnote%5D=gift&name=TEN-OFF&percent_off=50")
  }

  func testCreateCouponEncodesAmountOffWithCurrency() async throws {
    let service = makeService(mode: .management, dashboardLocked: { false })
    WriteStub.install(status: 200, json: couponWriteFixture)
    let coupon = try await service.createCoupon(
      draft: .init(
        name: "TEN-OFF", percentOff: nil, amountOff: 1000, currency: "usd",
        duration: "once", durationInMonths: nil, redeemBy: nil,
        maxRedemptions: nil, metadata: nil),
      summary: "Create coupon")
    XCTAssertEqual(coupon.id, "coupon_test_123")
    XCTAssertEqual(
      try XCTUnwrap(WriteStub.firstBodyString()),
      "amount_off=1000&currency=usd&duration=once&name=TEN-OFF")
  }

  func testUpdateCouponEncodesOnlySetFields() async throws {
    let service = makeService(mode: .management, dashboardLocked: { false })
    WriteStub.install(status: 200, json: couponWriteFixture)
    let coupon = try await service.updateCoupon(
      id: "coupon_test_123",
      update: .init(name: "TEN-OFF-2", metadata: ["note": "gift"]),
      summary: "Update coupon")
    XCTAssertEqual(coupon.id, "coupon_test_123")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/coupons/coupon_test_123"))
    XCTAssertEqual(
      try XCTUnwrap(WriteStub.firstBodyString()),
      "metadata%5Bnote%5D=gift&name=TEN-OFF-2")
  }

  func testDeleteCouponSendsEmptyBodyAndDecodesDeletedObject() async throws {
    let service = makeService(mode: .management, dashboardLocked: { false })
    WriteStub.install(status: 200, json: couponDeleteFixture)
    let deleted = try await service.deleteCoupon(id: "coupon_test_123", summary: "Delete coupon")
    XCTAssertEqual(deleted.id, "coupon_test_123")
    XCTAssertTrue(deleted.deleted)
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertEqual(request.httpMethod, "DELETE")
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/coupons/coupon_test_123"))
    XCTAssertNil(WriteStub.firstBodyString(), "delete takes no parameters")
  }

  // MARK: - Promotion codes

  func testCreatePromotionCodeEncodesCouponReferenceAndLimits() async throws {
    let service = makeService(mode: .management, dashboardLocked: { false })
    WriteStub.install(status: 200, json: promotionCodeWriteFixture)
    let code = try await service.createPromotionCode(
      draft: .init(
        coupon: "coupon_test_123", code: "TEN-OFF", active: true, expiresAt: nil,
        maxRedemptions: 100, customer: nil, metadata: ["note": "gift"]),
      summary: "Create promotion code")
    XCTAssertEqual(code.id, "promo_test_123")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/promotion_codes"))
    XCTAssertEqual(
      try XCTUnwrap(WriteStub.firstBodyString()),
      "active=true&code=TEN-OFF&max_redemptions=100&metadata%5Bnote%5D=gift"
        + "&promotion%5Bcoupon%5D=coupon_test_123&promotion%5Btype%5D=coupon")
  }

  func testUpdatePromotionCodeEncodesOnlySetFields() async throws {
    let service = makeService(mode: .management, dashboardLocked: { false })
    WriteStub.install(status: 200, json: promotionCodeWriteFixture)
    let code = try await service.updatePromotionCode(
      id: "promo_test_123", active: false, metadata: ["note": "gift"],
      summary: "Update promotion code")
    XCTAssertEqual(code.id, "promo_test_123")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertTrue(request.url!.path.hasSuffix("/v1/promotion_codes/promo_test_123"))
    XCTAssertEqual(
      try XCTUnwrap(WriteStub.firstBodyString()),
      "active=false&metadata%5Bnote%5D=gift")
  }

  // MARK: - Dashboard mode gates

  func testDashboardModeRefusesCreateProduct() async throws {
    let service = makeService(mode: .dashboard, dashboardLocked: { false })
    do {
      _ = try await service.createProduct(
        name: "Hoodie", description: nil, active: nil, metadata: nil, summary: "s")
      XCTFail("createProduct must refuse in dashboard mode")
    } catch let error as BillingWriteError {
      XCTAssertEqual(error, .dashboardMode)
    }
    XCTAssertTrue(WriteStubURLProtocol.recordedRequests.isEmpty, "no network in dashboard mode")
    let entries = await audit.entries(limit: 10)
    XCTAssertEqual(entries.count, 1)
    XCTAssertEqual(entries[0].outcome, "refused: dashboard mode")
    XCTAssertTrue(entries[0].path.hasSuffix("/v1/products"))
  }

  func testDashboardLockedAccountRefusesUpdatePrice() async throws {
    let service = makeService(mode: .management, dashboardLocked: { true })
    do {
      _ = try await service.updatePrice(
        id: "price_123", nickname: nil, active: nil, metadata: nil, summary: "s")
      XCTFail("updatePrice must refuse when the account is locked")
    } catch let error as BillingWriteError {
      XCTAssertEqual(error, .dashboardMode)
    }
    XCTAssertTrue(WriteStubURLProtocol.recordedRequests.isEmpty, "no network when locked")
    let entries = await audit.entries(limit: 10)
    XCTAssertEqual(entries.count, 1)
    XCTAssertTrue(entries[0].path.hasSuffix("/v1/prices/price_123"))
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

    WriteStub.install(status: 200, json: productWriteFixture)
    _ = try await service.createProduct(
      name: "Hoodie", description: nil, active: nil, metadata: nil, summary: "s")
    WriteStub.install(status: 200, json: productWriteFixture)
    _ = try await service.updateProduct(
      id: "prod_123",
      update: .init(name: "Hoodie-XL", description: nil, active: nil, metadata: nil),
      summary: "s")
    WriteStub.install(status: 200, json: productDeleteFixture)
    _ = try await service.deleteProduct(id: "prod_123", summary: "s")
    WriteStub.install(status: 200, json: priceWriteFixture)
    _ = try await service.createPrice(
      draft: .init(
        product: "prod_123", currency: "usd", unitAmount: 2000, nickname: nil,
        recurringInterval: "month", recurringIntervalCount: nil, active: nil, metadata: nil),
      summary: "s")
    WriteStub.install(status: 200, json: priceWriteFixture)
    _ = try await service.updatePrice(
      id: "price_123", nickname: nil, active: nil, metadata: nil, summary: "s")

    let requests = WriteStubURLProtocol.recordedRequests
    XCTAssertEqual(requests.count, 5, "one request per verb")
    for (index, request) in requests.enumerated() {
      let key = try XCTUnwrap(keyOf(request), "request \(index) carries no idempotency key")
      XCTAssertFalse(key.isEmpty, "request \(index) carries an empty idempotency key")
    }
    let entries = await audit.entries(limit: 8)
    XCTAssertEqual(entries.count, 5)
    let auditedKeys = Set(entries.map(\.idempotencyKey))
    let sentKeys = Set(requests.compactMap(keyOf))
    XCTAssertEqual(auditedKeys, sentKeys, "audit keys must match the sent keys exactly")
  }

  // MARK: - Audit linkage

  func testAuditEntryCarriesAccountAndSummary() async throws {
    let service = makeService(mode: .management, dashboardLocked: { false })
    WriteStub.install(
      status: 200, json: productWriteFixture, headers: ["Request-Id": "req_test_123"])
    _ = try await service.createProduct(
      name: "Hoodie", description: nil, active: nil, metadata: nil, summary: "Create product")
    let request = try XCTUnwrap(WriteStubURLProtocol.recordedRequests.first)
    let headerKey = try XCTUnwrap(request.value(forHTTPHeaderField: "Idempotency-Key"))
    let entries = await audit.entries(limit: 10)
    XCTAssertEqual(entries[0].idempotencyKey, headerKey, "audit key must match the sent key")
    XCTAssertEqual(entries[0].requestID, "req_test_123")
    XCTAssertEqual(entries[0].outcome, "succeeded")
    XCTAssertEqual(entries[0].accountID, "acct_test_123")
    XCTAssertEqual(entries[0].accountName, "Shot Store")
    XCTAssertEqual(entries[0].summary, "Create product")
  }
}
