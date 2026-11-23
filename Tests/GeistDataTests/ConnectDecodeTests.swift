// ConnectDecodeTests.swift — Tests/GeistDataTests
// The M8 Connect data layer (decision 0032). Decode fixtures mirror the
// responses stripe-mock 0.206.0 actually serves for the v1 Connect endpoints
// (probed against the decision 0029 overlay): an Account with requirements,
// capabilities and external accounts; a Capability; a Person; a BankAccount
// external account; account_link and login_link creations; an account
// session. All IDs are obviously fake (`*_test_*`).

import Foundation
import StripeModels
import StripeClient
import XCTest
@testable import GeistData

final class ConnectDecodeTests: XCTestCase {
    private let decoder = JSONDecoder()

    // MARK: - Fixtures (shapes the mock returns; required keys from the spec)

    private let accountJSON = """
    {
      "id": "acct_test_123",
      "object": "account",
      "business_profile": {"name": "alice inc", "url": "https://example.com"},
      "business_type": "company",
      "capabilities": {"card_payments": "active", "transfers": "active"},
      "charges_enabled": true,
      "controller": {"type": "application", "is_controller": true},
      "country": "US",
      "created": 1234567890,
      "default_currency": "usd",
      "details_submitted": true,
      "email": "alice@example.com",
      "external_accounts": {"data": [], "has_more": false, "object": "list", "total_count": 0, "url": "/v1/accounts/acct_test_123/external_accounts"},
      "future_requirements": {
        "alternatives": [],
        "current_deadline": null,
        "currently_due": [],
        "disabled_reason": null,
        "errors": [],
        "eventually_due": [],
        "past_due": []
      }
      "metadata": {},
      "payouts_enabled": true,
      "requirements": {
        "alternatives": [],
        "current_deadline": null,
        "currently_due": ["individual.tax_id"],
        "disabled_reason": null,
        "errors": [],
        "eventually_due": [],
        "past_due": []
      }
      "settings": {
        "bacs_debit_payments": {"display_name": null, "service_user_number": null},
        "branding": {"icon": null, "logo": null, "primary_color": null, "secondary_color": null},
        "card_payments": {
          "decline_on": null,
          "statement_descriptor_prefix": null,
          "statement_descriptor_prefix_kana": null,
          "statement_descriptor_prefix_kanji": null
        }
        "dashboard": {"display_name": "alice inc", "timezone": "US/Eastern"},
        "payout_schedule": {"delay_days": 2, "interval": "daily"},
        "payout_statement_descriptor": "ALICE INC",
        "payouts_enabled": true,
        "payments": {
          "statement_descriptor": null,
          "statement_descriptor_kana": null,
          "statement_descriptor_kanji": null,
          "statement_descriptor_prefix_kana": null
        }
      },
      "tos_acceptance": {"date": 1234567890, "ip": null, "user_agent": null},
      "type": "express"
    }
    """

    private let capabilityJSON = """
    {
      "account": "acct_test_123",
      "id": "card_payments",
      "object": "capability",
      "requested": true,
      "requested_at": 1234567890,
      "requirements": {"alternatives": [], "currently_due": [], "errors": [], "eventually_due": [], "past_due": [], "pending_verification": []},
      "status": "active"
    }
    """

    private let personJSON = """
    {
      "id": "person_test_123",
      "object": "person",
      "account": "acct_test_123",
      "created": 1234567890,
      "email": "bob@example.com",
      "first_name": "Bob",
      "last_name": "Example",
      "livemode": false,
      "metadata": {},
      "relationship": {"owner": true, "percent_ownership": 50},
      "requirements": {"alternatives": [], "currently_due": [], "errors": [], "eventually_due": [], "past_due": [], "pending_verification": []},
      "type": "company_person"
    }
    """

    private let bankAccountJSON = """
    {
      "id": "ba_test_123",
      "object": "bank_account",
      "account": "acct_test_123",
      "account_holder_name": "Alice Example",
      "account_holder_type": "company",
      "account_type": "checking",
      "bank_name": "STRIPE TEST BANK",
      "country": "US",
      "currency": "usd",
      "fingerprint": "fp_test_123",
      "last4": "6789",
      "metadata": {},
      "routing_number": "110000000",
      "status": "new"
    }
    """

    private let accountLinkJSON = """
    {
      "created": 1234567890,
      "expires_at": 1234654290,
      "object": "account_link",
      "url": "https://example.com/setup/s/acct_test_123/MerI6itPZo2K"
    }
    """

    private let loginLinkJSON = """
    {
      "created": 1234567890,
      "object": "login_link",
      "url": "https://example.com/express/acct_test_123/ehJImT2clfHr"
    }
    """

    // The exact response stripe-mock 0.206.0 serves for
    // POST /v1/account_sessions (captured and re-identified; account and
    // client_secret faked). All 22 component keys the pinned spec requires.
    private let accountSessionJSON = #"{
  "account": "acct_test_123",
  "client_secret": "accs_secret_test_1234567890abcdef",
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
    "reporting_chart": {
      "enabled": true,
      "features": {}
    },
    "tax_registrations": {
      "enabled": false,
      "features": {}
    },
    "tax_settings": {
      "enabled": false,
      "features": {}
    },
    "terminal_hardware_orders": {
      "enabled": true,
      "features": {}
    },
    "terminal_hardware_shop": {
      "enabled": true,
      "features": {}
    }
  },
  "expires_at": 1234567891,
  "livemode": false,
  "object": "account_session"
}"#

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try decoder.decode(type, from: Data(json.utf8))
    }

    // MARK: Account

    func testAccountDecodesWithRequirementsAndCapabilities() throws {
        let account = try decode(Account.self, accountJSON)
        XCTAssertEqual(account.id, "acct_test_123")
        XCTAssertEqual(account.businessType?.valueOrNil?.rawValue, "company")
        XCTAssertEqual(account.country, "US")
        XCTAssertEqual(account.chargesEnabled, true)
        XCTAssertEqual(account.payoutsEnabled, true)
        XCTAssertEqual(account.requirements?.currentlyDue.valueOrNil, ["individual.tax_id"])
        XCTAssertEqual(account.capabilities?.cardPayments, .active)
        XCTAssertEqual(account.capabilities?.transfers, .active)
    }

    func testAccountRequirementsNilFieldsDecodeAsNull() throws {
        // Spec-required keys that may be null must decode with an explicit
        // null present (required-but-may-be-null).
        let account = try decode(Account.self, accountJSON)
        XCTAssertNil(account.requirements?.currentDeadline.valueOrNil)
        XCTAssertNil(account.requirements?.disabledReason.valueOrNil)
    }

    // MARK: Capability / Person / External account

    func testCapabilityDecodes() throws {
        let capability = try decode(Capability.self, capabilityJSON)
        XCTAssertEqual(capability.id, "card_payments")
        XCTAssertEqual(capability.status, CapabilityStatus.active)
        XCTAssertTrue(capability.requested)
    }

    func testPersonDecodes() throws {
        let person = try decode(Person.self, personJSON)
        XCTAssertEqual(person.id, "person_test_123")
        XCTAssertEqual(person.email?.valueOrNil, "bob@example.com")
        XCTAssertEqual(person.relationship?.owner.valueOrNil, true)
    }

    func testExternalBankAccountDecodes() throws {
        let bank = try decode(BankAccount.self, bankAccountJSON)
        XCTAssertEqual(bank.id, "ba_test_123")
        XCTAssertEqual(bank.bankName.valueOrNil, "STRIPE TEST BANK")
        XCTAssertEqual(bank.last4, "6789")
    }

    // MARK: Links and sessions

    func testAccountLinkDecodes() throws {
        let link = try decode(AccountLink.self, accountLinkJSON)
        XCTAssertEqual(link.url, "https://example.com/setup/s/acct_test_123/MerI6itPZo2K")
        XCTAssertGreaterThan(link.expiresAt.seconds, 0)
    }

    func testLoginLinkDecodes() throws {
        let link = try decode(LoginLink.self, loginLinkJSON)
        XCTAssertEqual(link.url, "https://example.com/express/acct_test_123/ehJImT2clfHr")
    }

    func testAccountSessionDecodes() throws {
        let session = try decode(AccountSession.self, accountSessionJSON)
        XCTAssertEqual(session.account, "acct_test_123")
        XCTAssertFalse(session.clientSecret.isEmpty)
    }

    // MARK: Mock-sample round trip

    func testMockAccountSampleDecodesAndRoundTrips() throws {
        let account = try decode(Account.self, accountJSON)
        let encoded = try JSONEncoder().encode(account)
        let reparsed = try decoder.decode(Account.self, from: encoded)
        XCTAssertEqual(reparsed, account)
    }
}
