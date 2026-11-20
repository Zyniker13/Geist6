// CustomersWriteFixtures.swift — TestsApp
// Response fixtures for the customer write-path tests. Shapes come from
// stripe-mock (0.206.0) against the pinned endpoints; every value is
// obviously fake (`cus_123`, `alice@example.com`).

import Foundation

// MARK: - Customer

nonisolated(unsafe) let customerWriteFixtureJSON = """
{
  "address": {
    "city": null,
    "country": null,
    "line1": null,
    "line2": null,
    "postal_code": null,
    "state": null
  },
  "balance": 0,
  "created": 1234567890,
  "currency": "usd",
  "default_source": null,
  "delinquent": false,
  "description": null,
  "email": null,
  "id": "cus_123",
  "invoice_prefix": "7FE1103",
  "invoice_settings": {
    "custom_fields": null,
    "default_payment_method": null,
    "footer": null,
    "rendering_options": {
      "amount_tax_display": null,
      "template": null
    }
  },
  "livemode": false,
  "metadata": {},
  "name": "Bob",
  "next_invoice_sequence": 1,
  "object": "customer",
  "phone": null,
  "preferred_locales": [],
  "shipping": {},
  "tax_exempt": "none",
  "test_clock": null
}
"""

nonisolated(unsafe) let customerWriteFixture: [String: Any] = {
  guard let parsed = try? JSONSerialization.jsonObject(with: Data(customerWriteFixtureJSON.utf8)),
    let dict = parsed as? [String: Any] else {
    preconditionFailure("customerWriteFixtureJSON must decode")
  }
  return dict
}()

nonisolated(unsafe) let customerDeleteFixture: [String: Any] = [
  "deleted": true, "id": "cus_123", "object": "customer",
]

// MARK: - Discount removal

nonisolated(unsafe) let discountDeleteFixtureJSON = """
{
  "checkout_session": null,
  "customer": null,
  "customer_account": null,
  "deleted": true,
  "id": "_Rjdx6X5UDD30rAv",
  "invoice": null,
  "invoice_item": null,
  "object": "discount",
  "promotion_code": null,
  "source": {
    "coupon": null,
    "type": "coupon"
  },
  "start": 1234567890,
  "subscription": null,
  "subscription_item": null
}
"""

nonisolated(unsafe) let discountDeleteFixture: [String: Any] = {
  guard let parsed = try? JSONSerialization.jsonObject(with: Data(discountDeleteFixtureJSON.utf8)),
    let dict = parsed as? [String: Any] else {
    preconditionFailure("discountDeleteFixtureJSON must decode")
  }
  return dict
}()

// MARK: - Balance transactions

nonisolated(unsafe) let balanceTxnCreateFixtureJSON = """
{
  "amount": 100,
  "checkout_session": null,
  "created": 1234567890,
  "credit_note": null,
  "currency": "usd",
  "customer": "cus_123",
  "customer_account": null,
  "description": null,
  "ending_balance": -500,
  "id": "cbtxn_Rjdx6DoG52DHoLx",
  "invoice": null,
  "livemode": false,
  "metadata": null,
  "object": "customer_balance_transaction",
  "type": "adjustment"
}
"""

nonisolated(unsafe) let balanceTxnCreateFixture: [String: Any] = {
  guard let parsed = try? JSONSerialization.jsonObject(with: Data(balanceTxnCreateFixtureJSON.utf8)),
    let dict = parsed as? [String: Any] else {
    preconditionFailure("balanceTxnCreateFixtureJSON must decode")
  }
  return dict
}()

nonisolated(unsafe) let balanceTxnUpdateFixtureJSON = """
{
  "amount": -500,
  "checkout_session": null,
  "created": 1234567890,
  "credit_note": null,
  "currency": "usd",
  "customer": "cus_123",
  "customer_account": null,
  "description": "x",
  "ending_balance": -500,
  "id": "bt_123",
  "invoice": null,
  "livemode": false,
  "metadata": null,
  "object": "customer_balance_transaction",
  "type": "adjustment"
}
"""

nonisolated(unsafe) let balanceTxnUpdateFixture: [String: Any] = {
  guard let parsed = try? JSONSerialization.jsonObject(with: Data(balanceTxnUpdateFixtureJSON.utf8)),
    let dict = parsed as? [String: Any] else {
    preconditionFailure("balanceTxnUpdateFixtureJSON must decode")
  }
  return dict
}()

// MARK: - Tax IDs

nonisolated(unsafe) let taxIdCreateFixtureJSON = """
{
  "country": "DE",
  "created": 1234567890,
  "customer": "cus_123",
  "customer_account": null,
  "id": "txi_Rjdx6WahlY9DeJQ",
  "livemode": false,
  "object": "tax_id",
  "owner": {
    "customer": "cus_123",
    "customer_account": null,
    "type": "customer"
  },
  "type": "eu_vat",
  "value": "DE123456789",
  "verification": {
    "status": "pending",
    "verified_address": null,
    "verified_name": null
  }
}
"""

nonisolated(unsafe) let taxIdCreateFixture: [String: Any] = {
  guard let parsed = try? JSONSerialization.jsonObject(with: Data(taxIdCreateFixtureJSON.utf8)),
    let dict = parsed as? [String: Any] else {
    preconditionFailure("taxIdCreateFixtureJSON must decode")
  }
  return dict
}()

nonisolated(unsafe) let taxIdDeleteFixture: [String: Any] = [
  "deleted": true, "id": "txi_123", "object": "tax_id",
]

// MARK: - Funding instructions

nonisolated(unsafe) let fundingInstructionsFixtureJSON = """
{
  "bank_transfer": {
    "country": "US",
    "financial_addresses": [
      {
        "supported_networks": [
          "ach",
          "domestic_wire_us"
        ],
        "type": "aba"
      }
    ],
    "type": "eu_bank_transfer"
  },
  "currency": "usd",
  "funding_type": "bank_transfer",
  "livemode": false,
  "object": "funding_instructions"
}
"""

nonisolated(unsafe) let fundingInstructionsFixture: [String: Any] = {
  guard let parsed = try? JSONSerialization.jsonObject(with: Data(fundingInstructionsFixtureJSON.utf8)),
    let dict = parsed as? [String: Any] else {
    preconditionFailure("fundingInstructionsFixtureJSON must decode")
  }
  return dict
}()

// MARK: - Cash balance funding

nonisolated(unsafe) let cashBalanceFundFixtureJSON = """
{
  "created": 1234567890,
  "currency": "usd",
  "customer": "cus_123",
  "customer_account": null,
  "ending_balance": 10000,
  "funded": {
    "bank_transfer": {
      "eu_bank_transfer": {
        "bic": "BANKDEAAXXX",
        "iban_last4": "7089",
        "sender_name": "Sample Business GmbH"
      },
      "reference": "Payment for Invoice 7FE1103-155",
      "type": "eu_bank_transfer"
    }
  },
  "id": "ccsbtxn_Rje2kwSDFurifvP",
  "livemode": false,
  "net_amount": 5000,
  "object": "customer_cash_balance_transaction",
  "type": "funded"
}
"""

nonisolated(unsafe) let cashBalanceFundFixture: [String: Any] = {
  guard let parsed = try? JSONSerialization.jsonObject(with: Data(cashBalanceFundFixtureJSON.utf8)),
    let dict = parsed as? [String: Any] else {
    preconditionFailure("cashBalanceFundFixtureJSON must decode")
  }
  return dict
}()
