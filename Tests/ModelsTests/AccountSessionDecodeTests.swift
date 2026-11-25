import Foundation
import Testing
@testable import StripeModels

/// Regression: stripe-mock (and the live API) omit the reporting/terminal
/// component configs on POST /v1/account_sessions even though the pinned
/// spec lists them as required; decoding must tolerate the absence.
@Suite("AccountSession decode")
struct AccountSessionDecodeTests {
  /// Captured from stripe-mock's response to the request the UI flow sends
  /// (components[account_onboarding][enabled]=true), with the three keys
  /// the mock leaves out absent, exactly as the API returns it.
  private static let mockPayload = #"""
  {
    "account": "acct_1PgafTB7WZ01zgkW",
    "client_secret": "accs_secret__QXhWgWIhGJ2Zl68tEmbZ29Gtc86adyWl6eEz2h6K7HtpnoB",
    "components": {
      "account_management": {
        "enabled": false,
        "features": {
          "disable_stripe_user_authentication": true,
          "external_account_collection": true
        }
      },
      "account_onboarding": {
        "enabled": true,
        "features": {
          "disable_stripe_user_authentication": true,
          "external_account_collection": true
        }
      },
      "balance_report": {
        "enabled": true,
        "features": {}
      },
      "balances": {
        "enabled": false,
        "features": {
          "disable_stripe_user_authentication": true,
          "edit_payout_schedule": false,
          "external_account_collection": true,
          "instant_payouts": true,
          "standard_payouts": false
        }
      },
      "disputes_list": {
        "enabled": true,
        "features": {
          "capture_payments": true,
          "destination_on_behalf_of_charge_management": true,
          "dispute_management": true,
          "refund_management": true,
          "smart_disputes_management": true
        }
      },
      "documents": {
        "enabled": false,
        "features": {}
      },
      "financial_account": {
        "enabled": true,
        "features": {
          "disable_stripe_user_authentication": true,
          "external_account_collection": true,
          "send_money": true,
          "transfer_balance": true
        }
      },
      "financial_account_transactions": {
        "enabled": true,
        "features": {
          "card_spend_dispute_management": true
        }
      },
      "instant_payouts_promotion": {
        "enabled": true,
        "features": {
          "disable_stripe_user_authentication": true,
          "external_account_collection": true,
          "instant_payouts": true
        }
      },
      "issuing_card": {
        "enabled": true,
        "features": {
          "card_management": true,
          "card_spend_dispute_management": true,
          "cardholder_management": true,
          "spend_control_management": true
        }
      },
      "issuing_cards_list": {
        "enabled": true,
        "features": {
          "card_management": true,
          "card_spend_dispute_management": true,
          "cardholder_management": true,
          "disable_stripe_user_authentication": true,
          "spend_control_management": true
        }
      },
      "notification_banner": {
        "enabled": false,
        "features": {
          "disable_stripe_user_authentication": true,
          "external_account_collection": true
        }
      },
      "payment_details": {
        "enabled": false,
        "features": {
          "capture_payments": true,
          "destination_on_behalf_of_charge_management": false,
          "dispute_management": true,
          "refund_management": true,
          "smart_disputes_management": true
        }
      },
      "payment_disputes": {
        "enabled": true,
        "features": {
          "destination_on_behalf_of_charge_management": true,
          "dispute_management": true,
          "refund_management": true,
          "smart_disputes_management": true
        }
      },
      "payment_method_settings": {
        "enabled": true,
        "features": {
          "disable_stripe_user_authentication": true
        }
      },
      "payments": {
        "enabled": false,
        "features": {
          "capture_payments": true,
          "destination_on_behalf_of_charge_management": false,
          "dispute_management": true,
          "refund_management": true,
          "smart_disputes_management": true
        }
      },
      "payout_details": {
        "enabled": true,
        "features": {}
      },
      "payout_reconciliation_report": {
        "enabled": true,
        "features": {}
      },
      "payouts": {
        "enabled": false,
        "features": {
          "disable_stripe_user_authentication": true,
          "edit_payout_schedule": false,
          "external_account_collection": true,
          "instant_payouts": true,
          "standard_payouts": false
        }
      },
      "payouts_list": {
        "enabled": false,
        "features": {}
      },
      "tax_registrations": {
        "enabled": false,
        "features": {}
      },
      "tax_settings": {
        "enabled": false,
        "features": {}
      }
    },
    "expires_at": 1234567890,
    "livemode": false,
    "object": "account_session"
  }
  """#

  @Test func decodesWhenReportingAndTerminalConfigsAreAbsent() throws {
    let session = try JSONDecoder().decode(
      AccountSession.self, from: Data(Self.mockPayload.utf8))
    #expect(session.clientSecret == "accs_secret__QXhWgWIhGJ2Zl68tEmbZ29Gtc86adyWl6eEz2h6K7HtpnoB")
    #expect(session.components.accountOnboarding.enabled)
    #expect(session.components.reportingChart == nil)
    #expect(session.components.terminalHardwareOrders == nil)
    #expect(session.components.terminalHardwareShop == nil)
  }
}
