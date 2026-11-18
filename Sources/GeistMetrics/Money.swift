import Foundation

/// A money amount in a single currency, held in the currency's smallest
/// unit (the unit the Stripe API uses). Display formatting is the UI
/// layer's job; this type only carries the value and the divide rule.
public struct Money: Sendable, Equatable, Hashable {
    /// The amount in the currency's smallest unit (e.g. cents). May be
    /// negative for money leaving the account.
    public var amount: Int
    /// ISO-4217 currency code, e.g. "USD".
    public var currency: String

    public init(amount: Int, currency: String) {
        self.amount = amount
        self.currency = currency
    }

    /// Whether this currency's API amount is already the major unit
    /// (no divide by 100).
    public var isZeroDecimal: Bool {
        Currency.isZeroDecimal(currency)
    }

    /// The major-unit value, e.g. 12345 cents → 123.45, 12345 JPY → 12345.
    public var majorUnits: Decimal {
        isZeroDecimal ? Decimal(amount) : Decimal(amount) / 100
    }

    /// The absolute value (used to show refunds/disputes as positive).
    public var absolute: Money {
        Money(amount: Swift.abs(amount), currency: currency)
    }
}
