import Foundation
import StripeModels
import XCTest
@testable import GeistData

/// PaymentsFilter (M4c-5, decision 0019): matching semantics over decoded
/// fixtures. All values are obviously fake (`*_test_*` IDs, small amounts).
final class PaymentsFilterTests: XCTestCase {
    private let decoder = JSONDecoder()

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try decoder.decode(type, from: Data(json.utf8))
    }

    private static let expandedCustomerJSON =
        #"{"created": 1750000000, "id": "cus_test_456", "livemode": false, "object": "customer"}"#

    // MARK: - Fixtures

    private func intent(
        id: String = "pi_test_123",
        status: String = "succeeded",
        amount: Int = 1000,
        created: Int = 1750000000,
        customer: String? = nil,
        methods: [String] = ["card"]
    ) throws -> PaymentIntent {
        // A customer is either a bare ID or, when it starts with `{`, a raw
        // JSON object (the expanded-customer fixture).
        let customerJSON = customer.map { $0.hasPrefix("{") ? $0 : "\"" + $0 + "\"" } ?? "null"
        let methodsJSON = methods.map { "\"" + $0 + "\"" }.joined(separator: ", ")
        let json = """
        {
          "allowed_payment_method_types": null,
          "amount": \(amount),
          "amount_capturable": 0,
          "amount_details": {},
          "amount_received": 0,
          "application": null,
          "application_fee_amount": null,
          "automatic_payment_methods": {"enabled": true},
          "canceled_at": 1234567890,
          "cancellation_reason": null,
          "capture_method": "automatic",
          "client_secret": "pi_test_123_secret_testvalue",
          "confirmation_method": "automatic",
          "created": \(created),
          "currency": "usd",
          "customer": \(customerJSON),
          "customer_account": null,
          "description": "Test intent",
          "excluded_payment_method_types": null,
          "id": "\(id)",
          "last_payment_error": {"type": "idempotency_error"},
          "latest_charge": null,
          "livemode": false,
          "managed_payments": {"enabled": true},
          "metadata": {},
          "next_action": {"type": "type"},
          "object": "payment_intent",
          "on_behalf_of": null,
          "payment_method": null,
          "payment_method_configuration_details": {"id": "obj_test_123", "parent": null},
          "payment_method_options": {},
          "payment_method_types": [\(methodsJSON)],
          "payment_record": null,
          "processing": {"type": "card"},
          "receipt_email": null,
          "review": null,
          "setup_future_usage": null,
          "shipping": {},
          "statement_descriptor": null,
          "statement_descriptor_suffix": null,
          "status": "\(status)",
          "transfer_data": {"destination": {"id": "obj_test_123", "object": "account"}},
          "transfer_group": null
        }
        """
        return try decode(PaymentIntent.self, json)
    }

    private func charge(
        id: String = "ch_test_123",
        status: String = "succeeded",
        amount: Int = 1000,
        created: Int = 1750000000,
        customer: String? = nil,
        detailsType: String = "card"
    ) throws -> Charge {
        // A customer is either a bare ID or, when it starts with `{`, a raw
        // JSON object (the expanded-customer fixture).
        let customerJSON = customer.map { $0.hasPrefix("{") ? $0 : "\"" + $0 + "\"" } ?? "null"
        let json = """
        {
          "amount": \(amount),
          "amount_captured": 0,
          "amount_refunded": 0,
          "application": null,
          "application_fee": null,
          "application_fee_amount": null,
          "balance_transaction": "txn_test_123",
          "billing_details": {"name": "Alice"},
          "calculated_statement_descriptor": null,
          "captured": false,
          "created": \(created),
          "currency": "usd",
          "customer": \(customerJSON),
          "description": "Test charge",
          "disputed": false,
          "failure_balance_transaction": null,
          "failure_code": null,
          "failure_message": null,
          "fraud_details": {},
          "id": "\(id)",
          "livemode": false,
          "metadata": {},
          "object": "charge",
          "on_behalf_of": null,
          "outcome": {"type": "type"},
          "paid": true,
          "payment_intent": null,
          "payment_method": "card_test_123",
          "payment_method_details": {"type": "\(detailsType)"},
          "receipt_email": null,
          "receipt_number": null,
          "refunded": false,
          "refunds": {
            "data": [],
            "has_more": false,
            "object": "list",
            "url": "/v1/charges/ch_test_123/refunds"
          },
          "review": null,
          "shipping": {},
          "source_transfer": null,
          "statement_descriptor": null,
          "statement_descriptor_suffix": null,
          "status": "\(status)",
          "transfer_data": {"amount": null, "destination": {"id": "obj_test_123", "object": "account"}},
          "transfer_group": null
        }
        """
        return try decode(Charge.self, json)
    }

    private func refund(
        id: String = "re_test_123",
        status: String = "succeeded",
        amount: Int = 1000,
        created: Int = 1750000000,
        customer: String? = nil
    ) throws -> Refund {
        // A customer is either a bare ID or, when it starts with `{`, a raw
        // JSON object (the expanded-customer fixture).
        let customerJSON = customer.map { $0.hasPrefix("{") ? $0 : "\"" + $0 + "\"" } ?? "null"
        let json = """
        {
          "amount": \(amount),
          "balance_transaction": null,
          "charge": "ch_test_123",
          "created": \(created),
          "currency": "usd",
          "customer": \(customerJSON),
          "customer_account": null,
          "destination_details": {"type": "card"},
          "id": "\(id)",
          "metadata": {},
          "object": "refund",
          "payment_intent": null,
          "payment_method": null,
          "reason": null,
          "receipt_number": null,
          "source_transfer_reversal": null,
          "status": "\(status)",
          "transfer_reversal": null
        }
        """
        return try decode(Refund.self, json)
    }

    private func setupIntent(
        id: String = "seti_test_123",
        status: String = "succeeded",
        created: Int = 1750000000,
        customer: String? = nil,
        methods: [String] = ["card"]
    ) throws -> SetupIntent {
        // A customer is either a bare ID or, when it starts with `{`, a raw
        // JSON object (the expanded-customer fixture).
        let customerJSON = customer.map { $0.hasPrefix("{") ? $0 : "\"" + $0 + "\"" } ?? "null"
        let methodsJSON = methods.map { "\"" + $0 + "\"" }.joined(separator: ", ")
        let json = """
        {
          "allowed_payment_method_types": null,
          "application": null,
          "automatic_payment_methods": {"enabled": null},
          "cancellation_reason": null,
          "client_secret": "seti_test_123_secret_testvalue",
          "created": \(created),
          "customer": \(customerJSON),
          "description": null,
          "excluded_payment_method_types": null,
          "flow_directions": null,
          "id": "\(id)",
          "last_setup_error": {"type": "idempotency_error"},
          "latest_attempt": null,
          "livemode": false,
          "mandate": null,
          "metadata": {},
          "next_action": {"type": "type"},
          "object": "setup_intent",
          "on_behalf_of": null,
          "payment_method": null,
          "payment_method_configuration_details": {"id": "obj_test_123", "parent": null},
          "payment_method_options": {},
          "payment_method_types": [\(methodsJSON)],
          "single_use_mandate": null,
          "status": "\(status)",
          "usage": "off_session"
        }
        """
        return try decode(SetupIntent.self, json)
    }

    private func method(
        id: String = "pm_test_123",
        type: String = "card",
        created: Int = 1750000000,
        customer: String? = nil
    ) throws -> PaymentMethod {
        // A customer is either a bare ID or, when it starts with `{`, a raw
        // JSON object (the expanded-customer fixture).
        let customerJSON = customer.map { $0.hasPrefix("{") ? $0 : "\"" + $0 + "\"" } ?? "null"
        let json = """
        {
          "allow_redisplay": "unspecified",
          "billing_details": {"name": "Alice"},
          "card": {
            "brand": "visa",
            "checks": {"address_line1_check": null, "address_postal_code_check": null, "cvc_check": "pass"},
            "country": "US",
            "display_brand": "visa",
            "exp_month": 8,
            "exp_year": 2030,
            "fingerprint": "fp_test_123",
            "funding": "credit",
            "generated_from": null,
            "last4": "4242",
            "networks": {"available": ["visa"], "preferred": null},
            "regulated_status": null,
            "three_d_secure_usage": {"supported": true},
            "wallet": null
          },
          "created": \(created),
          "customer": \(customerJSON),
          "customer_account": null,
          "id": "\(id)",
          "livemode": false,
          "metadata": {},
          "object": "payment_method",
          "type": "\(type)"
        }
        """
        return try decode(PaymentMethod.self, json)
    }

    private func link(
        id: String = "plink_test_123",
        active: Bool = true,
        methods: [String]? = nil
    ) throws -> PaymentLink {
        let activeJSON = active ? "true" : "false"
        let methodsJSON = methods.map { types in
            "[" + types.map { "\"" + $0 + "\"" }.joined(separator: ", ") + "]"
        } ?? "null"
        let json = """
        {
          "active": \(activeJSON),
          "after_completion": {"hosted_confirmation": {"custom_message": null}, "type": "hosted_confirmation"},
          "allow_promotion_codes": false,
          "application": null,
          "application_fee_amount": null,
          "application_fee_percent": null,
          "automatic_tax": {"enabled": false, "liability": {"type": "account"}},
          "billing_address_collection": "auto",
          "consent_collection": {"payment_method_reuse_agreement": {"position": "hidden"}, "promotions": null, "terms_of_service": null},
          "currency": "usd",
          "custom_fields": [],
          "custom_text": {
            "after_submit": {"message": "message"},
            "shipping_address": {"message": "message"},
            "submit": {"message": "message"},
            "terms_of_service_acceptance": {"message": "message"}
          },
          "customer_creation": "if_required",
          "id": "\(id)",
          "inactive_message": null,
          "invoice_creation": {
            "enabled": true,
            "invoice_data": {
              "account_tax_ids": null,
              "custom_fields": null,
              "description": null,
              "footer": null,
              "issuer": {"type": "account"},
              "metadata": null,
              "rendering_options": {"amount_tax_display": null, "template": null}
            }
          },
          "livemode": false,
          "managed_payments": {"enabled": true},
          "metadata": {},
          "object": "payment_link",
          "on_behalf_of": null,
          "payment_intent_data": {
            "capture_method": null,
            "description": null,
            "metadata": {"order_key": "value"},
            "setup_future_usage": null,
            "statement_descriptor": null,
            "statement_descriptor_suffix": null,
            "transfer_group": null
          },
          "payment_method_collection": "if_required",
          "payment_method_options": {"card": {"restrictions": {"brands_blocked": ["discover_global_network"]}}},
          "payment_method_types": \(methodsJSON),
          "phone_number_collection": {"enabled": false},
          "restrictions": {"completed_sessions": {"count": 0, "limit": 0}},
          "shipping_address_collection": {"allowed_countries": ["US"]},
          "shipping_options": [],
          "submit_type": "auto",
          "subscription_data": {
            "description": null,
            "invoice_settings": {"issuer": {"type": "account"}},
            "metadata": {"order_key": "value"},
            "trial_period_days": null,
            "trial_settings": {"end_behavior": {"missing_payment_method": "cancel"}}
          },
          "tax_id_collection": {"enabled": false, "required": "never"},
          "transfer_data": {"amount": null, "destination": {"id": "obj_test_123", "object": "account"}},
          "url": "https://example.com/plink_test_123"
        }
        """
        return try decode(PaymentLink.self, json)
    }

    // MARK: - Empty filter and intervals

    func testEmptyFilterMatchesEverything() throws {
        let filter = PaymentsFilter.none
        XCTAssertTrue(filter.isEmpty)
        XCTAssertTrue(try filter.matches(intent()))
        XCTAssertTrue(try filter.matches(charge()))
        XCTAssertTrue(try filter.matches(refund()))
        XCTAssertTrue(try filter.matches(setupIntent()))
        XCTAssertTrue(try filter.matches(method()))
        XCTAssertTrue(try filter.matches(link()))
    }

    func testCreatedIntervalRequiresBothBounds() {
        let start = Date(timeIntervalSince1970: 1_750_000_000)
        let end = Date(timeIntervalSince1970: 1_760_000_000)
        XCTAssertNil(PaymentsFilter(dateStart: start).createdInterval)
        XCTAssertNil(PaymentsFilter(dateEnd: end).createdInterval)
        XCTAssertEqual(PaymentsFilter(dateStart: start, dateEnd: end).createdInterval, DateInterval(start: start, end: end))
    }

    // MARK: - PaymentIntent

    func testIntentCreatedStartInclusiveEndExclusive() throws {
        let filter = PaymentsFilter(
            dateStart: Date(timeIntervalSince1970: 1_750_000_000),
            dateEnd: Date(timeIntervalSince1970: 1_750_000_100)
        )
        let atStart = try intent(created: 1_750_000_000)
        let between = try intent(created: 1_750_000_050)
        let atEnd = try intent(created: 1_750_000_100)
        XCTAssertTrue(filter.matches(atStart))
        XCTAssertTrue(filter.matches(between))
        XCTAssertFalse(filter.matches(atEnd))
    }

    func testIntentAmountBounds() throws {
        let both = try intent(amount: 1500)
        XCTAssertTrue(PaymentsFilter(amountMin: 1000, amountMax: 2000).matches(both))
        XCTAssertFalse(PaymentsFilter(amountMin: 2000).matches(both))
        XCTAssertFalse(PaymentsFilter(amountMax: 1000).matches(both))
        // Inclusive bounds.
        XCTAssertTrue(PaymentsFilter(amountMin: 1500, amountMax: 1500).matches(both))
    }

    func testIntentCustomerMatches() throws {
        XCTAssertEqual(
            PaymentsFilter(customer: "cus_test_456")
                .matches(try intent(customer: "cus_test_456")),
            true
        )
        XCTAssertFalse(PaymentsFilter(customer: "cus_test_999").matches(try intent(customer: "cus_test_456")))
        // Expanded customer object matches by ID.
        XCTAssertTrue(
            PaymentsFilter(customer: "cus_test_456")
                .matches(try intent(customer: Self.expandedCustomerJSON))
        )
        // An intent without a customer never matches a customer filter.
        XCTAssertFalse(PaymentsFilter(customer: "cus_test_456").matches(try intent()))
    }

    func testIntentStatusMatchesRawValue() throws {
        let succeeded = try intent(status: "succeeded")
        let requiresMethod = try intent(status: "requires_payment_method")
        XCTAssertTrue(PaymentsFilter(status: "succeeded").matches(succeeded))
        XCTAssertFalse(PaymentsFilter(status: "requires_payment_method").matches(succeeded))
        XCTAssertTrue(PaymentsFilter(status: "requires_payment_method").matches(requiresMethod))
    }

    func testIntentMethodTypeMatches() throws {
        let mixed = try intent(methods: ["card", "sepa_debit"])
        XCTAssertTrue(PaymentsFilter(methodType: "card").matches(mixed))
        XCTAssertFalse(PaymentsFilter(methodType: "us_bank_account").matches(mixed))
    }

    // MARK: - Charge

    func testChargeStatusAndTypeMatch() throws {
        let card = try charge(status: "succeeded", detailsType: "card")
        let sepa = try charge(status: "pending", detailsType: "sepa_debit")
        XCTAssertTrue(PaymentsFilter(status: "succeeded").matches(card))
        XCTAssertFalse(PaymentsFilter(status: "failed").matches(card))
        XCTAssertTrue(PaymentsFilter(methodType: "sepa_debit").matches(sepa))
        XCTAssertFalse(PaymentsFilter(methodType: "card").matches(sepa))
        // A charge with no payment method details never matches a type filter.
        XCTAssertFalse(PaymentsFilter(methodType: "card").matches(try charge(detailsType: "")))
    }

    func testChargeAmountCreatedAndCustomer() throws {
        let charge = try self.charge(amount: 2500, created: 1_750_000_050, customer: "cus_test_456")
        let filter = PaymentsFilter(
            dateStart: Date(timeIntervalSince1970: 1_750_000_000),
            dateEnd: Date(timeIntervalSince1970: 1_750_000_100),
            customer: "cus_test_456",
            amountMin: 2000,
            amountMax: 3000
        )
        XCTAssertTrue(filter.matches(charge))
        XCTAssertFalse(filter.matches(charge: charge, customer: "cus_test_999"))
        XCTAssertFalse(filter.matches(charge: charge, amountMin: 3000))
        XCTAssertFalse(filter.matches(charge: charge, dateStart: Date(timeIntervalSince1970: 1_750_000_100)))
    }

    // MARK: - Refund

    func testRefundStatusAmountAndCustomer() throws {
        let pending = try refund(status: "pending", amount: 500, customer: "cus_test_456")
        XCTAssertTrue(PaymentsFilter(status: "pending").matches(pending))
        XCTAssertFalse(PaymentsFilter(status: "succeeded").matches(pending))
        XCTAssertTrue(PaymentsFilter(amountMin: 500, amountMax: 500).matches(pending))
        XCTAssertTrue(PaymentsFilter(customer: "cus_test_456").matches(pending))
        XCTAssertFalse(PaymentsFilter(customer: "cus_test_999").matches(pending))
    }

    // MARK: - SetupIntent

    func testSetupIntentStatusMethodAndCustomer() throws {
        let setup = try setupIntent(status: "requires_payment_method", customer: "cus_test_456", methods: ["card"])
        XCTAssertTrue(PaymentsFilter(status: "requires_payment_method").matches(setup))
        XCTAssertFalse(PaymentsFilter(status: "succeeded").matches(setup))
        XCTAssertTrue(PaymentsFilter(methodType: "card").matches(setup))
        XCTAssertFalse(PaymentsFilter(methodType: "sepa_debit").matches(setup))
        XCTAssertTrue(PaymentsFilter(customer: "cus_test_456").matches(setup))
        XCTAssertFalse(PaymentsFilter(customer: "cus_test_999").matches(setup))
    }

    // MARK: - PaymentMethod

    func testMethodTypeAndCustomer() throws {
        let card = try method(type: "card", customer: "cus_test_456")
        XCTAssertTrue(PaymentsFilter(methodType: "card").matches(card))
        XCTAssertFalse(PaymentsFilter(methodType: "sepa_debit").matches(card))
        XCTAssertTrue(PaymentsFilter(customer: "cus_test_456").matches(card))
        // Expanded customer object matches by ID.
        let expanded = try method(customer: Self.expandedCustomerJSON)
        XCTAssertTrue(PaymentsFilter(customer: "cus_test_456").matches(expanded))
        // A method without a customer never matches a customer filter.
        XCTAssertFalse(PaymentsFilter(customer: "cus_test_456").matches(try method()))
    }

    // MARK: - PaymentLink

    func testLinkActiveFilter() throws {
        let active = try link(active: true)
        let inactive = try link(active: false)
        XCTAssertTrue(PaymentsFilter(linkActive: true).matches(active))
        XCTAssertFalse(PaymentsFilter(linkActive: true).matches(inactive))
        XCTAssertTrue(PaymentsFilter(linkActive: false).matches(inactive))
        XCTAssertTrue(PaymentsFilter().matches(active))
        XCTAssertTrue(PaymentsFilter().matches(inactive))
    }

    func testLinkMethodTypeFilter() throws {
        let card = try link(methods: ["card"])
        let multi = try link(methods: ["card", "sepa_debit"])
        let none = try link(methods: nil)
        XCTAssertTrue(PaymentsFilter(methodType: "card").matches(card))
        XCTAssertTrue(PaymentsFilter(methodType: "sepa_debit").matches(multi))
        XCTAssertFalse(PaymentsFilter(methodType: "card").matches(none))
    }

    // MARK: - Payout

    func testPayoutStatusAmountAndCreated() throws {
        let paid = try payout(status: "paid", amount: 1100, created: 1_750_000_050)
        XCTAssertTrue(PaymentsFilter(status: "paid").matches(paid))
        XCTAssertFalse(PaymentsFilter(status: "pending").matches(paid))
        XCTAssertTrue(PaymentsFilter(amountMin: 1100, amountMax: 1100).matches(paid))
        XCTAssertFalse(PaymentsFilter(amountMax: 1000).matches(paid))
        XCTAssertTrue(
            PaymentsFilter(
                dateStart: Date(timeIntervalSince1970: 1_750_000_000),
                dateEnd: Date(timeIntervalSince1970: 1_750_000_100)
            ).matches(paid)
        )
    }

    // MARK: - Transfer

    func testTransferAmountAndCreated() throws {
        let transfer = try self.transfer(amount: 800, created: 1_750_000_050)
        XCTAssertTrue(PaymentsFilter(amountMin: 800, amountMax: 800).matches(transfer))
        XCTAssertFalse(PaymentsFilter(amountMin: 900).matches(transfer))
        XCTAssertFalse(PaymentsFilter(amountMax: 700).matches(transfer))
        // Status is not a transfers field; an irrelevant status filter is
        // ignored (same convention as payment methods).
        XCTAssertFalse(PaymentsFilter.fields(for: .transfers).contains(.status))
        XCTAssertTrue(
            PaymentsFilter(
                dateStart: Date(timeIntervalSince1970: 1_750_000_000),
                dateEnd: Date(timeIntervalSince1970: 1_750_000_100)
            ).matches(transfer)
        )
    }

    // MARK: - Topup

    func testTopupStatusAmountAndCreated() throws {
        let succeeded = try topup(status: "succeeded", amount: 5000, created: 1_750_000_050)
        XCTAssertTrue(PaymentsFilter(status: "succeeded").matches(succeeded))
        XCTAssertFalse(PaymentsFilter(status: "failed").matches(succeeded))
        XCTAssertTrue(PaymentsFilter(amountMin: 5000).matches(succeeded))
        XCTAssertFalse(PaymentsFilter(amountMax: 4000).matches(succeeded))
        XCTAssertTrue(
            PaymentsFilter(
                dateStart: Date(timeIntervalSince1970: 1_750_000_000),
                dateEnd: Date(timeIntervalSince1970: 1_750_000_100)
            ).matches(succeeded)
        )
    }

    // MARK: - Report run

    /// Report runs carry no customer, method type, or status field beyond
    /// their `status` string; the run's created date applies.
    func testReportRunStatusAndCreated() throws {
        let succeeded = try reportRun(status: "succeeded", created: 1_750_000_050)
        XCTAssertTrue(PaymentsFilter(status: "succeeded").matches(succeeded))
        XCTAssertFalse(PaymentsFilter(status: "failed").matches(succeeded))
        XCTAssertTrue(
            PaymentsFilter(
                dateStart: Date(timeIntervalSince1970: 1_750_000_000),
                dateEnd: Date(timeIntervalSince1970: 1_750_000_100)
            ).matches(succeeded)
        )
        XCTAssertFalse(
            PaymentsFilter(
                dateStart: Date(timeIntervalSince1970: 1_750_000_100)
            ).matches(succeeded)
        )
        // Customer and method type are not report-run dimensions: a filter
        // that sets only those matches every run.
        XCTAssertTrue(PaymentsFilter(customer: "cus_test_1").matches(succeeded))
        XCTAssertTrue(PaymentsFilter(methodType: "card").matches(succeeded))
        XCTAssertFalse(PaymentsFilter.fields(for: .reports).contains(.customer))
        XCTAssertFalse(PaymentsFilter.fields(for: .reports).contains(.methodType))
        XCTAssertTrue(PaymentsFilter.fields(for: .reports).contains(.status))
        XCTAssertTrue(PaymentsFilter.fields(for: .reports).contains(.dateRange))
    }

    private func reportRun(
        id: String = "frr_test_123",
        status: String = "succeeded",
        created: Int = 1750000000
    ) throws -> ReportingReportRun {
        let json = """
        {
          "id": "\(id)",
          "object": "reporting.report_run",
          "created": \(created),
          "error": null,
          "livemode": false,
          "parameters": {
            "interval_end": \(created + 86_400),
            "interval_start": \(created)
          },
          "report_type": "balance.summary.1",
          "result": null,
          "status": "\(status)",
          "succeeded_at": \(status == "succeeded" ? String(created) : "null")
        }
        """
        return try decode(ReportingReportRun.self, json)
    }

    // MARK: - Segments and fields

    func testFieldsPerSegment() {
        let intents = PaymentsFilter.fields(for: .paymentIntents)
        XCTAssertTrue(
            intents.isSuperset(of: [.dateRange, .customer, .status, .amount, .methodType])
        )
        // Payment links carry no created timestamp or customer field.
        XCTAssertFalse(PaymentsFilter.fields(for: .paymentLinks).contains(.dateRange))
        XCTAssertFalse(PaymentsFilter.fields(for: .paymentLinks).contains(.customer))
        // Refunds have no payment-method type.
        XCTAssertFalse(PaymentsFilter.fields(for: .refunds).contains(.methodType))
        // Methods carry no amount or status.
        XCTAssertFalse(PaymentsFilter.fields(for: .paymentMethods).contains(.amount))
        XCTAssertFalse(PaymentsFilter.fields(for: .paymentMethods).contains(.status))
    }

    func testIsRelevantTracksSetDimensions() {
        XCTAssertTrue(PaymentsFilter(status: "succeeded").isRelevant(to: .paymentIntents))
        XCTAssertFalse(PaymentsFilter(status: "succeeded").isRelevant(to: .paymentMethods))
        XCTAssertFalse(PaymentsFilter(status: "succeeded").isRelevant(to: .paymentLinks))
        XCTAssertTrue(PaymentsFilter(linkActive: true).isRelevant(to: .paymentLinks))
        XCTAssertFalse(PaymentsFilter(linkActive: true).isRelevant(to: .charges))
        // Dates are relevant to methods (they have created) but not to links.
        XCTAssertTrue(
            PaymentsFilter(dateStart: Date(timeIntervalSince1970: 1_750_000_000))
                .isRelevant(to: .paymentMethods)
        )
        XCTAssertFalse(
            PaymentsFilter(dateStart: Date(timeIntervalSince1970: 1_750_000_000))
                .isRelevant(to: .paymentLinks)
        )
        XCTAssertFalse(PaymentsFilter.none.isRelevant(to: .charges))
    }
}

private extension PaymentsFilter {
    /// Convenience so charge-match tests can vary one dimension without
    /// re-decoding full JSON for each variant.
    func matches(
        charge base: Charge,
        customer: String? = nil,
        amountMin: Int? = nil,
        dateStart: Date? = nil
    ) -> Bool {
        var varied = self
        if let customer { varied.customer = customer }
        if let amountMin { varied.amountMin = amountMin }
        if let dateStart { varied.dateStart = dateStart }
        return varied.matches(base)
    }
}

// MARK: - Money-flow fixture builders

private extension PaymentsFilterTests {
    private func payout(
        id: String = "po_test_123",
        status: String = "paid",
        amount: Int = 1000,
        created: Int = 1750000000
    ) throws -> Payout {
        let json = """
        {
          "amount": \(amount),
          "arrival_date": \(created + 86_400),
          "automatic": true,
          "balance_transaction": "txn_test_123",
          "created": \(created),
          "currency": "usd",
          "date": null,
          "destination": "ba_test_123",
          "failure_code": null,
          "failure_message": null,
          "id": "\(id)",
          "livemode": false,
          "metadata": {},
          "method": "standard",
          "object": "payout",
          "original_payout": null,
          "reconciliation_status": "not_applicable",
          "reversed_by": null,
          "statement_descriptor": null,
          "status": "\(status)",
          "type": "bank_account",
          "source_type": "card"
        }
        """
        return try decode(Payout.self, json)
    }

    private func transfer(
        id: String = "tr_test_123",
        amount: Int = 1000,
        created: Int = 1750000000
    ) throws -> Transfer {
        let json = """
        {
          "id": "\(id)",
          "object": "transfer",
          "amount": \(amount),
          "amount_reversed": 0,
          "balance_transaction": "txn_test_456",
          "created": \(created),
          "currency": "usd",
          "description": null,
          "destination": "acct_test_123",
          "livemode": false,
          "metadata": {},
          "reversed": false,
          "source_transaction": null,
          "source_type": "card",
          "transfer_group": null,
          "reversals": {
            "object": "list",
            "total_count": 0,
            "has_more": false,
            "url": "/v1/transfers/\(id)/reversals",
            "data": []
          }
        }
        """
        return try decode(Transfer.self, json)
    }

    private func topup(
        id: String = "tu_test_123",
        status: String = "succeeded",
        amount: Int = 1000,
        created: Int = 1750000000
    ) throws -> Topup {
        let json = """
        {
          "id": "\(id)",
          "object": "topup",
          "amount": \(amount),
          "balance_transaction": "txn_test_789",
          "created": \(created),
          "currency": "usd",
          "description": null,
          "expected_availability_date": \(created + 86_400),
          "failure_code": null,
          "failure_message": null,
          "initiated_by": "user",
          "livemode": false,
          "metadata": {},
          "source": null,
          "statement_descriptor": null,
          "status": "\(status)",
          "transfer_group": null
        }
        """
        return try decode(Topup.self, json)
    }
}
