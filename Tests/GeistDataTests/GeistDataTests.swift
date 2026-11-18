import Foundation
import GeistMetrics
import StripeModels
import XCTest
@testable import GeistData

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
        status: String, id: String = "ch_test_123"
    ) throws -> Charge {
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

    private var _btxCurrencies: [String?] = []
    private var _customerEmails: [String?] = []
    private var _retrieveChargeIDs: [String] = []
    private var _retrieveCustomerIDs: [String] = []
    private var _searchQueries: [String] = []

    init(
        balance: Balance? = nil,
        balanceTransactions: [BalanceTransaction] = [],
        charges: [Charge] = [],
        customers: [Customer] = [],
        payouts: [Payout] = [],
        events: [Event] = [],
        searchChargesResults: [Charge] = []
    ) {
        self.balance = balance
        self.balanceTransactions = balanceTransactions
        self.charges = charges
        self.customers = customers
        self.payouts = payouts
        self.events = events
        self.searchChargesResults = searchChargesResults
    }

    var btxCurrencies: [String?] { lock.lock(); defer { lock.unlock() }; return _btxCurrencies }
    var customerEmails: [String?] { lock.lock(); defer { lock.unlock() }; return _customerEmails }
    var retrieveChargeIDs: [String] { lock.lock(); defer { lock.unlock() }; return _retrieveChargeIDs }
    var retrieveCustomerIDs: [String] { lock.lock(); defer { lock.unlock() }; return _retrieveCustomerIDs }
    var searchQueries: [String] { lock.lock(); defer { lock.unlock() }; return _searchQueries }

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

    func charges(created: DateInterval?) async throws -> [Charge] {
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

    func payouts() async throws -> [Payout] {
        return payouts
    }

    func events(created: DateInterval?) async throws -> [Event] {
        return events
    }

    func searchCharges(query: String) async throws -> [Charge] {
        record { _searchQueries.append(query) }
        return searchChargesResults
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

        let hits = try await service.search("ch_open")
        XCTAssertEqual(hits.count, 1)
        guard case .charge(let found) = hits[0] else {
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

        let hits = try await service.search("cus_open")
        XCTAssertEqual(hits.count, 1)
        guard case .customer(let found) = hits[0] else {
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

        let hits = try await service.search("alice@example.com")
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(backend.customerEmails, ["alice@example.com"])
        // An email query must not hit the Search API.
        XCTAssertTrue(backend.searchQueries.isEmpty)
    }

    func testBareAmountUsesSearchAPI() async throws {
        let charge = try Fixture.charge(1_000, created: t0, currency: "usd", status: "succeeded", id: "ch_amt")
        let backend = FakeBackend(searchChargesResults: [charge])
        let service = SearchService(backend: backend)

        let hits = try await service.search("1000")
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
        XCTAssertNil(SearchService.idKind("pi_123"))
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
}
