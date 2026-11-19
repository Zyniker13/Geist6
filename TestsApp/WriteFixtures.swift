// WriteFixtures.swift — TestsApp
// Shared write-test fixtures: stripe-mock responses with obviously fake
// values (IDs, URLs, names). Empty collections are NSDictionary()/
// NSArray() per the boxing rule in PaymentsWriteTests.

import Foundation

nonisolated(unsafe) let plinkWriteFixture: [String: Any] = [
    "active": true,
    "after_completion": [
      "hosted_confirmation": [
        "custom_message": NSNull()
      ],
      "type": "hosted_confirmation"
    ],
    "allow_promotion_codes": false,
    "application": NSNull(),
    "application_fee_amount": NSNull(),
    "application_fee_percent": NSNull(),
    "automatic_tax": [
      "enabled": false,
      "liability": [
        "type": "account"
      ]
    ],
    "billing_address_collection": "auto",
    "consent_collection": [
      "payment_method_reuse_agreement": [
        "position": "hidden"
      ],
      "promotions": NSNull(),
      "terms_of_service": NSNull()
    ],
    "currency": "usd",
    "custom_fields": NSArray(),
    "custom_text": [
      "after_submit": [
        "message": "message"
      ],
      "shipping_address": [
        "message": "message"
      ],
      "submit": [
        "message": "message"
      ],
      "terms_of_service_acceptance": [
        "message": "message"
      ]
    ],
    "customer_creation": "if_required",
    "id": "plink_test_123",
    "inactive_message": NSNull(),
    "invoice_creation": [
      "enabled": true,
      "invoice_data": [
        "account_tax_ids": NSNull(),
        "custom_fields": NSNull(),
        "description": NSNull(),
        "footer": NSNull(),
        "issuer": [
          "type": "account"
        ],
        "metadata": NSNull(),
        "rendering_options": [
          "amount_tax_display": NSNull(),
          "template": NSNull()
        ]
      ]
    ],
    "livemode": false,
    "managed_payments": [
      "enabled": true
    ],
    "metadata": NSDictionary(),
    "object": "payment_link",
    "on_behalf_of": NSNull(),
    "payment_intent_data": [
      "capture_method": NSNull(),
      "description": NSNull(),
      "metadata": [
        "undefined": "metadata"
      ],
      "setup_future_usage": NSNull(),
      "statement_descriptor": NSNull(),
      "statement_descriptor_suffix": NSNull(),
      "transfer_group": NSNull()
    ],
    "payment_method_collection": "if_required",
    "payment_method_options": [
      "card": [
        "restrictions": [
          "brands_blocked": ["discover_global_network"]
        ]
      ]
    ],
    "payment_method_types": NSNull(),
    "phone_number_collection": [
      "enabled": false
    ],
    "restrictions": [
      "completed_sessions": [
        "count": 94851343,
        "limit": 102976443
      ]
    ],
    "shipping_address_collection": [
      "allowed_countries": ["SC"]
    ],
    "shipping_options": NSArray(),
    "submit_type": "auto",
    "subscription_data": [
      "description": NSNull(),
      "invoice_settings": [
        "issuer": [
          "type": "account"
        ]
      ],
      "metadata": [
        "undefined": "metadata"
      ],
      "trial_period_days": NSNull(),
      "trial_settings": [
        "end_behavior": [
          "missing_payment_method": "cancel"
        ]
      ]
    ],
    "tax_id_collection": [
      "enabled": false,
      "required": "never"
    ],
    "transfer_data": [
      "amount": NSNull(),
      "destination": [
        "id": "obj_123",
        "object": "account"
      ]
    ],
    "url": "https://example.com/pay/plink_test_123"
  ]
nonisolated(unsafe) let chargeWriteFixture: [String: Any] = [
    "amount": 1000,
    "amount_captured": 0,
    "amount_refunded": 0,
    "application": NSNull(),
    "application_fee": NSNull(),
    "application_fee_amount": NSNull(),
    "balance_transaction": "txn_test_123",
    "billing_details": [
      "address": [
        "city": NSNull(),
        "country": NSNull(),
        "line1": NSNull(),
        "line2": NSNull(),
        "postal_code": NSNull(),
        "state": NSNull()
      ],
      "email": NSNull(),
      "name": "Alice",
      "phone": NSNull(),
      "tax_id": NSNull()
    ],
    "calculated_statement_descriptor": NSNull(),
    "captured": false,
    "created": 1234567890,
    "currency": "usd",
    "customer": NSNull(),
    "description": "Test charge",
    "disputed": false,
    "failure_balance_transaction": NSNull(),
    "failure_code": NSNull(),
    "failure_message": NSNull(),
    "fraud_details": NSDictionary(),
    "id": "ch_test_123",
    "livemode": false,
    "metadata": NSDictionary(),
    "object": "charge",
    "on_behalf_of": NSNull(),
    "outcome": [
      "advice_code": NSNull(),
      "network_advice_code": NSNull(),
      "network_decline_code": NSNull(),
      "network_status": NSNull(),
      "reason": NSNull(),
      "seller_message": NSNull(),
      "type": "type"
    ],
    "paid": true,
    "payment_intent": NSNull(),
    "payment_method": "pm_test_123",
    "payment_method_details": [
      "card": [
        "amount_authorized": NSNull(),
        "authorization_code": NSNull(),
        "brand": "visa",
        "checks": [
          "address_line1_check": NSNull(),
          "address_postal_code_check": NSNull(),
          "cvc_check": "pass"
        ],
        "country": "US",
        "electronic_commerce_indicator": NSNull(),
        "exp_month": 8,
        "exp_year": 2030,
        "extended_authorization": [
          "status": "disabled"
        ],
        "fingerprint": "AOB934RVNwzk6xtn",
        "funding": "credit",
        "incremental_authorization": [
          "status": "unavailable"
        ],
        "installments": [
          "plan": [
            "count": NSNull(),
            "interval": NSNull(),
            "type": "fixed_count"
          ]
        ],
        "last4": "4242",
        "mandate": NSNull(),
        "multicapture": [
          "status": "unavailable"
        ],
        "network": "visa",
        "network_token": [
          "used": false
        ],
        "network_transaction_id": NSNull(),
        "overcapture": [
          "maximum_amount_capturable": 100,
          "status": "unavailable"
        ],
        "regulated_status": NSNull(),
        "three_d_secure": [
          "authentication_flow": NSNull(),
          "electronic_commerce_indicator": NSNull(),
          "exemption_indicator": NSNull(),
          "result": NSNull(),
          "result_reason": NSNull(),
          "transaction_id": NSNull(),
          "version": NSNull()
        ],
        "transaction_link_id": NSNull(),
        "wallet": [
          "dynamic_last4": NSNull(),
          "type": "link"
        ]
      ],
      "type": "card"
    ],
    "receipt_email": NSNull(),
    "receipt_number": NSNull(),
    "receipt_url": "https://example.com/receipts/ch_test_123",
    "refunded": false,
    "refunds": [
      "data": [[
        "amount": 100,
        "balance_transaction": NSNull(),
        "charge": "ch_test_123",
        "created": 1234567890,
        "currency": "usd",
        "customer": NSNull(),
        "customer_account": NSNull(),
        "destination_details": [
          "card": [
            "type": "reversal"
          ],
          "type": "card"
        ],
        "id": "re_test_123",
        "metadata": NSDictionary(),
        "object": "refund",
        "payment_intent": NSNull(),
        "payment_method": NSNull(),
        "reason": NSNull(),
        "receipt_number": NSNull(),
        "source_transfer_reversal": NSNull(),
        "status": "succeeded",
        "transfer_reversal": NSNull()
      ]],
      "has_more": false,
      "object": "list",
      "url": "/v1/charges/ch_test_123/refunds"
    ],
    "review": NSNull(),
    "shipping": NSDictionary(),
    "source_transfer": NSNull(),
    "statement_descriptor": NSNull(),
    "statement_descriptor_suffix": NSNull(),
    "status": "succeeded",
    "transfer_data": [
      "amount": NSNull(),
      "destination": [
        "id": "obj_123",
        "object": "account"
      ]
    ],
    "transfer_group": NSNull()
  ]
