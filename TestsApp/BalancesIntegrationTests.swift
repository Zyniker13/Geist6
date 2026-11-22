// BalancesIntegrationTests.swift — TestsApp
// Integration tests for the balances screens (M7 tier 1) against
// `stripe-mock` on port 12111 (the port `scripts/check.sh` starts). The mock
// holds one balance transaction (+100 usd, type `charge`, fee 0) and a
// balance whose usd available/pending are both 0 — matching the home card.
//
// Read-only by construction: both calls are reads on `StripeDataBackend`,
// which has no write methods, so nothing here can mutate Stripe state.

import Foundation
import Testing
@testable import Geist6
import GeistData
import StripeClient
import StripeModels

struct BalancesIntegrationTests {

  private static let mockBaseURL = URL(string: "http://127.0.0.1:12111")!

  private static func makeBackend() -> StripeClient {
    StripeClient(apiKey: "sk_test_zzz", mode: .management, baseURL: mockBaseURL)
  }

  /// The home balances card and the balances screen must agree on the
  /// balance data path: per-currency lines exactly as Stripe reports them.
  @Test func balanceRetrieveMatchesHomeSnapshotShape() async throws {
    let backend = Self.makeBackend()
    let loader = HomeDataLoader(backend: backend)
    let snapshot = try await loader.load(
      period: DateInterval(
        start: Date(timeIntervalSince1970: 1_000_000_000), end: Date()),
      currency: "usd")

    let balance = try await backend.retrieveBalance()
    let screenLines = balance.available.map { amount in
      (currency: amount.currency, amount: amount.amount)
    }
    let homeLines = snapshot.balances.map { line in
      (currency: line.currency, amount: line.available.amount)
    }
    #expect(screenLines.count == homeLines.count)
    for (screen, home) in zip(screenLines, homeLines) {
      #expect(screen.currency == home.currency)
      #expect(screen.amount == home.amount)
    }
    #expect(screenLines.count == 1)
    #expect(screenLines.first?.currency == "usd")
  }

  /// The ledger: stripe-mock's single fixture transaction must decode with
  /// net 100, fee 0, type charge — the same values the detail screen's
  /// Net/Fee/Gross facts render.
  @Test func balanceTransactionsListDecodesTheFixtureLedger() async throws {
    let transactions = try await Self.makeBackend()
      .balanceTransactions(created: nil, currency: nil)

    #expect(transactions.count == 1)
    let transaction = try #require(transactions.first)
    #expect(transaction.id == "txn_1PgaxNB7WZ01zgkWEV3TLf40")
    #expect(transaction.amount == 100)
    #expect(transaction.fee == 0)
    #expect(transaction.net == 100)
    #expect(transaction.currency == "usd")
    #expect(transaction.type.rawValue == "charge")
    #expect(transaction.status == "available")
    #expect(transaction.reportingCategory == "charge")
    #expect(transaction.source.valueOrNil?.idOrNil == "ch_1PgafuB7WZ01zgkWXYmPNZs8")
  }

  /// Detail path: retrieve by ID returns the same ledger facts as the list.
  @Test func balanceTransactionRetrieveMatchesTheListEntry() async throws {
    let backend = Self.makeBackend()
    let listed = try await backend.balanceTransactions(created: nil, currency: nil)
    let id = try #require(listed.first?.id)
    let detail = try await backend.retrieveBalanceTransaction(
      id: id, nil, expand: nil)

    #expect(detail.id == id)
    #expect(detail.net == 100)
    #expect(detail.fee == 0)
    #expect(detail.type.rawValue == "charge")
  }

  /// stripe-mock ignores list filters (it serves its fixtures verbatim), so
  /// the ledger is the same single-transaction list under any currency
  /// filter; the screens only pass through what Stripe returns.
  @Test func balanceTransactionsUnderACurrencyFilterStillServeTheLedger() async throws {
    let transactions = try await Self.makeBackend()
      .balanceTransactions(created: nil, currency: "eur")
    // stripe-mock fixture behavior: filters are not applied.
    #expect(transactions.map { $0.id } == ["txn_1PgaxNB7WZ01zgkWEV3TLf40"])
  }
}
