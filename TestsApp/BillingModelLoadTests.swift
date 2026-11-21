import Foundation
import GeistData
import StripeModels
import Testing

@testable import Geist6

private enum StubError: Error { case boom }

/// A billing backend whose methods fail on demand, so tests can prove one
/// section's failure neither clears another section's rows nor blanks the
/// whole screen: the model stores each section's result and error
/// independently.
private struct FaultInjectingBackend: BillingBackend {
  var productsError: Error?
  var couponsError: Error?
  var promotionCodesError: Error?
  var invoicesError: Error?
  var products: [Product] = []
  var coupons: [Coupon] = []
  var promotionCodes: [PromotionCode] = []
  var invoices: [Invoice] = []

  func products() async throws -> [Product] {
    if let productsError { throw productsError }
    return products
  }
  func searchProducts(query: String) async throws -> [Product] { products }
  func retrieveProduct(byID: String) async throws -> Product { throw StubError.boom }
  func prices(product: String?) async throws -> [Price] { [] }
  func searchPrices(query: String) async throws -> [Price] { [] }
  func retrievePrice(id: String) async throws -> Price { throw StubError.boom }
  func coupons() async throws -> [Coupon] {
    if let couponsError { throw couponsError }
    return coupons
  }
  func retrieveCoupon(id: String) async throws -> Coupon { throw StubError.boom }
  func promotionCodes() async throws -> [PromotionCode] {
    if let promotionCodesError { throw promotionCodesError }
    return promotionCodes
  }
  func retrievePromotionCode(id: String) async throws -> PromotionCode { throw StubError.boom }
  func invoices() async throws -> [Invoice] {
    if let invoicesError { throw invoicesError }
    return invoices
  }
  func retrieveInvoice(id: String) async throws -> Invoice { throw StubError.boom }
  func subscriptions() async throws -> [Subscription] { [] }
  func retrieveSubscription(id: String) async throws -> Subscription { throw StubError.boom }

  func retrieveBalance() async throws -> Balance { throw StubError.boom }
  func balanceTransactions(created: DateInterval?, currency: String?) async throws
    -> [BalanceTransaction]
  { [] }
  func charges(created: DateInterval?) async throws -> [Charge] { [] }
  func retrieveCharge(id: String) async throws -> Charge { throw StubError.boom }
  func customers(created: DateInterval?, email: String?) async throws -> [Customer] { [] }
  func retrieveCustomer(id: String) async throws -> Customer { throw StubError.boom }
  func payouts() async throws -> [Payout] { [] }
  func events(created: DateInterval?) async throws -> [Event] { [] }
  func searchCharges(query: String) async throws -> [Charge] { [] }
  func searchPaymentIntents(query: String) async throws -> [PaymentIntent] { [] }
  func rawObject(path: String) async throws -> Data { throw StubError.boom }
}

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

private func decoded<T: Decodable>(_ json: String, as type: T.Type) -> T {
  guard let value = try? JSONDecoder().decode(T.self, from: Data(json.utf8)) else {
    preconditionFailure("fixture must decode")
  }
  return value
}

@MainActor
@Suite
struct BillingModelLoadTests {
  /// A decode failure in one section must not take down the others: the
  /// regression behind the billing screen going fully blank when the product
  /// list could not be decoded, which also prevented coupons from ever
  /// loading because the loads ran sequentially under one catch.
  @Test func sectionFailureKeepsOtherSectionsLoaded() async {
    let backend = FaultInjectingBackend(
      couponsError: StubError.boom,
      coupons: [decoded(couponFixtureJSON, as: Coupon.self)],
      promotionCodes: [decoded(promotionCodeFixtureJSON, as: PromotionCode.self)])
    let model = BillingModel(backend: backend)
    await model.load()
    #expect(model.phase == .loaded)
    #expect(model.productsError == nil)
    #expect(model.couponsError != nil)
    #expect(model.promotionCodesError == nil)
    #expect(model.coupons.isEmpty)
    #expect(model.promotionCodes.count == 1)
  }

  @Test func successfulSectionsKeepTheirErrorStateClear() async {
    let backend = FaultInjectingBackend(
      promotionCodesError: StubError.boom,
      coupons: [decoded(couponFixtureJSON, as: Coupon.self)])
    let model = BillingModel(backend: backend)
    await model.load()
    #expect(model.phase == .loaded)
    #expect(model.productsError == nil)
    #expect(model.couponsError == nil)
    #expect(model.promotionCodesError != nil)
    #expect(model.coupons.count == 1)
  }

  @Test func everySectionFailingStillEndsTheLoad() async {
    let backend = FaultInjectingBackend(
      productsError: StubError.boom,
      couponsError: StubError.boom,
      promotionCodesError: StubError.boom)
    let model = BillingModel(backend: backend)
    await model.load()
    #expect(model.phase == .loaded)
    #expect(model.productsError != nil)
    #expect(model.couponsError != nil)
    #expect(model.promotionCodesError != nil)
  }

  @Test func invoicesSectionLoadsIndependently() async {
    let backend = FaultInjectingBackend(
      invoicesError: StubError.boom,
      coupons: [decoded(couponFixtureJSON, as: Coupon.self)])
    let model = BillingModel(backend: backend)
    await model.load()
    #expect(model.phase == .loaded)
    #expect(model.invoicesError != nil)
    #expect(model.couponsError == nil)
    #expect(model.invoices.isEmpty)
    #expect(model.coupons.count == 1)
  }

  @Test func invoicesSectionPopulatesFromBackend() async {
    let backend = FaultInjectingBackend(
      invoices: [decoded(invoiceWriteFixtureJSON, as: Invoice.self)])
    let model = BillingModel(backend: backend)
    await model.load()
    #expect(model.phase == .loaded)
    #expect(model.invoicesError == nil)
    #expect(model.invoices.count == 1)
  }

  @Test func loadClearsStaleSectionErrorsOnSuccess() async {
    var backend = FaultInjectingBackend(couponsError: StubError.boom)
    let model = BillingModel(backend: backend)
    await model.load()
    #expect(model.couponsError != nil)
    backend.couponsError = nil
    let refreshed = BillingModel(backend: backend)
    await refreshed.load()
    #expect(refreshed.couponsError == nil)
    #expect(refreshed.phase == .loaded)
  }
}
