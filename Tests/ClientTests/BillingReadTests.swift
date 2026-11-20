// BillingReadTests.swift — Tests/ClientTests
// Tests for the BillingBackend protocol conformance (BillingBackend on
// StripeClient): list and retrieve products, prices, coupons, and promotion
// codes through the protocol, against a stubbed transport.
//
// Includes the regression test for the retrieveProduct(id:) infinite
// recursion: the conformance method once called itself (the generated
// method shares its `id:` label), overflowing the stack.

import XCTest

@testable import StripeClient
@testable import GeistData
import StripeModels

// MARK: - Fixtures (from stripe-mock 0.206.0, obviously fake values)

nonisolated(unsafe) let productFixtureJSON = """
{
  "active": true,
  "created": 1234567890,
  "default_price": "price_123",
  "description": "cozy hoodie",
  "id": "prod_123",
  "images": [],
  "livemode": false,
  "marketing_features": [],
  "metadata": {
    "note": "gift"
  },
  "name": "Hoodie",
  "object": "product",
  "package_dimensions": {
    "height": 10,
    "length": 20,
    "weight": 30,
    "width": 40
  },
  "shippable": null,
  "statement_descriptor": null,
  "tax_code": null,
  "tax_details": {
    "performance_location": null,
    "tax_code": null
  },
  "type": "service",
  "unit_label": null,
  "updated": 1234567890,
  "url": null
}
"""

nonisolated(unsafe) let productFixture: [String: Any] = {
  guard let parsed = try? JSONSerialization.jsonObject(with: Data(productFixtureJSON.utf8)),
    let dict = parsed as? [String: Any] else {
    preconditionFailure("product fixture JSON must decode")
  }
  return dict
}()

nonisolated(unsafe) let priceFixtureJSON = """
{
  "active": true,
  "billing_scheme": "per_unit",
  "created": 1234567890,
  "currency": "usd",
  "custom_unit_amount": null,
  "id": "price_123",
  "livemode": false,
  "lookup_key": null,
  "metadata": {},
  "nickname": "Hoodie Monthly",
  "object": "price",
  "product": "prod_123",
  "recurring": {
    "interval": "month",
    "interval_count": 1,
    "meter": null,
    "usage_type": "licensed"
  },
  "tax_behavior": "unspecified",
  "tiers_mode": null,
  "transform_quantity": null,
  "type": "recurring",
  "unit_amount": 2000,
  "unit_amount_decimal": "2000"
}
"""

nonisolated(unsafe) let priceFixture: [String: Any] = {
  guard let parsed = try? JSONSerialization.jsonObject(with: Data(priceFixtureJSON.utf8)),
    let dict = parsed as? [String: Any] else {
    preconditionFailure("price fixture JSON must decode")
  }
  return dict
}()

nonisolated(unsafe) let couponFixtureJSON = """
{
  "id": "coupon_test_123",
  "object": "coupon",
  "amount_off": 1000,
  "applies_to": {"products": ["prod_123"]},
  "created": 1234567890,
  "currency": "usd",
  "duration": "once",
  "duration_in_months": null,
  "livemode": false,
  "max_redemptions": null,
  "metadata": {
    "note": "gift"
  },
  "name": "TEN-OFF",
  "percent_off": null,
  "redeem_by": null,
  "times_redeemed": 0,
  "valid": true
}
"""

nonisolated(unsafe) let couponFixture: [String: Any] = {
  guard let parsed = try? JSONSerialization.jsonObject(
    with: Data(couponFixtureJSON.utf8)),
    let dict = parsed as? [String: Any] else {
    preconditionFailure("coupon fixture JSON must decode")
  }
  return dict
}()

nonisolated(unsafe) let percentCouponFixture: [String: Any] = [
  "id": "coupon_test_456",
  "object": "coupon",
  "amount_off": NSNull(),
  "applies_to": NSNull(),
  "created": 1234567890,
  "currency": NSNull(),
  "duration": "forever",
  "duration_in_months": NSNull(),
  "livemode": false,
  "max_redemptions": 100,
  "metadata": NSDictionary(),
  "name": "HALF-OFF",
  "percent_off": 50,
  "redeem_by": 1798761600,
  "times_redeemed": 3,
  "valid": true,
]

nonisolated(unsafe) let promotionCodeFixtureJSON = """
{
  "id": "promo_test_123",
  "object": "promotion_code",
  "active": true,
  "code": "TEN-OFF",
  "created": 1234567890,
  "customer": null,
  "customer_account": null,
  "expires_at": null,
  "livemode": false,
  "max_redemptions": null,
  "metadata": {
    "note": "gift"
  },
  "promotion": {"coupon": "coupon_test_123", "type": "coupon"},
  "restrictions": {
    "first_time_transaction": false,
    "minimum_amount": null,
    "minimum_amount_currency": null
  },
  "times_redeemed": 0
}
"""

nonisolated(unsafe) let promotionCodeFixture: [String: Any] = {
  guard let parsed = try? JSONSerialization.jsonObject(
    with: Data(promotionCodeFixtureJSON.utf8)),
    let dict = parsed as? [String: Any] else {
    preconditionFailure("promotion code fixture JSON must decode")
  }
  return dict
}()

// MARK: - Test

@MainActor
final class BillingReadTests: XCTestCase {

  private func makeClient() -> StripeClient {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [RecordingURLProtocol.self]
    RecordingURLProtocol.recordedRequests = []
    RecordingURLProtocol.recordedResponses = []
    return StripeClient(
      apiKey: "sk_test_fake", mode: .management,
      baseURL: URL(string: "http://127.0.0.1:1")!, configuration: config)
  }

  // MARK: - Regression

  func testRetrieveProductConformanceReachesTheNetwork() async throws {
    StubBuilder.install(status: 200, json: productFixture)
    let backend: BillingBackend = makeClient()
    let product = try await backend.retrieveProduct(byID: "prod_123")
    XCTAssertEqual(product.id, "prod_123")
    let request = try XCTUnwrap(RecordingURLProtocol.recordedRequests.first)
    XCTAssertEqual(request.httpMethod, "GET")
    XCTAssertEqual(request.url!.path, "/v1/products/prod_123")
  }

  // MARK: - Coupons

  func testCouponsConformanceListsAndDecodes() async throws {
    let envelope: [String: Any] = [
      "object": "list",
      "url": "/v1/coupons",
      "has_more": false,
      "data": [couponFixture, percentCouponFixture],
    ]
    StubBuilder.install(status: 200, json: envelope)
    let backend: BillingBackend = makeClient()
    let coupons = try await backend.coupons()
    XCTAssertEqual(coupons.count, 2)
    XCTAssertEqual(coupons[0].id, "coupon_test_123")
    XCTAssertEqual(coupons[1].percentOff.valueOrNil, 50)
    let request = try XCTUnwrap(RecordingURLProtocol.recordedRequests.first)
    XCTAssertEqual(request.httpMethod, "GET")
    XCTAssertEqual(request.url!.path, "/v1/coupons")
  }

  func testRetrieveCouponConformanceReachesTheNetwork() async throws {
    StubBuilder.install(status: 200, json: couponFixture)
    let backend: BillingBackend = makeClient()
    let coupon = try await backend.retrieveCoupon(id: "coupon_test_123")
    XCTAssertEqual(coupon.id, "coupon_test_123")
    XCTAssertEqual(coupon.amountOff.valueOrNil, 1000)
    let request = try XCTUnwrap(RecordingURLProtocol.recordedRequests.first)
    XCTAssertEqual(request.httpMethod, "GET")
    XCTAssertEqual(request.url!.path, "/v1/coupons/coupon_test_123")
  }

  // MARK: - Promotion codes

  func testPromotionCodesConformanceListsAndDecodes() async throws {
    let envelope: [String: Any] = [
      "object": "list",
      "url": "/v1/promotion_codes",
      "has_more": false,
      "data": [promotionCodeFixture],
    ]
    StubBuilder.install(status: 200, json: envelope)
    let backend: BillingBackend = makeClient()
    let codes = try await backend.promotionCodes()
    XCTAssertEqual(codes.count, 1)
    XCTAssertEqual(codes[0].id, "promo_test_123")
    XCTAssertEqual(codes[0].code, "TEN-OFF")
    let request = try XCTUnwrap(RecordingURLProtocol.recordedRequests.first)
    XCTAssertEqual(request.httpMethod, "GET")
    XCTAssertEqual(request.url!.path, "/v1/promotion_codes")
  }

  func testRetrievePromotionCodeConformanceReachesTheNetwork() async throws {
    StubBuilder.install(status: 200, json: promotionCodeFixture)
    let backend: BillingBackend = makeClient()
    let code = try await backend.retrievePromotionCode(id: "promo_test_123")
    XCTAssertEqual(code.id, "promo_test_123")
    XCTAssertEqual(code.promotion.coupon.valueOrNil?.idOrNil, "coupon_test_123")
    let request = try XCTUnwrap(RecordingURLProtocol.recordedRequests.first)
    XCTAssertEqual(request.httpMethod, "GET")
    XCTAssertEqual(request.url!.path, "/v1/promotion_codes/promo_test_123")
  }
}
