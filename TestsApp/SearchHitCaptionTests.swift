import Foundation
import GeistData
import GeistMetrics
import StripeClient
import StripeModels
import Testing
@testable import Geist6

/// Tests for the search hit's secondary caption line: the kind plus the
/// fields that explain why a hit matched. The live ones run against
/// `stripe-mock` on the same port `scripts/check.sh` starts (12111).
struct SearchHitCaptionTests {

  private static let mockBaseURL = URL(string: "http://127.0.0.1:12111")!

  private static func makeBackend() -> StripeClient {
    StripeClient(apiKey: "sk_test_zzz", mode: .management, baseURL: mockBaseURL)
  }

  @Test func chargeCaptionShowsAmountAndStatus() async throws {
    let service = SearchService(backend: SearchHitCaptionTests.makeBackend())
    let results = try await service.search("ch_1")

    let hit = try #require(results.hits.first)
    guard case .charge = hit else {
      Issue.record("expected a charge hit, got \(hit)")
      return
    }
    // The mock's fixture charge is 100 minor units of USD ($1.00) that
    // succeeded; the caption must say what it is, what it was worth, and
    // how it ended.
    #expect(hit.caption.hasPrefix("Charge · "))
    #expect(hit.caption.hasSuffix(" · succeeded"))
    #expect(hit.caption.contains("1.00"))
  }

  @Test func moneyFormatHonorsZeroDecimalCurrencies() {
    // JPY amounts are already the major unit: 1000 → 1,000 (no cents).
    let jpy = MoneyFormat.string(Money(amount: 1000, currency: "jpy"))
    #expect(jpy.contains("1,000"))

    // USD amounts divide by 100: 10000 → 100.00.
    let usd = MoneyFormat.string(Money(amount: 10000, currency: "usd"))
    #expect(usd.contains("100.00"))
  }

  @Test func customerCaptionWithoutEmailStaysKindOnly() async throws {
    // stripe-mock's fixture customer has a null email, so the caption is
    // the kind label alone.
    let service = SearchService(backend: SearchHitCaptionTests.makeBackend())
    let results = try await service.search("cus_1")

    let hit = try #require(results.hits.first)
    guard case .customer = hit else {
      Issue.record("expected a customer hit, got \(hit)")
      return
    }
    #expect(hit.caption == "Customer")
  }

  @Test func objectCaptionStaysTheKindLabel() {
    let hit = SearchHit.object(
      kind: .payout, id: "po_test_1",
      json: .object(["id": .string("po_test_1")])
    )
    #expect(hit.caption == hit.objectKind?.label)
  }
}
