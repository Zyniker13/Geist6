import Foundation
import Testing
@testable import Geist6
import GeistData
import GeistMetrics
import StripeClient
import StripeModels

/// Integration tests against `stripe-mock` on the same port `scripts/check.sh`
/// starts (12111). The mock's fixture objects are all dated `1234567890`
/// (February 2009) and the account holds one `usd` charge of 100, one balance
/// transaction of +100, one customer, one in-transit payout of 1100, and one
/// `plan.created` event, so period-filtered lists are empty for recent windows
/// and exactly one item for a window that covers 2009.
struct SearchAndHomeIntegrationTests {

  private static let mockBaseURL = URL(string: "http://127.0.0.1:12111")!

  private static func makeBackend() -> StripeClient {
    StripeClient(apiKey: "sk_test_zzz", mode: .management, baseURL: mockBaseURL)
  }

  /// A window that contains every stripe-mock fixture (they date to 2009).
  private static var widePeriod: DateInterval {
    let now = Date()
    return DateInterval(
      start: Date(timeIntervalSince1970: 1_000_000_000), end: now
    )
  }

  /// A window the fixtures fall outside of.
  private static var narrowPeriod: DateInterval {
    let now = Date()
    return DateInterval(
      start: now.addingTimeInterval(-60 * 60 * 24 * 30), end: now
    )
  }

  // MARK: Search

  @Test func searchByChargeIDRetrievesTheCharge() async throws {
    let service = SearchService(backend: SearchAndHomeIntegrationTests.makeBackend())
    let results = try await service.search("ch_1")

    let hit = try #require(results.hits.first)
    guard case .charge(let charge) = hit else {
      Issue.record("expected a charge hit, got \(hit)")
      return
    }
    #expect(charge.id == "ch_1")
    #expect(charge.amount == 100)
  }

  @Test func searchByAmountUsesTheSearchAPI() async throws {
    let service = SearchService(backend: SearchAndHomeIntegrationTests.makeBackend())
    let results = try await service.search("amount:100")

    #expect(!results.hits.isEmpty)
    let hit = try #require(results.hits.first)
    guard case .charge(let charge) = hit else {
      Issue.record("expected a charge hit, got \(hit)")
      return
    }
    #expect(charge.amount == 100)
  }

  @Test func searchByEmailFallsBackToCustomerList() async throws {
    // stripe-mock has no Search API and its customer fixture has a null
    // email, so this query takes the list-fallback path and the mock
    // returns its one fixture customer regardless of the filter. The
    // assertion is that the fallback completes and yields customers.
    let service = SearchService(backend: SearchAndHomeIntegrationTests.makeBackend())
    let results = try await service.search("nobody@example.com")

    #expect(!results.hits.isEmpty)
    for hit in results.hits {
      guard case .customer = hit else {
        Issue.record("expected only customer hits, got \(hit)")
        return
      }
    }
  }

  // MARK: Open by ID

  @Test func openByIDFetchesARawInvoice() async throws {
    let service = ObjectByIDService(backend: SearchAndHomeIntegrationTests.makeBackend())
    let resolved = try await service.fetch("in_1")

    #expect(resolved.kind == .invoice)
    #expect(resolved.id == "in_1")
    #expect(resolved.json["id"].stringValue == "in_1")
  }

  @Test func openByUnknownIDThrows() async throws {
    let service = ObjectByIDService(backend: SearchAndHomeIntegrationTests.makeBackend())
    await #expect(throws: ObjectByIDError.self) {
      _ = try await service.fetch("not a stripe id")
    }
  }

  // MARK: Home dashboard

  @Test func homeSnapshotForAWideWindowContainsEveryFixture() async throws {
    let loader = HomeDataLoader(backend: SearchAndHomeIntegrationTests.makeBackend())
    let snapshot = try await loader.load(period: Self.widePeriod, currency: "usd")

    #expect(snapshot.balances.count == 1)
    let usd = try #require(snapshot.balances.first)
    #expect(usd.currency == "usd")
    #expect(usd.available.amount == 0)
    #expect(usd.pending.amount == 0)

    #expect(snapshot.payments.count == 1)
    #expect(snapshot.payments.first?.amount == 100)
    #expect(snapshot.customers.count == 1)
    #expect(snapshot.payouts.count == 1)
    #expect(snapshot.payouts.first?.status == "in_transit")
    #expect(snapshot.activity.count == 1)
    #expect(snapshot.activity.first?.type == "plan.created")
  }

  @Test func homeSnapshotForARecentWindowHasEmptyPeriodLists() async throws {
    let loader = HomeDataLoader(backend: SearchAndHomeIntegrationTests.makeBackend())
    let snapshot = try await loader.load(period: Self.narrowPeriod, currency: "usd")

    #expect(snapshot.payments.isEmpty)
    #expect(snapshot.customers.isEmpty)
    #expect(snapshot.activity.isEmpty)
    // Payouts are not period-filtered: the in-transit fixture still shows.
    #expect(snapshot.payouts.count == 1)
  }
}
