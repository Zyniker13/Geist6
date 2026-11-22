import Foundation
import GeistMetrics
import StripeModels
import XCTest
@testable import GeistData
@testable import StripeClient

// MARK: - Fixtures

/// Hand-checked fixtures. All values are obviously fake (test_ IDs, example
/// amounts) and decoded from JSON, which also exercises the generated
/// decoders.
private enum Fixture {
    static let decoder = JSONDecoder()

    static func balance(
        available: [(amount: Int, currency: String)],
        pending: [(amount: Int, currency: String)]
    ) throws -> Balance {
        func amounts(_ xs: [(amount: Int, currency: String)]) -> String {
            xs.map { "{\"amount\": \($0.amount), \"currency\": \"\($0.currency)\"}" }
                .joined(separator: ", ")
        }
        let json = """
        {
          "object": "balance",
          "livemode": false,
          "available": [\(amounts(available))],
          "pending": [\(amounts(pending))]
        }
        """
        return try decoder.decode(Balance.self, from: Data(json.utf8))
    }

    static func btx(
        _ amount: Int, created: Int, currency: String,
        category: String, type: String, id: String = "btx_test_123"
    ) throws -> BalanceTransaction {
        let json = """
        {
          "amount": \(amount),
          "available_on": \(created),
          "balance_type": "payments",
          "created": \(created),
          "currency": "\(currency)",
          "fee": 0,
          "fee_details": [],
          "id": "\(id)",
          "net": \(amount),
          "object": "balance_transaction",
          "reporting_category": "\(category)",
          "status": "available",
          "type": "\(type)"
        }
        """
        return try decoder.decode(BalanceTransaction.self, from: Data(json.utf8))
    }

    static func charge(
        _ amount: Int, created: Int, currency: String,
        status: String, id: String = "ch_test_123",
        description: String? = nil, customer: String? = nil
    ) throws -> Charge {
        let descriptionJSON = description.map { "\"description\": \"\($0)\"," } ?? ""
        let customerJSON = customer.map { "\"customer\": \"\($0)\"," } ?? ""
        let json = """
        {
          "amount": \(amount),
          "amount_captured": \(amount),
          "amount_refunded": 0,
          "billing_details": {},
          "captured": true,
          "created": \(created),
          "currency": "\(currency)",
          "disputed": false,
          \(descriptionJSON)
          \(customerJSON)
          "id": "\(id)",
          "livemode": false,
          "metadata": {},
          "object": "charge",
          "paid": true,
          "refunded": false,
          "status": "\(status)"
        }
        """
        return try decoder.decode(Charge.self, from: Data(json.utf8))
    }

    static func paymentIntent(
        _ amount: Int, created: Int, currency: String,
        status: String, id: String = "pi_test_123", description: String? = nil
    ) throws -> PaymentIntent {
        let descriptionJSON = description.map { "\"description\": \"\($0)\"," } ?? ""
        let json = """
        {
          "amount": \(amount),
          "amount_capturable": 0,
          "amount_received": 0,
          "capture_method": "automatic",
          "confirmation_method": "automatic",
          "created": \(created),
          "currency": "\(currency)",
          \(descriptionJSON)
          "id": "\(id)",
          "livemode": false,
          "metadata": {},
          "object": "payment_intent",
          "payment_method_types": ["card"],
          "status": "\(status)"
        }
        """
        return try decoder.decode(PaymentIntent.self, from: Data(json.utf8))
    }

    static func customer(
        created: Int, id: String = "cus_test_123",
        name: String? = nil, email: String? = nil
    ) throws -> Customer {
        let nameJSON = name.map { "\"name\": \"\($0)\"," } ?? ""
        let emailJSON = email.map { "\"email\": \"\($0)\"," } ?? ""
        let json = """
        {
          \(nameJSON)
          \(emailJSON)
          "created": \(created),
          "id": "\(id)",
          "livemode": false,
          "object": "customer"
        }
        """
        return try decoder.decode(Customer.self, from: Data(json.utf8))
    }

    static func payout(
        _ amount: Int, created: Int, arrival: Int, currency: String,
        status: String, id: String = "po_test_123"
    ) throws -> Payout {
        let json = """
        {
          "amount": \(amount),
          "arrival_date": \(arrival),
          "automatic": true,
          "created": \(created),
          "currency": "\(currency)",
          "id": "\(id)",
          "livemode": false,
          "method": "standard",
          "object": "payout",
          "reconciliation_status": "not_applicable",
          "source_type": "card",
          "status": "\(status)",
          "type": "bank_account"
        }
        """
        return try decoder.decode(Payout.self, from: Data(json.utf8))
    }

    static func event(
        _ type: String, created: Int, object: String, id: String = "evt_test_123"
    ) throws -> Event {
        let json = """
        {
          "created": \(created),
          "data": { "object": { "object": "\(object)", "id": "ch_test_123" } },
          "id": "\(id)",
          "livemode": false,
          "object": "event",
          "pending_webhooks": 0,
          "type": "\(type)"
        }
        """
        return try decoder.decode(Event.self, from: Data(json.utf8))
    }
}

// MARK: - Fake backend

/// Errors the fake backend throws.
private enum TestError: Error, Equatable {
    case noBalance
    case notFound
}

/// An in-memory `StripeDataBackend` for tests.
///
/// The data is fixed at init (immutable, so the loader's concurrent reads are
/// race-free). The calls the loader and search issue are recorded under a
/// lock so the routing can be asserted.
private final class FakeBackend: StripeDataBackend, @unchecked Sendable {
    private let lock = NSLock()
    private let balance: Balance?
    private let balanceTransactions: [BalanceTransaction]
    private let charges: [Charge]
    private let customers: [Customer]
    private let payouts: [Payout]
    private let events: [Event]
    private let searchChargesResults: [Charge]
    private let searchPaymentIntentsResults: [PaymentIntent]
    /// When set, `searchCharges` throws this error, to exercise the
    /// list-fallback path (Decision 0013).
    private let searchFailure: StripeAPIError?
    /// When set, `searchPaymentIntents` throws this error, to exercise the
    /// intents-Search-unavailable path (Decision 0023).
    private let searchIntentFailure: StripeAPIError?
    /// Raw JSON bodies served by `rawObject(path:)`, keyed by path.
    private let rawObjects: [String: Data]

    private var _btxCurrencies: [String?] = []
    private var _btxPayouts: [String] = []
    private var _customerEmails: [String?] = []
    private var _retrieveChargeIDs: [String] = []
    private var _retrieveCustomerIDs: [String] = []
    private var _searchQueries: [String] = []
    private var _intentSearchQueries: [String] = []
    private var _rawPaths: [String] = []
    private var _chargeListCalls = 0

    init(
        balance: Balance? = nil,
        balanceTransactions: [BalanceTransaction] = [],
        charges: [Charge] = [],
        customers: [Customer] = [],
        payouts: [Payout] = [],
        events: [Event] = [],
        searchChargesResults: [Charge] = [],
        searchPaymentIntentsResults: [PaymentIntent] = [],
        searchFailure: StripeAPIError? = nil,
        searchIntentFailure: StripeAPIError? = nil,
        rawObjects: [String: Data] = [:]
    ) {
        self.balance = balance
        self.balanceTransactions = balanceTransactions
        self.charges = charges
        self.customers = customers
        self.payouts = payouts
        self.events = events
        self.searchChargesResults = searchChargesResults
        self.searchPaymentIntentsResults = searchPaymentIntentsResults
        self.searchFailure = searchFailure
        self.searchIntentFailure = searchIntentFailure
        self.rawObjects = rawObjects
    }

    var btxCurrencies: [String?] { lock.lock(); defer { lock.unlock() }; return _btxCurrencies }
    var customerEmails: [String?] { lock.lock(); defer { lock.unlock() }; return _customerEmails }
    var retrieveChargeIDs: [String] { lock.lock(); defer { lock.unlock() }; return _retrieveChargeIDs }
    var retrieveCustomerIDs: [String] { lock.lock(); defer { lock.unlock() }; return _retrieveCustomerIDs }
    var searchQueries: [String] { lock.lock(); defer { lock.unlock() }; return _searchQueries }
    var intentSearchQueries: [String] { lock.lock(); defer { lock.unlock() }; return _intentSearchQueries }
    var rawPaths: [String] { lock.lock(); defer { lock.unlock() }; return _rawPaths }
    var chargeListCalls: Int { lock.lock(); defer { lock.unlock() }; return _chargeListCalls }

    private func record(_ body: () -> Void) {
        lock.lock(); defer { lock.unlock() }; body()
    }

    func retrieveBalance() async throws -> Balance {
        guard let balance else { throw TestError.noBalance }
        return balance
    }

    func balanceTransactions(created: DateInterval?, currency: String?) async throws -> [BalanceTransaction] {
        record { _btxCurrencies.append(currency) }
        return balanceTransactions
    }

    func balanceTransactions(payout: String) async throws -> [BalanceTransaction] {
        record { _btxPayouts.append(payout) }
        return balanceTransactions.filter { $0.unknownFields?["payout"]?.stringValue == payout }
    }

    func charges(created: DateInterval?) async throws -> [Charge] {
        record { _chargeListCalls += 1 }
        return charges
    }

    func retrieveCharge(id: String) async throws -> Charge {
        record { _retrieveChargeIDs.append(id) }
        guard let charge = charges.first(where: { $0.id == id }) else { throw TestError.notFound }
        return charge
    }

    func customers(created: DateInterval?, email: String?) async throws -> [Customer] {
        record { _customerEmails.append(email) }
        guard let email else { return customers }
        return customers.filter { $0.email.valueOrNil == email }
    }

    func retrieveCustomer(id: String) async throws -> Customer {
        record { _retrieveCustomerIDs.append(id) }
        guard let customer = customers.first(where: { $0.id == id }) else { throw TestError.notFound }
        return customer
    }

    func retrievePayout(id: String) async throws -> Payout {
        guard let payout = payouts.first(where: { $0.id == id }) else { throw TestError.notFound }
        return payout
    }

    func payouts() async throws -> [Payout] {
        return payouts
    }

    func events(created: DateInterval?) async throws -> [Event] {
        return events
    }

    func searchCharges(query: String) async throws -> [Charge] {
        record { _searchQueries.append(query) }
        if let searchFailure { throw searchFailure }
        return searchChargesResults
    }

    func searchPaymentIntents(query: String) async throws -> [PaymentIntent] {
        record { _intentSearchQueries.append(query) }
        if let searchIntentFailure { throw searchIntentFailure }
        return searchPaymentIntentsResults
    }

    func rawObject(path: String) async throws -> Data {
        record { _rawPaths.append(path) }
        guard let body = rawObjects[path] else { throw TestError.notFound }
        return body
    }
}

// MARK: - HomeDataLoader

final class HomeDataLoaderTests: XCTestCase {
    private let t0 = 1_700_000_000

    private func period() -> DateInterval {
        DateInterval(
            start: Date(timeIntervalSince1970: TimeInterval(t0 - 1_000)),
            end: Date(timeIntervalSince1970: TimeInterval(t0 + 1_000))
        )
    }

    func testLoadBuildsSnapshot() async throws {
        let balance = try Fixture.balance(
            available: [(amount: 10_000, currency: "usd"), (amount: 500, currency: "eur")],
            pending: [(amount: 200, currency: "usd")]
        )
        let btx = try [
            Fixture.btx(10_000, created: t0, currency: "usd", category: "charge", type: "charge")
        ]
        let charge = try Fixture.charge(10_000, created: t0, currency: "usd", status: "succeeded", id: "ch_a")
        let customer = try Fixture.customer(created: t0, id: "cus_a")
        let payout = try Fixture.payout(
            50_000, created: t0, arrival: t0 + 86_400, currency: "usd", status: "pending", id: "po_a"
        )
        let event = try Fixture.event("charge.succeeded", created: t0, object: "charge", id: "evt_a")

        let backend = FakeBackend(
            balance: balance,
            balanceTransactions: btx,
            charges: [charge],
            customers: [customer],
            payouts: [payout],
            events: [event]
        )
        let loader = HomeDataLoader(backend: backend)
        let snapshot = try await loader.load(period: period(), currency: "usd")

        // Balances are aggregated per currency, sorted by code.
        XCTAssertEqual(snapshot.balances.count, 2)
        XCTAssertEqual(snapshot.balances[0].currency, "eur")
        XCTAssertEqual(snapshot.balances[0].available.amount, 500)
        XCTAssertEqual(snapshot.balances[0].pending.amount, 0)
        XCTAssertEqual(snapshot.balances[1].currency, "usd")
        XCTAssertEqual(snapshot.balances[1].available.amount, 10_000)
        XCTAssertEqual(snapshot.balances[1].pending.amount, 200)

        // The ledger figures are computed from the balance transactions.
        XCTAssertEqual(snapshot.figures.volume.amount, 10_000)
        XCTAssertEqual(snapshot.figures.net.amount, 10_000)

        // The lists are passed through.
        XCTAssertEqual(snapshot.payments.map(\.id), ["ch_a"])
        XCTAssertEqual(snapshot.customers.map(\.id), ["cus_a"])
        XCTAssertEqual(snapshot.payouts.map(\.id), ["po_a"])
        XCTAssertEqual(snapshot.activity.count, 1)

        // The loader forwards the currency to the ledger and no email filter
        // to the customer list.
        XCTAssertEqual(backend.btxCurrencies, ["usd"])
        XCTAssertEqual(backend.customerEmails, [nil])
    }

    func testBalancesAggregatesDuplicateCurrencies() throws {
        // Two available lines for the same currency are summed.
        let balance = try Fixture.balance(
            available: [(amount: 1_000, currency: "usd"), (amount: 2_500, currency: "usd")],
            pending: [(amount: 100, currency: "usd")]
        )
        let lines = HomeDataLoader.balances(from: balance)
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines[0].available.amount, 3_500)
        XCTAssertEqual(lines[0].pending.amount, 100)
    }

    func testBalancesUnionOfAvailableAndPending() throws {
        // A currency that only appears in pending still gets a line.
        let balance = try Fixture.balance(
            available: [(amount: 1_000, currency: "usd")],
            pending: [(amount: 50, currency: "eur")]
        )
        let lines = HomeDataLoader.balances(from: balance)
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0].currency, "eur")
        XCTAssertEqual(lines[0].available.amount, 0)
        XCTAssertEqual(lines[0].pending.amount, 50)
        XCTAssertEqual(lines[1].currency, "usd")
        XCTAssertEqual(lines[1].available.amount, 1_000)
        XCTAssertEqual(lines[1].pending.amount, 0)
    }

    func testLoadPropagatesBackendError() async {
        // No balance configured → the loader surfaces the backend error.
        let backend = FakeBackend()
        let loader = HomeDataLoader(backend: backend)
        do {
            _ = try await loader.load(period: period(), currency: "usd")
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? TestError, .noBalance)
        }
    }
}

// MARK: - HomePeriod

final class HomePeriodTests: XCTestCase {
    func testIntervalEndsAtNow() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        for (period, seconds) in [
            (HomePeriod.last7Days, 7 * 86_400),
            (HomePeriod.last30Days, 30 * 86_400),
            (HomePeriod.last90Days, 90 * 86_400),
            (HomePeriod.last12Months, 365 * 86_400)
        ] {
            let interval = period.interval(now: now)
            XCTAssertEqual(interval.end, now)
            XCTAssertEqual(interval.start, now.addingTimeInterval(-TimeInterval(seconds)))
        }
    }
}

// MARK: - SearchService

final class SearchServiceTests: XCTestCase {
    private let t0 = 1_700_000_000

    func testOpenChargeByID() async throws {
        let charge = try Fixture.charge(1_000, created: t0, currency: "usd", status: "succeeded", id: "ch_open")
        let backend = FakeBackend(charges: [charge])
        let service = SearchService(backend: backend)

        let results = try await service.search("ch_open")
        XCTAssertEqual(results.hits.count, 1)
        guard case .charge(let found) = results.hits[0] else {
            return XCTFail("expected a charge hit")
        }
        XCTAssertEqual(found.id, "ch_open")
        XCTAssertEqual(backend.retrieveChargeIDs, ["ch_open"])
        // An ID query must not fall through to the Search API.
        XCTAssertTrue(backend.searchQueries.isEmpty)
    }

    func testOpenCustomerByID() async throws {
        let customer = try Fixture.customer(created: t0, id: "cus_open", name: "Alice", email: "alice@example.com")
        let backend = FakeBackend(customers: [customer])
        let service = SearchService(backend: backend)

        let results = try await service.search("cus_open")
        XCTAssertEqual(results.hits.count, 1)
        guard case .customer(let found) = results.hits[0] else {
            return XCTFail("expected a customer hit")
        }
        XCTAssertEqual(found.id, "cus_open")
        XCTAssertEqual(backend.retrieveCustomerIDs, ["cus_open"])
    }

    func testEmailFiltersCustomers() async throws {
        let alice = try Fixture.customer(created: t0, id: "cus_alice", name: "Alice", email: "alice@example.com")
        let bob = try Fixture.customer(created: t0, id: "cus_bob", name: "Bob", email: "bob@example.com")
        let backend = FakeBackend(customers: [alice, bob])
        let service = SearchService(backend: backend)

        let hits = try await service.search("alice@example.com").hits
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(backend.customerEmails, ["alice@example.com"])
        // An email query must not hit the Search API.
        XCTAssertTrue(backend.searchQueries.isEmpty)
    }

    func testBareAmountUsesSearchAPI() async throws {
        let charge = try Fixture.charge(1_000, created: t0, currency: "usd", status: "succeeded", id: "ch_amt")
        let backend = FakeBackend(searchChargesResults: [charge])
        let service = SearchService(backend: backend)

        let hits = try await service.search("1000").hits
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(backend.searchQueries, ["amount:1000"])
    }

    func testAmountWithCurrencyUsesSearchAPI() async throws {
        let backend = FakeBackend(searchChargesResults: [])
        let service = SearchService(backend: backend)
        _ = try await service.search("1000 USD")
        XCTAssertEqual(backend.searchQueries, ["amount:1000 USD"])
    }

    func testFreeTextFallsBackToSearchAPI() async throws {
        let backend = FakeBackend(searchChargesResults: [])
        let service = SearchService(backend: backend)
        _ = try await service.search("invoice")
        XCTAssertEqual(backend.searchQueries, ["invoice"])
    }

    func testEmptyQueryThrows() async {
        let service = SearchService(backend: FakeBackend())
        do {
            _ = try await service.search("   ")
            XCTFail("expected emptyQuery")
        } catch {
            XCTAssertEqual(error as? SearchError, .emptyQuery)
        }
    }

    func testResolveReturnsBestHit() async throws {
        let charge = try Fixture.charge(1_000, created: t0, currency: "usd", status: "succeeded", id: "ch_best")
        let backend = FakeBackend(searchChargesResults: [charge])
        let service = SearchService(backend: backend)
        let hit = try await service.resolve("1000")
        XCTAssertEqual(hit.id, "ch_best")
    }

    func testResolveThrowsNotFoundWhenNoHits() async {
        let backend = FakeBackend(searchChargesResults: [])
        let service = SearchService(backend: backend)
        do {
            _ = try await service.resolve("1000")
            XCTFail("expected notFound")
        } catch {
            XCTAssertEqual(error as? SearchError, .notFound("1000"))
        }
    }

    func testIDKind() {
        XCTAssertEqual(SearchService.idKind("ch_123"), .charge)
        XCTAssertEqual(SearchService.idKind("cus_123"), .customer)
        XCTAssertEqual(
            SearchService.idKind("pi_123"),
            .other(.paymentIntent)
        )
        XCTAssertNil(SearchService.idKind("hello"))
    }

    func testAmountQuery() {
        XCTAssertEqual(SearchService.amountQuery("1000"), "amount:1000")
        XCTAssertEqual(SearchService.amountQuery("1000 USD"), "amount:1000 USD")
        XCTAssertNil(SearchService.amountQuery("12.34"))
        XCTAssertNil(SearchService.amountQuery("hello"))
        XCTAssertNil(SearchService.amountQuery(""))
    }

    func testSearchHitTitle() throws {
        let charge = try Fixture.charge(1_000, created: t0, currency: "usd", status: "succeeded", id: "ch_title")
        XCTAssertEqual(SearchHit.charge(charge).title, "ch_title")

        let named = try Fixture.customer(created: t0, id: "cus_named", name: "Alice", email: "alice@example.com")
        XCTAssertEqual(SearchHit.customer(named).title, "Alice")

        let emailOnly = try Fixture.customer(created: t0, id: "cus_email", email: "bob@example.com")
        XCTAssertEqual(SearchHit.customer(emailOnly).title, "bob@example.com")

        let bare = try Fixture.customer(created: t0, id: "cus_bare")
        XCTAssertEqual(SearchHit.customer(bare).title, "cus_bare")
    }

    // MARK: Object by ID

    func testUnknownIDKindRoutesToRawObject() async throws {
        let payoutJSON = """
        {"id": "po_raw", "object": "payout", "amount": 50000, "status": "paid"}
        """
        let backend = FakeBackend(
            rawObjects: ["/v1/payouts/po_raw": Data(payoutJSON.utf8)]
        )
        let service = SearchService(backend: backend)

        let results = try await service.search("po_raw")
        XCTAssertEqual(results.hits.count, 1)
        guard case .object(let kind, let id, let json) = results.hits[0] else {
            return XCTFail("expected an object hit")
        }
        XCTAssertEqual(kind, .payout)
        XCTAssertEqual(id, "po_raw")
        XCTAssertEqual(json.string(atPath: "status"), "paid")
        XCTAssertEqual(results.hits[0].title, "Payout po_raw")
        // The request went through the raw fetch, not a typed retrieve.
        XCTAssertEqual(backend.rawPaths, ["/v1/payouts/po_raw"])
        XCTAssertTrue(backend.retrieveChargeIDs.isEmpty)
        XCTAssertTrue(backend.retrieveCustomerIDs.isEmpty)
    }

    func testObjectTitleUsesAvailableFields() throws {
        let json = try StripeJSON.decode(Data(#"{"id": "in_raw", "object": "invoice"}"#.utf8))
        let hit = SearchHit.object(kind: .invoice, id: "in_raw", json: json)
        XCTAssertEqual(hit.title, "Invoice in_raw")
        XCTAssertEqual(hit.objectKind, .invoice)
        XCTAssertEqual(hit.id, "in_raw")
    }

    // MARK: Search fallback (Decision 0013)

    /// Builds a `StripeAPIError` for the fallback matcher tests. `Detail` has
    /// no memberwise init, so a message is decoded from JSON.
    private func apiError(status: Int, message: String? = nil) throws -> StripeAPIError {
        let detail: StripeAPIError.Detail
        if let message {
            detail = try JSONDecoder().decode(
                StripeAPIError.Detail.self,
                from: Data("{\"message\": \"\(message)\"}".utf8)
            )
        } else {
            detail = StripeAPIError.Detail()
        }
        return StripeAPIError(status: status, type: .undocumented, detail: detail)
    }

    func testTextQueryMergesChargesAndIntents() async throws {
        let charge = try Fixture.charge(
            1_000, created: t0, currency: "usd", status: "succeeded", id: "ch_coffee"
        )
        let intent = try Fixture.paymentIntent(
            1_000, created: t0, currency: "usd", status: "succeeded",
            id: "pi_coffee", description: "Coffee prepayment"
        )
        let backend = FakeBackend(
            searchChargesResults: [charge], searchPaymentIntentsResults: [intent]
        )
        let service = SearchService(backend: backend)

        let results = try await service.search("coffee")
        XCTAssertEqual(results.hits.map(\.id), ["ch_coffee", "pi_coffee"])
        XCTAssertFalse(results.approximate)
        XCTAssertEqual(backend.searchQueries, ["coffee"])
        XCTAssertEqual(backend.intentSearchQueries, ["coffee"])
        guard case .paymentIntent(let intentHit) = results.hits[1] else {
            return XCTFail("expected a payment intent hit")
        }
        XCTAssertEqual(intentHit.id, "pi_coffee")
    }

    func testAmountQueryAlsoSearchesIntents() async throws {
        let backend = FakeBackend(
            searchChargesResults: [], searchPaymentIntentsResults: []
        )
        let service = SearchService(backend: backend)

        _ = try await service.search("1500")
        XCTAssertEqual(backend.searchQueries, ["amount:1500"])
        XCTAssertEqual(backend.intentSearchQueries, ["amount:1500"])
    }

    func testIntentSearchUnavailableKeepsChargeHits() async throws {
        let charge = try Fixture.charge(
            1_000, created: t0, currency: "usd", status: "succeeded", id: "ch_coffee"
        )
        let backend = FakeBackend(
            searchChargesResults: [charge], searchIntentFailure: try apiError(status: 404)
        )
        let service = SearchService(backend: backend)

        let results = try await service.search("coffee")
        XCTAssertEqual(results.hits.map(\.id), ["ch_coffee"])
        XCTAssertFalse(results.approximate)
        XCTAssertEqual(backend.chargeListCalls, 0)
    }

    func testIntentSearchPropagatesRealErrors() async throws {
        let backend = FakeBackend(searchIntentFailure: try apiError(status: 500, message: "backend down"))
        let service = SearchService(backend: backend)
        do {
            _ = try await service.search("coffee")
            XCTFail("expected the API error to propagate")
        } catch let error as StripeAPIError {
            XCTAssertEqual(error.status, 500)
        }
    }

    func testFallbackKeepsIntentHitsWhenChargeSearchUnavailable() async throws {
        let coffee = try Fixture.charge(
            1_000, created: t0, currency: "usd", status: "succeeded",
            id: "ch_coffee", description: "Coffee subscription"
        )
        let intent = try Fixture.paymentIntent(
            2_000, created: t0, currency: "usd", status: "succeeded",
            id: "pi_coffee", description: "Coffee prepayment"
        )
        let backend = FakeBackend(
            charges: [coffee],
            searchPaymentIntentsResults: [intent],
            searchFailure: try apiError(status: 404)
        )
        let service = SearchService(backend: backend)

        let results = try await service.search("coffee")
        XCTAssertEqual(results.hits.map(\.id), ["ch_coffee", "pi_coffee"])
        XCTAssertTrue(results.approximate)
    }

    func testSearchUnavailableMatches404() throws {
        XCTAssertTrue(SearchService.searchUnavailable(try apiError(status: 404)))
    }

    func testSearchUnavailableMatchesNotEnabledMessage() throws {
        XCTAssertTrue(
            SearchService.searchUnavailable(
                try apiError(status: 400, message: "Search has not been enabled for this account")
            )
        )
    }

    func testSearchUnavailableRejectsOtherErrors() throws {
        XCTAssertFalse(
            SearchService.searchUnavailable(
                try apiError(status: 400, message: "You did not specify a query")
            )
        )
        XCTAssertFalse(
            SearchService.searchUnavailable(
                try apiError(status: 500, message: "Search backend is temporarily unavailable")
            )
        )
    }

    func testFallbackFiltersChargesOnUnavailableSearch() async throws {
        // Search API 404 → the service fetches the charge list and filters.
        let coffee = try Fixture.charge(
            1_000, created: t0, currency: "usd", status: "succeeded",
            id: "ch_coffee", description: "Coffee subscription"
        )
        let other = try Fixture.charge(
            2_000, created: t0, currency: "usd", status: "succeeded", id: "ch_other"
        )
        let backend = FakeBackend(charges: [coffee, other], searchFailure: try apiError(status: 404))
        let service = SearchService(backend: backend)

        let results = try await service.search("coffee")
        XCTAssertEqual(backend.searchQueries, ["coffee"])
        XCTAssertEqual(backend.chargeListCalls, 1)
        XCTAssertEqual(results.hits.map(\.id), ["ch_coffee"])
        XCTAssertTrue(results.approximate)
    }

    func testFallbackMatchesIDAndCustomer() async throws {
        let byID = try Fixture.charge(
            1_000, created: t0, currency: "usd", status: "succeeded", id: "ch_special"
        )
        let byCustomer = try Fixture.charge(
            2_000, created: t0, currency: "usd", status: "succeeded",
            id: "ch_other", customer: "cus_special"
        )
        let backend = FakeBackend(
            charges: [byID, byCustomer],
            searchFailure: try apiError(status: 400, message: "Search has not been enabled for this account")
        )
        let service = SearchService(backend: backend)

        let results = try await service.search("special")
        XCTAssertEqual(results.hits.map(\.id), ["ch_special", "ch_other"])
    }

    func testFallbackMatchesBareAmount() async throws {
        let charge = try Fixture.charge(
            1_500, created: t0, currency: "usd", status: "succeeded", id: "ch_amt"
        )
        let backend = FakeBackend(charges: [charge], searchFailure: try apiError(status: 404))
        let service = SearchService(backend: backend)

        let results = try await service.search("1500")
        XCTAssertEqual(results.hits.map(\.id), ["ch_amt"])
        XCTAssertTrue(results.approximate)
        // The Search API was tried first, then the list fallback.
        XCTAssertEqual(backend.searchQueries, ["amount:1500"])
        XCTAssertEqual(backend.chargeListCalls, 1)
    }

    func testNonAvailabilityErrorPropagates() async throws {
        // A server error is not an availability error: it must surface.
        let backend = FakeBackend(searchFailure: try apiError(status: 500, message: "backend down"))
        let service = SearchService(backend: backend)
        do {
            _ = try await service.search("coffee")
            XCTFail("expected the API error to propagate")
        } catch let error as StripeAPIError {
            XCTAssertEqual(error.status, 500)
        } catch {
            XCTFail("unexpected error type: \(error)")
        }
    }
}

// MARK: - StripeJSON / ObjectByIDService

final class ObjectByIDTests: XCTestCase {
    func testStripeObjectKindMatch() {
        XCTAssertEqual(StripeObjectKind.match("ch_123"), .charge)
        XCTAssertEqual(StripeObjectKind.match("cus_123"), .customer)
        XCTAssertEqual(StripeObjectKind.match("po_123"), .payout)
        XCTAssertEqual(StripeObjectKind.match("evt_123"), .event)
        XCTAssertEqual(StripeObjectKind.match("txn_123"), .balanceTransaction)
        XCTAssertEqual(StripeObjectKind.match("in_123"), .invoice)
        XCTAssertEqual(StripeObjectKind.match("pi_123"), .paymentIntent)
        XCTAssertEqual(StripeObjectKind.match("re_123"), .refund)
        XCTAssertEqual(StripeObjectKind.match("sub_123"), .subscription)
        XCTAssertEqual(StripeObjectKind.match("prod_123"), .product)
        XCTAssertEqual(StripeObjectKind.match("acct_123"), .account)
        XCTAssertEqual(StripeObjectKind.match("price_123"), .price)
        XCTAssertNil(StripeObjectKind.match("pr_123"))
        XCTAssertNil(StripeObjectKind.match("unknown_123"))
        XCTAssertNil(StripeObjectKind.match("hello"))
    }

    func testCollectionPaths() {
        XCTAssertEqual(StripeObjectKind.charge.collectionPath, "charges")
        XCTAssertEqual(
            StripeObjectKind.balanceTransaction.collectionPath,
            "balance_transactions"
        )
        XCTAssertEqual(
            StripeObjectKind.paymentIntent.collectionPath,
            "payment_intents"
        )
    }

    func testDecodeAndFlatten() throws {
        let json = try StripeJSON.decode(Data("""
        {
          "id": "ch_1",
          "object": "charge",
          "amount": 1500,
          "paid": true,
          "note": null,
          "tags": ["a", "b"],
          "billing_details": {"email": "alice@example.com"},
          "metadata": {"order": "42"}
        }
        """.utf8))
        guard case .object(let root) = json else {
            return XCTFail("expected an object")
        }
        XCTAssertEqual(root["id"]?.stringValue, "ch_1")
        XCTAssertEqual(root["amount"]?.intValue, 1500)
        XCTAssertEqual(root["paid"]?.boolValue, true)
        XCTAssertEqual(root["note"], .null)
        // Nested objects and arrays render as counts in the flat list.
        XCTAssertEqual(json.flattened().first(where: { $0.key == "tags" })?.value, "[2]")
        XCTAssertEqual(json.flattened().first(where: { $0.key == "billing_details" })?.value, "{…}")
        XCTAssertEqual(root["billing_details"]?.flattened().first?.key, "email")
        XCTAssertEqual(root["billing_details"]?.flattened().first?.value, "alice@example.com")
        XCTAssertEqual(root["metadata"]?.flattened().first?.value, "42")
    }

    func testStringAtPath() throws {
        let json = try StripeJSON.decode(Data("""
        {"billing_details": {"email": "alice@example.com"}, "amount": 1500}
        """.utf8))
        XCTAssertEqual(json.string(atPath: "billing_details.email"), "alice@example.com")
        XCTAssertNil(json.string(atPath: "amount"))
        XCTAssertNil(json.string(atPath: "missing.path"))
    }

    func testFetchBuildsPathAndDecodes() async throws {
        let payoutJSON = """
        {"id": "po_fetch", "object": "payout", "amount": 50000, "status": "paid"}
        """
        let backend = FakeBackend(
            rawObjects: ["/v1/payouts/po_fetch": Data(payoutJSON.utf8)]
        )
        let service = ObjectByIDService(backend: backend)

        let fetched = try await service.fetch("po_fetch")
        XCTAssertEqual(fetched.kind, .payout)
        XCTAssertEqual(fetched.id, "po_fetch")
        XCTAssertEqual(backend.rawPaths, ["/v1/payouts/po_fetch"])
    }

    func testFetchRejectsUnknownPrefix() async {
        let service = ObjectByIDService(backend: FakeBackend())
        do {
            _ = try await service.fetch("not_a_stripe_id")
            XCTFail("expected unknownKind")
        } catch let error as ObjectByIDError {
            guard case .unknownKind(let id) = error else {
                return XCTFail("unexpected error: \(error)")
            }
            XCTAssertEqual(id, "not_a_stripe_id")
        } catch {
            XCTFail("unexpected error type: \(error)")
        }
    }

    func testFetchDecodesIntoStripeJSON() async throws {
        let json = """
        {"id": "ch_fetch", "object": "charge", "amount": 2000, "paid": true}
        """
        let backend = FakeBackend(
            rawObjects: ["/v1/charges/ch_fetch": Data(json.utf8)]
        )
        let fetched = try await ObjectByIDService(backend: backend).fetch("ch_fetch")
        XCTAssertEqual(fetched.json.string(atPath: "id"), "ch_fetch")
        guard case .object(let root) = fetched.json else {
            return XCTFail("expected an object tree")
        }
        XCTAssertEqual(root["amount"]?.intValue, 2000)
        XCTAssertEqual(root["paid"]?.boolValue, true)
    }
}

// MARK: - Metadata parsing

final class ParseMetadataLinesTests: XCTestCase {
    func testParsesSimplePairs() throws {
        XCTAssertEqual(parseMetadataLines("order_id=12345\ncolor=blue"), ["order_id": "12345", "color": "blue"])
    }

    func testTrimsWhitespaceAndSkipsBlankLines() {
        XCTAssertEqual(
            parseMetadataLines("  order_id = 12345 \n\n\tcolor=blue\n"),
            ["order_id": "12345", "color": "blue"]
        )
    }

    func testValueMayContainEquals() {
        XCTAssertEqual(parseMetadataLines("query=a=b"), ["query": "a=b"])
    }

    func testDuplicateKeysKeepLastValue() {
        XCTAssertEqual(parseMetadataLines("color=blue\ncolor=red"), ["color": "red"])
    }

    func testLineWithoutEqualsFailsParse() {
        XCTAssertNil(parseMetadataLines("order_id=12345\nno equals sign"))
    }

    func testEmptyKeyFailsParse() {
        XCTAssertNil(parseMetadataLines("=value"))
    }

    func testEmptyTextClearsAllMetadata() {
        XCTAssertEqual(parseMetadataLines(""), [:])
        XCTAssertEqual(parseMetadataLines("\n  \n"), [:])
    }
}
