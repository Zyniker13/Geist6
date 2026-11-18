import Foundation
import StripeModels
import XCTest
@testable import GeistMetrics

/// Hand-checked fixtures. All values are obviously fake (test_ IDs, example
/// amounts) and decoded from JSON, which also exercises the generated
/// decoders.
private enum Fixture {
    static let decoder = JSONDecoder()

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

    static func customer(created: Int, id: String = "cus_test_123") throws -> Customer {
        let json = """
        {
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

final class HomeMetricsTests: XCTestCase {
    // A fixed one-day period: [1_700_000_000, 1_700_086_400).
    private let start = Date(timeIntervalSince1970: 1_700_000_000)
    private let end = Date(timeIntervalSince1970: 1_700_086_400)
    private let t0 = 1_700_000_000

    private func input(
        _ btx: [BalanceTransaction] = [], _ charges: [Charge] = [],
        _ customers: [Customer] = [], _ payouts: [Payout] = [],
        _ events: [Event] = [], currency: String = "usd"
    ) -> HomeMetricsInput {
        HomeMetricsInput(
            periodStart: start, periodEnd: end, currency: currency,
            balanceTransactions: btx, charges: charges, customers: customers,
            payouts: payouts, events: events
        )
    }

    // MARK: - Ledger figures

    func testUSDLedgerFigures() throws {
        let btx = try [
            Fixture.btx(10_000, created: t0, currency: "usd", category: "charge", type: "charge"),
            Fixture.btx(-300, created: t0, currency: "usd", category: "fee", type: "stripe_fee"),
            Fixture.btx(-500, created: t0, currency: "usd", category: "refund", type: "refund"),
            Fixture.btx(-200, created: t0, currency: "usd", category: "dispute", type: "payment_reversal"),
            // A failed refund returns the money: positive, netted into refunds.
            Fixture.btx(50, created: t0, currency: "usd", category: "refund_failure", type: "refund_failure"),
            // A won dispute returns the money: positive, netted into disputes.
            Fixture.btx(100, created: t0, currency: "usd", category: "dispute_reversal", type: "payment_reversal")
        ]
        let fig = HomeMetrics.compute(input(btx))
        XCTAssertEqual(fig.volume.amount, 10_000)
        XCTAssertEqual(fig.fees.amount, 300)
        // -500 + 50 = -450 → shown as 450.
        XCTAssertEqual(fig.refunds.amount, 450)
        // -200 + 100 = -100 → shown as 100.
        XCTAssertEqual(fig.disputes.amount, 100)
        // 10000 - 300 - 450 - 100 = 9150.
        XCTAssertEqual(fig.net.amount, 9_150)
    }

    func testJPYZeroDecimalMajorUnits() throws {
        // 12345 JPY is twelve thousand three hundred forty-five yen, not 123.45.
        let btx = try [
            Fixture.btx(12_345, created: t0, currency: "jpy", category: "charge", type: "charge")
        ]
        let fig = HomeMetrics.compute(input(btx, currency: "jpy"))
        XCTAssertEqual(fig.volume.majorUnits, Decimal(12_345))
        XCTAssertEqual(fig.volume.currency, "jpy")
    }

    func testEURFigures() throws {
        let btx = try [
            Fixture.btx(1_234, created: t0, currency: "eur", category: "charge", type: "charge"),
            Fixture.btx(-39, created: t0, currency: "eur", category: "fee", type: "stripe_fee")
        ]
        let fig = HomeMetrics.compute(input(btx, currency: "eur"))
        XCTAssertEqual(fig.volume.majorUnits, Decimal(string: "12.34")!)
        XCTAssertEqual(fig.fees.majorUnits, Decimal(string: "0.39")!)
        XCTAssertEqual(fig.net.majorUnits, Decimal(string: "11.95")!)
    }

    // MARK: - Filtering

    func testPeriodFiltering() throws {
        let inside = try Fixture.btx(
            1_000, created: t0, currency: "usd",
            category: "charge", type: "charge", id: "btx_in"
        )
        let atEnd = try Fixture.btx(
            2_000, created: 1_700_086_400, currency: "usd",
            category: "charge", type: "charge", id: "btx_end"
        )
        let after = try Fixture.btx(
            3_000, created: 1_700_086_401, currency: "usd",
            category: "charge", type: "charge", id: "btx_after"
        )
        let fig = HomeMetrics.compute(input([inside, atEnd, after]))
        // Half-open [start, end): only `inside` counts.
        XCTAssertEqual(fig.volume.amount, 1_000)
    }

    func testCurrencyFilter() throws {
        let usd = try Fixture.btx(
            1_000, created: t0, currency: "usd",
            category: "charge", type: "charge", id: "btx_usd"
        )
        let eur = try Fixture.btx(
            2_000, created: t0, currency: "eur",
            category: "charge", type: "charge", id: "btx_eur"
        )
        let fig = HomeMetrics.compute(input([usd, eur], currency: "usd"))
        XCTAssertEqual(fig.volume.amount, 1_000)
        XCTAssertEqual(fig.volume.currency, "usd")
    }

    // MARK: - Type fallback

    func testTypeFallbackWhenCategoryUndocumented() throws {
        // reporting_category is a value the classifier doesn't recognize, so
        // it falls back to the type.
        let btx = try [
            Fixture.btx(1_000, created: t0, currency: "usd", category: "some_new_category", type: "charge"),
            Fixture.btx(-100, created: t0, currency: "usd", category: "some_new_category", type: "stripe_fee")
        ]
        let fig = HomeMetrics.compute(input(btx))
        XCTAssertEqual(fig.volume.amount, 1_000)
        XCTAssertEqual(fig.fees.amount, 100)
    }

    // MARK: - Charge counts

    func testChargeCounts() throws {
        let charges = try [
            Fixture.charge(1_000, created: t0, currency: "usd", status: "succeeded", id: "ch_ok1"),
            Fixture.charge(2_000, created: t0, currency: "usd", status: "succeeded", id: "ch_ok2"),
            Fixture.charge(3_000, created: t0, currency: "usd", status: "failed", id: "ch_fail"),
            Fixture.charge(4_000, created: t0, currency: "usd", status: "pending", id: "ch_pend")
        ]
        let fig = HomeMetrics.compute(input([], charges))
        XCTAssertEqual(fig.successfulPayments, 2)
        XCTAssertEqual(fig.failedPayments, 1)
    }

    // MARK: - Customers

    func testNewCustomers() throws {
        let customers = try [
            Fixture.customer(created: t0, id: "cus_a"),
            Fixture.customer(created: t0 + 10, id: "cus_b"),
            Fixture.customer(created: 1_700_086_401, id: "cus_out")
        ]
        let fig = HomeMetrics.compute(input([], [], customers))
        XCTAssertEqual(fig.newCustomers, 2)
    }

    // MARK: - Payouts

    func testPayoutCategorization() throws {
        let payouts = try [
            Fixture.payout(
                50_000, created: t0, arrival: t0 + 86_400, currency: "usd",
                status: "pending", id: "po_pending"
            ),
            Fixture.payout(
                20_000, created: t0, arrival: t0 + 86_400, currency: "usd",
                status: "in_transit", id: "po_transit"
            ),
            Fixture.payout(
                10_000, created: t0, arrival: t0, currency: "usd",
                status: "paid", id: "po_paid"
            )
        ]
        let fig = HomeMetrics.compute(input([], [], [], payouts))
        XCTAssertEqual(fig.upcomingPayouts.count, 1)
        XCTAssertEqual(fig.upcomingPayouts.first?.id, "po_pending")
        XCTAssertEqual(fig.inTransitPayouts.count, 1)
        XCTAssertEqual(fig.inTransitPayouts.first?.id, "po_transit")
        // "paid" is neither upcoming nor in transit.
        XCTAssertEqual(fig.upcomingPayouts.first?.amount.amount, 50_000)
    }

    // MARK: - Recent activity

    func testRecentActivityOrderAndObject() throws {
        let events = try [
            Fixture.event("charge.succeeded", created: t0, object: "charge", id: "evt_old"),
            Fixture.event("payout.paid", created: t0 + 5, object: "payout", id: "evt_mid"),
            Fixture.event("customer.created", created: t0 + 10, object: "customer", id: "evt_new")
        ]
        let fig = HomeMetrics.compute(input([], [], [], [], events))
        XCTAssertEqual(fig.recentActivity.count, 3)
        // Newest first.
        XCTAssertEqual(fig.recentActivity.first?.type, "customer.created")
        XCTAssertEqual(fig.recentActivity.first?.object, "customer")
        XCTAssertEqual(fig.recentActivity.last?.type, "charge.succeeded")
        XCTAssertEqual(fig.recentActivity.last?.object, "charge")
    }

    func testRecentActivityCapsAtTwenty() throws {
        let events = try (0..<25).map { ix in
            try Fixture.event("charge.succeeded", created: t0 + ix, object: "charge", id: "evt_\(ix)")
        }
        let fig = HomeMetrics.compute(input([], [], [], [], events))
        XCTAssertEqual(fig.recentActivity.count, 20)
        // The 5 oldest are dropped.
        XCTAssertEqual(fig.recentActivity.last?.type, "charge.succeeded")
    }

    // MARK: - Daily volume

    func testDailyVolumeBucketsByUTCDay() throws {
        // Two charges on the same UTC day (2023-11-14, the period starts at
        // 22:13 UTC), one on the next (2023-11-15).
        let day1a = try Fixture.btx(
            1_000, created: 1_700_000_000, currency: "usd",
            category: "charge", type: "charge", id: "btx_d1a"
        )
        let day1b = try Fixture.btx(
            2_000, created: 1_700_005_000, currency: "usd",
            category: "charge", type: "charge", id: "btx_d1b"
        )
        let day2 = try Fixture.btx(
            3_000, created: 1_700_050_000, currency: "usd",
            category: "charge", type: "charge", id: "btx_d2"
        )
        let fig = HomeMetrics.compute(input([day1a, day1b, day2]))
        XCTAssertEqual(fig.dailyVolume.count, 2)
        XCTAssertEqual(fig.dailyVolume[0].amount.amount, 3_000)
        XCTAssertEqual(fig.dailyVolume[1].amount.amount, 3_000)
        // Ascending by day.
        XCTAssertLessThan(fig.dailyVolume[0].day, fig.dailyVolume[1].day)
        // Each day key is the start of its UTC day.
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        for entry in fig.dailyVolume {
            let comps = cal.dateComponents([.hour, .minute, .second], from: entry.day)
            XCTAssertEqual(comps.hour, 0)
            XCTAssertEqual(comps.minute, 0)
            XCTAssertEqual(comps.second, 0)
        }
    }

    // MARK: - Money

    func testMoneyMajorUnits() {
        // Exact Decimal values (Decimal(string:) avoids Double rounding).
        XCTAssertEqual(Money(amount: 12_345, currency: "usd").majorUnits, Decimal(string: "123.45")!)
        XCTAssertEqual(Money(amount: 12_345, currency: "jpy").majorUnits, Decimal(12_345))
        XCTAssertEqual(Money(amount: -500, currency: "usd").absolute.amount, 500)
    }

    func testCurrencyCodeCaseInsensitive() {
        // Stripe returns lowercase codes; the zero-decimal rule must hold
        // regardless of case.
        XCTAssertTrue(Currency.isZeroDecimal("jpy"))
        XCTAssertTrue(Currency.isZeroDecimal("JPY"))
        XCTAssertTrue(Currency.isZeroDecimal("Jpy"))
        XCTAssertFalse(Currency.isZeroDecimal("usd"))
        XCTAssertTrue(Currency.dividesBy100("usd"))
        XCTAssertFalse(Currency.dividesBy100("jpy"))
        // A JPY amount is never divided, even when the code is lowercase.
        XCTAssertEqual(Money(amount: 1_000, currency: "jpy").majorUnits, Decimal(1_000))
        XCTAssertEqual(Money(amount: 1_000, currency: "JPY").majorUnits, Decimal(1_000))
    }

    func testNoDivideSet() {
        // The 15 no-divide currencies are never divided.
        for code in Currency.noDivide {
            XCTAssertEqual(Money(amount: 100, currency: code).majorUnits, Decimal(100))
        }
        // Everything else divides by 100.
        XCTAssertEqual(Money(amount: 100, currency: "usd").majorUnits, Decimal(1))
        XCTAssertEqual(Money(amount: 100, currency: "gbp").majorUnits, Decimal(1))
    }
}
