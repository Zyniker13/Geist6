import Foundation
import StripeModels
import XCTest
@testable import GeistData

/// Checkout sessions (M4c-6): decode parity against the stripe-mock sample
/// shape and `PaymentsFilter` matching semantics over decoded fixtures. All
/// values are obviously fake (`cs_test_123`, example.com, test amounts).
final class CheckoutSessionTests: XCTestCase {
    private let decoder = JSONDecoder()

    private func decodeSession(
        id: String = "cs_test_123",
        created: Int = 1234567890,
        status: String = "open",
        customer: String? = nil
    ) throws -> CheckoutSession {
        // A customer is either a bare ID or, when it starts with `{`, a raw
        // JSON object (the expanded-customer fixture).
        let customerJSON = customer.map { $0.hasPrefix("{") ? $0 : "\"" + $0 + "\"" } ?? "null"
        let json = """
        {
          "adaptive_pricing": {"enabled": true},
          "after_expiration": {
            "recovery": {
              "allow_promotion_codes": true, "enabled": true,
              "expires_at": null, "url": null
            }
          },
          "allow_promotion_codes": null,
          "allowed_payment_method_types": null,
          "amount_subtotal": null,
          "amount_total": null,
          "automatic_tax": {
            "enabled": false,
            "liability": {"type": "account"}, "provider": null, "status": null
          },
          "billing_address_collection": null,
          "cancel_url": "https://example.com/cancel",
          "client_reference_id": null,
          "client_secret": null,
          "collected_information": {
            "business_name": null,
            "individual_name": null,
            "shipping_details": {
              "address": {
                "city": null, "country": null, "line1": null, "line2": null,
                "postal_code": null, "state": null
              },
              "name": "name"
            }
          },
          "consent": {"promotions": null, "terms_of_service": null},
          "consent_collection": {
            "payment_method_reuse_agreement": {"position": "hidden"},
            "promotions": null, "terms_of_service": null
          },
          "created": \(created),
          "currency": null,
          "currency_conversion": {
            "amount_subtotal": 1555417355, "amount_total": 1117121693,
            "fx_rate": "291452898", "source_currency": "usd"
          },
          "custom_fields": [],
          "custom_text": {
            "after_submit": {"message": "message"},
            "shipping_address": {"message": "message"},
            "submit": {"message": "message"},
            "terms_of_service_acceptance": {"message": "message"}
          },
          "customer": \(customerJSON),
          "customer_account": null,
          "customer_creation": null,
          "customer_details": {
            "address": {
              "city": null, "country": null, "line1": null, "line2": null,
              "postal_code": null, "state": null
            },
            "business_name": null,
            "email": "alice@example.com",
            "individual_name": null, "name": null, "phone": null,
            "tax_exempt": "none", "tax_ids": null
          },
          "customer_email": null,
          "discounts": null,
          "expires_at": 1234567890,
          "id": "\(id)",
          "integration_identifier": null,
          "invoice": null,
          "invoice_creation": {
            "enabled": true,
            "invoice_data": {
              "account_tax_ids": null, "custom_fields": null, "description": null,
              "footer": null,
              "issuer": {"type": "account"}, "metadata": null,
              "rendering_options": {"amount_tax_display": null, "template": null}
            }
          },
          "livemode": false,
          "locale": null,
          "managed_payments": {"enabled": true},
          "metadata": {},
          "mode": "payment",
          "object": "checkout.session",
          "origin_context": null,
          "payment_intent": "pi_test_123",
          "payment_link": null,
          "payment_method_collection": null,
          "payment_method_configuration_details": {"id": "obj_123", "parent": null},
          "payment_method_options": {},
          "payment_method_types": ["card"],
          "payment_status": "unpaid",
          "permissions": {"update_shipping_details": null},
          "phone_number_collection": {"enabled": false},
          "recovered_from": null,
          "saved_payment_method_options": {
            "allow_redisplay_filters": null, "payment_method_remove": null,
            "payment_method_save": null
          },
          "setup_intent": null,
          "shipping_address_collection": {"allowed_countries": ["SC"]},
          "shipping_cost": {
            "amount_subtotal": 1555417355, "amount_tax": 1424534716,
            "amount_total": 1117121693, "shipping_rate": null
          },
          "shipping_options": [],
          "status": "\(status)",
          "submit_type": null,
          "subscription": null,
          "success_url": "https://example.com/success",
          "total_details": {
            "amount_discount": 406046392, "amount_shipping": null,
            "amount_tax": 1424534716
          },
          "ui_mode": null,
          "url": "https://checkout.example.com/pay/c/\(id)",
          "wallet_options": {}
        }
        """
        return try decoder.decode(CheckoutSession.self, from: Data(json.utf8))
    }

    // MARK: - Decode

    func testDecodesStripeMockShape() throws {
        let session = try decodeSession()

        XCTAssertEqual(session.id, "cs_test_123")
        XCTAssertEqual(session.object.rawValue, "checkout.session")
        XCTAssertEqual(session.mode.rawValue, "payment")
        XCTAssertEqual(session.status.valueOrNil?.rawValue, "open")
        XCTAssertEqual(session.paymentStatus.rawValue, "unpaid")
        XCTAssertNil(session.amountTotal.valueOrNil, "totals stay null until completion")
        XCTAssertNil(session.currency.valueOrNil)
        XCTAssertNil(session.customer.valueOrNil)
        XCTAssertEqual(
            session.customerDetails.valueOrNil?.email.valueOrNil, "alice@example.com")
        XCTAssertEqual(
            session.url.valueOrNil, "https://checkout.example.com/pay/c/cs_test_123")
        XCTAssertEqual(session.created.date.timeIntervalSince1970, 1_234_567_890)
        XCTAssertEqual(session.paymentIntent.valueOrNil, .id("pi_test_123"))
        XCTAssertEqual(session.totalDetails.valueOrNil?.amountDiscount, 406046392)
    }

    // MARK: - Filter matching

    func testStatusFilterMatchesSessionStatus() throws {
        var session = try decodeSession()
        let open = PaymentsFilter(status: "open")
        XCTAssertTrue(open.matches(session))

        session.status = Nullable(.expired)
        XCTAssertFalse(open.matches(session), "expired must not match an open filter")
        XCTAssertTrue(PaymentsFilter(status: "expired").matches(session))
    }

    func testCustomerFilterMatchesCustomerID() throws {
        let session = try decodeSession(customer: "cus_test_456")
        XCTAssertTrue(PaymentsFilter(customer: "cus_test_456").matches(session))
        XCTAssertFalse(PaymentsFilter(customer: "cus_test_999").matches(session))

        // A session without a customer does not match a customer filter.
        let anonymous = try decodeSession()
        XCTAssertFalse(PaymentsFilter(customer: "cus_test_456").matches(anonymous))
    }

    func testCreatedRangeMatchesHalfOpenInterval() throws {
        let session = try decodeSession(created: 1_750_000_000)
        let inside = PaymentsFilter(
            dateStart: Date(timeIntervalSince1970: 1_750_000_000),
            dateEnd: Date(timeIntervalSince1970: 1_750_100_000)
        )
        XCTAssertTrue(inside.matches(session))

        let before = PaymentsFilter(
            dateEnd: Date(timeIntervalSince1970: 1_749_999_999)
        )
        XCTAssertFalse(before.matches(session))

        let after = PaymentsFilter(
            dateStart: Date(timeIntervalSince1970: 1_750_100_000)
        )
        XCTAssertFalse(after.matches(session))
    }
}
