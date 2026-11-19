import Foundation
import StripeModels
import XCTest
@testable import GeistData

/// Tier-2 payment resources riding along with payments (M4c-7, decision
/// 0022): mandates, confirmation tokens, and the payment intent
/// amount-details line items. Each fixture mirrors the stripe-mock sample
/// shape with PII and values replaced by obviously fake ones
/// (`ma_test_123`, `ctoken_test_123`, `acct_test_123`, example.com).
final class Tier2Tests: XCTestCase {
    private let decoder = JSONDecoder()

    // MARK: Mandate

    private func mandateJSON(
        status: String = "active",
        type: String = "multi_use"
    ) -> Data {
        let json = """
        {
          "customer_acceptance": {
            "accepted_at": 1234567890,
            "online": {
              "ip_address": "203.0.113.10",
              "user_agent": "test-agent/1.0"
            },
            "type": "online"
          },
          "id": "ma_test_123",
          "livemode": false,
          "multi_use": {},
          "object": "mandate",
          "payment_method": "pm_test_123",
          "payment_method_details": {
            "sepa_debit": {"reference": "test-reference", "url": ""},
            "type": "sepa_debit"
          },
          "status": "\(status)",
          "type": "\(type)"
        }
        """
        return Data(json.utf8)
    }

    func testDecodesMandateStripeMockShape() throws {
        let mandate = try decoder.decode(Mandate.self, from: mandateJSON())
        XCTAssertEqual(mandate.id, "ma_test_123")
        XCTAssertEqual(mandate.status, .active)
        XCTAssertEqual(mandate.type, .multiUse)
        XCTAssertEqual(mandate.paymentMethod.idOrNil, "pm_test_123")
        XCTAssertEqual(mandate.livemode, false)
        XCTAssertEqual(mandate.customerAcceptance.type, .online)
    }

    func testMandateUnknownStatusDecodesLosslessly() throws {
        // Lossless enums keep unknown payloads decodable instead of failing.
        let mandate = try decoder.decode(
            Mandate.self, from: mandateJSON(status: "future_status"))
        guard case .undocumented(let raw) = mandate.status else {
            return XCTFail("expected undocumented status, got \(mandate.status)")
        }
        XCTAssertEqual(raw, "future_status")
    }

    // MARK: Confirmation token

    private func confirmationTokenJSON() -> Data {
        let json = """
        {
          "created": 1234567890,
          "expires_at": 1234567890,
          "id": "ctoken_test_123",
          "livemode": true,
          "mandate_data": {
            "customer_acceptance": {
              "online": {"ip_address": null, "user_agent": null},
              "type": "online"
            }
          },
          "metadata": null,
          "object": "confirmation_token",
          "payment_intent": null,
          "payment_method_options": {
            "card": {"cvc_token": null}
          },
          "payment_method_preview": {
            "allow_redisplay": "unspecified",
            "billing_details": {
              "address": {
                "city": "Testville",
                "country": "US",
                "line1": "1 Test Lane",
                "line2": null,
                "postal_code": "00000",
                "state": "CA"
              },
              "email": null,
              "name": "Test User",
              "phone": null,
              "tax_id": null
            },
            "customer": null,
            "customer_account": null,
            "type": "us_bank_account",
            "us_bank_account": {
              "account_holder_type": "company",
              "account_type": "checking",
              "bank_name": "TEST BANK",
              "financial_connections_account": null,
              "fingerprint": "test_fingerprint",
              "last4": "6789",
              "networks": {"preferred": "ach", "supported": ["ach"]},
              "routing_number": "110000000",
              "status_details": {}
            }
          },
          "return_url": "https://example.com/return",
          "setup_future_usage": "off_session",
          "setup_intent": null,
          "shipping": {
            "address": {
              "city": "Testville",
              "country": "US",
              "line1": "1 Test Lane",
              "line2": null,
              "postal_code": "00000",
              "state": "CA"
            },
            "name": "Test Recipient",
            "phone": null
          },
          "use_stripe_sdk": true
        }
        """
        return Data(json.utf8)
    }

    func testDecodesConfirmationTokenStripeMockShape() throws {
        let token = try decoder.decode(ConfirmationToken.self, from: confirmationTokenJSON())
        XCTAssertEqual(token.id, "ctoken_test_123")
        XCTAssertEqual(token.setupFutureUsage.valueOrNil, .offSession)
        XCTAssertEqual(token.expiresAt.valueOrNil?.seconds, 1_234_567_890)
        let preview = token.paymentMethodPreview.valueOrNil
        XCTAssertEqual(preview?.usBankAccount?.last4.valueOrNil, "6789")
    }

    // MARK: Payment intent amount-details line items

    private func lineItemsJSON() -> Data {
        let json = """
        {
          "object": "list",
          "data": [
            {
              "discount_amount": null,
              "id": "li_test_1",
              "object": "payment_intent_amount_details_line_item",
              "payment_method_options": {},
              "product_code": null,
              "product_name": "Test product",
              "quantity": 2,
              "tax": {"total_tax_amount": 100},
              "unit_cost": 1500,
              "unit_of_measure": null
            }
          ],
          "has_more": false,
          "url": "/v1/payment_intents/pi_test_123/amount_details_line_items"
        }
        """
        return Data(json.utf8)
    }

    func testDecodesLineItemsListStripeMockShape() throws {
        let list = try decoder.decode(
            PaymentFlowsAmountDetailsResourceLineItemsList.self, from: lineItemsJSON())
        XCTAssertEqual(list.data.count, 1)
        let item = try XCTUnwrap(list.data.first)
        XCTAssertEqual(item.productName, "Test product")
        XCTAssertEqual(item.quantity, 2)
        XCTAssertEqual(item.unitCost, 1500)
        XCTAssertEqual(item.tax.valueOrNil?.totalTaxAmount, 100)
        XCTAssertNil(item.discountAmount.valueOrNil)
        XCTAssertEqual(list.hasMore, false)
    }

    // MARK: Open-by-ID routing for the new kinds

    func testMandatePrefixMapsToMandateKind() {
        XCTAssertEqual(StripeObjectKind.match("ma_test_123"), .mandate)
        XCTAssertEqual(StripeObjectKind.mandate.collectionPath, "mandates")
        XCTAssertEqual(StripeObjectKind.mandate.label, "Mandate")
    }

    func testConfirmationTokenPrefixMapsToItsKind() {
        XCTAssertEqual(StripeObjectKind.match("ctoken_test_123"), .confirmationToken)
        XCTAssertEqual(
            StripeObjectKind.confirmationToken.collectionPath, "confirmation_tokens")
        XCTAssertEqual(StripeObjectKind.confirmationToken.label, "Confirmation token")
    }

    func testExistingPrefixesUnaffected() {
        // `ma_` must not shadow other prefixes; confirm long-standing kinds.
        XCTAssertEqual(StripeObjectKind.match("pm_test_123"), .paymentMethod)
        XCTAssertEqual(StripeObjectKind.match("pi_test_123"), .paymentIntent)
        XCTAssertEqual(StripeObjectKind.match("acct_test_123"), .account)
        XCTAssertEqual(StripeObjectKind.match("not-stripe"), nil)
    }
}
