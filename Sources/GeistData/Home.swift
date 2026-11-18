import Foundation
import GeistMetrics
import StripeModels

/// A selectable time window for the home dashboard.
public enum HomePeriod: String, CaseIterable, Sendable, Identifiable {
    case last7Days
    case last30Days
    case last90Days
    case last12Months

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .last7Days: return "7 days"
        case .last30Days: return "30 days"
        case .last90Days: return "90 days"
        case .last12Months: return "12 months"
        }
    }

    /// The half-open interval `[start, end)` ending at `now`.
    public func interval(now: Date) -> DateInterval {
        let seconds: TimeInterval
        switch self {
        case .last7Days: seconds = 7 * 86_400
        case .last30Days: seconds = 30 * 86_400
        case .last90Days: seconds = 90 * 86_400
        case .last12Months: seconds = 365 * 86_400
        }
        return DateInterval(start: now.addingTimeInterval(-seconds), end: now)
    }
}

/// Everything the home dashboard shows for one account, one period, one currency.
public struct HomeSnapshot: Sendable {
    /// A balance line for a single currency.
    public struct CurrencyBalance: Sendable, Identifiable, Equatable {
        public var currency: String
        public var available: Money
        public var pending: Money
        public var id: String { currency }
    }

    public var balances: [CurrencyBalance]
    public var figures: HomeFigures
    public var payments: [Charge]
    public var customers: [Customer]
    public var payouts: [Payout]
    public var activity: [ActivityItem]

    public init(
        balances: [CurrencyBalance],
        figures: HomeFigures,
        payments: [Charge],
        customers: [Customer],
        payouts: [Payout],
        activity: [ActivityItem]
    ) {
        self.balances = balances
        self.figures = figures
        self.payments = payments
        self.customers = customers
        self.payouts = payouts
        self.activity = activity
    }
}

/// Loads a `HomeSnapshot` from a `StripeDataBackend`.
///
/// All reads are issued concurrently and the figures are computed by
/// `HomeMetrics` from the balance-transaction ledger, per `docs/metrics.md`.
public struct HomeDataLoader: Sendable {
    public let backend: any StripeDataBackend

    public init(backend: any StripeDataBackend) {
        self.backend = backend
    }

    /// Load the dashboard for `period` and the primary `currency`.
    ///
    /// The currency drives the ledger figures; balances are shown for every
    /// currency the account holds.
    public func load(period: DateInterval, currency: String) async throws -> HomeSnapshot {
        async let balance = backend.retrieveBalance()
        async let transactions = backend.balanceTransactions(created: period, currency: currency)
        async let chargeList = backend.charges(created: period)
        async let customerList = backend.customers(created: period, email: nil)
        async let payoutList = backend.payouts()
        async let eventList = backend.events(created: period)

        let (bal, btx, rawCharges, rawCustomers, payouts, rawEvents) = try await (
            balance, transactions, chargeList, customerList, payoutList, eventList
        )

        // The server is asked to filter by `created`, but not every backend
        // (including stripe-mock) honors it, so filter defensively here.
        let charges = Self.inPeriod(rawCharges, period, \.created)
        let customers = Self.inPeriod(rawCustomers, period, \.created)
        let events = Self.inPeriod(rawEvents, period, \.created)

        let input = HomeMetricsInput(
            periodStart: period.start,
            periodEnd: period.end,
            currency: currency,
            balanceTransactions: btx,
            charges: charges,
            customers: customers,
            payouts: payouts,
            events: events
        )
        let figures = HomeMetrics.compute(input)

        return HomeSnapshot(
            balances: Self.balances(from: bal),
            figures: figures,
            payments: charges,
            customers: customers,
            payouts: payouts,
            activity: figures.recentActivity
        )
    }

    /// Collapse the balance object's per-currency `available`/`pending` arrays
    /// into one line per currency, sorted by code.
    static func balances(from balance: Balance) -> [HomeSnapshot.CurrencyBalance] {
        var availableByCurrency: [String: Int] = [:]
        for amount in balance.available {
            availableByCurrency[amount.currency, default: 0] += amount.amount
        }
        var pendingByCurrency: [String: Int] = [:]
        for amount in balance.pending {
            pendingByCurrency[amount.currency, default: 0] += amount.amount
        }
        let currencies = Set(availableByCurrency.keys).union(pendingByCurrency.keys).sorted()
        return currencies.map { code in
            HomeSnapshot.CurrencyBalance(
                currency: code,
                available: Money(amount: availableByCurrency[code, default: 0], currency: code),
                pending: Money(amount: pendingByCurrency[code, default: 0], currency: code)
            )
        }
    }

    /// Keep only the objects whose `created` timestamp falls in `period`.
    private static func inPeriod<T>(
        _ objects: [T], _ period: DateInterval, _ created: KeyPath<T, StripeTimestamp>
    ) -> [T] {
        objects.filter {
            let date = $0[keyPath: created].date
            return date >= period.start && date < period.end
        }
    }
}
