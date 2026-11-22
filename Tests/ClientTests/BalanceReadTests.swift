// BalanceReadTests.swift — Tests/ClientTests
// Tests for the balances screens (M7 tier 1): `StripeDataBackend`'s
// `retrieveBalance()` and `balanceTransactions(created:currency:)`
// conformances on StripeClient, plus the BalanceTransaction decode of the
// stripe-mock fixture shape, against a stubbed transport.
//
// The fixture mirrors stripe-mock 0.206.0's embedded balance_transaction
// (obviously fake values); the list envelope is the standard /v1 list shape.

import XCTest

@testable import StripeClient
@testable import GeistData
import StripeModels

// MARK: - Fixtures (from stripe-mock 0.206.0, obviously fake values)

let balanceTransactionFixtureJSON = """
{
  "amount": 100,
  "available_on": 1234567890,
  "balance_type": "payments",
  "created": 1234567890,
  "currency": "usd",
  "description": "My First Test Charge (created for API docs)",
  "exchange_rate": null,
  "fee": 0,
  "fee_details": [],
  "id": "txn_1234567890",
  "net": 100,
  "object": "balance_transaction",
  "reporting_category": "charge",
  "source": "ch_1234567890",
  "status": "available",
  "type": "charge"
}
"""

nonisolated(unsafe) let balanceTransactionFixture: [String: Any] = {
  guard let parsed = try? JSONSerialization.jsonObject(
    with: Data(balanceTransactionFixtureJSON.utf8)),
    let dict = parsed as? [String: Any] else {
    preconditionFailure("balance transaction fixture JSON must decode")
  }
  return dict
}()

let balanceFixtureJSON = """
{
  "object": "balance",
  "available": [
    {
      "amount": 314159,
      "currency": "usd",
      "source_types": {"bank_account": 0, "card": 314159, "fpx": 0}
    }
  ],
  "connect_reserved": [
    {"amount": 100, "currency": "usd"}
  ],
  "instant_available": [
    {
      "amount": 314159,
      "currency": "usd",
      "net_available": [
        {"amount": 314159, "destination": "acct_test_123", "source_type": "card"}
      ]
    }
  ],
  "issuing": {"available": [{"amount": 0, "currency": "usd"}]},
  "livemode": false,
  "pending": [
    {
      "amount": 10000,
      "currency": "usd",
      "source_types": {"bank_account": 0, "card": 10000, "fpx": 0}
    }
  ],
  "refund_and_dispute_prefunding": {"available": [{"amount": 0, "currency": "usd"}], "pending": [{"amount": 0, "currency": "usd"}]}
}
"""

nonisolated(unsafe) let balanceFixture: [String: Any] = {
  guard let parsed = try? JSONSerialization.jsonObject(
    with: Data(balanceFixtureJSON.utf8)),
    let dict = parsed as? [String: Any] else {
    preconditionFailure("balance fixture JSON must decode")
  }
  return dict
}()

// MARK: - Test

@MainActor
final class BalanceReadTests: XCTestCase {

  private func makeClient() -> StripeClient {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [RecordingURLProtocol.self]
    RecordingURLProtocol.recordedRequests = []
    RecordingURLProtocol.recordedResponses = []
    return StripeClient(
      apiKey: "sk_test_fake", mode: .management,
      baseURL: URL(string: "http://127.0.0.1:1")!, configuration: config)
  }

  // MARK: Balance

  func testRetrieveBalanceConformanceReachesTheNetworkAndDecodes() async throws {
    StubBuilder.install(status: 200, json: balanceFixture)
    let backend: StripeDataBackend = makeClient()
    let balance = try await backend.retrieveBalance()
    XCTAssertEqual(balance.available.count, 1)
    XCTAssertEqual(balance.available.first?.currency, "usd")
    XCTAssertEqual(balance.available.first?.amount, 314159)
    XCTAssertEqual(balance.pending.first?.amount, 10000)
    let request = try XCTUnwrap(RecordingURLProtocol.recordedRequests.first)
    XCTAssertEqual(request.httpMethod, "GET")
    XCTAssertEqual(request.url!.path, "/v1/balance")
  }

  // MARK: Balance transactions

  func testBalanceTransactionsConformanceReachesTheNetworkAndDecodes() async throws {
    StubBuilder.install(
      status: 200,
      json: ["object": "list", "url": "/v1/balance_transactions", "has_more": false,
             "data": [balanceTransactionFixture]])
    let backend: StripeDataBackend = makeClient()
    let transactions = try await backend.balanceTransactions(created: nil, currency: nil)
    XCTAssertEqual(transactions.count, 1)
    let transaction = try XCTUnwrap(transactions.first)
    XCTAssertEqual(transaction.id, "txn_1234567890")
    XCTAssertEqual(transaction.amount, 100)
    XCTAssertEqual(transaction.fee, 0)
    XCTAssertEqual(transaction.net, 100)
    XCTAssertEqual(transaction.currency, "usd")
    XCTAssertEqual(transaction.type.rawValue, "charge")
    XCTAssertEqual(transaction.status, "available")
    let request = try XCTUnwrap(RecordingURLProtocol.recordedRequests.first)
    XCTAssertEqual(request.httpMethod, "GET")
    XCTAssertEqual(request.url!.path, "/v1/balance_transactions")
    XCTAssertTrue(request.url!.query?.contains("currency=usd") != true, "no currency filter when nil")
  }

  func testBalanceTransactionsSendsCreatedAndCurrencyParams() async throws {
    StubBuilder.install(
      status: 200,
      json: ["object": "list", "url": "/v1/balance_transactions", "has_more": false,
             "data": [balanceTransactionFixture]])
    let backend: StripeDataBackend = makeClient()
    let interval = DateInterval(
      start: Date(timeIntervalSince1970: 1_000), end: Date(timeIntervalSince1970: 2_000))
    _ = try await backend.balanceTransactions(created: interval, currency: "usd")
    let request = try XCTUnwrap(RecordingURLProtocol.recordedRequests.first)
    let query = try XCTUnwrap(request.url!.query)
    XCTAssertTrue(query.contains("currency=usd"), "currency filter missing: \(query)")
    XCTAssertTrue(query.contains("created"), "created filter missing: \(query)")
  }

  /// The mock's ledger is a single flat object; the fixture decode must be
  /// lossless so the detail screen's Net/Fee/Gross facts and the list row's
  /// net title both render from the same decode.
  func testBalanceTransactionFixtureDecodesAllLedgerFacts() throws {
    let transaction = try StripeClient.decoder.decode(
      BalanceTransaction.self, from: Data(balanceTransactionFixtureJSON.utf8))
    XCTAssertEqual(transaction.id, "txn_1234567890")
    XCTAssertEqual(transaction.net, 100)
    XCTAssertEqual(transaction.fee, 0)
    XCTAssertEqual(transaction.amount, 100)
    XCTAssertEqual(transaction.reportingCategory, "charge")
    XCTAssertEqual(transaction.availableOn, StripeTimestamp(seconds: 1_234_567_890))
    let source = try XCTUnwrap(transaction.source.valueOrNil?.idOrNil)
    XCTAssertEqual(source, "ch_1234567890")
  }

  /// Regression guard for the 2026-11-18 wrapper recursion (see
  /// MockServerTests): the list side must not re-enter itself either.
  func testBalanceTransactionsListWrapperTerminates() async throws {
    StubBuilder.install(
      status: 200,
      json: ["object": "list", "url": "/v1/balance_transactions", "has_more": false,
             "data": [balanceTransactionFixture]])
    let client = makeClient()
    let backend: StripeDataBackend = client
    let transactions = try await backend.balanceTransactions(created: nil, currency: nil)
    XCTAssertEqual(transactions.first?.id, "txn_1234567890")
  }
}
