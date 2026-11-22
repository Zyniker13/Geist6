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
  var invoices: [Invoice] = []

  func products() async throws -> [Product] { products }
  func searchProducts(query: String) async throws -> [Product] {
    recorder.searchedQuery = query
    return products
  }
  func retrieveProduct(byID: String) async throws -> Product { throw StubError.missing }
  var prices: [Price] = []
  func prices(product: String?) async throws -> [Price] { prices }
  func searchPrices(query: String) async throws -> [Price] {
    recorder.searchedQuery = query
    return prices
  }
  func retrievePrice(id: String) async throws -> Price { throw StubError.missing }
  func coupons() async throws -> [Coupon] { coupons }
  func retrieveCoupon(id: String) async throws -> Coupon { throw StubError.missing }
  func promotionCodes() async throws -> [PromotionCode] { promotionCodes }
  func retrievePromotionCode(id: String) async throws -> PromotionCode { throw StubError.missing }

  func invoices() async throws -> [Invoice] { invoices }
  func retrieveInvoice(id: String) async throws -> Invoice { throw StubError.missing }
  func subscriptions() async throws -> [Subscription] { [] }
  func retrieveSubscription(id: String) async throws -> Subscription { throw StubError.missing }

  func retrieveBalance() async throws -> Balance { throw StubError.missing }
  func balanceTransactions(created: DateInterval?, currency: String?) async throws
    -> [BalanceTransaction]
  { [] }
  func balanceTransactions(payout: String) async throws -> [BalanceTransaction] { [] }
  func charges(created: DateInterval?) async throws -> [Charge] { [] }
  func retrieveCharge(id: String) async throws -> Charge { throw StubError.missing }
  func customers(created: DateInterval?, email: String?) async throws -> [Customer] { [] }
  func retrieveCustomer(id: String) async throws -> Customer { throw StubError.missing }
  func retrievePayout(id: String) async throws -> Payout { throw StubError.missing }
  func payouts() async throws -> [Payout] { [] }

  func transfers() async throws -> [Transfer] { [] }

  func retrieveTransfer(id: String) async throws -> Transfer { throw StubError.missing }

  func transferReversals(transfer: String) async throws -> [TransferReversal] { [] }

  func topups() async throws -> [Topup] { [] }

  func retrieveTopup(id: String) async throws -> Topup { throw StubError.missing }

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

/// A second invoice derived from the shared fixture with distinct identity
/// fields, so search-filter tests can tell the two rows apart.
private let secondInvoiceFixtureJSON = invoiceWriteFixtureJSON
  .replacingOccurrences(of: "\"in_123\"", with: "\"in_456\"")
  .replacingOccurrences(of: "\"number\": null", with: "\"number\": \"ABCD-0042\"")
  .replacingOccurrences(of: "\"alice@example.com\"", with: "\"bob@example.com\"")

/// Price fixtures for the prices search-filter tests: a nickname and product
/// ID that differ across the pair, matching the invoice tests' shape.
private let sectionPriceFixtureJSON = """
  {
    "active": true,
    "billing_scheme": "per_unit",
    "created": 1234567890,
    "currency": "usd",
    "custom_unit_amount": null,
    "id": "price_search_123",
    "livemode": false,
    "lookup_key": null,
    "metadata": {},
    "nickname": "Sticker Monthly",
    "object": "price",
    "product": "prod_search_123",
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
    "unit_amount": 500,
    "unit_amount_decimal": "500"
  }
  """

private let secondPriceFixtureJSON = sectionPriceFixtureJSON
  .replacingOccurrences(of: "\"price_search_123\"", with: "\"price_search_456\"")
  .replacingOccurrences(of: "\"prod_search_123\"", with: "\"prod_search_456\"")
  .replacingOccurrences(of: "Sticker Monthly", with: "Mug Annual")

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
    coupons: [Coupon] = [], promotionCodes: [PromotionCode] = [],
    invoices: [Invoice] = [], prices: [Price] = []
  ) -> (BillingModel, SearchRecorder) {
    let recorder = SearchRecorder()
    var backend = SearchRecordingBackend(
      recorder: recorder, coupons: coupons, promotionCodes: promotionCodes,
      invoices: invoices)
    backend.prices = prices
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

  @Test func searchFiltersInvoicesByIDCustomerEmailAndNumber() async {
    let invoices = [
      decoded(invoiceWriteFixtureJSON, as: Invoice.self),
      decoded(secondInvoiceFixtureJSON, as: Invoice.self),
    ]
    let (model, _) = makeModel(invoices: invoices)
    await model.search("bob")
    #expect(model.invoices.map(\.id) == ["in_456"])
    await model.search("0042")
    #expect(model.invoices.map(\.id) == ["in_456"])
    await model.search("in_123")
    #expect(model.invoices.map(\.id) == ["in_123"])
  }

  @Test func searchFiltersPricesByIDNicknameAndProduct() async {
    let prices = [
      decoded(sectionPriceFixtureJSON, as: Price.self),
      decoded(secondPriceFixtureJSON, as: Price.self)
    ]
    let (model, _) = makeModel(prices: prices)
    await model.search("mug")
    #expect(model.prices.map(\.id) == ["price_search_456"])
    await model.search("prod_search_123")
    #expect(model.prices.map(\.id) == ["price_search_123"])
    await model.search("price_search_456")
    #expect(model.prices.map(\.id) == ["price_search_456"])
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
    #expect(model.invoices.isEmpty)
    #expect(model.phase == .loaded)
  }
}
