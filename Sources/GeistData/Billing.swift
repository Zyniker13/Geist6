// Billing.swift — Sources/GeistData
// The billing surface of the Stripe API used by the billing screens:
// products, prices, coupons, and promotion codes, with search and
// per-product price listings.
//
// Like `PaymentsBackend` and `CustomersBackend`, this protocol is read-only:
// it has no write methods, so a view model built on it cannot write by
// construction. Product and price writes (create, update, delete) go through
// `BillingWriteService`, which is only handed out in manage mode.

import Foundation
import StripeModels
import StripeClient

/// The catalog surface of the Stripe API used by the billing screens.
public protocol BillingBackend: StripeDataBackend, Sendable {
    /// The account's products.
    func products() async throws -> [Product]

    /// Search products with a Stripe Search API query string.
    func searchProducts(query: String) async throws -> [Product]

    /// A single product.
    func retrieveProduct(byID: String) async throws -> Product

    /// Prices. The prices of one product when `product` is given; the
    /// account-wide listing otherwise.
    func prices(product: String?) async throws -> [Price]

    /// Search prices with a Stripe Search API query string.
    func searchPrices(query: String) async throws -> [Price]

    /// A single price.
    func retrievePrice(id: String) async throws -> Price

    /// The account's coupons, newest first (Stripe's list order).
    func coupons() async throws -> [Coupon]

    /// A single coupon.
    func retrieveCoupon(id: String) async throws -> Coupon

    /// The account's promotion codes, newest first.
    func promotionCodes() async throws -> [PromotionCode]

    /// A single promotion code.
    func retrievePromotionCode(id: String) async throws -> PromotionCode
}

// MARK: - StripeClient conformance

extension StripeClient: BillingBackend {
    public func products() async throws -> [Product] {
        let result = try await listProducts()
        return result.data
    }

    public func searchProducts(query: String) async throws -> [Product] {
        var params = ProductSearchParams()
        params.query = query
        let result = try await searchProduct(params)
        return result.data
    }

    public func retrieveProduct(byID: String) async throws -> Product {
        try await self.retrieveProduct(id: byID)
    }

    public func prices(product: String?) async throws -> [Price] {
        var params = PriceListParams()
        params.product = product
        let result = try await listPrices(params)
        return result.data
    }

    public func searchPrices(query: String) async throws -> [Price] {
        var params = PriceSearchParams()
        params.query = query
        let result = try await searchPrice(params)
        return result.data
    }

    public func retrievePrice(id: String) async throws -> Price {
        try await retrievePrice(price: id)
    }

    public func coupons() async throws -> [Coupon] {
        let result = try await listCoupons()
        return result.data
    }

    public func retrieveCoupon(id: String) async throws -> Coupon {
        try await retrieveCoupon(coupon: id)
    }

    public func promotionCodes() async throws -> [PromotionCode] {
        let result = try await listPromotionCodes()
        return result.data
    }

    public func retrievePromotionCode(id: String) async throws -> PromotionCode {
        try await retrievePromotionCode(promotionCode: id)
    }
}
