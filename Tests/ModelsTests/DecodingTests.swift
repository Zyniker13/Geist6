import Foundation
import StripeModels
import Testing

@testable import StripeModels

/// Decode tests for the generated search-result containers. The OpenAPI spec
/// titles every `GET /v1/*/search` response `SearchResult` even though the
/// `data` item type differs per endpoint; a generator bug once collapsed all
/// of them into one struct with `data: [Charge]` (decision 0023). These tests
/// pin each endpoint's own result type and item type.
struct DecodingTests {
    /// Search envelope shape mirrored from stripe-mock with obviously fake
    /// values (`pi_test_123`, `cus_test_123`, example.com).
    private func searchEnvelope(items: String) -> Data {
        let json = """
        {
          "data": [\(items)],
          "has_more": false,
          "object": "search_result",
          "total_count": 1,
          "url": "/v1/search-url"
        }
        """
        return Data(json.utf8)
    }

    private func paymentIntentJSON() -> String {
        """
        {
          "amount": 1099,
          "amount_capturable": 0,
          "amount_received": 0,
          "capture_method": "automatic",
          "confirmation_method": "automatic",
          "created": 1234567890,
          "currency": "usd",
          "description": "search fixture",
          "id": "pi_test_123",
          "livemode": false,
          "metadata": {"order": "a1"},
          "object": "payment_intent",
          "payment_method_types": ["card"],
          "status": "requires_payment_method"
        }
        """
    }

    private func customerJSON() -> String {
        """
        {
          "created": 1234567890,
          "email": "alice@example.com",
          "id": "cus_test_123",
          "livemode": false,
          "name": "Alice",
          "object": "customer"
        }
        """
    }

    @Test func paymentIntentSearchResultDecodesPaymentIntents() throws {
        let result = try JSONDecoder().decode(
            PaymentIntentSearchResult.self,
            from: searchEnvelope(items: paymentIntentJSON())
        )
        #expect(result.data.count == 1)
        #expect(result.data[0].id == "pi_test_123")
        #expect(result.data[0].amount == 1099)
        #expect(result.data[0].status == .requiresPaymentMethod)
        #expect(result.totalCount == 1)
        #expect(!result.hasMore)
        #expect(result.data[0].metadata["order"] == "a1")
    }

    @Test func customerSearchResultDecodesCustomers() throws {
        let result = try JSONDecoder().decode(
            CustomerSearchResult.self,
            from: searchEnvelope(items: customerJSON())
        )
        #expect(result.data.count == 1)
        #expect(result.data[0].id == "cus_test_123")
        #expect(result.data[0].email.valueOrNil == "alice@example.com")
    }

    @Test func chargeSearchResultKeepsLegacyName() throws {
        // The first-generated search container keeps the plain name that
        // existing call sites reference.
        let chargeJSON = """
        {
          "amount": 100,
          "amount_captured": 100,
          "amount_refunded": 0,
          "billing_details": {},
          "captured": true,
          "created": 1234567890,
          "currency": "usd",
          "disputed": false,
          "id": "ch_test_123",
          "livemode": false,
          "metadata": {},
          "object": "charge",
          "paid": true,
          "refunded": false,
          "status": "succeeded"
        }
        """
        let result = try JSONDecoder().decode(
            SearchResult.self,
            from: searchEnvelope(items: chargeJSON)
        )
        #expect(result.data.count == 1)
        #expect(result.data[0].id == "ch_test_123")
        #expect(result.data[0].amount == 100)
    }
}
