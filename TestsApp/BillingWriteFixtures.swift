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

// MARK: - Coupon

nonisolated(unsafe) let couponWriteFixtureJSON = """
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

nonisolated(unsafe) let couponWriteFixture: [String: Any] = {
  guard let parsed = try? JSONSerialization.jsonObject(
    with: Data(couponWriteFixtureJSON.utf8)),
    let dict = parsed as? [String: Any] else {
    preconditionFailure("couponWriteFixtureJSON must decode")
  }
  return dict
}()

/// A percent-off coupon, for the list fixture and the update test.
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

nonisolated(unsafe) let couponDeleteFixture: [String: Any] = [
  "deleted": true, "id": "coupon_test_123", "object": "coupon",
]

// MARK: - Promotion code

nonisolated(unsafe) let promotionCodeWriteFixtureJSON = """
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

nonisolated(unsafe) let promotionCodeWriteFixture: [String: Any] = {
  guard let parsed = try? JSONSerialization.jsonObject(
    with: Data(promotionCodeWriteFixtureJSON.utf8)),
    let dict = parsed as? [String: Any] else {
    preconditionFailure("promotionCodeWriteFixtureJSON must decode")
  }
  return dict
}()
