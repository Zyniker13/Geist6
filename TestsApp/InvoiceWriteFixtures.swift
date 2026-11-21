// InvoiceWriteFixtures.swift — TestsApp
// Response fixtures for the invoice write-path tests. The shape follows
// stripe-mock (0.206.0) for /v1/invoices against the pinned spec; every
// value is obviously fake (`in_123`, `il_123`, `cus_123`).

import Foundation

// MARK: - Invoice

nonisolated(unsafe) let invoiceWriteFixtureJSON = """
{
  "account_country": "US",
  "account_name": null,
  "account_tax_ids": null,
  "amount_due": 1000,
  "amount_overpaid": 0,
  "amount_paid": 0,
  "amount_paid_off_stripe": 0,
  "amount_remaining": 1000,
  "amount_shipping": 0,
  "application": null,
  "attempt_count": 0,
  "attempted": false,
  "auto_advance": false,
  "automatic_tax": {
    "disabled_reason": null,
    "enabled": false,
    "liability": null,
    "provider": null,
    "status": null
  },
  "automatically_finalizes_at": null,
  "billing_reason": "manual",
  "collection_method": "charge_automatically",
  "created": 1234567890,
  "currency": "usd",
  "custom_fields": null,
  "customer": "cus_123",
  "customer_account": null,
  "customer_address": null,
  "customer_email": "alice@example.com",
  "customer_name": "Alice",
  "customer_phone": null,
  "customer_shipping": null,
  "customer_tax_exempt": "none",
  "customer_tax_ids": [],
  "default_payment_method": null,
  "default_source": null,
  "default_tax_rates": [],
  "description": null,
  "discounts": [],
  "due_date": 1234567890,
  "effective_at": 1234567890,
  "ending_balance": null,
  "footer": null,
  "from_invoice": null,
  "hosted_invoice_url": null,
  "id": "in_123",
  "invoice_pdf": null,
  "issuer": {
    "type": "self"
  },
  "last_finalization_error": null,
  "latest_revision": null,
  "lines": {
    "data": [
      {
        "amount": 1000,
        "currency": "usd",
        "description": "Test line",
        "discount_amounts": [],
        "discountable": true,
        "discounts": [],
        "id": "il_123",
        "invoice": "in_123",
        "livemode": false,
        "metadata": {},
        "object": "line_item",
        "parent": null,
        "period": {
          "end": 1721954054,
          "start": 1721954054
        },
        "pretax_credit_amounts": null,
        "pricing": {
          "type": "unit_details",
          "unit_amount_decimal": null
        },
        "quantity": 1,
        "quantity_decimal": null,
        "subscription": null,
        "subtotal": 1000,
        "taxes": null
      }
    ],
    "has_more": false,
    "object": "list",
    "url": "/v1/invoices/in_123/lines"
  },
  "livemode": false,
  "metadata": {},
  "next_payment_attempt": null,
  "number": null,
  "object": "invoice",
  "on_behalf_of": null,
  "parent": null,
  "payment_settings": {
    "default_mandate": null,
    "payment_method_options": {},
    "payment_method_types": null
  },
  "period_end": 1234567890,
  "period_start": 1234567890,
  "post_payment_credit_notes_amount": 0,
  "pre_payment_credit_notes_amount": 0,
  "receipt_number": null,
  "rendering": {
    "amount_tax_display": null,
    "pdf": {
      "page_size": null
    },
    "template": null,
    "template_version": null
  },
  "shipping_cost": null,
  "shipping_details": null,
  "starting_balance": 0,
  "statement_descriptor": null,
  "status": "draft",
  "status_transitions": {
    "finalized_at": null,
    "marked_uncollectible_at": null,
    "paid_at": null,
    "voided_at": null
  },
  "subtotal": 1000,
  "subtotal_excluding_tax": 1000,
  "test_clock": null,
  "total": 1000,
  "total_discount_amounts": [],
  "total_excluding_tax": 1000,
  "total_pretax_credit_amounts": null,
  "total_taxes": null,
  "webhooks_delivered_at": null
}
"""

nonisolated(unsafe) let invoiceWriteFixture: [String: Any] = {
  guard let parsed = try? JSONSerialization.jsonObject(with: Data(invoiceWriteFixtureJSON.utf8)),
    let dict = parsed as? [String: Any] else {
    preconditionFailure("invoiceWriteFixtureJSON must decode")
  }
  return dict
}()

// MARK: - Finalized invoice

/// Same invoice after a lifecycle verb, with status changed to "open" so a
/// test can prove the response was decoded, not just the request encoded.
nonisolated(unsafe) let invoiceFinalizedFixture: [String: Any] = {
  var dict = invoiceWriteFixture
  dict["status"] = "open"
  return dict
}()

// MARK: - Deleted invoice

nonisolated(unsafe) let invoiceDeleteFixture: [String: Any] = [
  "deleted": true, "id": "in_123", "object": "invoice",
]

// MARK: - Invoice list

nonisolated(unsafe) let invoiceListFixture: [String: Any] = {
  var list = invoiceWriteFixture
  list["data"] = [invoiceWriteFixture]
  list["has_more"] = false
  list["object"] = "list"
  list["url"] = "/v1/invoices"
  return [
    "object": "list", "data": [invoiceWriteFixture], "has_more": false,
    "url": "/v1/invoices",
  ]
}()
