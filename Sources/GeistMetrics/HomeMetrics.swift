import Foundation
import StripeModels

/// The raw data the home dashboard needs for one account, one currency, one
/// period. The fetch layer (app target) fills this; the computation here is
/// pure and unit-tested with hand-checked fixtures.
public struct HomeMetricsInput: Sendable {
    /// Half-open period `[start, end)` in absolute time.
    public var periodStart: Date
    public var periodEnd: Date
    /// The selected display currency (ISO-4217).
    public var currency: String
    /// Balance transactions for the period (already filtered server-side by
    /// created range and currency; re-filtered here defensively).
    public var balanceTransactions: [BalanceTransaction]
    /// Charges for the period.
    public var charges: [Charge]
    /// Customers created in the period.
    public var customers: [Customer]
    /// Payouts (all statuses; categorized here).
    public var payouts: [Payout]
    /// Recent events (last 30 days).
    public var events: [Event]

    public init(
        periodStart: Date, periodEnd: Date, currency: String,
        balanceTransactions: [BalanceTransaction], charges: [Charge],
        customers: [Customer], payouts: [Payout], events: [Event]
    ) {
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.currency = currency
        self.balanceTransactions = balanceTransactions
        self.charges = charges
        self.customers = customers
        self.payouts = payouts
        self.events = events
    }
}

/// Pure computation of the home-dashboard figures. No network, no clock:
/// the period is supplied, so the result is deterministic and testable.
public enum HomeMetrics {

    /// Which home figure a balance transaction feeds.
    private enum Bucket {
        case volume, fee, refund, dispute, other
    }

    /// Classify a balance transaction by `reporting_category` first, falling
    /// back to `type` when the category is empty or undocumented.
    private static func bucket(_ btx: BalanceTransaction) -> Bucket {
        switch btx.reportingCategory {
        case "charge", "partial_capture_reversal": return .volume
        case "fee": return .fee
        case "refund", "refund_failure": return .refund
        case "dispute", "dispute_reversal": return .dispute
        default: return bucketByType(btx.type)
        }
    }

    /// Fallback classification by `type`, per the reporting-categories
    /// page's type→category table. Anything not listed is excluded.
    private static func bucketByType(_ type: BalanceTransactionType) -> Bucket {
        switch type {
        case .charge, .payment: return .volume
        case .refund, .paymentRefund, .paymentFailureRefund: return .refund
        case .paymentReversal: return .dispute
        case .stripeFee: return .fee
        default: return .other
        }
    }

    /// Compute the figures for the given input.
    public static func compute(_ input: HomeMetricsInput) -> HomeFigures {
        let cur = input.currency
        let inPeriod = { (ts: StripeTimestamp) in
            let date = ts.date
            return date >= input.periodStart && date < input.periodEnd
        }

        // Ledger figures, summed in the smallest unit.
        var volume = 0
        var fees = 0
        var refunds = 0
        var disputes = 0
        var daily: [Date: Int] = [:]

        for btx in input.balanceTransactions where btx.currency == cur && inPeriod(btx.created) {
            switch bucket(btx) {
            case .volume:
                volume += btx.amount
                daily[startOfUTCDay(btx.created.date), default: 0] += btx.amount
            case .fee:
                fees += btx.amount
            case .refund:
                refunds += btx.amount
            case .dispute:
                disputes += btx.amount
            case .other:
                break
            }
        }

        // Refunds, disputes and fees are netted in the ledger (negative =
        // money leaving); the figures are shown as positive magnitudes.
        let refundsMoney = Money(amount: Swift.abs(refunds), currency: cur)
        let disputesMoney = Money(amount: Swift.abs(disputes), currency: cur)
        let volumeMoney = Money(amount: volume, currency: cur)
        let feesMoney = Money(amount: Swift.abs(fees), currency: cur)
        let netMoney = Money(
            amount: volume - Swift.abs(fees) - Swift.abs(refunds) - Swift.abs(disputes),
            currency: cur
        )

        // Charge counts.
        var succeeded = 0
        var failed = 0
        for charge in input.charges where inPeriod(charge.created) {
            switch charge.status {
            case .succeeded: succeeded += 1
            case .failed: failed += 1
            default: break
            }
        }

        // New customers.
        let newCustomers = input.customers
            .filter { inPeriod($0.created) }
            .count

        // Payouts by status.
        var upcoming: [PayoutSummary] = []
        var inTransit: [PayoutSummary] = []
        for payout in input.payouts {
            let summary = PayoutSummary(
                id: payout.id,
                amount: Money(amount: payout.amount, currency: payout.currency),
                arrivalDate: payout.arrivalDate.date,
                status: payout.status
            )
            switch payout.status {
            case "pending": upcoming.append(summary)
            case "in_transit": inTransit.append(summary)
            default: break
            }
        }

        // Recent activity: the 20 newest events.
        let activity = input.events
            .sorted { $0.created.date > $1.created.date }
            .prefix(20)
            .map { event in
                ActivityItem(
                    type: event.type.rawValue,
                    object: objectType(of: event),
                    created: event.created.date
                )
            }

        // Daily volume, one entry per UTC day, ascending.
        let dailyVolume = daily
            .map { DailyVolume(day: $0.key, amount: Money(amount: $0.value, currency: cur)) }
            .sorted { $0.day < $1.day }

        return HomeFigures(
            volume: volumeMoney,
            fees: feesMoney,
            refunds: refundsMoney,
            disputes: disputesMoney,
            net: netMoney,
            successfulPayments: succeeded,
            failedPayments: failed,
            newCustomers: newCustomers,
            upcomingPayouts: upcoming,
            inTransitPayouts: inTransit,
            recentActivity: Array(activity),
            dailyVolume: dailyVolume
        )
    }

    /// The object type an event concerns, from the event data when present,
    /// else the prefix of the event type (e.g. "charge" from
    /// "charge.succeeded").
    private static func objectType(of event: Event) -> String {
        if let fromData = event.data.object.unknownFields?["object"]?.stringValue {
            return fromData
        }
        let prefix = event.type.rawValue.split(separator: ".").first
        return prefix.map(String.init) ?? "unknown"
    }

    /// The start of the UTC day containing `date`.
    private static func startOfUTCDay(_ date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return calendar.date(from: components) ?? date
    }
}
