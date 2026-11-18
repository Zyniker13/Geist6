import Foundation

/// A payout shown on the home dashboard (upcoming or in transit).
public struct PayoutSummary: Sendable, Equatable, Hashable {
    public var id: String
    public var amount: Money
    public var arrivalDate: Date
    public var status: String

    public init(id: String, amount: Money, arrivalDate: Date, status: String) {
        self.id = id
        self.amount = amount
        self.arrivalDate = arrivalDate
        self.status = status
    }
}

/// One row in the recent-activity list.
public struct ActivityItem: Sendable, Equatable, Hashable {
    /// The event type, e.g. "charge.succeeded".
    public var type: String
    /// The object the event concerns, e.g. "charge" or "payout".
    public var object: String
    public var created: Date

    public init(type: String, object: String, created: Date) {
        self.type = type
        self.object = object
        self.created = created
    }
}

/// One bar in the daily-volume chart: a UTC day and the volume that day.
public struct DailyVolume: Sendable, Equatable, Hashable {
    /// The start of the UTC day.
    public var day: Date
    public var amount: Money

    public init(day: Date, amount: Money) {
        self.day = day
        self.amount = amount
    }
}

/// The computed home-dashboard figures for one account, one currency, one
/// period. All money figures are in the selected currency.
public struct HomeFigures: Sendable, Equatable {
    /// Money taken in from sales (charge + partial_capture_reversal).
    public var volume: Money
    /// Stripe fees (fee category).
    public var fees: Money
    /// Net refunds (refund − refund_failure), shown positive.
    public var refunds: Money
    /// Net disputes (dispute − dispute_reversal), shown positive.
    public var disputes: Money
    /// volume − fees − refunds − disputes.
    public var net: Money
    /// Count of charges with status "succeeded" in the period.
    public var successfulPayments: Int
    /// Count of charges with status "failed" in the period.
    public var failedPayments: Int
    /// Count of customers created in the period.
    public var newCustomers: Int
    /// Payouts with status "pending" (scheduled, not yet sent).
    public var upcomingPayouts: [PayoutSummary]
    /// Payouts with status "in_transit".
    public var inTransitPayouts: [PayoutSummary]
    /// The 20 newest events.
    public var recentActivity: [ActivityItem]
    /// Daily volume for the period, one entry per UTC day.
    public var dailyVolume: [DailyVolume]

    public init(
        volume: Money, fees: Money, refunds: Money, disputes: Money, net: Money,
        successfulPayments: Int, failedPayments: Int, newCustomers: Int,
        upcomingPayouts: [PayoutSummary], inTransitPayouts: [PayoutSummary],
        recentActivity: [ActivityItem], dailyVolume: [DailyVolume]
    ) {
        self.volume = volume
        self.fees = fees
        self.refunds = refunds
        self.disputes = disputes
        self.net = net
        self.successfulPayments = successfulPayments
        self.failedPayments = failedPayments
        self.newCustomers = newCustomers
        self.upcomingPayouts = upcomingPayouts
        self.inTransitPayouts = inTransitPayouts
        self.recentActivity = recentActivity
        self.dailyVolume = dailyVolume
    }
}
