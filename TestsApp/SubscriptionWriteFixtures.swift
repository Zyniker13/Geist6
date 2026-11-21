// SubscriptionWriteFixtures.swift — TestsApp
// Response fixtures for the subscription write-path tests. The shape follows
// stripe-mock (0.206.0) for /v1/subscriptions against the pinned spec; every
// value is obviously fake (`sub_123`, `si_123`, `price_123`, `plan_123`,
// `cus_123`). The subscription item carries a `plan` because the generated
// `SubscriptionItem.plan` is non-optional even though stripe-mock omits it
// for price-based items.

import Foundation

// MARK: - Subscription

nonisolated(unsafe) let subscriptionWriteFixtureJSON = """
{
  "application": null,
  "application_fee_percent": null,
  "automatic_tax": {
    "disabled_reason": null,
    "enabled": false,
    "liability": {
      "type": "account"
    }
  },
  "billing_cycle_anchor": 1234567890,
  "billing_cycle_anchor_config": {
    "day_of_month": 1361669285,
    "hour": null,
    "minute": null,
    "month": null,
    "second": null
  },
  "billing_mode": {
    "flexible": {},
    "type": "classic"
  },
  "billing_schedules": [
    {
      "applies_to": null,
      "bill_until": {
        "computed_timestamp": 2082605468,
        "duration": {
          "interval": "month",
          "interval_count": null
        },
        "timestamp": null,
        "type": "duration"
      },
      "key": "key"
    }
  ],
  "billing_thresholds": {
    "amount_gte": null,
    "reset_billing_cycle_anchor": null
  },
  "cancel_at": 1234567890,
  "cancel_at_period_end": true,
  "canceled_at": 1234567890,
  "cancellation_details": {
    "comment": null,
    "feedback": null,
    "feedback_option": null,
    "reason": null
  },
  "collection_method": "charge_automatically",
  "created": 1234567890,
  "currency": "usd",
  "customer": "cus_123",
  "customer_account": null,
  "days_until_due": null,
  "default_payment_method": null,
  "default_source": null,
  "default_tax_rates": [],
  "description": null,
  "discounts": [],
  "ended_at": 1234567890,
  "id": "sub_123",
  "invoice_settings": {
    "account_tax_ids": null,
    "custom_fields": null,
    "description": null,
    "footer": null,
    "issuer": {
      "type": "self"
    }
  },
  "items": {
    "data": [
      {
        "billing_thresholds": {
          "usage_gte": null
        },
        "created": 1721954060,
        "current_period_end": 976287773,
        "current_period_start": 1896570518,
        "current_trial": {
          "end_date": 1725067410,
          "start_date": 1573629589,
          "trial_offer": "trial_offer"
        },
        "discounts": [],
        "id": "si_123",
        "metadata": {},
        "object": "subscription_item",
        "price": {
          "active": true,
          "billing_scheme": "per_unit",
          "created": 1721948530,
          "currency": "usd",
          "custom_unit_amount": {
            "maximum": null,
            "minimum": null,
            "preset": null
          },
          "id": "price_123",
          "livemode": false,
          "lookup_key": null,
          "metadata": {},
          "nickname": null,
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
          "transform_quantity": {
            "divide_by": 1592560163,
            "round": "down"
          },
          "type": "recurring",
          "unit_amount": 2000,
          "unit_amount_decimal": "2000"
        },
        "quantity": 1,
        "subscription": "sub_123",
        "tax_rates": [],
        "plan": {
          "active": true,
          "amount": 2000,
          "amount_decimal": "2000",
          "billing_scheme": "per_unit",
          "created": 1721948530,
          "currency": "usd",
          "id": "plan_123",
          "interval": "month",
          "interval_count": 1,
          "livemode": false,
          "metadata": {},
          "meter": null,
          "nickname": null,
          "object": "plan",
          "product": "prod_123",
          "tiers_mode": null,
          "transform_usage": {
            "divide_by": 1592560163,
            "round": "down"
          },
          "trial_period_days": null,
          "usage_type": "licensed"
        }
      }
    ],
    "has_more": false,
    "object": "list",
    "url": "/v1/subscription_items?subscription=sub_123"
  },
  "latest_invoice": null,
  "livemode": false,
  "managed_payments": {
    "enabled": true
  },
  "metadata": {},
  "next_pending_invoice_item_invoice": 1234567890,
  "object": "subscription",
  "on_behalf_of": null,
  "pause_collection": {
    "behavior": "mark_uncollectible",
    "resumes_at": null
  },
  "payment_settings": {
    "payment_method_options": {
      "acss_debit": {},
      "bancontact": {
        "preferred_language": "fr"
      },
      "billie": {},
      "card": {
        "network": null,
        "request_three_d_secure": null
      },
      "customer_balance": {
        "funding_type": null
      },
      "konbini": {},
      "payto": {},
      "pix": {},
      "sepa_debit": {},
      "upi": {},
      "us_bank_account": {}
    },
    "payment_method_types": null,
    "save_default_payment_method": null
  },
  "pending_invoice_item_interval": {
    "interval": "month",
    "interval_count": 797691627
  },
  "pending_setup_intent": null,
  "pending_update": {
    "billing_cycle_anchor": null,
    "cancel_at_period_end": null,
    "discount": {
      "checkout_session": null,
      "customer": null,
      "customer_account": null,
      "end": null,
      "id": "disc_123",
      "invoice": null,
      "invoice_item": null,
      "object": "discount",
      "promotion_code": null,
      "source": {
        "coupon": null,
        "type": "coupon"
      },
      "start": 109757538,
      "subscription": null,
      "subscription_item": null
    },
    "discounts": [],
    "expires_at": 833811170,
    "metadata": null,
    "subscription_items": null,
    "trial_end": null,
    "trial_from_plan": null
  },
  "schedule": null,
  "start_date": 1234567890,
  "status": "active",
  "test_clock": null,
  "transfer_data": {
    "amount_percent": null,
    "destination": {
      "id": "acct_test_123",
      "object": "account"
    }
  },
  "trial_end": 1234567890,
  "trial_settings": {
    "end_behavior": {
      "billing_cycle_anchor": null,
      "missing_payment_method": "create_invoice"
    }
  },
  "trial_start": 1234567890
}
"""

nonisolated(unsafe) let subscriptionWriteFixture: [String: Any] = {
  guard let parsed = try? JSONSerialization.jsonObject(with: Data(subscriptionWriteFixtureJSON.utf8)),
    let dict = parsed as? [String: Any] else {
    preconditionFailure("subscriptionWriteFixtureJSON must decode")
  }
  return dict
}()

// MARK: - Canceled subscription

/// Same subscription after a cancel, with status changed to "canceled" so a
/// test can prove the response was decoded, not just the request encoded.
nonisolated(unsafe) let subscriptionCanceledFixture: [String: Any] = {
  var dict = subscriptionWriteFixture
  dict["status"] = "canceled"
  return dict
}()

// MARK: - Subscription item

nonisolated(unsafe) let subscriptionItemFixtureJSON = """
{
  "billing_thresholds": {
    "usage_gte": null
  },
  "created": 1721954060,
  "current_period_end": 976287773,
  "current_period_start": 1896570518,
  "current_trial": {
    "end_date": 1725067410,
    "start_date": 1573629589,
    "trial_offer": "trial_offer"
  },
  "discounts": [],
  "id": "si_123",
  "metadata": {},
  "object": "subscription_item",
  "price": {
    "active": true,
    "billing_scheme": "per_unit",
    "created": 1721948530,
    "currency": "usd",
    "custom_unit_amount": {
      "maximum": null,
      "minimum": null,
      "preset": null
    },
    "id": "price_123",
    "livemode": false,
    "lookup_key": null,
    "metadata": {},
    "nickname": null,
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
    "transform_quantity": {
      "divide_by": 1592560163,
      "round": "down"
    },
    "type": "recurring",
    "unit_amount": 2000,
    "unit_amount_decimal": "2000"
  },
  "quantity": 2,
  "subscription": "sub_123",
  "tax_rates": [],
  "plan": {
    "active": true,
    "amount": 2000,
    "amount_decimal": "2000",
    "billing_scheme": "per_unit",
    "created": 1721948530,
    "currency": "usd",
    "id": "plan_123",
    "interval": "month",
    "interval_count": 1,
    "livemode": false,
    "metadata": {},
    "meter": null,
    "nickname": null,
    "object": "plan",
    "product": "prod_123",
    "tiers_mode": null,
    "transform_usage": {
      "divide_by": 1592560163,
      "round": "down"
    },
    "trial_period_days": null,
    "usage_type": "licensed"
  }
}
"""

nonisolated(unsafe) let subscriptionItemFixture: [String: Any] = {
  guard let parsed = try? JSONSerialization.jsonObject(with: Data(subscriptionItemFixtureJSON.utf8)),
    let dict = parsed as? [String: Any] else {
    preconditionFailure("subscriptionItemFixtureJSON must decode")
  }
  return dict
}()

// MARK: - Deleted discount

nonisolated(unsafe) let deletedDiscountFixture: [String: Any] = [
  "deleted": true,
  "id": "disc_123",
  "object": "discount",
  "source": ["coupon": NSNull(), "type": "coupon"],
  "start": 1234567890,
]
