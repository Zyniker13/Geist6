import Foundation
import GeistData
import StripeModels
import Testing

@testable import Geist6

private enum StubError: Error { case missing }

/// Records the parameters `BillingModel` passes, so tests can prove the
/// search query actually reaches the Stripe Search call.
private final class SearchRecorder: @unchecked Sendable {
  var searchedQuery: String?
}

/// A billing backend that returns fixtures and records the search query.
private struct SearchRecordingBackend: BillingBackend {
  let recorder: SearchRecorder
  var products: [Product] = []
  var coupons: [Coupon] = []
  var promotionCodes: [PromotionCode] = []

  func products() async throws -> [Product] { products }
  func searchProducts(query: String) async throws -> [Product] {
    recorder.searchedQuery = query
    return products
  }
  func retrieveProduct(byID: String) async throws -> Product { throw StubError.missing }
  func prices(product: String?) async throws -> [Price] { [] }
  func searchPrices(query: String) async throws -> [Price] { [] }
  func retrievePrice(id: String) async throws -> Price { throw StubError.missing }
  func coupons() async throws -> [Coupon] { coupons }
  func retrieveCoupon(id: String) async throws -> Coupon { throw StubError.missing }
  func promotionCodes() async throws -> [PromotionCode] { promotionCodes }
  func retrievePromotionCode(id: String) async throws -> PromotionCode { throw StubError.missing }

  func retrieveBalance() async throws -> Balance { throw StubError.missing }
  func balanceTransactions(created: DateInterval?, currency: String?) async throws
    -> [BalanceTransaction]
  { [] }
  func charges(created: DateInterval?) async throws -> [Charge] { [] }
  func retrieveCharge(id: String) async throws -> Charge { throw StubError.missing }
  func customers(created: DateInterval?, email: String?) async throws -> [Customer] { [] }
  func retrieveCustomer(id: String) async throws -> Customer { throw StubError.missing }
  func payouts() async throws -> [Payout] { [] }
  func events(created: DateInterval?) async throws -> [Event] { [] }
  func searchCharges(query: String) async throws -> [Charge] { [] }
  func searchPaymentIntents(query: String) async throws -> [PaymentIntent] { [] }
  func rawObject(path: String) async throws -> Data { throw StubError.missing }
}

/// Fixture values with obviously fake identifiers, matching the shapes the
/// Stripe Search API does not cover: coupons and promotion codes are
/// filtered client-side, so the fixtures prove the filter logic.
private let couponFixtureJSON = """
  {
    "id": "coupon_test_123",
    "object": "coupon",
    "amount_off": 1000,
    "applies_to": null,
    "created": 1234567890,
    "currency": "usd",
    "duration": "once",
    "duration_in_months": null,
    "livemode": false,
    "max_redemptions": null,
    "metadata": null,
    "name": "TEN-OFF",
    "percent_off": null,
    "redeem_by": null,
    "times_redeemed": 0,
    "valid": true
  }
  """

private let percentCouponFixtureJSON = """
  {
    "id": "coupon_test_456",
    "object": "coupon",
    "amount_off": null,
    "applies_to": null,
    "created": 1234567890,
    "currency": null,
    "duration": "forever",
    "duration_in_months": null,
    "livemode": false,
    "max_redemptions": 100,
    "metadata": null,
    "name": "HALF-OFF",
    "percent_off": 50,
    "redeem_by": null,
    "times_redeemed": 3,
    "valid": true
  }
  """

private let promotionCodeFixtureJSON = """
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
    "metadata": null,
    "promotion": {"coupon": "coupon_test_123", "type": "coupon"},
    "restrictions": {
      "first_time_transaction": false,
      "minimum_amount": null,
      "minimum_amount_currency": null
    },
    "times_redeemed": 0
  }
  """

private let welcomePromotionCodeFixtureJSON = """
  {
    "id": "promo_test_789",
    "object": "promotion_code",
    "active": true,
    "code": "WELCOME22",
    "created": 1234567890,
    "customer": null,
    "customer_account": null,
    "expires_at": null,
    "livemode": false,
    "max_redemptions": null,
    "metadata": null,
    "promotion": {"coupon": "coupon_test_456", "type": "coupon"},
    "restrictions": {
      "first_time_transaction": false,
      "minimum_amount": null,
      "minimum_amount_currency": null
    },
    "times_redeemed": 0
  }
  """

private func decoded<T: Decodable>(_ json: String, as type: T.Type) -> T {
  guard let value = try? JSONDecoder().decode(T.self, from: Data(json.utf8)) else {
    preconditionFailure("fixture must decode")
  }
  return value
}

@MainActor
@Suite
struct BillingModelSearchTests {
  private func makeModel(
    coupons: [Coupon] = [], promotionCodes: [PromotionCode] = []
  ) -> (BillingModel, SearchRecorder) {
    let recorder = SearchRecorder()
    let backend = SearchRecordingBackend(
      recorder: recorder, coupons: coupons, promotionCodes: promotionCodes)
    return (BillingModel(backend: backend), recorder)
  }

  @Test func emptySearchReturnsEverything() async {
    let coupons = [
      decoded(couponFixtureJSON, as: Coupon.self),
      decoded(percentCouponFixtureJSON, as: Coupon.self),
    ]
    let promotionCodes = [
      decoded(promotionCodeFixtureJSON, as: PromotionCode.self),
      decoded(welcomePromotionCodeFixtureJSON, as: PromotionCode.self),
    ]
    let (model, _) = makeModel(coupons: coupons, promotionCodes: promotionCodes)
    await model.search("")
    #expect(model.phase == .loaded)
    #expect(model.coupons.count == 2)
    #expect(model.promotionCodes.count == 2)
  }

  @Test func searchFiltersCouponsByNameCaseInsensitively() async {
    let coupons = [
      decoded(couponFixtureJSON, as: Coupon.self),
      decoded(percentCouponFixtureJSON, as: Coupon.self),
    ]
    let (model, _) = makeModel(coupons: coupons)
    await model.search("half")
    #expect(model.phase == .loaded)
    #expect(model.coupons.map(\.id) == ["coupon_test_456"])
  }

  @Test func searchFiltersPromotionCodesByCodeAndCouponID() async {
    let promotionCodes = [
      decoded(promotionCodeFixtureJSON, as: PromotionCode.self),
      decoded(welcomePromotionCodeFixtureJSON, as: PromotionCode.self),
    ]
    let (model, _) = makeModel(promotionCodes: promotionCodes)
    await model.search("welcome")
    #expect(model.promotionCodes.map(\.id) == ["promo_test_789"])
    // The coupon id behind a promotion code matches too.
    await model.search("coupon_test_123")
    #expect(model.promotionCodes.map(\.id) == ["promo_test_123"])
  }

  @Test func searchPassesQueryToStripeSearch() async {
    let (model, recorder) = makeModel()
    await model.search("gold")
    #expect(recorder.searchedQuery == "gold")
    #expect(model.phase == .loaded)
  }

  @Test func searchWithNoMatchesClearsEverySection() async {
    let coupons = [decoded(couponFixtureJSON, as: Coupon.self)]
    let (model, _) = makeModel(coupons: coupons)
    await model.search("no-such-thing")
    #expect(model.products.isEmpty)
    #expect(model.coupons.isEmpty)
    #expect(model.promotionCodes.isEmpty)
    #expect(model.phase == .loaded)
  }
}
