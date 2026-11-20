// BillingWriteFixtures.swift — TestsApp
// Response fixtures for the billing write-path tests. Shapes come from
// stripe-mock (0.206.0) against the pinned endpoints; every value is
// obviously fake (`prod_123`, `price_123`).

import Foundation

// MARK: - Product

nonisolated(unsafe) let productWriteFixtureJSON = """
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

nonisolated(unsafe) let productWriteFixture: [String: Any] = {
  guard let parsed = try? JSONSerialization.jsonObject(with: Data(productWriteFixtureJSON.utf8)),
    let dict = parsed as? [String: Any] else {
    preconditionFailure("productWriteFixtureJSON must decode")
  }
  return dict
}()

nonisolated(unsafe) let productDeleteFixture: [String: Any] = [
  "deleted": true, "id": "prod_123", "object": "product",
]

// MARK: - Price

nonisolated(unsafe) let priceWriteFixtureJSON = """
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

nonisolated(unsafe) let priceWriteFixture: [String: Any] = {
  guard let parsed = try? JSONSerialization.jsonObject(with: Data(priceWriteFixtureJSON.utf8)),
    let dict = parsed as? [String: Any] else {
    preconditionFailure("priceWriteFixtureJSON must decode")
  }
  return dict
}()

nonisolated(unsafe) let oneTimePriceWriteFixtureJSON = """
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
"""

nonisolated(unsafe) let oneTimePriceWriteFixture: [String: Any] = {
  guard let parsed = try? JSONSerialization.jsonObject(
    with: Data(oneTimePriceWriteFixtureJSON.utf8)),
    let dict = parsed as? [String: Any] else {
    preconditionFailure("oneTimePriceWriteFixtureJSON must decode")
  }
  return dict
}()
