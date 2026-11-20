import Foundation
import StripeModels
import XCTest
@testable import GeistData

/// Products and prices (M6): decode parity against the stripe-mock sample
/// shape. All values are obviously fake (`prod_123`, `price_123`,
/// example.com, test amounts).
final class BillingDecodeTests: XCTestCase {
    private let decoder = JSONDecoder()

    private func decodeProduct(from json: String) throws -> Product {
        let data = Data(json.utf8)
        do {
            return try decoder.decode(Product.self, from: data)
        } catch {
            throw DecodingError.billingFixture("product", underlying: error)
        }
    }

    private func decodePrice(from json: String) throws -> Price {
        let data = Data(json.utf8)
        do {
            return try decoder.decode(Price.self, from: data)
        } catch {
            throw DecodingError.billingFixture("price", underlying: error)
        }
    }

    func testProductDecodesStripeMockShape() throws {
        let product = try decodeProduct(
            from: """
            {
              "active": true,
              "created": 1234567890,
              "default_price": "price_123",
              "description": "cozy hoodie",
              "id": "prod_123",
              "images": ["https://cdn.example.com/img1"],
              "livemode": false,
              "marketing_features": [],
              "metadata": {"note": "gift"},
              "name": "Hoodie",
              "object": "product",
              "package_dimensions": null,
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
            """)
        XCTAssertEqual(product.id, "prod_123")
        XCTAssertEqual(product.name, "Hoodie")
        XCTAssertEqual(product.description.valueOrNil, "cozy hoodie")
        XCTAssertEqual(product.active, true)
        XCTAssertNotNil(product.defaultPrice)
        XCTAssertEqual(product.metadata["note"], "gift")
        XCTAssertEqual(product.livemode, false)
    }

    func testProductWithoutDefaultPriceDecodes() throws {
        let product = try decodeProduct(
            from: """
            {
              "active": false,
              "created": 1234567890,
              "default_price": null,
              "description": null,
              "id": "prod_456",
              "images": [],
              "livemode": false,
              "marketing_features": [],
              "metadata": {},
              "name": "Sticker",
              "object": "product",
              "package_dimensions": null,
              "shippable": null,
              "statement_descriptor": null,
              "tax_code": null,
              "tax_details": {"performance_location": null, "tax_code": null},
              "type": "service",
              "unit_label": null,
              "updated": 1234567890,
              "url": null
            }
            """)
        XCTAssertEqual(product.id, "prod_456")
        XCTAssertEqual(product.name, "Sticker")
        XCTAssertEqual(product.description.valueOrNil, nil)
        XCTAssertEqual(product.active, false)
        XCTAssertEqual(product.defaultPrice, nil)
    }

    func testRecurringPriceDecodesStripeMockShape() throws {
        let price = try decodePrice(
            from: """
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
            """)
        XCTAssertEqual(price.id, "price_123")
        XCTAssertEqual(price.currency, "usd")
        XCTAssertEqual(price.unitAmount.valueOrNil, 2000)
        XCTAssertEqual(price.nickname.valueOrNil, "Hoodie Monthly")
        XCTAssertEqual(price.product, .string("prod_123"))
        XCTAssertEqual(price.type, .recurring)
        let recurring = price.recurring.valueOrNil
        XCTAssertEqual(recurring?.interval, .month)
        XCTAssertEqual(recurring?.intervalCount, 1)
    }

    func testOneTimePriceDecodesWithoutRecurring() throws {
        let price = try decodePrice(
            from: """
            {
              "active": true,
              "billing_scheme": "per_unit",
              "created": 1234567890,
              "currency": "usd",
              "custom_unit_amount": null,
              "id": "price_456",
              "livemode": false,
              "lookup_key": null,
              "metadata": {},
              "nickname": null,
              "object": "price",
              "product": "prod_123",
              "recurring": null,
              "tax_behavior": "unspecified",
              "tiers_mode": null,
              "transform_quantity": null,
              "type": "one_time",
              "unit_amount": 500,
              "unit_amount_decimal": "500"
            }
            """)
        XCTAssertEqual(price.id, "price_456")
        XCTAssertEqual(price.type, .oneTime)
        XCTAssertEqual(price.recurring.valueOrNil, nil)
    }

    func testProductListEnvelopeDecodes() throws {
        let list = try decoder.decode(
            ProductList.self,
            from: Data("""
            {
              "data": [
                {"active": true, "created": 1234567890, "default_price": null,
                 "description": null, "id": "prod_123", "images": [],
                 "livemode": false, "marketing_features": [], "metadata": {},
                 "name": "Hoodie", "object": "product", "package_dimensions": null,
                 "shippable": null, "statement_descriptor": null, "tax_code": null,
                 "tax_details": {"performance_location": null, "tax_code": null},
                 "type": "service",
                 "unit_label": null, "updated": 1234567890, "url": null}
              ],
              "has_more": false,
              "object": "list",
              "total_count": 1,
              "url": "/v1/products"
            }
            """.utf8))
        XCTAssertEqual(list.data.count, 1)
        XCTAssertEqual(list.data[0].name, "Hoodie")
        XCTAssertFalse(list.hasMore)
    }

    func testPriceListEnvelopeDecodes() throws {
        let list = try decoder.decode(
            PriceList.self,
            from: Data("""
            {
              "data": [
                {"active": true, "billing_scheme": "per_unit",
                 "created": 1234567890, "currency": "usd",
                 "custom_unit_amount": null, "id": "price_123", "livemode": false,
                 "lookup_key": null, "metadata": {}, "nickname": null,
                 "object": "price", "product": "prod_123",
                 "recurring": {"interval": "month", "interval_count": 1,
                               "meter": null, "usage_type": "licensed"},
                 "tax_behavior": "unspecified", "tiers_mode": null,
                 "transform_quantity": null, "type": "recurring",
                 "unit_amount": 2000, "unit_amount_decimal": "2000"}
              ],
              "has_more": true,
              "object": "list",
              "total_count": 1,
              "url": "/v1/prices"
            }
            """.utf8))
        XCTAssertEqual(list.data.count, 1)
        XCTAssertEqual(list.data[0].id, "price_123")
        XCTAssertTrue(list.hasMore)
    }
}

/// Wraps fixture-decode failures so the test message names the object.
private enum DecodingError: Error {
    case billingFixture(String, underlying: Error)
}
